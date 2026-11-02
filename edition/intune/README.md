# Managing Nexus Voice and its models with Intune

IT installs the app and its speech models with Intune. The models come from
TE's own Azure storage, so people never download one and never see a model
step in setup.

```ts
Azure Blob container (TE tenant)
└─ mirror-to-azure.sh ........ copies the approved models, SHA-256 checked
   │
   ├─ Intune Win32 app "Nexus Voice models" (System)
   │   └─ Install-NexusVoiceModels.ps1 → %ProgramData%\Nexus Voice\models
   ├─ Intune macOS shell script (root)
   │   └─ install-nexus-voice-models.sh → /Library/Application Support/Nexus Voice/models
   │
   └─ Nexus Voice on the laptop
       ├─ finds its model in that folder → uses it in place, read-only,
       │  checks its SHA-256 once before first use, never downloads
       └─ missing a model (another language) → downloads it from the
          same container if the build has a mirror (HEX_EDITION_MODEL_MIRROR),
          never from Hugging Face
```

What stays the same: transcription runs on the laptop. Audio never goes to
Azure or anywhere else. Azure only stores the model files.

## The models

`models.json` lists every model Nexus Voice can run, each pinned by file
name, size, and SHA-256 in the app's source. The default bundle covers
English and most European languages (about 1.5 GB):

| id | language | size |
| --- | --- | --- |
| `parakeet-unified-english` | English (the default) | 731 MB |
| `parakeet-v3` | German, French, Spanish, Italian, Polish, Czech, Dutch, Portuguese and 16 more European languages | 740 MB |
| `speech-detector` | skips silent recordings, all languages | 1 MB |

