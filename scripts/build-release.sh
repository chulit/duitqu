#!/usr/bin/env bash
# Called by semantic-release (exec prepareCmd) with the release version as $1.
# Builds the signed release APK with the version injected (pubspec is NOT
# edited) and stages it at the repo root for the github plugin to attach.
set -euo pipefail

VERSION="${1:?version argument required}"
IFS='.' read -r MAJ MIN PAT <<< "$VERSION"
CODE=$(( MAJ * 10000 + MIN * 100 + PAT ))

# Split per ABI: a universal APK triples the download with engines for CPUs
# the phone never uses. Flutter raises each split's versionCode above the
# base code, so these install as normal updates — and releases must stay
# split from now on (a future universal would code lower).
flutter build apk --release --split-per-abi --build-name="$VERSION" --build-number="$CODE" \
  --obfuscate --split-debug-info=build/symbols

# Integrity gate: every APK must carry the permanent DuitQu release certificate.
# SHA-256 of duitqu-release.jks (alias duitqu), generated 2026-10-15.
PERMANENT_SHA256="09b8dd4ef55b3626ccc8cad6fa1c28521fbcd56bcabd351a6894b35b8546c352"
BT=$(ls "$ANDROID_HOME/build-tools" | sort -V | tail -1)
for ABI in arm64-v8a armeabi-v7a x86_64; do
  APK="DuitQu-v${VERSION}-${ABI}.apk"
  cp "build/app/outputs/flutter-apk/app-${ABI}-release.apk" "$APK"
  "$ANDROID_HOME/build-tools/$BT/apksigner" verify --print-certs "$APK" \
    | grep -qi "$PERMANENT_SHA256" \
    || { echo "ERROR: $APK not signed with the permanent DuitQu keystore"; exit 1; }
  echo "Signed OK: $APK (versionName $VERSION, base versionCode $CODE)"
done
