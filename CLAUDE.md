# Living Wall — Phase 1

Smart LED ambient wall product. Premium home lighting that doubles as moody atmosphere. This repository is the **Flutter mobile app** that controls the wall(s) via WLED firmware running on ESP32.

**Phase 1 = local-first MVP.** No cloud, no accounts, no backend. App talks directly to walls over the local WiFi network.

---

## Quick context

- **Hardware:** ESP32-S3 + stock WLED firmware + LED strip (density/length TBD by ID team)
- **Communication:** WLED JSON API over HTTP + WebSocket on local network
- **App:** Flutter, this repository
- **Group sync:** WLED UDP sync handles room-level synchronization — app does not orchestrate
- **Discovery:** mDNS scan for `_wled._tcp` with subnet ping fallback

---

## Phase 1 scope

### IN
- iOS + Android app
- Hierarchy: Home → Room → Wall
- 18 curated scenes (catalog hardcoded in `assets/scenes.json`)
- 4 categories: Tenang / Fokus / Sosial / Dinamis
- Per-wall and per-room control
- Onboarding (captive portal wrapped as guided UX)
- Add wall / add room flows
- Local persistence via drift (SQLite)

### OUT (deferred to Phase 2+)
- Cloud backend, accounts, multi-user
- Firebase / Push notifications
- HomeKit / Google Home / Matter
- OTA firmware updates from app
- Audio reactivity (needs WLED firmware fork)
- Voice control
- Schedules / automations
- Adding scenes beyond the curated 18

---

## Tech stack

| Package | Version | Role |
|---|---|---|
| flutter | 3.24+ | Framework (Material 3, Dart 3.x) |
| flutter_riverpod | ^2.5 | State management |
| riverpod_generator | ^2.4 | Provider code-gen |
| go_router | ^14 | Declarative routing |
| dio | ^5.5 | HTTP client (with retry/timeout) |
| web_socket_channel | ^3 | WebSocket to WLED `/ws` |
| multicast_dns | ^0.3 | mDNS discovery |
| network_info_plus | ^6 | WiFi SSID/IP |
| drift | ^2.20 | Type-safe SQLite |
| freezed | ^2.5 | Immutable models |
| json_serializable | ^6.8 | JSON parsing |
| google_fonts | ^6.2 | Fraunces + Hanken Grotesk |
| permission_handler | ^11 | Android location, iOS local network |
| url_launcher | ^6.3 | Open WiFi settings |

### Don't add without discussion
- **Anything cloud/Firebase** — violates local-first decision
- **State libs other than Riverpod** — already standardized
- **Heavy UI kits** (GetX, etc) — Material 3 + custom theme is enough
- **Forks of WLED dependencies** — we're stock-firmware on purpose

---

## Architecture — 4 layers

```
presentation/  → widgets, screens, routing
       ↓
application/   → Riverpod providers, controllers, use cases
       ↓
data/          → models (Freezed), services, repositories, drift DB
       ↓
core/          → theme, constants, utils
```

**Rule:** layers call downward only. A widget can read providers but cannot import services. A controller can call repositories but cannot import widgets.

### Folder structure
```
lib/
  main.dart                # ProviderScope + runApp
  app.dart                 # MaterialApp.router
  core/
    theme/                 # app_theme.dart, colors.dart, typography.dart
    constants/             # durations.dart, network.dart
  data/
    models/                # home.dart, room.dart, wall.dart, scene.dart (all Freezed)
    database/              # app_database.dart, tables.dart (drift)
    services/              # wled_client.dart, wled_socket.dart, discovery_service.dart, wifi_service.dart
    repositories/          # home_repository.dart, wall_repository.dart, scene_repository.dart
  application/
    providers/             # *_providers.dart (one file per domain)
    controllers/           # onboarding_controller.dart, scene_application_controller.dart, add_wall_controller.dart
  presentation/
    routing/               # app_router.dart, routes.dart
    screens/
      onboarding/          # empty_state, wifi_guide, discovery, name_place
      dashboard/           # dashboard_screen.dart
      room/                # room_screen.dart (parameterized, used 4x)
      wall/                # wall_control_screen.dart
      scenes/              # scene_gallery_screen.dart, adjustment_sheet.dart
    widgets/               # room_card, mini_controls, scene_card, sync_banner, etc.
assets/
  scenes.json              # 18 scene catalog
  images/scenes/           # bundled thumbnails
```

---

## Domain model

