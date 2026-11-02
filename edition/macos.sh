# Sourced by scripts/build-app.sh when HEX_EDITION_NAME is set: the office
# edition's name, bundle identifier, URL scheme, and icon. Kept out of the
# upstream script so merging anomalyco/hex stays a two-line conflict at most.
#
# A different bundle identifier makes macOS treat the edition as its own app
# (its own permissions and login item), so it never borrows Hex's grants.
app_name=$HEX_EDITION_NAME
bundle_id=${HEX_EDITION_BUNDLE_ID:-nexus.voice}

# Called after the bundle's icon is copied, before it is signed.
edition_finish_bundle() {
  plist="$bundle/Contents/Info.plist"
  # The flat .icns, not Icon Composer's Assets.car: macOS falls back to
  # CFBundleIconFile when CFBundleIconName is absent.
  rm -f "$bundle/Contents/Resources/Assets.car"
  cp "$root/edition/assets/AppIcon.icns" "$bundle/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$plist" 2>/dev/null || true
  scheme=$(printf '%s' "$app_name" | tr '[:upper:] ' '[:lower:]-')
  /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $scheme" "$plist"
  plutil -replace NSCameraUsageDescription -string "$app_name mirrors and records a cabled iPhone's screen for a capture." "$plist"
}
