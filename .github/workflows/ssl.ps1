# Install OpenSSL 32-bit from Shining Light Productions
$version = "3.1.4"
$installerName = "Win32OpenSSL-$version.exe"
$installerUrl = "https://slproweb.com/download/$installerName"
$installerPath = "$env:TEMP\$installerName"
$installDir = "C:\OpenSSL32"

Write-Host "Downloading OpenSSL installer..."
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

Write-Host "Installing OpenSSL to $installDir..."
$args = "/silent", "/sp-", "/suppressmsgboxes", "/DIR=`"$installDir`""
Start-Process -FilePath $installerPath -ArgumentList $args -Wait

# Add to PATH for current session
$env:Path = "$installDir\bin;$env:Path"

Write-Host "OpenSSL installed successfully to $installDir"