### Entities
- **Home** — top-level container. Phase 1: only one home, but model supports multiple.
- **Room** — a space in the home. Maps 1:1 to a WLED UDP sync group.
- **Wall** — a physical LED panel. Belongs to exactly one Room. Has WLED device (ESP32) at an IP address.
- **Scene** — a curated mood preset. Catalog is static (18 scenes). Maps to WLED JSON API params: `fx`, `pal`, `bri`, `sx`, `ix`, optional `col`.

### Relationships
- Home has many Rooms
- Room has many Walls (one Room must have at least one Wall after onboarding)
- Wall references a Room (foreign key, required)
- Scene is independent — referenced by id from anywhere

### State that's NOT persisted
- **WallState** (current brightness, on/off, active scene) — derived from WebSocket stream, lives only in memory
- **Discovered walls** — transient, only during add-wall flow

---

## Design system

### Palette
- **Background:** `#000000` (true black)
- **Surfaces:** `#0C0D10`, `#141619`, `#1C1F25` (rising layers)
- **Accent (periwinkle):** `#7C8EF5` primary, `#9AA8FF` light, `#5D6FE0` deep
- **Text:** `#EEF0F5` full, with `.56` and `.32` opacity for dim/faint

### Category colors (only for scene category badges)
- Tenang `#8AA6C9` (blue-grey)
- Fokus `#9EC5A8` (sage green)
- Sosial `#D2A07A` (warm tan)
- Dinamis `#C688B8` (mauve)

### Typography
- **Display:** Fraunces (italic for emphasis only — `em` not `b`)
- **Body:** Hanken Grotesk
- Load via `google_fonts` package, **not** bundled (saves ~400KB)

### Don't
- **Amber palette** — we explicitly moved away from it. Periwinkle is the chrome.
- **Round corners > 20px** unless specifically a phone-frame mockup
- **Heavy drop shadows** — surfaces use 1px borders, not shadows
- **Glassmorphism / blur** for chrome — only for modal scrim if needed
- **Emoji icons** — use SVG icon set defined in design (line style, periwinkle stroke)

### Scene thumbnails
Use real photographic images (Unsplash references in design canvas), bundled to `assets/images/scenes/`. Not CSS gradients — gradients are for the wall's actual rendered state.

---

## Key user flows (memorize these)

### 1. Onboarding (4 steps)
First launch → Empty state → WiFi guide → Discovery → Name & place → Dashboard

### 2. Daily use (the 80% case)
Open app → Dashboard → tap mini-control on RoomCard → wall changes. Most actions never leave the Dashboard.

### 3. Pick scene (deeper)
Wall Control → tap "Lihat semua" → Scene Gallery (category tabs) → tap scene → applied immediately. Adjustment Sheet only opens if user wants to fine-tune.

### 4. Group control
Already implicit: a Room is a sync group. Change one wall in the room → all walls in that room change. To exclude one wall temporarily, the user can mark it excluded in Room screen.

### 5. Add wall / Add room (entry per context)
- **'+' button on Dashboard** = add room (then immediately enter add-wall flow)
- **'Tambah wall' inside Room screen** = add wall to this specific room
- Wall is ALWAYS placed in a room. No "unassigned" state.
- Add wall flow = same 3-step module (WiFi → Discovery → Name) used by onboarding

---

## Scene catalog (18 scenes — IDs and params)

Reference only — full data is in `assets/scenes.json`. Each scene has a stable `id`.

**Tenang (6):** ocean, candle, dawn, aurora, rain, breathe
**Fokus (3):** focus, forest, daylight
**Sosial (6):** sunset, dinner, movie, tokyo, golden, sakura
**Dinamis (3):** fireplace, twinkle, party

Default `transition: 14` (1.4s). Wind Down (`dawn`) uses `30` (3s) for slower fade.

See `docs/scene-catalog.html` for full params per scene including fx/pal/bri/sx/ix/col.

---

## Network architecture

### Three services, separated by concern
1. **WledClient** — HTTP POST to `/json/state` to control wall
2. **WledSocket** — WebSocket to `/ws` to receive state changes (with reconnect)
3. **DiscoveryService** — mDNS scan (8s timeout) then subnet ping fallback

### Sync groups
When a wall is added to a Room, app must set both:
```
udpn.send = true
udpn.recv = true
```
via `/json/cfg`. After that, app does not orchestrate sync — WLED does it.

### IP discovery is not persistent
Walls' IPs can change (DHCP). On each app launch, run discovery and match by `deviceId` (MAC) to update stored IP. Don't trust stored IPs as truth — they're caches.

---

## Native config (don't forget)

