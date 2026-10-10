param(
    [Parameter(Mandatory = $true)]
    [string] $Path
)

$ErrorActionPreference = 'Stop'
$signature = Get-AuthenticodeSignature -LiteralPath $Path
if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate -or -not $signature.TimeStamperCertificate) {
    throw "Expected a valid, timestamped Authenticode signature on $Path; status: $($signature.Status)"
}
Write-Host "Verified timestamped signature: $Path"
