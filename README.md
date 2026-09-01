# Samsung TV2M Receiver

Reproducible tooling for viewing a compatible Samsung TV on an Android device
through Samsung's legacy TV-to-mobile Wi-Fi Display workflow.

The working path uses:

- Samsung ScreenSharing UPnP on TCP 9119
- Wi-Fi Display control on TCP 7236
- Samsung MCCP control on TCP 7237
- HDCP 2.1 and a secure Android display surface

## Compatibility boundary

This is not a generic Android screen-streaming application. The Android
firmware must provide a hardware-backed Wi-Fi Display sink, such as Samsung's
`libstagefright_wfd` integration, and provisioned HDCP receiver support.

Validated:

- Samsung Galaxy S7 Edge, Android 8: supported
- Google Pixel 10 Pro XL, Android 17: unsupported on stock firmware

See [docs/compatibility.md](docs/compatibility.md) for the evidence and device
qualification checklist.

## Prerequisites

- Windows with PowerShell 7
- Android Platform Tools (`adb`) on `PATH`
- JDK with `javac`, `jar`, and `keytool` on `PATH`
- Android SDK platform 35 or newer
- Android SDK Build Tools containing `aapt`, `d8`, `zipalign`, and `apksigner`
- TV and phone on the same LAN
- USB debugging authorized on the Android phone

Set the Android SDK through `ANDROID_SDK_ROOT` or `ANDROID_HOME`. The build
script also checks `%LOCALAPPDATA%\Android\Sdk`.

## Build

```powershell
.\android\tv2m-receiver\build.ps1
```

The generated APK and debug keystore stay under `android\...\build\` and are
ignored by Git.

## Start playback

Provide the TV address as a parameter:

```powershell
.\start-tv2m.ps1 -Address 192.168.1.50
```

Or configure it for the current shell:

```powershell
$env:SAMSUNG_TV_ADDRESS = '192.168.1.50'
.\start-tv2m.ps1
```

When multiple Android devices are connected:

```powershell
.\start-tv2m.ps1 -Address 192.168.1.50 -DeviceId <adb-serial>
```

Stop playback:

```powershell
.\start-tv2m.ps1 -Stop -DeviceId <adb-serial>
```

The video appears on the Android device. It does not create a desktop video
window. Android screenshots and scrcpy show a black video region because the
TV requires an HDCP-secure surface.

## Verify the repository

```powershell
.\verify.ps1
```

This checks PowerShell syntax, scans tracked source for local device
identifiers, and performs a clean Android build.

## Repository layout

```text
.
|-- android/
|   `-- tv2m-receiver/
|       |-- AndroidManifest.xml
|       |-- build.ps1
|       `-- src/
|-- docs/
|   |-- compatibility.md
|   `-- protocol.md
|-- start-tv2m.ps1
|-- verify.ps1
`-- NOTICE.md
```

## Scope

This repository documents and invokes a supported receiver path present in
owned Samsung hardware. It does not contain Samsung APKs, firmware libraries,
decompiled vendor source, HDCP keys, or techniques for bypassing content
protection.
