$releaseDir = "C:\RandallEngineering\Jokarz-Engineering\releases"
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}

$apkSource = "C:\RandallEngineering\Jokarz-Engineering\build\app\outputs\flutter-apk\app-release.apk"
$apkDest = Join-Path $releaseDir "jokarz-engineering-v1.0.7.apk"
Copy-Item $apkSource -Destination $apkDest -Force

$zipDest = Join-Path $releaseDir "jokarz-engineering-windows-v1.0.7.zip"
if (Test-Path $zipDest) { Remove-Item $zipDest -Force }
Compress-Archive -Path "C:\RandallEngineering\Jokarz-Engineering\build\windows\x64\runner\Release\*" -DestinationPath $zipDest -Force

Get-ChildItem $releaseDir | Select-Object Name, Length
Write-Host "Releases packaged successfully!"
