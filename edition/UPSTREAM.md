# Following upstream Hex

Nexus Voice tracks [`anomalyco/hex`](https://github.com/anomalyco/hex)
branch `dev`. Every day a scheduled Claude task reviews the new upstream
commits, decides which ones belong in Nexus Voice, and opens a pull request
on this fork's `dev` branch for a human to merge. Nothing reaches `dev`
without that merge.

## The daily review

```ts
upstream/dev has new commits since the last sync?
├─ no ───────────── stop; nothing to do
└─ yes
   ├─ branch upstream-sync/<YYYY-MM-DD> from origin/dev
   ├─ merge upstream/dev (one merge commit keeps future merges cheap)
   ├─ revert, on that branch, each commit the rubric below rejects
   ├─ resolve conflicts in the edition's touch points (edition/README.md)
   ├─ carry packaging/windows/hex.iss changes into edition/windows/nexus-voice.iss
   ├─ cargo check, and with HEX_EDITION_NAME="Nexus Voice", cargo clippy --bin hex
   └─ open a PR: "Upstream sync <date>", one line per commit: taken / skipped + why
```

Prefer merging over cherry-picking: a merge records that the fork has seen
those commits, so tomorrow's review starts where today's ended, and git
resolves later upstream changes against them. A rejected commit is merged and
then reverted, which records the decision.

## Rubric

Take (the default):

- bug fixes, crash fixes, security fixes, dependency and Rune pin bumps
- dictation, transcription, model, paste, microphone, and shortcut
  improvements on **Windows or macOS**
- new Labs features (they ship off by default, so they cost office users
  nothing)
- translations, accessibility, and UI polish
- Linux-only changes (harmless: Nexus Voice doesn't ship Linux, and keeping
  them avoids conflicts later)

Skip (revert on the sync branch, say why in the PR):

- changes that only make sense for Anomaly's own publishing: release
  service uploads, website (`site/`), Homebrew/AUR/legacy appcast, signing
  with Anomaly's keys, TypeScript SDK releases. Keep them when they don't
  touch anything the edition builds or runs; skip only what would fail or
  publish from this fork.
- anything that turns on network access, telemetry, or cloud processing by
  default
- anything that would remove or bypass the edition switch (`src/edition.rs`):
  the updater must stay off for edition builds

Flag for a human (take it, but call it out at the top of the PR):

- changes to data formats, settings migrations, or the data folder
- new permission prompts (microphone, screen recording, accessibility)
- large UI redesigns, renamed features, or removed features
- version bumps (time to cut a new Nexus Voice release)

## By hand

```sh
git remote add upstream https://github.com/anomalyco/hex.git   # once
git fetch upstream dev
git log --oneline origin/dev..upstream/dev                     # what's new
git switch -c upstream-sync/$(date +%F) origin/dev
git merge upstream/dev
```

After merging a sync PR that bumps the version, run the **Nexus Voice
release** workflow (edition/README.md) to hand out the new build.
