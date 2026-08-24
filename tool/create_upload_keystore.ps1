param(
    [string]$PublisherName = "Japandi Dev",
    [string]$KeyAlias = "squirio-upload"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $projectRoot "android"
$keystorePath = Join-Path $androidDir "app\upload-keystore.jks"
$propertiesPath = Join-Path $androidDir "key.properties"

if ((Test-Path -LiteralPath $keystorePath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw "Signing files already exist. Back them up and remove them explicitly before creating replacements."
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if ($null -eq $keytool) {
    throw "keytool was not found. Install a JDK or add its bin directory to PATH."
}

$securePassword = Read-Host "Create a strong upload-key password" -AsSecureString
$confirmation = Read-Host "Enter the password again" -AsSecureString

$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$confirmationPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmation)

try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    $confirmedPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($confirmationPointer)

    if ([string]::IsNullOrWhiteSpace($password) -or $password.Length -lt 12) {
        throw "Use a password containing at least 12 characters."
    }
    if ($password -cne $confirmedPassword) {
        throw "The passwords do not match."
    }

    & $keytool.Source -genkeypair -v `
        -keystore $keystorePath `
        -storetype JKS `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias $KeyAlias `
        -storepass $password `
        -keypass $password `
        -dname "CN=$PublisherName, O=$PublisherName, C=ID"

    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE."
    }

    @(
        "storePassword=$password"
        "keyPassword=$password"
        "keyAlias=$KeyAlias"
        "storeFile=upload-keystore.jks"
    ) | Set-Content -LiteralPath $propertiesPath -Encoding utf8

    Write-Host "Upload keystore created successfully."
    Write-Host "Back up these two files somewhere secure:"
    Write-Host "  $keystorePath"
    Write-Host "  $propertiesPath"
    Write-Host "Then run: flutter build appbundle --release"
}
finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    if ($confirmationPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($confirmationPointer)
    }
    $password = $null
    $confirmedPassword = $null
}
