#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${JELLYBOY_BUILD_ROOT:-$root/.build/verify}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing $1. $2" >&2
    exit 1
  fi
}

require_command xcodegen "Install XcodeGen 2.45 or later."
require_command swiftlint "Install SwiftLint 0.65 or later."
require_command oxfmt "Install oxfmt 0.57 or later."

cd "$root"

generated_hashes_before="$(shasum jellyboy.xcodeproj/project.pbxproj Info.plist)"
xcodegen --spec project.yml
generated_hashes_after="$(shasum jellyboy.xcodeproj/project.pbxproj Info.plist)"
if [[ "$generated_hashes_before" != "$generated_hashes_after" ]]; then
  echo "Generated Xcode files are stale. Run xcodegen and commit the result." >&2
  exit 1
fi

icon_paths=(Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-*.png)
icon_source_before="$(shasum Design/AppIcon.svg)"
icon_pixels_before="$(
  swift "$root/script/hash_image_pixels.swift" "${icon_paths[@]}" |
    shasum -a 256 |
    awk '{print $1}'
)"
"$root/script/generate_app_icons.swift"
icon_source_after="$(shasum Design/AppIcon.svg)"
icon_pixels_after="$(
  swift "$root/script/hash_image_pixels.swift" "${icon_paths[@]}" |
    shasum -a 256 |
    awk '{print $1}'
)"
if [[ "$icon_source_before" != "$icon_source_after" ]]; then
  echo "Generated app icon source was stale. Regenerate and commit it." >&2
  exit 1
fi
if [[ "$icon_pixels_before" != "$icon_pixels_after" ]]; then
  echo "Generated app icons were stale. Regenerate and commit them." >&2
  exit 1
fi

for icon in "${icon_paths[@]}"; do
  if [[ "$(sips -g hasAlpha "$icon" 2>/dev/null | awk '/hasAlpha/ {print $2}')" != "no" ]]; then
    echo "App Store icons must not contain alpha: $icon" >&2
    exit 1
  fi
done

legacy_name="jelly""box"
if git grep -in "$legacy_name" -- .; then
  echo "Legacy pre-rename naming remains in tracked files." >&2
  exit 1
fi

oxfmt --check README.md 'Design/**/*.md' 'docs/**/*.md' 'distribution/**/*.md'
swift format lint --strict --recursive Sources Tests
swiftlint lint --strict --config .swiftlint.yml

xcodebuild \
  -project "$root/jellyboy.xcodeproj" \
  -scheme jellyboy \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$build_root/macos-tests" \
  CODE_SIGNING_ALLOWED=NO \
  test

xcodebuild \
  -project "$root/jellyboy.xcodeproj" \
  -scheme jellyboy \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$build_root/ios-simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build
