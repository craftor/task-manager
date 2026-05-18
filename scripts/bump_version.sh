#!/bin/bash
# Usage: ./scripts/bump_version.sh 0.7.28

NEW_VERSION=$1
if [ -z "$NEW_VERSION" ]; then
  echo "Usage: ./scripts/bump_version.sh <version>"
  exit 1
fi

# Update pubspec.yaml
sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

# Update lib/version.dart
sed -i "s/const String appVersion = '[^']*'/const String appVersion = '$NEW_VERSION'/" lib/version.dart

echo "Bumped version to $NEW_VERSION"