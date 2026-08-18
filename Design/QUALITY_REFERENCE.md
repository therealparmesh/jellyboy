# Jellyfin quality reference

jellyboy's fixed bitrate presets are derived from the official open-source Jellyfin clients, pinned on August 16, 2026:

- [Swiftfin `PlaybackBitrate`](https://github.com/jellyfin/Swiftfin/blob/0ec38cfe47dcc14ed4ae8083da00d40c557bb0b3/Shared/Objects/PlaybackBitrate/PlaybackBitrate.swift)
- [Swiftfin source-bitrate filtering](https://github.com/jellyfin/Swiftfin/blob/0ec38cfe47dcc14ed4ae8083da00d40c557bb0b3/Shared/Extensions/JellyfinAPI/MediaSourceInfo.swift)
- [jellyfin-web quality options](https://github.com/jellyfin/jellyfin-web/blob/889b7b6f25d1dd207792f127f79d57a362b09483/src/components/qualityOptions.js)

The video ladder is Maximum; 120, 80, 60, 40, 20, 15, 10, 8, 6, 4, 3, and 1.5 Mbps; then 720 and 420 Kbps. The audio ladder is Maximum; 2, 1.5, and 1 Mbps; then 320, 256, 192, 128, 96, and 64 Kbps. Known source bitrates hide fixed presets above the source, matching Swiftfin's behavior.

Swiftfin's Maximum value is 360 Mbps, which jellyboy sends as both the playback request and device-profile ceiling. jellyboy does not expose Swiftfin's Auto option because Auto depends on a real server bitrate test. A label without that mechanism would misrepresent the behavior.

Only the public numeric presets and behavior are reproduced. jellyboy's implementation and interface are independent Swift code and use no copied Jellyfin graphics.
