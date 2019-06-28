Invoke-Expression (new-object net.webclient).downloadstring('https://get.scoop.sh')

scoop install sudo
scoop bucket add extras
scoop install git --global
scoop install vscode --global
scoop install curl --global
scoop install azure-cli --global
scoop install firefox --global
scoop install terraform --global
scoop install helm --global
scoop install kubectl --global
scoop install nodejs-lts --global
scoop install cmder --global
scoop install openssh --global

$Path = $env:TEMP; $Installer = "chrome_installer.exe"; Invoke-WebRequest "http://dl.google.com/chrome/install/latest/chrome_installer.exe" -OutFile $Path\$Installer; Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait; Remove-Item $Path\$Installer

# Install VS Code Plugins
code --install-extension mauve.terraform

