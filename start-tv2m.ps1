#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
    [string]$Address = $env:SAMSUNG_TV_ADDRESS,

    [Parameter()]
    [string]$DeviceId,

    [Parameter()]
    [ValidatePattern('^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}$')]
    [string]$WlanMac,

    [Parameter()]
    [ValidatePattern('^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}$')]
    [string]$P2pMac,

    [Parameter()]
    [ValidatePattern('^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}$')]
    [string]$BluetoothMac,

    [Parameter()]
    [switch]$Stop
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$receiverPackage = 'tools.samsung.tv2mreceiver'
$receiverActivity = "$receiverPackage/.MainActivity"
$receiverProject = Join-Path $PSScriptRoot 'android\tv2m-receiver'
$receiverApk = Join-Path $receiverProject 'build\tv2m-receiver.apk'

function Invoke-Adb {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & adb -s $DeviceId @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed with exit code $LASTEXITCODE"
    }
}

function Get-DeviceMac {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Label
    )

    $value = (
        & adb -s $DeviceId shell cat $Path 2>$null |
            Select-Object -Last 1
    )
    if ($LASTEXITCODE -ne 0 -or $value -notmatch '^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}$') {
        throw "Unable to read $Label from $Path. Supply it explicitly."
    }
    return $value.Trim()
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw 'adb is not available on PATH.'
}

if (-not $DeviceId) {
    $devices = @(
        & adb devices |
            Select-Object -Skip 1 |
            Where-Object { $_ -match '\sdevice$' } |
            ForEach-Object { ($_ -split '\s+')[0] }
    )
    if ($devices.Count -ne 1) {
        throw "Expected one authorized Android device, found $($devices.Count). Use -DeviceId."
    }
    $DeviceId = $devices[0]
}

if ($Stop) {
    Invoke-Adb -Arguments @('shell', 'am', 'force-stop', $receiverPackage)
    Write-Output "Stopped Samsung TV2M playback on Android device $DeviceId."
    return
}

if (-not $Address) {
    throw 'Supply -Address or set SAMSUNG_TV_ADDRESS.'
}

$model = (& adb -s $DeviceId shell getprop ro.product.model).Trim()
$wfdLibraries = @(
    & adb -s $DeviceId shell ls `
        /system/lib/libstagefright_wfd.so `
        /system/lib64/libstagefright_wfd.so 2>$null
)
$withTvPackage = @(
    & adb -s $DeviceId shell pm path com.samsung.android.app.withtv 2>$null
)
if ($wfdLibraries.Count -eq 0 -and $withTvPackage.Count -eq 0) {
    throw @"
Android device '$model' does not provide a compatible TV2M WFD/HDCP media stack.
Its firmware must provide libstagefright_wfd or an equivalent hardware-backed WFD sink.
"@
}

if (-not (Test-Path -LiteralPath $receiverApk -PathType Leaf)) {
    & (Join-Path $receiverProject 'build.ps1')
}

$installedPath = (& adb -s $DeviceId shell pm path $receiverPackage 2>$null)
if (-not $installedPath) {
    & adb -s $DeviceId install --no-incremental -r -g $receiverApk
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to install receiver APK on Android device $DeviceId."
    }
}

if (-not $WlanMac) {
    $WlanMac = Get-DeviceMac -Path '/sys/class/net/wlan0/address' -Label 'WLAN MAC'
}
if (-not $P2pMac) {
    $P2pMac = Get-DeviceMac -Path '/sys/class/net/p2p0/address' -Label 'Wi-Fi Direct MAC'
}
if (-not $BluetoothMac) {
    $bluetoothOutput = Invoke-Adb -Arguments @('shell', 'dumpsys', 'bluetooth_manager')
    $bluetoothMatch = [regex]::Match(
        ($bluetoothOutput -join "`n"),
        '(?im)^\s*address:\s*([0-9a-f]{2}(?::[0-9a-f]{2}){5})\s*$'
    )
    if (-not $bluetoothMatch.Success) {
        throw 'Unable to determine the Bluetooth MAC. Supply -BluetoothMac.'
    }
    $BluetoothMac = $bluetoothMatch.Groups[1].Value
}

$body = @"
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
    s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:X_ConnectScreenSharingTV2M
        xmlns:u="urn:samsung.com:service:ScreenSharingService:1">
      <mWlanMacAddress>$WlanMac</mWlanMacAddress>
      <mP2pDeviceAddress>$P2pMac</mP2pDeviceAddress>
      <mBluetoothMacAddress>$BluetoothMac</mBluetoothMacAddress>
    </u:X_ConnectScreenSharingTV2M>
  </s:Body>
</s:Envelope>
"@

$headers = @{
    SOAPAction = '"urn:samsung.com:service:ScreenSharingService:1#X_ConnectScreenSharingTV2M"'
}
try {
    $response = Invoke-WebRequest `
        -Uri "http://$Address`:9119/upnp/control/ScreenSharingService1" `
        -Method Post `
        -Headers $headers `
        -ContentType 'text/xml; charset=utf-8' `
        -Body $body `
        -TimeoutSec 10
} catch {
    $details = $_.ErrorDetails.Message
    throw "TV rejected the screen-sharing request. $details"
}
if ($response.StatusCode -ne 200) {
    throw "TV rejected screen sharing with HTTP $($response.StatusCode)."
}

Invoke-Adb -Arguments @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
Invoke-Adb -Arguments @('shell', 'am', 'force-stop', $receiverPackage)
& adb -s $DeviceId shell run-as $receiverPackage rm -f files/status 2>$null
Invoke-Adb -Arguments @(
    'shell',
    'am',
    'start',
    '-W',
    '-n',
    $receiverActivity,
    '-a',
    'android.intent.action.VIEW',
    '-d',
    "wfd://$Address`:7236"
)

$deadline = (Get-Date).AddSeconds(15)
$playbackStarted = $false
do {
    Start-Sleep -Milliseconds 500
    $status = (
        & adb -s $DeviceId shell run-as $receiverPackage cat files/status 2>$null
    ) -join ''
    if ($status -like 'error:*') {
        throw "Samsung TV2M playback failed: $status"
    }
    $playbackStarted = $status -eq 'playing'
} while (-not $playbackStarted -and (Get-Date) -lt $deadline)

if (-not $playbackStarted) {
    throw 'Samsung TV2M did not reach media rendering within 15 seconds.'
}

Write-Output "SUCCESS: TV playback is running on $model ($DeviceId)."
Write-Output 'Look at the phone screen; no video window will open on this PC.'
Write-Output 'NOTE: HDCP requires a secure phone surface, so screenshots and scrcpy show black video.'
