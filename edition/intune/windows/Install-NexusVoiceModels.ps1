<#
  Installs Nexus Voice speech models machine-wide, for Intune (Win32 app,
  install behavior: System). Downloads each model from your Azure Blob
  container, checks its size and SHA-256 against models.json (packaged
  beside this script), and places it in
  %ProgramData%\Nexus Voice\models, readable by everyone and writable only
  by administrators. Nexus Voice uses those files in place, so people never
  download a model.

  Install command:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-NexusVoiceModels.ps1 `
      -BaseUrl "https://<account>.blob.core.windows.net/<container>" -Sas "<read-only SAS token>"
  Uninstall command:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-NexusVoiceModels.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$Sas = '',
    [string[]]$Models = @('parakeet-unified-english', 'parakeet-v3', 'speech-detector'),
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$target = Join-Path $env:ProgramData 'Nexus Voice\models'
$log = Join-Path $env:ProgramData 'Nexus Voice\models-install.log'
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
function Log($message) { "$(Get-Date -Format s) $message" | Add-Content $log; Write-Output $message }

if ($Uninstall) {
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Log 'Removed the managed models.'
    exit 0
}
if (-not $BaseUrl) { throw 'Pass -BaseUrl, the Azure Blob container URL.' }
$BaseUrl = $BaseUrl.TrimEnd('/')
$query = if ($Sas) { '?' + $Sas.TrimStart('?') } else { '' }

$manifestPath = Join-Path $PSScriptRoot 'models.json'
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
New-Item -ItemType Directory -Force $target | Out-Null

foreach ($id in $Models) {
    $model = $manifest.models | Where-Object id -eq $id
    if (-not $model) { throw "Unknown model id '$id' (see models.json)." }
    $destination = Join-Path $target $model.file
    if ((Test-Path $destination) -and (Get-Item $destination).Length -eq $model.bytes -and
        (Get-FileHash $destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $model.sha256) {
        Log "$id is already installed."
        continue
    }
    $partial = "$destination.partial"
    Log "Downloading $id ($([math]::Round($model.bytes / 1MB)) MB)..."
    $attempt = 0
    while ($true) {
        try {
            Start-BitsTransfer -Source "$BaseUrl/$($model.file)$query" -Destination $partial -ErrorAction Stop
            break
        } catch {
            $attempt++
            if ($attempt -ge 4) {
                Log "BITS failed ($($_.Exception.Message)); trying Invoke-WebRequest."
                Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/$($model.file)$query" -OutFile $partial
                break
            }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
    if ((Get-Item $partial).Length -ne $model.bytes) { Remove-Item $partial -Force; throw "$id has the wrong size." }
    $hash = (Get-FileHash $partial -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $model.sha256) { Remove-Item $partial -Force; throw "$id failed its SHA-256 check." }
    Move-Item -Force $partial $destination
    Log "$id installed and verified."
}

# Everyone reads, only SYSTEM and Administrators write.
icacls $target /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
Log 'Done.'
