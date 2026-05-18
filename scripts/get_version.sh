#!/bin/bash
# Extract version from lib/version.dart

VERSION=$(grep "const String appVersion = '" lib/version.dart | sed "s/.*const String appVersion = '\([^']*\)'.*/\1/")
echo "$VERSION"