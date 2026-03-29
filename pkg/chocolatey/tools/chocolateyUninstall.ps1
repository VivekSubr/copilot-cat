$ErrorActionPreference = 'Stop'

$targetDir = Join-Path $env:ProgramFiles 'Copilot Cat'

# Remove Start Menu shortcut
$shortcutPath = Join-Path ([Environment]::GetFolderPath('CommonStartMenu')) 'Programs\Copilot Cat.lnk'
if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }

# Remove from PATH
Uninstall-ChocolateyPath -PathToUninstall $targetDir -PathType 'Machine'

# Remove install directory
if (Test-Path $targetDir) { Remove-Item $targetDir -Recurse -Force }

Write-Host "Copilot Cat uninstalled."
