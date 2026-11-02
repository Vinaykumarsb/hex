# Intune detection script for the Nexus Voice models Win32 app: reports
# installed when every default model is in %ProgramData%\Nexus Voice\models
# at its pinned size. (Install-NexusVoiceModels.ps1 already checked SHA-256,
# and Nexus Voice checks it again before first use.)
$target = Join-Path $env:ProgramData 'Nexus Voice\models'
$expected = @{
    'parakeet-unified-en-0.6b-Q8_0.gguf' = 731357568
    'parakeet-tdt-0.6b-v3-Q8_0.gguf'     = 739508576
    'silero-vad-v6.2-F32.gguf'           = 1241056
}
foreach ($file in $expected.Keys) {
    $path = Join-Path $target $file
    if (-not (Test-Path $path) -or (Get-Item $path).Length -ne $expected[$file]) { exit 1 }
}
Write-Output 'Nexus Voice models installed'
exit 0
