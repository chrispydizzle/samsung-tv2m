# Hardware compatibility

Compatibility has two independent parts:

- The TV must expose Samsung's legacy TV-to-mobile ScreenSharing workflow.
- The Android device must provide a hardware-backed Wi-Fi Display receiver.

General Smart View, casting, Miracast, or Wi-Fi Direct support does not by
itself prove compatibility with this workflow.

## Validated TV

| Device | Platform | Result |
|---|---|---|
| Samsung UN75MU8000 (2017 MU series) | Tizen platform family `17_KANTM_UHD` | Supported: the TV accepted `X_ConnectScreenSharingTV2M`, opened WFD on port 7236, required HDCP 2.1, and maintained playback with MCCP on port 7237. |

The following estimates are based on the validated MU8000, public evidence of
the ScreenSharing service on later models, and Samsung's Smart View product
timeline. They are not results from a representative hardware test sample.

| Samsung TV family | Estimated chance for this exact workflow | Rationale |
|---|---:|---|
| Same `17_KANTM_UHD` platform as the MU8000 | 85-95% | Most likely to share the same Tizen generation, AllShare/WFD stack, and ScreenSharing service behavior. |
| Other 2017 M/MU/Q models | 70-85% | Released while Samsung's TV-to-mobile Smart View workflow was active. |
| 2016 K/KU/KS models | 50-70% | Likely to contain a related Smart View stack, but protocol and codec differences are more plausible. |
| 2018 N/NU/Q and 2019 R/Q models | 50-75% | Public observations include the ScreenSharing service on a 2019 Q60R, but the complete TV2M path has not been validated here. |
| 2020 and newer models | Under 30% | Samsung retired the standalone Smart View workflow and may have removed or replaced the legacy integration. |
| Pre-Tizen and older Samsung TVs | Under 20% | Some models offered a legacy "Second TV" feature, but it may use an incompatible protocol generation. |

Model year is only a rough guide. Stronger compatibility indicators are:

1. TCP port 9119 is available while the TV is awake.
2. The TV advertises `urn:samsung.com:device:ScreenSharing:1`.
3. Its ScreenSharing service schema contains
   `X_ConnectScreenSharingTV2M`.
4. Its ScreenSharing metadata reports `WFDRole:PrimarySink` or
   `WFDRole:Dual`, along with WLAN frequency and BSSID information.
5. After an authorized TV2M request, the TV opens WFD port 7236.
6. During playback, the TV provides MCCP control on port 7237.

If the first four indicators are present, the TV is a strong candidate. The
remaining risks are differences in HDCP requirements, codec negotiation, or
MCCP behavior. If port 9119 or `X_ConnectScreenSharingTV2M` is absent, this
exact workflow is not available even if the TV supports ordinary Smart View or
Miracast casting.

## Required Android firmware capabilities

A candidate receiver must provide all of the following:

1. A Wi-Fi Display sink registered with Android's media framework.
2. Support for the `wfd://` media-source scheme or an equivalent callable API.
3. RTSP/WFD sink negotiation compatible with the TV.
4. HDCP 2.1 receiver credentials provisioned by the device vendor.
5. A secure hardware video-decoding and rendering path.
6. Normal TCP access to the TV's MCCP service on port 7237.

Wi-Fi Direct support alone is not enough.

## Validated Android devices

| Device | Firmware result | Evidence |
|---|---|---|
| Samsung Galaxy S7 Edge, Android 8 | Supported | Samsung WFD sink completed HDCP, RTSP SETUP/PLAY, media preparation, rendering, and MCCP status exchange. |
| Google Pixel 10 Pro XL, Android 17 | Unsupported | Stock media framework treated `wfd://<tv>:7236` as a local file and returned `MediaPlayer` error `1/-2147483648`. |

## Qualification

The launcher checks for known firmware indicators:

- `/system/lib/libstagefright_wfd.so`
- `/system/lib64/libstagefright_wfd.so`
- Samsung's `com.samsung.android.app.withtv` package

These checks are evidence of likely support, not a universal vendor allowlist.
Other OEM firmware can be compatible if it exposes an equivalent
hardware-backed WFD sink.

If Android restricts access to radio MAC addresses, supply them explicitly:

```powershell
.\start-tv2m.ps1 `
    -Address 192.168.1.50 `
    -WlanMac AA:BB:CC:DD:EE:01 `
    -P2pMac AA:BB:CC:DD:EE:02 `
    -BluetoothMac AA:BB:CC:DD:EE:03
```
