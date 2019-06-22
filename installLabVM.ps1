Invoke-Expression (new-object net.webclient).downloadstring('https://get.scoop.sh')

scoop install sudo
scoop install git --global
scoop bucket add extras
scoop install vscode --global
scoop install curl --global
scoop install firefox --global
scoop install terraform --global
scoop install helm --global
scoop install kubectl --global
scoop install nodejs-lts --global
scoop install openssh --global

$Path = $env:TEMP; $Installer = "chrome_installer.exe"; Invoke-WebRequest "http://dl.google.com/chrome/install/latest/chrome_installer.exe" -OutFile $Path\$Installer; Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait; Remove-Item $Path\$Installer
