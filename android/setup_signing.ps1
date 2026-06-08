# Configuration de la signature Android pour Google Play
# Exécutez ce script une fois :  .\setup_signing.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (Test-Path "upload-keystore.jks") {
    Write-Host "Le keystore upload-keystore.jks existe deja."
    exit 0
}

Write-Host "=== Creation de la cle de signature release ===" -ForegroundColor Cyan
Write-Host "Choisissez un mot de passe fort (min. 6 caracteres)."
Write-Host "CONSERVEZ-LE : Google ne peut pas le recuperer si vous le perdez.`n"

$pass = Read-Host "Mot de passe du keystore" -AsSecureString
$passConfirm = Read-Host "Confirmer le mot de passe" -AsSecureString

$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
$plainConfirm = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($passConfirm))

if ($plain -ne $plainConfirm) {
    Write-Error "Les mots de passe ne correspondent pas."
    exit 1
}

if ($plain.Length -lt 6) {
    Write-Error "Mot de passe trop court (minimum 6 caracteres)."
    exit 1
}

keytool -genkeypair -v `
    -storetype JKS `
    -keystore upload-keystore.jks `
    -alias upload `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -storepass $plain `
    -keypass $plain `
    -dname "CN=Budget Tracker, OU=Mobile, O=BudgetTracker, L=France, ST=France, C=FR"

@"
storePassword=$plain
keyPassword=$plain
keyAlias=upload
"@ | Set-Content -Encoding ascii key.properties

Write-Host "`nKeystore cree : android/upload-keystore.jks" -ForegroundColor GreenWrite-Host "Configuration : android/key.properties" -ForegroundColor Green
Write-Host "`nProchaine etape (depuis la racine du projet) :" -ForegroundColor Yellow
Write-Host "  flutter build appbundle --release"
