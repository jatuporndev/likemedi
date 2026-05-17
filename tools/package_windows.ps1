param(
    [string]$OutputName = "likemedieval-windows",
    [bool]$CleanRootExport = $true
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $root "dist"
$packageDir = Join-Path $distRoot $OutputName
$zipPath = Join-Path $distRoot "$OutputName.zip"

$requiredFiles = @(
    "likemedieval.exe",
    "EOSSDK-Win64-Shipping.dll",
    "xaudio2_9redist.dll"
)

$eosgDlls = Get-ChildItem -Path $root -Filter "libeosg.windows.*.x86_64.dll" -File
if ($eosgDlls.Count -eq 0) {
    throw "Missing EOSG native DLL. Export the Windows build from Godot before packaging."
}

foreach ($file in $requiredFiles) {
    $path = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required export file: $file"
    }
}

if (Test-Path -LiteralPath $packageDir) {
    Remove-Item -LiteralPath $packageDir -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

foreach ($file in $requiredFiles) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $packageDir
}
foreach ($dll in $eosgDlls) {
    Copy-Item -LiteralPath $dll.FullName -Destination $packageDir
}

$consoleExe = Join-Path $root "likemedieval.console.exe"
if (Test-Path -LiteralPath $consoleExe) {
    Copy-Item -LiteralPath $consoleExe -Destination $packageDir
}

Compress-Archive -LiteralPath $packageDir -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Created $zipPath"

if ($CleanRootExport) {
    foreach ($file in $requiredFiles) {
        Remove-Item -LiteralPath (Join-Path $root $file) -Force
    }
    foreach ($dll in $eosgDlls) {
        Remove-Item -LiteralPath $dll.FullName -Force
    }
    if (Test-Path -LiteralPath $consoleExe) {
        Remove-Item -LiteralPath $consoleExe -Force
    }
    Write-Host "Cleaned root export files"
}
