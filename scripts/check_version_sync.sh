#!/bin/bash
set -euo pipefail

PUBSPEC_VERSION_RAW=$(grep "^version:" pubspec.yaml | sed "s/version:[[:space:]]*//")
DART_VERSION=$(grep "const String appVersion = '" lib/version.dart | sed "s/.*const String appVersion = '\([^']*\)'.*/\1/")

if [ -z "${PUBSPEC_VERSION_RAW}" ] || [ -z "${DART_VERSION}" ]; then
  echo "❌ Failed to parse version values."
  exit 1
fi

# Flutter pubspec versions may include a build number suffix (for example
# `0.12.0+1`). `lib/version.dart` intentionally stores only the user-facing
# semantic version (`0.12.0`), so compare the part before `+`.
PUBSPEC_VERSION="${PUBSPEC_VERSION_RAW%%+*}"

if [ "${PUBSPEC_VERSION}" != "${DART_VERSION}" ]; then
  echo "❌ Version mismatch detected:"
  echo "   pubspec.yaml: ${PUBSPEC_VERSION_RAW} (semantic: ${PUBSPEC_VERSION})"
  echo "   lib/version.dart: ${DART_VERSION}"
  exit 1
fi

echo "✅ Version sync check passed: ${DART_VERSION} (pubspec: ${PUBSPEC_VERSION_RAW})"
