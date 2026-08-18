# TestFlight notes

## What's new

Build 6 keeps long titles and wide artwork inside a stable, vertical library grid with no horizontal overflow. Device-local downloads live under Offline, so a server library named Downloads remains distinct. The app icon now has deterministic pixel rendering across build machines.

## What to test

- Sign in over local HTTP and remote HTTPS, switch servers, and verify recent URLs never display credentials
- Confirm the library picker matches the signed-in user's Jellyfin library names and order
- Confirm a server library named Downloads stays distinct from the Offline destination
- Switch between libraries and confirm each one shows only its own movies, series, music, and authenticated artwork
- Check that long titles and landscape artwork stay inside the vertical card grid without horizontal scrolling
- Compare Maximum with the source-appropriate official Jellyfin presets down to 420 Kbps for video and 64 Kbps for audio
- Confirm the player reports Direct, Direct Stream, or Transcode and AV or VLC accurately
- Test audio, subtitle, speed, and quality selectors with multiple tracks
- Test text subtitles and a bitmap subtitle that requires server conversion
- Play compatible media through AirPlay and verify VLC-only media falls back clearly when conversion is needed
- Lock the device and test background audio, Control Center, seeking, and 10-second skip controls
- Download maximum and reduced-quality media with selected audio and subtitles, find it under Offline, play it without the server, remove one item, and clear all downloads
- Play Live TV through both a direct source and a server-converted HLS source
- Check Red and Blue palettes in Light, Dark, and System appearance
- Check iPhone and iPad layouts in portrait and landscape with large text and VoiceOver

Include the device model, OS version, Jellyfin server version, selected quality, reported playback method and engine, and relevant media codecs. Never include passwords, access tokens, or a complete private server URL.
