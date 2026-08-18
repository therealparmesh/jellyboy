---
title: jellyboy Privacy Policy
---

# jellyboy privacy policy

_Effective date: August 16, 2026_

## Summary

The jellyboy developer does not collect your information. jellyboy has no developer-operated account, analytics, advertising, tracking, or backend service.

## Your Jellyfin server

jellyboy connects directly to the Jellyfin server address you choose. Your server receives the sign-in and media requests needed to provide its service, including your username, password during sign-in, access token after sign-in, playback and download choices, device identifier, IP address, and other standard network information. The server operator's privacy and retention practices apply to that traffic.

Your password and access token are never sent to the jellyboy developer. Use a server you trust and HTTPS whenever traffic leaves a trusted local network. A server using plain HTTP does not encrypt traffic in transit.

## Data stored on the device

jellyboy stores the active server session in the operating system Keychain. Up to three server addresses and your appearance preferences are stored in local app settings. Server history does not contain usernames, passwords, access tokens, queries, or fragments.

Artwork may be retained temporarily by the operating system's network cache. Downloaded media, selected text subtitles, and download records are stored in app-private storage. Download records exclude access tokens, authorization headers, server file paths, and transcode URLs.

Use **Settings → Change Server** to remove the active saved login. Remove one download or all downloads from the Offline entry. Uninstalling removes app-private media and settings; the operating system may retain Keychain items across reinstall.

## Playback and third parties

Media is processed on the device by Apple's media frameworks or the bundled open-source VLCKit library. VLCKit does not add a jellyboy-operated service. If you choose AirPlay, the device and AirPlay destination handle that playback. Jellyfin server software, server plug-ins, reverse proxies, hosting providers, and AirPlay destinations are controlled by their respective operators and policies.

The built-in sample library uses local fictional metadata and does not contact a media server.

## App Store privacy response

The current release is described as **Data Not Collected** because the developer does not receive data from the app. Re-evaluate that response before every release if analytics, crash reporting, advertising, cloud services, or any developer-operated backend is added.

## Changes and contact

This policy may be updated when jellyboy changes. The effective date above identifies the current version.

- Email: [parmesh@hey.com](mailto:parmesh@hey.com)
- GitHub: [therealparmesh/jellyboy](https://github.com/therealparmesh/jellyboy)
