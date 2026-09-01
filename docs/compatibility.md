# Android compatibility

## Required firmware capabilities

A candidate receiver must provide all of the following:

1. A Wi-Fi Display sink registered with Android's media framework.
2. Support for the `wfd://` media-source scheme or an equivalent callable API.
3. RTSP/WFD sink negotiation compatible with the TV.
4. HDCP 2.1 receiver credentials provisioned by the device vendor.
5. A secure hardware video-decoding and rendering path.
6. Normal TCP access to the TV's MCCP service on port 7237.

Wi-Fi Direct support alone is not enough.

## Validated devices

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
