#!/usr/bin/env bash
# Copies the approved Nexus Voice speech models from their pinned upstream
# source into your organization's Azure Blob container, checking each file's
# size and SHA-256 against edition/intune/models.json first. Run it from
# Azure Cloud Shell (it has az and azcopy) or any machine with both:
#
#   ./mirror-to-azure.sh <storage-account> <container> [model-id ...]
#
# Default models: parakeet-unified-english parakeet-v3 speech-detector.
# The container should be private; laptops read it with a read-only SAS
# token (see README.md). Re-run after an upstream sync that changes a pin.
set -euo pipefail

account=${1:?Usage: $0 <storage-account> <container> [model-id ...]}
container=${2:?Usage: $0 <storage-account> <container> [model-id ...]}
shift 2
ids=("$@")
[ ${#ids[@]} -eq 0 ] && ids=(parakeet-unified-english parakeet-v3 speech-detector)

here=$(cd "$(dirname "$0")" && pwd)
manifest="$here/models.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

az storage container create --account-name "$account" --name "$container" \
  --public-access off --auth-mode login --only-show-errors >/dev/null

for id in "${ids[@]}"; do
  read -r file bytes sha source < <(python3 -c '
import json, sys
m = {x["id"]: x for x in json.load(open(sys.argv[1]))["models"]}[sys.argv[2]]
print(m["file"], m["bytes"], m["sha256"], m["source"])' "$manifest" "$id")
  echo "==> $id ($file, $((bytes / 1000000)) MB)"
  curl -fL --retry 4 -o "$work/$file" "$source"
  [ "$(stat -c %s "$work/$file" 2>/dev/null || stat -f %z "$work/$file")" = "$bytes" ] \
    || { echo "size mismatch for $file" >&2; exit 1; }
  echo "$sha  $work/$file" | sha256sum -c - >/dev/null 2>&1 \
    || echo "$sha  $work/$file" | shasum -a 256 -c - >/dev/null \
    || { echo "SHA-256 mismatch for $file" >&2; exit 1; }
  azcopy copy "$work/$file" "https://$account.blob.core.windows.net/$container/$file" \
    --overwrite ifSourceNewer --log-level ERROR
  rm -f "$work/$file"
done
azcopy copy "$manifest" "https://$account.blob.core.windows.net/$container/models.json" --overwrite true --log-level ERROR
echo "Done. Container URL: https://$account.blob.core.windows.net/$container"
