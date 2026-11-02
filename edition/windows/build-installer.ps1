# Builds <folder>-setup-<version>-windows-<x64|arm64>.exe, the office edition's
# per-user installer, around an already-built hex.exe (built with
# HEX_EDITION_NAME set, so it carries the edition's name and icon).
#
#   edition/windows/build-installer.ps1 -Executable dist\hex.exe -Version 3.3.0 -Arch x86_64 -OutDir dist
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Executable,
    [Parameter(Mandatory)] [string]$Version,
    [Parameter(Mandatory)] [ValidateSet('x86_64', 'aarch64')] [string]$Arch,
    [Parameter(Mandatory)] [string]$OutDir,
    [string]$Name = $(if ($env:HEX_EDITION_NAME) { $env:HEX_EDITION_NAME } else { 'Nexus Voice' })
)
$ErrorActionPreference = 'Stop'

$Executable = (Resolve-Path $Executable).Path
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$label = if ($Arch -eq 'x86_64') { 'x64' } else { 'arm64' }
$folder = ($Name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
$script = Join-Path $PSScriptRoot 'nexus-voice.iss'

$iscc = @(
    (Get-Command ISCC.exe -ErrorAction SilentlyContinue | ForEach-Object Source),
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $iscc) {
    winget install --id JRSoftware.InnoSetup -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
    $iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $iscc) { throw 'Inno Setup 6 (ISCC.exe) was not found.' }
}

& $iscc /Qp "/DAppVersion=$Version" "/DArch=$label" "/DExecutable=$Executable" "/DOutputDir=$OutDir" `
    "/DEditionName=$Name" "/DEditionFolder=$folder" $script
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }
Join-Path $OutDir "$folder-setup-$Version-windows-$label.exe"
