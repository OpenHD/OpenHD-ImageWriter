$zipUrl = "https://github.com/ohadravid/mingw-openssl/releases/download/2023-04-11/openssl-mingw-3.0.8-x86.zip"
$zipPath = "$env:TEMP\openssl-mingw.zip"
$installDir = "C:\OpenSSL32"

Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