### iOS (`ios/Runner/Info.plist`)
- `NSBonjourServices` array containing `_wled._tcp`
- `NSLocalNetworkUsageDescription` (clear user-facing copy)
- `NSAppTransportSecurity` → `NSAllowsLocalNetworking: true`

### Android (`android/app/src/main/AndroidManifest.xml`)
- `INTERNET`, `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`
- `ACCESS_FINE_LOCATION` (required to read SSID on Android 8.1+)
- `networkSecurityConfig="@xml/network_security_config"` with cleartext allowed for `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`

**These are not optional.** App will fail to discover walls without them, and the failure mode is silent.

---

## Code conventions

### Files
- `snake_case.dart` for filenames
- One public class per file when the class is non-trivial
- Test files: `<name>_test.dart` mirror in `test/` matching `lib/` structure

### Naming
- Widgets: `PascalCase`, end with role (`RoomCard`, `WallControlScreen`, `AdjustmentBottomSheet`)
- Providers: `camelCase` ending with `Provider` (`roomsProvider`, `wallStateProvider`)
- Controllers: `PascalCase` ending with `Controller` (`SceneApplicationController`)
- Constants: `camelCase` in classes (`AppColors.accent`), `SCREAMING_SNAKE` only for truly global env constants

### Models
- Always Freezed
- Always immutable
- JSON via `json_serializable`
- No mutable lists/maps as fields (use `List<T>` not `List<T?>?`)

### State
- **Read** state with `ref.watch()` in widgets
- **Read once** with `ref.read()` in event handlers and controllers only
- **Don't** modify state from widgets — go through a controller
- **AsyncValue** for everything that involves IO; never `try/catch` raw in widgets

### Imports order
1. Dart SDK
2. Flutter
3. External packages (alphabetical)
4. Same project (relative paths)

### Comments
- **Code comments in English.** Don't translate.
- Comment **why**, not **what**. Code says what.
- TODO comments must include name and date: `// TODO(rio, 2026-05): tune brightness on hardware`

---

## Common review checks

Run through this list whenever reviewing a diff, finishing a feature, or before suggesting a commit. Items are ordered by blast radius — top items break the app, bottom items just degrade quality.

### Architecture & state
- [ ] Layer direction respected: `presentation → application → data → core`. No widget imports a service. No controller imports a widget.
- [ ] State mutations go through a controller, never from a widget directly.
- [ ] `ref.watch()` only inside `build`/provider bodies; `ref.read()` only in event handlers and controllers.
- [ ] IO returns `AsyncValue<T>`. No raw `try/catch` swallowed inside widgets.
- [ ] No new state management package added (Riverpod only).

### Models & data
- [ ] New domain types are Freezed + `json_serializable`, immutable, no nullable collections.
- [ ] Drift schema migration added if any table changed.
- [ ] `*.g.dart` / `*.freezed.dart` not staged (check `.gitignore` is honored).
- [ ] Wall IPs treated as cache, not truth — discovery matches by `deviceId` (MAC) on each launch.

### Network & native config
- [ ] When a wall joins a room, both `udpn.send` and `udpn.recv` are set via `/json/cfg`.
- [ ] HTTP calls go through `WledClient` with retry/timeout — not raw `dio` calls scattered in features.
- [ ] WebSocket consumers handle reconnect; no assumption the socket stays open.
- [ ] iOS `Info.plist`: `NSBonjourServices` includes `_wled._tcp`, `NSLocalNetworkUsageDescription` set, ATS allows local networking.
- [ ] Android `AndroidManifest.xml`: WiFi/multicast/location permissions present, `networkSecurityConfig` allows cleartext for private subnets.

### Design system
- [ ] Colors come from `AppColors` — no inline hex except in the theme file itself.
- [ ] No amber / warm-yellow used for chrome. Category colors only on scene badges.
- [ ] Typography via `google_fonts` (Fraunces display, Hanken Grotesk body). Italic Fraunces only for emphasis.
- [ ] No glassmorphism/blur on chrome surfaces. No drop shadows — borders instead.
- [ ] No emoji icons; use the project SVG icon set.

### Scenes
- [ ] Scene catalog stays at 18 entries. New scenes only after hardware tuning.
- [ ] Scene params match `assets/scenes.json` shape: `fx`, `pal`, `bri`, `sx`, `ix`, optional `col`, `transition` (default 14).

