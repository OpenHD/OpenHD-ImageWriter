# download_and_install_openssl.ps1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host "=== OpenSSL → Qt MinGW installer ==="

# Hard-coded Qt MinGW path
$qtMingwRoot = 'C:\Qt\Tools\mingw810_32'

Write-Host "Qt MinGW root: $qtMingwRoot"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Script directory: $scriptDir"

$zipUrl  = 'https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-1.1.1w.zip'
$zipFile = Join-Path $scriptDir 'openssl-1.1.1w.zip'
$outDir  = Join-Path $scriptDir 'openssl111'

Write-Host "Zip file will be: $zipFile"
Write-Host "Extract dir will be: $outDir"
Write-Host ""

# Download OpenSSL if not already present
if (-not (Test-Path $zipFile)) {
    Write-Host "[1/5] Downloading OpenSSL..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
} else {
    Write-Host "[1/5] Zip already exists, skipping download."
}

# Clean old extraction, then extract
if (Test-Path $outDir) {
    Write-Host "[2/5] Removing old directory: $outDir"
    Remove-Item $outDir -Recurse -Force
}

Write-Host "[3/5] Extracting OpenSSL..."
Expand-Archive $zipFile -DestinationPath $outDir

# Resolve "openssl-*" subdir and x86 layout
$opensslBase = Get-ChildItem -Directory -Path $outDir |
    Where-Object { $_.Name -like 'openssl-*' } |
    Select-Object -First 1

if (-not $opensslBase) {
    throw "Could not find extracted OpenSSL directory under $outDir"
}

$openssl = Join-Path $opensslBase.FullName 'x86'
Write-Host "Resolved OpenSSL base: $($opensslBase.FullName)"
Write-Host "Resolved OpenSSL x86 path: $openssl"

if (-not (Test-Path $openssl)) {
    throw "OpenSSL x86 directory not found: $openssl"
}

if (-not (Test-Path $qtMingwRoot)) {
    throw "Qt MinGW root not found: $qtMingwRoot"
}

$binTarget = Join-Path $qtMingwRoot 'bin'
$libTarget = Join-Path $qtMingwRoot 'lib'
$incTarget = Join-Path $qtMingwRoot 'include\openssl'

Write-Host ""
Write-Host "Bin target:  $binTarget"
Write-Host "Lib target:  $libTarget"
Write-Host "Incl target: $incTarget"

# Ensure target directories exist
New-Item -ItemType Directory -Force -Path $binTarget  | Out-Null
New-Item -ItemType Directory -Force -Path $libTarget  | Out-Null
New-Item -ItemType Directory -Force -Path $incTarget  | Out-Null

Write-Host ""
Write-Host "[4/5] Copying DLLs and libs..."

Copy-Item (Join-Path $openssl 'bin\libcrypto-1_1.dll') $binTarget -Force
Copy-Item (Join-Path $openssl 'bin\libssl-1_1.dll')    $binTarget -Force
Copy-Item (Join-Path $openssl 'lib\libcrypto.lib')     $libTarget -Force
Copy-Item (Join-Path $openssl 'lib\libssl.lib')        $libTarget -Force

Write-Host "[5/5] Copying headers..."
$srcInclude = Join-Path $openssl 'include\openssl'
Write-Host "Copying from: $srcInclude"
Copy-Item (Join-Path $srcInclude '*') $incTarget -Recurse -Force

Write-Host ""
Write-Host "=== Done. Sanity check: list OpenSSL files in Qt bin/lib/include ==="

Write-Host "`n[bin]"
Get-ChildItem $binTarget | Where-Object { $_.Name -like 'lib*1_1*' }

Write-Host "`n[lib]"
Get-ChildItem $libTarget | Where-Object { $_.Name -like 'lib*ssl*' -or $_.Name -like 'lib*crypto*' }

Write-Host "`n[include\openssl]"
Get-ChildItem $incTarget | Select-Object -First 10
Write-Host "... (showing first 10 header files)"
