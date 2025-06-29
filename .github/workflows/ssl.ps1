$version = "3_5_0"
$installerName = "Win32OpenSSL-$version.exe"
$installerUrl = "https://slproweb.com/download/$installerName"
$installerPath = "$env:TEMP\$installerName"
$installDir = "C:\OpenSSL32"

Write-Host "Downloading OpenSSL installer from $installerUrl"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

Write-Host "Installing OpenSSL to $installDir..."
$args = "/silent", "/sp-", "/suppressmsgboxes", "/DIR=`"$installDir`""
Start-Process -FilePath $installerPath -ArgumentList $args -Wait

$env:Path = "$installDir\bin;$env:Path"
Write-Host "OpenSSL installed to $installDir"
