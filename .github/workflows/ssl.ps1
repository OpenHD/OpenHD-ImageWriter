# Installs 32-bit OpenSSL 3.5.0 (Light) from Shining Light Productions
$version = "3_5_0"
$installerName = "Win32OpenSSL_Light-$version.exe"
$installerUrl = "https://slproweb.com/download/$installerName"
$installerPath = "$env:TEMP\$installerName"
$installDir = "C:\OpenSSL32"

Write-Host "Downloading OpenSSL installer from $installerUrl"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

Write-Host "Installing OpenSSL to $installDir..."
$args = "/silent", "/sp-", "/suppressmsgboxes", "/DIR=`"$installDir`""
Start-Process -FilePath $installerPath -ArgumentList $args -Wait

# Add to PATH for current session
$env:Path = "$installDir\bin;$env:Path"

Write-Host "OpenSSL 3.5.0 (Light) installed successfully to $installDir"
