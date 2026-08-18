---
title: jellyboy Support
---

# jellyboy support

_Last updated: August 17, 2026_

## Contact

For help with jellyboy, contact [parmesh@hey.com](mailto:parmesh@hey.com).

Include the device model, operating-system version, jellyboy version, Jellyfin server version, selected quality, and whether the player reported AV or VLC. Never include passwords, access tokens, authorization headers, or a complete private server URL.

See the [privacy policy](privacy) for details about local data and network requests.

## Connection

Enter the complete address of your Jellyfin server, including its port or path when required. jellyboy adds `http://` to a local address without a scheme. Use HTTPS whenever the connection leaves a trusted home network.

If sign-in fails, confirm the same address, username, and password work in a browser. Check the server's reverse-proxy and local-network settings. Settings → Change Server returns to the connection screen and retains up to three recent server addresses without saving credentials in that history.

## Libraries

The library picker uses the names and order configured for the signed-in Jellyfin user. Selecting a library loads only playable items from that library. Live TV and Offline are separate entries in the same picker.

## Playback and Live TV

Maximum quality first asks Jellyfin for a direct source with Swiftfin's 360 Mbps ceiling. jellyboy uses Apple's player for compatible media and VLCKit for additional formats. If local playback fails, it asks Jellyfin for a remux or transcode. Lower quality limits intentionally allow server transcoding.

Live TV availability and guide data depend on the selected server. jellyboy supports channel playback but does not currently include guide, recording, or DVR controls.

For AirPlay video, choose media that uses the AV engine. VLC-only media may need Jellyfin conversion before an AirPlay destination can play it. Background audio and system media controls are available after playback starts.

## Audio and subtitles

Audio, subtitle, speed, and quality selectors appear in the player when options are available. Text subtitles can be selected directly. Some bitmap subtitle formats require Jellyfin to burn them into a converted stream.

## Downloads

Choose quality, audio, and subtitles before downloading. Maximum quality copies or remuxes when possible; a lower bitrate may ask the server to transcode. Open Offline to remove one item or clear all downloaded media.

Downloads run while jellyboy remains active. Background download continuation and Live TV downloads are not currently supported.

## Project

jellyboy is an independent project and is not affiliated with, endorsed by, or maintained by the Jellyfin project.

- GitHub: [therealparmesh/jellyboy](https://github.com/therealparmesh/jellyboy)
