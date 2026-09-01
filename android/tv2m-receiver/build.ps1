#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [string]$AndroidSdk
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $AndroidSdk) {
    $AndroidSdk = $env:ANDROID_SDK_ROOT
}
if (-not $AndroidSdk) {
    $AndroidSdk = $env:ANDROID_HOME
}
if (-not $AndroidSdk -and $IsWindows) {
    $AndroidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}
if (-not $AndroidSdk -or -not (Test-Path -LiteralPath $AndroidSdk)) {
    throw 'Android SDK not found. Set ANDROID_SDK_ROOT or pass -AndroidSdk.'
}

foreach ($command in 'javac', 'jar', 'keytool') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command is not available on PATH."
    }
}

$platform = Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'platforms') -Directory |
    Where-Object { $_.Name -match '^android-(\d+)$' -and [int]$Matches[1] -ge 35 } |
    Sort-Object { [int]($_.Name -replace '^android-', '') } -Descending |
    Select-Object -First 1
if (-not $platform) {
    throw 'Android SDK platform 35 or newer is required.'
}

$buildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'build-tools') -Directory |
    Where-Object {
        (Test-Path (Join-Path $_.FullName 'aapt.exe')) -and
        (Test-Path (Join-Path $_.FullName 'd8.bat')) -and
        (Test-Path (Join-Path $_.FullName 'zipalign.exe')) -and
        (Test-Path (Join-Path $_.FullName 'apksigner.bat'))
    } |
    Sort-Object {
        try {
            [version]$_.Name
        } catch {
            [version]'0.0'
        }
    } -Descending |
    Select-Object -First 1
if (-not $buildTools) {
    throw 'Compatible Android SDK Build Tools were not found.'
}

$root = $PSScriptRoot
$build = Join-Path $root 'build'
$classes = Join-Path $build 'classes'
$dex = Join-Path $build 'dex'
foreach ($path in $classes, $dex) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $path
}

$androidJar = Join-Path $platform.FullName 'android.jar'
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
$d8 = Join-Path $buildTools.FullName 'd8.bat'
$zipalign = Join-Path $buildTools.FullName 'zipalign.exe'
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$unsigned = Join-Path $build 'tv2m-unsigned.apk'
$aligned = Join-Path $build 'tv2m-aligned.apk'
$signed = Join-Path $build 'tv2m-receiver.apk'
$keystore = Join-Path $build 'debug.keystore'

Remove-Item -LiteralPath $unsigned, $aligned, $signed -Force -ErrorAction SilentlyContinue

& $aapt package -f `
    -M (Join-Path $root 'AndroidManifest.xml') `
    -I $androidJar `
    -F $unsigned
if ($LASTEXITCODE -ne 0) {
    throw 'aapt package failed.'
}

$source = Join-Path $root 'src\tools\samsung\tv2mreceiver\MainActivity.java'
& javac --release 8 -cp $androidJar -d $classes $source
if ($LASTEXITCODE -ne 0) {
    throw 'javac failed.'
}

$classFiles = Get-ChildItem -LiteralPath $classes -Recurse -Filter '*.class' |
    Select-Object -ExpandProperty FullName
& $d8 --min-api 23 --lib $androidJar --output $dex $classFiles
if ($LASTEXITCODE -ne 0) {
    throw 'd8 failed.'
}

Push-Location $dex
try {
    & $aapt add $unsigned classes.dex
    if ($LASTEXITCODE -ne 0) {
        throw 'aapt add failed.'
    }
} finally {
    Pop-Location
}

& $zipalign -f 4 $unsigned $aligned
if ($LASTEXITCODE -ne 0) {
    throw 'zipalign failed.'
}

if (-not (Test-Path -LiteralPath $keystore)) {
    & keytool -genkeypair `
        -keystore $keystore `
        -storepass android `
        -alias androiddebugkey `
        -keypass android `
        -dname 'CN=Android Debug,O=Samsung TV2M Research,C=US' `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -noprompt
    if ($LASTEXITCODE -ne 0) {
        throw 'Debug keystore generation failed.'
    }
}

& $apksigner sign `
    --ks $keystore `
    --ks-key-alias androiddebugkey `
    --ks-pass pass:android `
    --key-pass pass:android `
    --out $signed `
    $aligned
if ($LASTEXITCODE -ne 0) {
    throw 'APK signing failed.'
}

& $apksigner verify --verbose $signed
if ($LASTEXITCODE -ne 0) {
    throw 'APK signature verification failed.'
}

Write-Output "Built $signed"
