<div align="center">

# HADES

**Your music. Your underworld.**

A customizable YouTube Music client for Android, built with Flutter.

Created by **[ItzFallenMe](https://github.com/ItzFallenMe)**

</div>

Hades streams from YouTube Music, keeps a local library of favorites and
playlists, downloads tracks for offline listening, and gives you the kind of
theme and layout control you would expect from a dedicated local player.

It takes its streaming system and feature direction from
[SimpMusic](https://github.com/maxrave-dev/SimpMusic), and its deep,
artwork-driven customization from [namida](https://github.com/namidaco/namida).
Hades is an independent Flutter codebase written for this project.

## Features

### Streaming and discovery

- YouTube Music home feed, charts, new releases, moods & genres, and podcasts
- Search across songs, albums, artists, playlists, and videos
- Album, playlist, artist, mood, and podcast pages with Play all / Shuffle
- Background playback with a media notification and lock-screen controls
- Queue with drag-to-reorder, play next, and add to queue
- Autoplay similar music when the queue ends
- Sleep timer: 15 minutes to 2 hours, or end of the current track
- Playback speed from 0.5× to 2×, skip-silence, and 2–8 second crossfade
- Synced and plain lyrics from [LRCLIB](https://lrclib.net), with tap-to-seek,
  ±0.5 s timing offset, full-screen mode, copy, word-by-word highlighting, and
  optional AI translation
- SponsorBlock auto-skip and Return YouTube Dislike counts
- Ten-band device equalizer with presets and a custom curve
- Listening stats: plays, top artists and tracks, a 14-day chart, a listening
  clock, and a period recap

### Hades rituals (unique to Hades)

- **Today's Descent** — a once-a-day discovery mix built from your own orbit,
  cached for the day, with a listening streak and an animated underworld sigil
- **Time machine** — every track you played on this date in past years, grouped
  by year and playable as one memory queue
- **AI DJ** — a private set shaped by your favorites, history, and a mood, using
  your own Gemini or OpenAI key and real YouTube Music searches

### Library

- Favorites, local playlists, and listening history stored on the device
- Create, rename, reorder, and delete playlists
- Import any public YouTube or YouTube Music playlist by link
- Download any track for offline playback, with live progress and storage usage
- Recent searches
- JSON backup and restore for the library, listening history, and every setting
- In-app playback of downloaded audio when YouTube is unreachable

### Look and feel

- Light, dark, and AMOLED themes, plus system theme
- Dynamic colors extracted from the current artwork, or 9 accent presets
- Glassmorphism with adjustable blur and opacity across the mini player,
  navigation chrome, and every bottom sheet
- App animations with off/subtle/normal/lively presets for page transitions,
  staggered reveals, and micro-motion
- Three player layouts: Classic, Widescreen, and Minimal
- Floating or attached mini player
- Adjustable corner radius and artwork blur
- Comfortable or compact track lists
- Show/hide navigation tabs
- Animated artwork cross-fades
- Responsive layout: bottom navigation on phones, navigation rail on tablets

## Build an APK

### Requirements

- Flutter 3.44 (stable) with Dart 3.12
- Android SDK and JDK 17
- Android 6.0 (API 23) or newer

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

A release keystore is optional locally: without `android/key.properties`, the
Gradle build falls back to the debug key so the release APK still installs.
For a store-ready build, add a keystore and `android/key.properties`:

```properties
storeFile=../release.keystore
storePassword=…
keyAlias=…
keyPassword=…
```

### Live network check

Unit tests never touch the network. An opt-in live test checks YouTube Music
metadata, the radio queue, LRCLIB lyrics, and audio stream resolution:

```bash
flutter test --run-skipped -t network
```

> YouTube can answer a datacenter IP with "Sign in to confirm you're not a
> bot". The stream resolver tries the visitor-aware web client first, then
> several Android/iOS clients. On a normal home or mobile connection music
> playback resolves without a sign-in. Downloaded tracks still play offline.

## GitHub Actions

Every push to `main`, pull request, and manual dispatch builds a release APK in
[Actions](https://github.com/RayanBuilds/Hades/actions). Tagging a commit
(`git tag v1.0.0 && git push --tags`) also attaches the APK to a GitHub release.

The workflow is `.github/workflows/android.yml` and produces:

- **Hades-APK** — downloadable artifact in the Actions run
- **Hades-<version>.apk** — attached to the tag's GitHub release

To sign CI builds with your own key, add these repository secrets:

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | `base64 -w0 release.keystore` |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | key alias |
| `KEY_PASSWORD` | key password |

Without them the workflow still builds and uploads an APK signed with the debug
key, which is fine for side-loading and testing.

## Customization

Open **Settings → Customize**. Everything applies instantly:

- **Theme** — System, Light, Dark, or AMOLED
- **Dynamic artwork colors** — tint the interface from the current cover
- **Accent** — Ember, Gold, Crimson, Rose, Violet, Ocean, Cyan, Emerald, Sand
- **Player layout** — Classic, Widescreen, or Minimal
- **Mini player** — floating card or attached bar
- **Shape & texture** — corner radius 0–32, artwork blur 0–80
- **Lists** — comfortable or compact density
- **Navigation tabs** — hide Home, Explore, Search, Library, or Settings
- **Animated artwork** — cross-fade between covers

Choices are saved with `shared_preferences`.

## Project structure

```
lib/
  core/        theme tokens, constants, formatting, LRC parser
  data/
    api/       InnerTube client, stream resolver, LRCLIB lyrics
    models/    tracks, browse pages, lyrics, library records
    music_repository.dart
  state/       settings, library, downloads, player controllers
  ui/
    pages/     home, explore, search, library, downloads, player, settings
    widgets/   artwork, cards, tiles, sheets, mini player
    shell/     responsive app shell
```

State management is `provider` + `ChangeNotifier`, audio is `just_audio` with
`just_audio_background`, images use `cached_network_image`, and colors come from
`palette_generator`. InnerTube calls use YouTube Music's public web endpoints;
no API key or account is required.

## Limitations

- Hades is an unofficial client and is not affiliated with YouTube or Google.
- There is no Google account sign-in, so the home feed is anonymous and premium
  bitrates are unavailable.
- Some tracks may be region-restricted, age-restricted, or refused by YouTube's
  bot checks; the player surfaces the error.
- Playback is online-only unless a track was downloaded.
- Lyrics come from LRCLIB and can be missing or mismatched.
- Playback is not gapless between tracks; each track is resolved on demand.
  Crossfade is a volume fade, not a true overlapping mix.

### SimpMusic feature coverage

Hades covers SimpMusic's core listening loop: YouTube Music browsing, search,
podcasts, charts, moods, playlists, lyrics, downloads, SponsorBlock, Return
YouTube Dislike, a device equalizer, crossfade, playback speed, listening stats,
and a period recap, with namida-style customization on top. It also adds
rituals SimpMusic does not have: Today's Descent and the Time machine.

Some SimpMusic features need a Google account, a paid API, or native Android
surfaces that a single Flutter pass cannot provide. These are not in Hades yet:

- Google / YouTube Music sign-in, liked-song and playlist sync, multi-account,
  and "send back to Google" history
- SimpMusic Wrapped artwork sharing, monthly recap playlists, and chart API
- Home-screen widgets, Android Auto, Cast, and Discord Rich Presence
- Last.fm scrobbling, Listen Together rooms, and artist notifications
- Spotify Canvas animated art, 1080p video playback, and live stations
- AutoEq headphone profiles, delay/reverb effects, and Desktop/TV builds
- Word-by-word lyrics, romanization, and translated lyrics

## Privacy

Hades has no analytics, tracking, crash reporting, or backend of its own.
Search queries, favorites, playlists, history, and settings stay on the device.
Requests go to YouTube Music, googlevideo CDN hosts for audio, and LRCLIB for
lyrics. The optional AI DJ and lyric translation send only your prompt to the
AI provider you configure; your API key stays on the device and is never
included in exports.

## Credits

- [SimpMusic](https://github.com/maxrave-dev/SimpMusic) — InnerTube streaming
  approach, feature set, and inspiration.
- [namida](https://github.com/namidaco/namida) — customization depth,
  artwork-led theming, and player layout inspiration.
- [LRCLIB](https://lrclib.net) — open lyrics.
- Flutter, just_audio, audio_service, cached_network_image, palette_generator,
  provider, and the wider Flutter community.

## Disclaimer

Hades is provided for personal and educational use. It does not host, upload, or
distribute any media; artwork and audio come from YouTube's public web
endpoints. It is not a replacement for YouTube Music Premium. Please support
the artists you listen to by subscribing or buying their music, and make sure
your use complies with the laws and terms of service where you live.

---

Made with 🔥 by [ItzFallenMe](https://github.com/ItzFallenMe)
