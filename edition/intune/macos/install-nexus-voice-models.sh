#!/bin/bash
# Intune macOS shell script (run as signed-in user: No, so it runs as root):
# installs Nexus Voice speech models machine-wide in
# /Library/Application Support/Nexus Voice/models, readable by everyone and
# writable only by root. Downloads each from your Azure Blob container and
# checks its size and SHA-256 first; files already in place are skipped, so
# Intune can run it on a schedule ("Script frequency") to repair a laptop.
#
# Fill in BASE_URL and SAS below before uploading it to Intune.
set -euo pipefail

BASE_URL="https://<account>.blob.core.windows.net/<container>"
SAS=""   # read-only SAS token, without the leading '?'

target="/Library/Application Support/Nexus Voice/models"
log="/Library/Logs/Nexus Voice models.log"
# file  bytes  sha256 (from edition/intune/models.json)
MODELS="
parakeet-unified-en-0.6b-Q8_0.gguf 731357568 4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795
parakeet-tdt-0.6b-v3-Q8_0.gguf 739508576 5859f77944efcd8eafa23a6350731960b2b55b2203df51f319665c807d802cc7
silero-vad-v6.2-F32.gguf 1241056 0d871a800c420fdd5d1b17a3aea4296d1c39608f0ff4a9295eb76457eb1c88e6"

say() { echo "$(date '+%F %T') $*" | tee -a "$log"; }
mkdir -p "$target"
query=""; [ -n "$SAS" ] && query="?${SAS#\?}"

echo "$MODELS" | while read -r file bytes sha; do
  [ -z "$file" ] && continue
  dest="$target/$file"
  if [ -f "$dest" ] && [ "$(stat -f %z "$dest")" = "$bytes" ] \
     && [ "$(shasum -a 256 "$dest" | cut -d' ' -f1)" = "$sha" ]; then
    say "$file already installed"
    continue
  fi
  say "downloading $file ($((bytes / 1000000)) MB)"
  curl -fL --retry 4 --retry-delay 5 -o "$dest.partial" "${BASE_URL%/}/$file$query"
  if [ "$(stat -f %z "$dest.partial")" != "$bytes" ]; then
    rm -f "$dest.partial"; say "$file has the wrong size"; exit 1
  fi
  if [ "$(shasum -a 256 "$dest.partial" | cut -d' ' -f1)" != "$sha" ]; then
    rm -f "$dest.partial"; say "$file failed its SHA-256 check"; exit 1
  fi
  mv -f "$dest.partial" "$dest"
  say "$file installed and verified"
done

chown -R root:wheel "/Library/Application Support/Nexus Voice"
chmod -R 755 "/Library/Application Support/Nexus Voice"
find "$target" -type f -exec chmod 644 {} +
say "done"
