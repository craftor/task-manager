# scripts/run_tests.ps1
#
# Bypass `flutter test` by invoking the flutter_tools snapshot directly with
# the bundled dart.exe. Useful when the `flutter.bat` wrapper is blocked
# from writing to its cache (e.g. inside the Codex sandbox) but the
# underlying tool still works.
#
# Usage:
#   .\scripts\run_tests.ps1                                      # all tests
#   .\scripts\run_tests.ps1 test\unit\sync_manager_test.dart     # one file
#   .\scripts\run_tests.ps1 --reporter expanded                  # verbose
#
# Env:
#   FLUTTER_ROOT  Path to your Flutter SDK (default: C:\flutter)
#                 Override this if Flutter is installed elsewhere.

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'

# Resolve Flutter SDK root.
$flutterRoot = $env:FLUTTER_ROOT
if (-not $flutterRoot) {
    $flutterRoot = 'C:\flutter'
}

$dartExe    = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$snapshot   = Join-Path $flutterRoot 'bin\cache\flutter_tools.snapshot'
$pkgConfig  = Join-Path $flutterRoot 'packages\flutter_tools\.dart_tool\package_config.json'

foreach ($p in @($dartExe, $snapshot, $pkgConfig)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Error "Missing required Flutter asset: $p`nSet FLUTTER_ROOT to your Flutter SDK location."
        exit 1
    }
}

# `flutter test` reads pubspec.yaml from the current working directory, so
# always run from the project root (parent of the scripts/ folder). Push/
# pop preserves the caller's CWD.
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $argsList = @(
        '--packages', $pkgConfig
        $snapshot
        '--suppress-analytics'
        '--no-version-check'
        'test'
        '--reporter', 'compact'
    ) + $FlutterArgs

    & $dartExe @argsList
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
