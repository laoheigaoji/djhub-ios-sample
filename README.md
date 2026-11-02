# DJHUB iOS Sample

DJHUB is a SwiftUI short-drama metadata app for iPhone and iPad. It provides
catalog browsing, Top 200 rankings, categories, favorites, search, people and
company information, and drama detail pages.

DJHUB does not provide streaming playback, media downloads, or hidden playback
features.

## Build

- Xcode 27.1
- iOS 17.0 or later
- Open `DJHUB.xcodeproj`
- Build the shared `RovePlayer` scheme

The Release configuration enables `DJHUB_METADATA_ONLY`.

Optional Trakt credentials belong in `Config/TraktSecrets.xcconfig`; use
`Config/TraktSecrets.xcconfig.example` as the template. The local credentials
file is intentionally excluded from Git.
