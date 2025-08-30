#!/usr/bin/env bash
set -euo pipefail

SCHEME=${SCHEME:-JokguApplication}
ARCHIVE_PATH=${ARCHIVE_PATH:-build/${SCHEME}.xcarchive}
EXPORT_DIR=${EXPORT_DIR:-build/export}
METHOD=${METHOD:-development}
PLIST="ci/${METHOD}-exportoptions.plist"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$PLIST"
