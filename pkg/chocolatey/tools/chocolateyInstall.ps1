$ErrorActionPreference = 'Stop'

$installDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$zipUrl = 'https://github.com/copilot-cat/copilot-cat/releases/download/v1.0.0/copilot-cat-win64.zip'
$zipFile = Join-Path $env:TEMP 'copilot-cat.zip'
$targetDir = Join-Path $env:ProgramFiles 'Copilot Cat'

# Download and extract
Get-ChocolateyWebFile -PackageName 'copilot-cat' -FileFullPath $zipFile -Url64bit $zipUrl
Get-ChocolateyUnzip -FileFullPath $zipFile -Destination $targetDir

# Add to PATH
Install-ChocolateyPath -PathToInstall $targetDir -PathType 'Machine'

# Create Start Menu shortcut
$shortcutPath = Join-Path ([Environment]::GetFolderPath('CommonStartMenu')) 'Programs\Copilot Cat.lnk'
Install-ChocolateyShortcut -ShortcutFilePath $shortcutPath `
    -TargetPath (Join-Path $targetDir 'copilot-cat.exe') `
    -WorkingDirectory $targetDir

Write-Host "Copilot Cat installed to $targetDir"
Write-Host "Run: copilot-cat --help"
