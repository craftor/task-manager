#!/bin/bash
set -euo pipefail

PUBSPEC_VERSION=$(grep "^version:" pubspec.yaml | sed "s/version:[[:space:]]*//")
DART_VERSION=$(grep "const String appVersion = '" lib/version.dart | sed "s/.*const String appVersion = '\([^']*\)'.*/\1/")

if [ -z "${PUBSPEC_VERSION}" ] || [ -z "${DART_VERSION}" ]; then
  echo "❌ Failed to parse version values."
  exit 1
fi

if [ "${PUBSPEC_VERSION}" != "${DART_VERSION}" ]; then
  echo "❌ Version mismatch detected:"
  echo "   pubspec.yaml: ${PUBSPEC_VERSION}"
  echo "   lib/version.dart: ${DART_VERSION}"
  exit 1
fi

echo "✅ Version sync check passed: ${DART_VERSION}"
