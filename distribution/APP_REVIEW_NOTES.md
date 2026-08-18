# App Review notes

jellyboy is an independent client for user-selected Jellyfin media servers. It does not provide, host, sell, or bundle media. A user normally signs in to a server they control or are authorized to use.

## Review access

The built-in sample library is available without an account:

1. Launch jellyboy.
2. Tap **Open Sample Library**.
3. Browse the sample Movies, TV Shows, and Music libraries, plus Live TV and Offline.
4. Open a series to view episodes.
5. Open a movie, episode, audio item, or channel to inspect the player and selector controls.

Sample mode uses fictional local metadata and previews the player without streaming video. To review server authentication, real playback, transcoding, Live TV, or downloads, provide a temporary, remotely reachable HTTPS Jellyfin review account in App Store Connect's private Review Information. Do not commit reviewer credentials to this repository or TestFlight notes.

## Network and local servers

The app accepts a server address chosen by the user. It supports HTTPS and also plain HTTP because many personal Jellyfin servers are available only on a trusted local network. The connection screen and Settings warn users to use HTTPS outside their home network. Local-network permission is used only to reach the server selected by the user.

## Playback and downloads

jellyboy requests Jellyfin playback information for every online item. It uses Apple's AVPlayer for compatible media and the open-source VLCKit engine for additional direct-play formats. If local playback fails, or if the user selects a lower quality, the app can ask the selected server to remux or transcode.

The app supports user-selected audio, subtitles, speed, quality, Live TV channels, background audio, system media controls, compatible AirPlay routes, and app-private offline downloads. It does not include DVR controls, Live TV recording, or Live TV downloads.

## Accounts, payments, and privacy

There is no jellyboy developer account, subscription, purchase, in-app purchase, paywall, advertising, analytics, tracking, or Apple Pay integration. The user's Jellyfin access token is stored in Keychain and sent only to the selected server. Download records omit credentials and sensitive server paths.

The privacy policy is available in Settings and at https://therealparmesh.github.io/jellyboy/privacy.

## Third-party software

VLCKit is dynamically embedded under LGPL 2.1-or-later. Notices and relinking information are provided in `THIRD_PARTY_NOTICES.md` in the source repository.
