# Nexus Voice

Nexus Voice is our office edition of [Hex](https://github.com/anomalyco/hex)
(MIT): private, on-device dictation for Windows and Mac. Hold a key, speak,
let go, and it types into whatever app you're in. Nothing you say leaves the
computer.

This folder holds everything that makes the fork its own. The rest of the
repository is upstream Hex, kept as close to `anomalyco/hex` as possible so
upstream fixes keep flowing in (see [UPSTREAM.md](UPSTREAM.md)).

## What the edition changes

One build-time switch, `HEX_EDITION_NAME="Nexus Voice"`, turns a Hex build
into Nexus Voice. Without it the code builds plain Hex, unchanged.

```ts
HEX_EDITION_NAME="Nexus Voice"
├─ name ............ window title, tray, macOS menus, Windows file info,
│                    "Nexus Voice · powered by Hex" in the sidebar footer
├─ updates ......... off ("Managed by your organization"): Anomaly's release
│                    service would otherwise replace it with Hex. New
│                    versions come from this fork's Releases page.
├─ icon ............ edition/assets (app.ico, AppIcon.icns, app-icon.svg)
├─ macOS bundle .... "Nexus Voice.app", bundle ID nexus.voice
│                    (HEX_EDITION_BUNDLE_ID), own permissions and login item
├─ Windows setup ... nexus-voice-setup-<version>-windows-x64.exe, own
│                    Apps & Features entry and %APPDATA%\nexus-voice folder
└─ models .......... read in place from the IT-managed folder
                     (%ProgramData%\Nexus Voice\models, /Library/Application
                     Support/Nexus Voice/models), pinned SHA-256 checked;
                     anything else downloads from HEX_EDITION_MODEL_MIRROR
                     (TE's Azure Blob) instead of Hugging Face
```

Rolling out with Intune, including the models from Azure: [intune/README.md](intune/README.md).

Code touch points (keep them this small when merging upstream):

- `src/edition.rs`: the switch itself
- `src/transcription/models.rs` (`model_path`, `speech_detector_path`,
  `download_url`): the managed models folder and the mirror
- `src/updater.rs` (`managed_by_policy`), `src/rune_ui.rs` (window title),
  `src/rune_ui/sidebar.rs` (`edition_mark`), `src/app_paths.rs`
  (`app_name`), `src/windows/rune.rs` (tray), `src/macos_rune/status_item.rs`
  (menu title), `build.rs` (Windows file info and icon)
- `scripts/build-app.sh`: two lines that source `edition/macos.sh`
- `.github/workflows/nexus-voice.yml`: the release workflow
- `edition/windows/nexus-voice.iss`: the installer, derived from
  `packaging/windows/hex.iss`

Inside the app most copy still says "Hex" (onboarding, settings). That is
deliberate: renaming hundreds of translated strings would conflict with every
upstream change. Nexus Voice presents Hex as its engine.

Settings, History, and downloaded speech models live in the same data folder
as Hex (`%APPDATA%\hex`, `~/Library/Application Support/hex`). Don't run
Hex and Nexus Voice on the same computer at once; only one can listen.

## Releasing a new version

1. In GitHub: **Actions → Nexus Voice release → Run workflow** (on `dev`).
   Or push a tag: `git tag nexus-v3.3.0-1 && git push origin nexus-v3.3.0-1`.
2. About 40 minutes later the release appears under **Releases** with:
   - `nexus-voice-setup-<version>-windows-x64.exe` (installer)
   - `nexus-voice-<version>-windows-x64-portable.exe` (runs without installing)
   - `nexus-voice-<version>-macos-arm64.dmg` and `.zip`
   - `SHA256SUMS`
3. Send colleagues the release link and [INSTALL.md](INSTALL.md), or the
   download page in [site/index.html](site/index.html).

Forks start with Actions turned off. Turn them on under **Actions**, then
disable the upstream workflows you don't need (Release, Test builds,
Installers, Site, Release TypeScript SDK, Legacy appcast): they publish to
Anomaly's services and fail here without its secrets. Keep **Nexus Voice
release** and, if you like, **Compile**.

## Signing (before a company-wide rollout)

The workflow's builds are unsigned, so Windows SmartScreen and macOS
Gatekeeper warn once on first launch. For a rollout to everyone:

- **Windows:** have IT sign `hex.exe` and the setup `.exe` with the
  company's code-signing certificate, or deploy through Intune / SCCM,
  which skips SmartScreen.
- **macOS:** build with an Apple Developer ID
  (`HEX_TEAM_ID=<team> HEX_EDITION_NAME="Nexus Voice" scripts/build-app.sh`,
  then notarize), or deploy through the company's MDM (Jamf, Intune). An
  unsigned Mac app also loses its Microphone and Accessibility grants after
  each update.

Check with IT before sending it company-wide: dictation reads the
microphone and pastes into other apps, which security teams want to know
about. The speech model runs on the device, and Hex makes no network requests
except to download the model and, if you turn them on, optional features.

## Building locally

```sh
# macOS (Xcode 26):
HEX_RELEASE_UNSIGNED=1 HEX_EDITION_NAME="Nexus Voice" scripts/build-app.sh
# Windows (Git Bash, Vulkan SDK):
HEX_EDITION_NAME="Nexus Voice" scripts/build-windows.sh
pwsh edition/windows/build-installer.ps1 -Executable dist/hex-<v>-windows-x64.exe -Version <v> -Arch x86_64 -OutDir dist
```

The icon's source is `assets/app-icon.svg`; `app.ico`, `AppIcon.icns`, and
`app-512.png` are rendered from it.
