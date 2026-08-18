#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData-iOS"

cd "$ROOT_DIR"
xcodegen --spec project.yml
xcodebuild \
  -project "$ROOT_DIR/jellyboy.xcodeproj" \
  -scheme jellyboy \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build
