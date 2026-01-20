# Fail fast
$ErrorActionPreference = "Stop"

# Paths
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddonDir = Join-Path $RepoRoot "XIVEquip"
$ArchiveDir = Join-Path $RepoRoot "..\XIVEquipArchives"

# Validate addon directory
if (-not (Test-Path $AddonDir)) {
    throw "XIVEquip directory not found at expected path: $AddonDir"
}

# Find TOC
$TocFile = Get-ChildItem -Path $AddonDir -Filter "*.toc" | Select-Object -First 1
if (-not $TocFile) {
    throw "No .toc file found in XIVEquip directory."
}

# Extract version from TOC
$VersionLine = Get-Content $TocFile.FullName | Where-Object { $_ -match "^##\s*Version:" }
if (-not $VersionLine) {
    throw "No '## Version:' line found in TOC."
}

$Version = ($VersionLine -replace "^##\s*Version:\s*", "").Trim()
if (-not $Version) {
    throw "Version line found but version string is empty."
}

# Ensure archive directory exists
if (-not (Test-Path $ArchiveDir)) {
    New-Item -ItemType Directory -Path $ArchiveDir | Out-Null
}

# Build zip name
$ZipName = "XIVEquip-$Version.zip"
$ZipPath = Join-Path $ArchiveDir $ZipName

# Remove existing zip if present
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath
}

# Create zip
Compress-Archive `
    -Path (Join-Path $RepoRoot "XIVEquip") `
    -DestinationPath $ZipPath `
    -CompressionLevel Optimal

Write-Host "Build complete:" -ForegroundColor Green
Write-Host "  $ZipPath"
