param(
    [string]$RepoPath = ".",
    [switch]$CheckOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Run from the APP repository, not Node_device. No reset, commit, or push.
try {
    $resolved = (Resolve-Path -LiteralPath $RepoPath).Path
    $rootOutput = & git -C $resolved rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) { throw "RepoPath is not inside a Git repository." }
    $root = ($rootOutput -join "`n").Trim()
    function Invoke-CheckedGit {
        param([string[]]$GitArguments)
        $result = & git -C $root @GitArguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "git $($GitArguments -join ' ') failed:`n$($result -join "`n")"
        }
        return ($result -join "`n").Trim()
    }
    $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot "manifest.json") -Raw | ConvertFrom-Json
    $patch = Join-Path $PSScriptRoot $manifest.patch_file
    $patchHash = (Get-FileHash -LiteralPath $patch -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($patchHash -ne $manifest.patch_sha256) { throw "Patch checksum mismatch. Re-extract the ZIP." }
    if (-not (Test-Path -LiteralPath (Join-Path $root "pubspec.yaml"))) {
        throw "This is not the expected Flutter app root (pubspec.yaml is missing)."
    }
    $null = Invoke-CheckedGit -GitArguments @("diff", "--quiet", "--ignore-submodules")
    $null = Invoke-CheckedGit -GitArguments @("diff", "--cached", "--quiet", "--ignore-submodules")
    foreach ($property in $manifest.original_files.PSObject.Properties) {
        $path = $property.Name
        $expected = [string]$property.Value
        $committed = Invoke-CheckedGit -GitArguments @("rev-parse", "HEAD:$path")
        $working = Invoke-CheckedGit -GitArguments @("hash-object", "--path=$path", "--", $path)
        if ($committed -ne $expected -or $working -ne $expected) {
            throw "Source differs from the patch baseline: $path. Nothing applied. Do not force the patch."
        }
    }
    foreach ($path in $manifest.new_files) {
        if (Test-Path -LiteralPath (Join-Path $root $path)) {
            throw "New-file path already exists: $path. The patch may already be applied. Nothing applied."
        }
    }
    $null = Invoke-CheckedGit -GitArguments @("apply", "--check", $patch)
    if ($CheckOnly) {
        Write-Host "All baseline, checksum, and patch checks passed. No files changed."
        exit 0
    }
    $null = Invoke-CheckedGit -GitArguments @("apply", $patch)
    Write-Host "Patch applied to Node_App. No commit or push was made."
    Write-Host "Next: flutter pub get"
    Write-Host "Then: flutter test test/node_med_prompt_schedule_test.dart test/node_prompt_editor_test.dart"
    Write-Host "Review TESTING.md before using a physical device."
} catch {
    Write-Error $_ -ErrorAction Continue
    Write-Host "Stop here. Commit or stash existing work, or use a clean matching baseline; never force a partial application."
    exit 1
}
