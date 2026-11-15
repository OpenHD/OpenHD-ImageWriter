$ErrorActionPreference = 'Stop'
$archiveUri = 'https://dl.radxa.com/tools/windows/DriverAssitant_v5.14.zip'
$expectedHash = 'FFC71CCF8AA40AFE74B485393DC5572E431B6ECC84B13EEE5360907C7EC84276'
$driverArchitecture = @{ AMD64 = 'x64'; x86 = 'x86' }[$env:PROCESSOR_ARCHITECTURE]

try {
    if (!$driverArchitecture) {
        throw 'Rockusb is available for x64 and x86 Windows.'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.IO.Compression
    $client = [Net.WebClient]::new()
    try {
        $archiveBytes = $client.DownloadData($archiveUri)
    } finally {
        $client.Dispose()
    }

    $stream = [IO.MemoryStream]::new($archiveBytes)
    try {
        if ((Get-FileHash -InputStream $stream).Hash -ne $expectedHash) {
            throw 'The downloaded Rockusb archive does not match the verified vendor archive.'
        }
        $stream.Position = 0
        $archive = [IO.Compression.ZipArchive]::new($stream)
        try {
            $driverDir = Join-Path $PSScriptRoot 'rockusb'
            New-Item -ItemType Directory -Path $driverDir | Out-Null
            foreach ($file in 'rockusb.inf', 'rockusb.cat', 'rockusb.sys') {
                $entry = $archive.GetEntry("DriverAssitant_v5.14/Driver/$driverArchitecture/win10/$file")
                $source = $entry.Open()
                try {
                    $destination = [IO.File]::Create((Join-Path $driverDir $file))
                    try { $source.CopyTo($destination) } finally { $destination.Dispose() }
                } finally {
                    $source.Dispose()
                }
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $stream.Dispose()
    }

    $driverInf = Join-Path $driverDir 'rockusb.inf'
    $result = Start-Process -FilePath "$env:windir\System32\pnputil.exe" -Verb RunAs `
        -ArgumentList "/add-driver `"$driverInf`" /install" -Wait -PassThru -WindowStyle Hidden
    if ($result.ExitCode -eq 3010) { exit 3010 }
    if ($result.ExitCode -ne 0) {
        throw "Windows driver installation failed with exit code $($result.ExitCode)."
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
