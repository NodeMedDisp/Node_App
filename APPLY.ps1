$ErrorActionPreference = 'Stop'
$expectedCommit = '9e877a10436e65aec340622f6bff610e9e0faca1'
$patch = Join-Path $PSScriptRoot 'app_single_daily_medication.patch'

$root = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0) { throw 'Run this from your Node_App Git working directory.' }
Set-Location $root
if (!(Test-Path 'pubspec.yaml')) { throw 'This does not look like the Node_App root.' }
$head = (& git rev-parse HEAD).Trim()
if ($head -ne $expectedCommit) {
    throw "Wrong base commit. Expected $expectedCommit, found $head. Do not force this patch."
}
$dirty = (& git status --porcelain --untracked-files=no)
if ($dirty) { throw 'Tracked files have local changes. Use a clean worktree or save those changes first.' }
& git apply --check -- $patch
if ($LASTEXITCODE -ne 0) { throw 'The patch did not match this checkout. No files were changed.' }
& git apply -- $patch
if ($LASTEXITCODE -ne 0) { throw 'git apply failed. Inspect git status before continuing.' }
Write-Host 'Applied the APP patch. No Firebase records or device firmware were changed by installation.'
Write-Host 'Next: flutter pub get; flutter analyze; dart run tool/check_daily_medication_schedule.dart'
Write-Host 'Then fully stop and restart the app. Do not uninstall or clear app storage as a routine fix.'
