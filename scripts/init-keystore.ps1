#Requires -Version 5.1
<#
.SYNOPSIS
    One-time creation of the F-Droid repository signing key.

.DESCRIPTION
    Writes secrets/keystore.p12 (PKCS12, RSA 4096, alias fdroid),
    fdroid/fingerprint.txt (SHA-256 of the certificate, lowercase hex),
    and the two GitHub Actions secret payloads under secrets/.
    Never run this again unless the key is lost: a new key changes the
    repository fingerprint and clients must re-add the repo.
#>
[CmdletBinding()]
param(
    [switch] $Force,
    [string] $Password
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$secretsDir = Join-Path $root "secrets"
$keystorePath = Join-Path $secretsDir "keystore.p12"
$fingerprintPath = Join-Path $root "fdroid\fingerprint.txt"
$alias = "fdroid"

function Get-Keytool {
    $candidates = @()
    if ($env:JAVA_HOME) {
        $candidates += Join-Path $env:JAVA_HOME "bin\keytool.exe"
        $candidates += Join-Path $env:JAVA_HOME "bin\keytool"
    }
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) {
        $candidates += $cmd.Source
    }
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }
    throw "keytool not found. Install a JDK and/or set JAVA_HOME."
}

function New-Password {
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    } finally {
        $rng.Dispose()
    }
    return [Convert]::ToBase64String($bytes)
}

function Get-CertFingerprint([string] $Path, [string] $StorePassword) {
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $Path,
        $StorePassword,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    )
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hash = $sha.ComputeHash($cert.RawData)
        } finally {
            $sha.Dispose()
        }
        return -join ($hash | ForEach-Object { $_.ToString("x2") })
    } finally {
        $cert.Dispose()
    }
}

if ((Test-Path -LiteralPath $keystorePath) -and -not $Force) {
    throw "Keystore already exists at $keystorePath. Refusing to overwrite (pass -Force only if you intend to change the fingerprint)."
}

if ((Test-Path -LiteralPath $fingerprintPath) -and -not $Force) {
    $existing = (Get-Content -LiteralPath $fingerprintPath -Raw).Trim()
    if ($existing) {
        throw "fdroid/fingerprint.txt already has a fingerprint. Refusing to replace it (pass -Force only if you intend to change the fingerprint)."
    }
}

$keytool = Get-Keytool
if (-not $Password) {
    $Password = New-Password
}

New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $fingerprintPath) | Out-Null

$dname = "CN=redmanmale.github.io, OU=F-Droid, O=redmanmale"
& $keytool -genkeypair `
    -alias $alias `
    -keyalg RSA `
    -keysize 4096 `
    -validity 10000 `
    -storetype PKCS12 `
    -keystore $keystorePath `
    -storepass $Password `
    -keypass $Password `
    -dname $dname `
    -noprompt

if ($LASTEXITCODE -ne 0) {
    throw "keytool -genkeypair failed with exit code $LASTEXITCODE"
}

$fingerprint = Get-CertFingerprint -Path $keystorePath -StorePassword $Password
Set-Content -LiteralPath $fingerprintPath -Value $fingerprint -NoNewline -Encoding ascii

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath))
Set-Content -LiteralPath (Join-Path $secretsDir "FDROID_KEYSTORE_BASE64.txt") -Value $b64 -NoNewline -Encoding ascii
Set-Content -LiteralPath (Join-Path $secretsDir "FDROID_KEYSTORE_PASS.txt") -Value $Password -NoNewline -Encoding ascii

Write-Host ""
Write-Host "Created $keystorePath"
Write-Host "Wrote $fingerprintPath"
Write-Host ""
Write-Host "Repository fingerprint:"
Write-Host $fingerprint
Write-Host ""
Write-Host "GitHub Actions secrets (Settings -> Secrets and variables -> Actions):"
Write-Host "  FDROID_KEYSTORE_PASS     = $Password"
Write-Host "  FDROID_KEYSTORE_BASE64   = (also in secrets\FDROID_KEYSTORE_BASE64.txt)"
Write-Host ""
Write-Host "Keep keystore.p12 and the password offline as well. GitHub will not show the secret again."
Write-Host "Commit fdroid/fingerprint.txt. Do not commit anything in secrets/."