Add others by id when offices need them, for example `whisper` (Japanese,
Arabic, Turkish, Swedish, Finnish, Danish), `qwen` (Chinese, Korean,
Vietnamese), or `gigaam-v3-e2e-rnnt` (Russian). Each model has its own
licence (shown in the app's model details). Check the licences with legal
before you redistribute a model inside the company.

After an upstream sync that changes a model pin, run
`python3 edition/intune/make-manifest.py`, then mirror and redeploy. The app
refuses a file that doesn't match its pin.

## 1. Create the container and mirror the models

In Azure Cloud Shell (Bash), from a checkout of this repository:

```sh
az storage account create -n nexusvoicemodels -g <resource-group> -l westeurope \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access true
edition/intune/mirror-to-azure.sh nexusvoicemodels models
```

Pick how laptops read it:

- **Intune scripts only (most locked down):** keep the container private and
  give the scripts a read-only SAS token (Storage account → Shared access
  signature → Blob, Read, an expiry you'll renew). Turn off the in-app
  fallback by building without `HEX_EDITION_MODEL_MIRROR`; a laptop then has
  only the models IT installed.
- **Intune plus in-app fallback:** set the container's access level to
  *Blob (anonymous read)* and, under Networking, allow only TE's office and
  VPN address ranges. The app can't carry a secret, and the model files are
  public open-source weights anyway. Then set the repository variable
  `NEXUS_MODEL_MIRROR` to `https://nexusvoicemodels.blob.core.windows.net/models`
  (GitHub → Settings → Secrets and variables → Actions → Variables) before
  running the release workflow.

## 2. Deploy the models (Windows)

1. Put `windows/Install-NexusVoiceModels.ps1` and `models.json` in one
   folder and wrap it with the
   [Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool):
   `IntuneWinAppUtil.exe -c <folder> -s Install-NexusVoiceModels.ps1 -o <out>`.
2. Intune → Apps → Windows → Add → *Windows app (Win32)*:
   - Install command:
     `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-NexusVoiceModels.ps1 -BaseUrl "https://nexusvoicemodels.blob.core.windows.net/models" -Sas "<token>"`
   - Uninstall command:
     `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-NexusVoiceModels.ps1 -Uninstall`
   - Install behavior: **System**. Device restart: no.
   - Detection rules: custom script `windows/Detect-NexusVoiceModels.ps1`.
   - Add `-Models parakeet-unified-english,parakeet-v3,speech-detector,whisper`
     to the install command for more languages; the detection script checks
     only the default three.
3. Assign it to the same group as the app. Log: `%ProgramData%\Nexus Voice\models-install.log`.

## 3. Deploy the models (Mac)

1. Fill in `BASE_URL` and `SAS` at the top of
   `macos/install-nexus-voice-models.sh`.
2. Intune → Devices → macOS → Shell scripts → Add: upload it, *Run script as
   signed-in user: No*, *Script frequency: every 1 day* (it skips files
   already in place and repairs missing ones), *Max retries: 3*.
3. Log: `/Library/Logs/Nexus Voice models.log`.

## 4. Deploy the app

- **Windows:** `nexus-voice-setup-<version>-windows-x64.exe` from the
  release, as a Win32 app with install behavior **User** (it installs per
  user, no admin rights):
  - Install: `nexus-voice-setup-<version>-windows-x64.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART`
  - Uninstall: `"%APPDATA%\nexus-voice\uninstall\unins000.exe" /VERYSILENT`
  - Detection: file `%APPDATA%\nexus-voice\versions\<version>\hex.exe` exists.
  - The installer stops when the PC has no Vulkan graphics driver; add
    `/SKIPVULKANCHECK=1` only for machines you know transcribe on the CPU.
- **Mac:** the release's `nexus-voice-<version>-macos-arm64.pkg` as a macOS
  app (PKG). Intune requires the package to be signed with an Apple
  *Developer ID Installer* certificate, so sign it first (edition/README.md,
  "Signing"). Also push a PPPC profile that allows Accessibility for
  bundle ID `nexus.voice` so people aren't asked; macOS never lets a
  profile pre-grant the Microphone, so people still click Allow once.

A new version is a new release: upload its installer as a new app version
(or supersedence) in Intune. Nexus Voice never updates itself.

## Checking a laptop

- `%ProgramData%\Nexus Voice\models` (Windows) or
  `/Library/Application Support/Nexus Voice/models` (Mac) holds the files.
- In Nexus Voice → General, the model shows as installed with no Download
  button. In the model picker it offers *Forget* instead of *Delete*, and
  people can't remove IT's copy.
- Hex's log (`%APPDATA%\hex\logs\process.log`, `~/Library/Application Support/hex/logs/process.log`)
  records the SHA-256 check on first use.

## 5. Lock settings (policy)

IT sets these centrally; people see the feature off and can't turn it on.
They read as **off** when unset.

| Key | Effect | Recommended for rollout |
| --- | --- | --- |
| `ManagedModelsOnly` | Never download a speech model; use only IT's models | **On** |
| `DisableLabs` | All experimental (Labs) features off | **On** |
| `DisableOpenCodeProcessing` | No AI rewriting through OpenCode | **On** |
| `DisableTransforms` | No text transformations or user scripts | **On** |
| `RestrictTransformsToLoopback` | Transformations allowed, but only reach this computer and run no programs | Instead of the line above, if you want them |
| `DisableMeetings` | No meeting recording | Your call (legal/works council) |
| `DisableAnnotate` | No screen-recording captures | Your call |

- **Windows:** Intune → Devices → Configuration → *Import ADMX*: upload
  `policy/NexusVoice.admx` and `policy/en-US/NexusVoice.adml`, then create
  a profile from *Templates → Imported Administrative templates* and enable
  the policies above. They land as DWORDs under
  `HKLM\SOFTWARE\Policies\Nexus Voice`, which only administrators can
  write. (Group Policy works too: copy both files to the PolicyDefinitions
  store.)
- **Mac:** Intune → Devices → macOS → Configuration → *Templates → Custom*:
  upload `policy/nexus-voice.mobileconfig` (it turns on the four
  recommended keys; edit it to change that). macOS reads them as forced
  managed preferences in the `nexus.voice` domain; a value a person writes
  with `defaults write` locks nothing.

The app logs the locks it found at start ("features managed by your
organization") in `process.log`.

## Rolling out to thousands of laptops

```ts
Ring 0  IT + you (10)          ── a week: install, models, policy, every app people dictate into
Ring 1  one office (100–200)   ── two weeks: helpdesk questions, odd hardware, VPN/proxy
Ring 2  everyone (by region)   ── Intune assignment groups, one region at a time
```

- **Before Ring 1:** sign the Windows installer with TE's code-signing
  certificate and the Mac app with a Developer ID (edition/README.md,
  "Signing"). Unsigned builds work but train people to click through
  security warnings, which security teams rightly dislike at this scale.
- **Hardware floor:** the Windows build needs a Vulkan graphics driver
  (any NVIDIA, AMD, or Intel driver from the last few years). Laptops
  without one fail the installer's check; find them in Ring 1.
- **Disk:** about 1.5 GB per laptop for the default models, installed once
  by Intune (BITS downloads in the background and resumes).
- **Network:** in this setup the app shouldn't need the internet: models
  come from Intune, updates are off, and the locks above turn off the
  optional network features. Block Hugging Face and Anomaly's servers, and
  confirm in Ring 0 with a firewall log that nothing else is contacted.
- **Updates:** a new Nexus Voice version is a new Intune app version. Roll
  it through the same rings. The daily upstream review flags when one is
  worth releasing (edition/UPSTREAM.md).
- **Support:** each laptop keeps its own logs (`%APPDATA%\hex\logs`,
  `~/Library/Application Support/hex/logs`); nothing is collected
  centrally, so helpdesk asks for `process.log` when something fails.
- **Data protection:** dictated text is kept for 7 days in History on the
  laptop only (people can turn it off or clear it); no audio is stored.
  Give your DPO / works council this page and `edition/README.md`.