### Conventions hygiene
- [ ] Filenames `snake_case.dart`; widgets/controllers/providers follow naming suffix rules.
- [ ] Imports ordered: Dart SDK → Flutter → external (alphabetical) → relative.
- [ ] Comments explain **why**, not **what**. TODOs include name + date.
- [ ] No code comments in Indonesian. Discussion in Indonesian, code in English.

### Scope guard (Phase 1)
- [ ] No cloud, auth, Firebase, push notifications, HomeKit/Matter, OTA, audio reactivity, voice, or schedules introduced.
- [ ] No WLED firmware fork referenced — stock firmware only.

If any item fails, surface it explicitly rather than silently working around it.

---

## Communication style

**User prefers Indonesian for discussion**, English for code. So when explaining to the user, switch to Indonesian. When writing code, comments, commit messages, and PR titles — English.

**Pattern that works:** propose with reasoning, let user push back. Don't ask permission for every small choice; make the call and explain. But flag genuine forks in the road.

**User appreciates:**
- Concrete recommendations with rationale
- Identifying gaps and edge cases
- Pushing back constructively when something doesn't add up
- Visual artifacts (HTML docs) for design decisions

**User dislikes:**
- Walls of unstructured text
- Excessive hedging ("it could be A, or B, or C, what do you think?")
- Repeating things already decided
- Sycophancy

---

## Hard constraints (non-negotiables)

1. **Do not fork WLED firmware.** EUPL-1.2 license implications. Stock only.
2. **Do not add cloud/auth in Phase 1.** Local-first is the moat.
3. **Do not introduce a state management library besides Riverpod.**
4. **Do not propose audio reactivity / mic input.** Out of scope, needs firmware fork.
5. **Do not add scenes beyond the curated 18** without first tuning on hardware.
6. **Do not use amber/warm-yellow chrome palette.** Periwinkle is final.
7. **Do not skip iOS Bonjour or Android cleartext config.** Discovery will silently fail.
8. **Do not commit `*.g.dart` or `*.freezed.dart`** generated files. They're in `.gitignore`.

---

## Sprint plan reference

8-week plan, ~1-2 developers. See `docs/development-brief.html` section 10 for detail.

| Week | Focus |
|---|---|
| 1 | Foundation: theme, models, drift schema |
| 2 | WLED API client + WebSocket |
| 3 | Discovery + Onboarding (S01-S04) |
| 4 | Dashboard + Room (S05, S07) |
| 5 | Wall Control + Pick Scene (S06, S08, S09) |
| 6 | Group control + UDP sync setup |
| 7 | Add Wall + Add Room flows |
| 8 | Scene tuning on hardware + polish |

Risk gates at week 3 (iOS captive portal must work on real device) and week 8 (hardware spec must be final).

---

## Reference documents

All in `docs/` folder. Read these before deep work on a topic:

| Doc | When to consult |
|---|---|
| `docs/design-spec.html` | UI/UX decisions, journey breakdowns, design rationale |
| `docs/scene-catalog.html` | Scene parameters, WLED API mapping, scene tuning |
| `docs/development-brief.html` | Tech stack, architecture, native config, sprint plan |
| `docs/react-canvas.html` | Visual design reference (React mockups for 20 artboards) |

**Order of authority when these conflict:**
1. `CLAUDE.md` (this file) — most current decisions
2. `design-spec.html` — UI/UX source of truth
3. `development-brief.html` — implementation source of truth
4. `scene-catalog.html` — scene data source of truth
5. `react-canvas.html` — visual reference, may lag spec decisions

If you find a conflict, surface it to the user — don't pick silently.

---

## Common commands

```bash
# Setup
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate Freezed + drift

# Develop
flutter run                                                # debug build on connected device
flutter run --release                                      # for performance testing

# Quality
flutter analyze
flutter test
dart format lib/ test/

# Re-generate after model changes
dart run build_runner watch --delete-conflicting-outputs

# Native test on real device (discovery won't work in simulator/emulator)
flutter run -d <device-id>
```

---

## Current status

**Where we are:** Design + planning complete. Code not yet started.

**Next concrete step:** Sprint week 1 — initialize Flutter project, install dependencies, scaffold theme system, define 4 Freezed models (Home, Room, Wall, Scene), set up drift schema.

**Parallel hardware track:** Flash WLED to one ESP32 with target LED strip, validate that all 18 scene payloads render acceptably. Tune brightness/speed values. Result feeds into the eventual `assets/scenes.json`.

**Risk to watch:** LED strip spec (density, length per panel) has not been finalized by industrial design. This blocks final scene tuning at week 8. Surface to user if scene tuning approach needs adjustment.
