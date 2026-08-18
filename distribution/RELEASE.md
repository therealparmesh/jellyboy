# Release process

## Publisher prerequisites

1. Register bundle identifier `com.parmesh.jellyboy` with Apple Developer team `7654L3CX5L` and create its App Store Connect record. Confirm the App Store name before the first upload.
2. Complete Apple Developer and App Store Connect agreements, identity, tax, and banking requirements as applicable, even though the app is free.
3. Publish `docs/` through GitHub Pages and verify the support and privacy URLs without signing in.
4. Confirm the rights to the `jellyboy` name, icon, screenshots, and other submitted assets. Jellyfin discourages `Jelly[word]` names, and the name plus overall interface may raise separate Game Boy trademark or trade-dress concerns. The bundled font and frame pixels are original jellyboy constructions; retain their source and provenance records.
5. Prepare a remotely reachable HTTPS Jellyfin review account in App Store Connect's private Review Information. Never place its credentials in the repository or public TestFlight notes.
6. Complete the listing from `APP_STORE_METADATA.md`, private notes from `APP_REVIEW_NOTES.md`, and beta instructions from `TESTFLIGHT_NOTES.md`.

## Versioning

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are defined in `project.yml`. Increment the build number for every upload. Increment the marketing version for a user-visible release.

Release from a clean `main`, commit the version change as `chore: prepare <version> build <build>`, and push it before upload.

## Verify

Xcode 26 or later, XcodeGen 2.45 or later, SwiftLint 0.65 or later, and oxfmt 0.57 or later are required.

```sh
script/verify.sh
```

The command regenerates the project, rejects stale generated files, checks Markdown and Swift formatting, runs strict SwiftLint, executes all macOS-hosted unit tests, and compiles the complete iOS Simulator target without signing. The app-icon generator uses a fixed 16-by-16 pixel map so rasterization is identical across runners; freshness compares decoded sRGB pixels and dimensions rather than PNG container bytes, which can vary between encoder revisions without changing the image.

## Build a signed App Store archive

The project uses automatic signing with team `7654L3CX5L`. The Apple Development and Apple Distribution certificates must be installed in the login Keychain. The first CLI archive may create or refresh provisioning through the Xcode account configured on the release Mac.

```sh
script/release_ios.sh build
```

This runs the complete verifier, creates `dist/ios/jellyboy.xcarchive`, and exports `dist/ios/export/jellyboy.ipa` using `AppStoreExportOptions.plist`.

## Validate and upload

The upload mode refuses a dirty working tree, rebuilds the release, validates the IPA, and uploads it to App Store Connect:

```sh
script/release_ios.sh upload
```

The archive uses the explicit `jellyboy App Store` provisioning profile and a dedicated Apple Distribution certificate so the CLI does not depend on an unlocked login keychain. Signing files stay outside the repository in `~/.appstoreconnect/signing/jellyboy/`; override that directory with `JELLYBOY_SIGNING_DIR`.

Uploads use App Store Connect key ID `DC6F5JMNM3`, issuer `19bebb70-4123-40d3-9379-1476fcc51b60`, and private key path `~/.appstoreconnect/private_keys/AuthKey_DC6F5JMNM3.p8` by default. The key ID and issuer are not secrets; the `.p8` private key must remain outside the repository. Override with `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, or `API_PRIVATE_KEYS_DIR`.

The upload creates a processed build in App Store Connect. Assign it to internal or external TestFlight testers there, complete beta review when required, and later attach the approved build to an App Store version. The CLI intentionally does not submit a version for review or release it automatically.

## Submission checklist

- Fresh install, upgrade, relaunch, offline launch, and low-storage behavior
- Real iPhone and iPad playback with representative H.264, HEVC, VP9, audio, subtitles, and multiversion items
- Direct play, direct stream, transcode fallback, low-quality limits, Live TV, AirPlay, interruptions, and background audio
- Maximum and reduced-quality downloads, offline playback, removal, and clear all
- Local HTTP warning, remote HTTPS, reverse-proxy base paths, invalid credentials, expired tokens, and server unavailability
- VoiceOver, large text, portrait, landscape, light, dark, system, Red, and Blue themes
- Submission-safe fictional screenshots and working public support/privacy URLs
- Privacy manifest, App Privacy response, VLCKit notices, and asset/content rights clearance
- No committed keys, reviewer credentials, personal server addresses, tokens, archives, or IPA files

## Payments

jellyboy has no purchases, subscriptions, in-app purchases, or physical-goods checkout. Apple Pay is not part of the app or release pipeline.
