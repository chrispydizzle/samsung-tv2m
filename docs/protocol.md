# Protocol flow

## Sequence

```mermaid
sequenceDiagram
    participant CLI as PowerShell launcher
    participant TV as Samsung TV
    participant App as Android receiver
    participant WFD as OEM WFD/HDCP stack

    CLI->>CLI: Read Android WLAN, P2P, and Bluetooth addresses
    CLI->>TV: X_ConnectScreenSharingTV2M via UPnP :9119
    TV-->>CLI: BSSID, frequency, WFD source port 7236
    CLI->>App: Launch wfd://TV:7236
    App->>TV: Connect MCCP :7237
    App->>TV: VERSION MCCP/1.1
    App->>WFD: MediaPlayer.setDataSource(wfd://...)
    WFD->>TV: RTSP/WFD capability exchange :7236
    WFD<->>TV: HDCP 2.1 key exchange
    WFD->>TV: SETUP and PLAY
    TV-->>WFD: Encrypted MPEG-TS over RTP
    WFD-->>App: Render through secure SurfaceView
```

## UPnP trigger

The launcher posts the Samsung vendor action:

```text
urn:samsung.com:service:ScreenSharingService:1
#X_ConnectScreenSharingTV2M
```

Inputs identify the receiving phone's WLAN, Wi-Fi Direct, and Bluetooth
interfaces. The TV returns its Wi-Fi parameters and WFD source port.

## Wi-Fi Display

The receiver passes this URI to Android's media framework:

```text
wfd://<tv-address>:7236
```

Compatible Samsung firmware routes this scheme to its Wi-Fi Display sink
implementation. Stock Android implementations without that integration may
treat the URI as a filesystem path and fail immediately.

The validated Samsung sink advertises:

```text
User-Agent: SEC-WDH/VND-DAREF
wfd_content_protection: HDCP2.1
wfd2_tcp_ports: none
wfd2_buffer_len: none
```

The TV refuses to continue capability negotiation when the otherwise matching
sink profile advertises `wfd_content_protection: none`.

## MCCP

The companion control connection uses TCP 7237. The receiver sends:

```text
VERSION MCCP/1.1 Seq=0
mccp_version=1.2 device_type=mobile
```

Keeping this connection open prevents the TV from terminating an otherwise
working media session after approximately 45 seconds.

## Security boundary

The stream is decrypted and rendered inside the OEM's protected media path.
The receiver application receives a display surface, not decrypted video
frames. Screenshot and screen-capture APIs therefore return black video.
