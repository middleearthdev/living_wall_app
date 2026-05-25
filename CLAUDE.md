# Living Wall — Phase 1

Smart LED ambient wall product. Premium home lighting that doubles as moody atmosphere. This repository is the **Flutter mobile app** that controls the wall(s) via WLED firmware running on ESP32.

**Phase 1 = local-first MVP.** No cloud, no accounts, no backend. App talks directly to walls over the local WiFi network.

---

## Quick context

- **Hardware:** ESP32-S3 + stock WLED 0.14+ firmware + WS2812B strip at 60 LED/m fixed density
- **Mounting:** zigzag (serpentine), bottom-left origin, **rows spaced 5cm vertical pitch** (= 20 rows/m of wall height)
- **Pixel grid is non-square:** horizontal 1.67cm spacing × vertical 5cm spacing → 3:1 pixel ratio. Aspect class derivation MUST use physical mm, not grid LED count.
- **Wall model:** 2D grid (W × H), provisioned to WLED as **2D matrix mode** — not 1D strip
- **Communication:** WLED JSON API over HTTP + WebSocket on local network
- **App:** Flutter, this repository
- **Provisioning:** Per-unit QR code on label carries grid dimensions; scanned during onboarding/add-wall
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
- Multi-controller installations (single ESP32 per wall only)
- Aspect ratios outside 1:3 to 3:1 range
- Pre-rendered pixel data scenes (custom images/photos) — Phase 2+
- Commercial / B2B installs requiring site survey

---

## Product model

Living Wall is a **flexible platform**, not a fixed-SKU product. Two catalog tiers cover the common cases, plus a custom-loose tier for everything else within sane technical bounds.

### Catalog tiers (ready stock, landscape 3:2)

LED count = `(widthMm × 60 / 1000) × (heightMm × 20 / 1000)` — 60/m horizontal from the strip, 20/m vertical from the 5cm mounting pitch.

| Tier | Physical dims | Grid (W × H LEDs) | Total LED | Strip length |
|---|---|---|---|---|
| M | 1.2 × 0.8m | 72 × 16 | ~1,152 | 19.2m |
| L | 1.8 × 1.2m | 108 × 24 | ~2,592 | 43.2m |

### Custom tier (sales touch, 4–6 week lead)
- **Aspect ratio:** 1:3 to 3:1 derived from **physical mm** (anything outside → bespoke/B2B waitlist)
- **Dimensions:** kelipatan 200mm, **width 400–2400mm**, height 400–1600mm. 400mm minimum matches the ID sample panel.
- **Density:** strip 60 LED/m (horizontal); 5cm vertical pitch (20 rows/m)
- **Pricing:** surcharge multiplier by ratio deviation from 3:2 (1.0x catalog, 1.2x near-3:2, 1.4x further) — exact numbers owned by business doc, not this file
- **Terms:** 50% deposit, final sale, MOQ 1 per order

### App treats every wall identically
Critical rule: **app code has zero branching on M / L / custom.** The `Wall` model knows `gridWidth`, `gridHeight`, `aspectClass`, `lengthMm`, `heightMm` — nothing else. Tier is a production/marketing concept, not a runtime concept. Every wall, regardless of tier, is configured the same way: parse QR → set 2D matrix on WLED → done.

**Aspect class is derived from physical mm**, not grid LED count. Non-square pixels (3:1 ratio) mean grid ratio is meaningless as a visual measurement — 1200×800mm has grid 72×16 (ratio 4.5) but visual aspect 3:2.

### Tier L hardware validation
Tier L (~2,592 LED) is well within ESP32-S3 2D rendering capacity at 5cm vertical pitch (originally tagged tentative when we incorrectly assumed square-pixel density that would have put L at ~7,800 LED). Still validate ≥30 FPS on Plasma 2D + Polar Lights before locking the spec, but the prior fallback ladder (dual controller, density reduction) is unlikely to be needed.

---

## Spatial model — the 2D matrix

Walls are **2D grids**, not 1D strips. This is the foundational shift that makes scenes look consistent across different wall sizes.

### Why 2D, not 1D
- WLED firmware in default mode treats a strip as a flat list of LEDs (0…N). A scene like Sunset rendered as 1D becomes a horizontal gradient running through wire order — which on a zigzag-wired panel renders as visual nonsense.
- WLED 0.14+ adds native **2D Matrix mode**. Tell WLED the grid is W × H with serpentine wiring; 2D effects (Plasma 2D, Polar Lights, Fire 2D, Sunrise 2D, etc.) then render coherently in (x, y) space.
- Result: customer A with 1.2 × 0.8m and customer B with 2.4 × 1.6m both see Sunset as "orange at the bottom, purple at the top" — composition proportionally preserved.

### Provisioning (once, at add-wall)
1. User scans QR code on the wall label.
2. App parses payload (URL scheme): `v=1`, `serial`, `gw` (grid width), `gh` (grid height), `lw`/`lh` (mm), `wp` (wiring pattern), `tier`.
3. App POSTs to `/json/cfg` with the 2D matrix config + UDP sync settings.
4. WLED writes once to flash. **Do not re-send `cfg` on every app launch** — flash has finite write cycles.

### QR payload format
```
livingwall://provision?v=1&serial=LW-2026-00342&gw=72&gh=48&lw=1200&lh=800&wp=zigzag-bl-rm&tier=M
```

- `v=1` mandatory (schema version)
- `wp` canonical value: `zigzag-bl-rm` (bottom-left origin, row-major)
- **No HMAC/signing in Phase 1** — provisioning is local-network only; worst-case spoof = ugly rendering, not security
- App must validate: ratio within 1:3–3:1, dims in 200mm increments, within size envelope. Reject invalid with clear error.

### Scene compatibility classification

Each of the 18 scenes is tagged with one of three classes:

| Class | Renders well at | Examples |
|---|---|---|
| `universal` | Any aspect ratio | candle, breathe, focus, daylight, forest, sakura, fireplace, twinkle, party, movie |
| `landscape` | Wide aspect (composition has horizon / horizontal flow) | ocean, sunset, golden, aurora, tokyo |
| `portrait` | Tall aspect (vertical flow) | rain, dawn (wind down), dinner |

### Aspect class derivation (from grid dims, at registration)
- `landscape` if `gridWidth / gridHeight ≥ 1.2`
- `portrait` if `gridWidth / gridHeight ≤ 0.83`
- `square` otherwise (between 0.83 and 1.2)

### Scene gallery filtering UX
Show **all 18 scenes always.** Sort logic:
1. Scenes matching wall's aspect class first
2. Universal scenes second
3. Mismatched scenes at the bottom with a small label "kurang optimal untuk wall ini"

Never hide, never disable. Customer keeps the choice. Premium UX = informative, not restrictive.

### Quick scenes (Wall Control + RoomCard) aspect strategy
Quick-scene strips are pre-curated per surface, not dynamic sort like the gallery:

- **Wall Control** (6 tiles): `wallQuickScenesProvider(wallId)` returns 6 scenes curated for the wall's `aspectClass`. Landscape wall favors horizon scenes (ocean, sunset, golden), portrait favors vertical-flow (rain, dawn, dinner), square sticks to universals. Each list still mixes in universal staples (focus, candle, forest) so the strip covers everyday moods.
- **RoomCard** (3 mini tiles on Dashboard): **universal-only** (`candle`, `focus`, `movie`). A room can contain walls of mixed aspect — picking an orientation-specific quick scene would look great on one wall and "kurang optimal" on another. Aspect-aware curation only makes sense per-wall, not per-room.

Per-wall last-used quick scenes (replacing curation with usage history) is a Phase 2 nicety.

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
| permission_handler | ^11 | Android location, iOS local network, camera (for QR) |
| url_launcher | ^6.3 | Open WiFi settings |
| mobile_scanner | ^5 | QR scan during onboarding / add-wall provisioning |

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
- **Wall** — a physical LED panel mounted as a **2D grid**. Belongs to exactly one Room. Has WLED device (ESP32) at an IP address. Required fields: `gridWidth`, `gridHeight` (in LEDs), `aspectClass` (`landscape` / `portrait` / `square`, derived from grid dims at registration), `serialNumber` (from QR), `lengthMm`, `heightMm`.
- **Scene** — a curated mood preset. Catalog is static (18 scenes). Maps to WLED JSON API params: `fx`, `pal`, `bri`, `sx`, `ix`, optional `col`, plus a required `compatibility` tag (`universal` / `landscape` / `portrait`) used by the scene gallery for sort-and-badge.

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

### 1. Onboarding (5 steps, first wall)
First launch → Empty state → WiFi guide → Discovery → **QR scan** → Name & place → Dashboard

QR scan is mandatory in the primary path — it provisions the wall's 2D matrix config to WLED. Advanced manual entry is hidden behind a small "input manual" link as a fallback only.

### 2. Daily use (the 80% case)
Open app → Dashboard → tap mini-control on RoomCard → wall changes. Most actions never leave the Dashboard.

### 3. Pick scene (deeper)
Wall Control → tap "Lihat semua" → Scene Gallery (category tabs) → tap scene → applied immediately. Adjustment Sheet only opens if user wants to fine-tune. Gallery sorts scenes by aspect-class match for the current wall — universal first within match, mismatched at bottom with "kurang optimal" label, never hidden.

### 4. Group control
Already implicit: a Room is a sync group. Change one wall in the room → all walls in that room change. To exclude one wall temporarily, the user can mark it excluded in Room screen.

### 5. Add wall / Add room (entry per context)
- **'+' button on Dashboard** = add room (then immediately enter add-wall flow)
- **'Tambah wall' inside Room screen** = add wall to this specific room
- Wall is ALWAYS placed in a room. No "unassigned" state.
- Add wall flow = **3 steps** (Discovery → QR scan → Name). WiFi guide is skipped — app is already running on WiFi.
- QR scan is mandatory for every new wall, regardless of whether it's the first or the nth. Same component reused from onboarding.

### 6. Reconfigure wall (Wall Settings → "Konfigurasi ulang")
Rare but supported. Used when QR was misscanned, the wall was upgraded with a different panel, or factory provisioning was wrong.
- Primary path: scan QR again
- Fallback: manual dimension entry, hidden as "lanjutan" with a warning
- Confirmation: "Mengganti konfigurasi akan menyebabkan scene saat ini reset ke default. Lanjutkan?"
- Re-issues `/json/cfg` to WLED. This is a flash write — do not expose as a frequent action.

---

## Scene catalog (18 scenes — IDs, params, compatibility)

Reference only — full data is in `assets/scenes.json`. Each scene has a stable `id` and a `compatibility` tag (`universal` / `landscape` / `portrait`).

**Tenang (6):** ocean `[landscape]`, candle `[universal]`, dawn `[portrait]`, aurora `[landscape]`, rain `[portrait]`, breathe `[universal]`
**Fokus (3):** focus `[universal]`, forest `[universal]`, daylight `[universal]`
**Sosial (6):** sunset `[landscape]`, dinner `[portrait]`, movie `[universal]`, tokyo `[landscape]`, golden `[landscape]`, sakura `[universal]`
**Dinamis (3):** fireplace `[universal]`, twinkle `[universal]`, party `[universal]`

Totals: 10 universal, 5 landscape, 3 portrait = 18.

Default `transition: 14` (1.4s). Wind Down (`dawn`) uses `30` (3s) for slower fade.

All scene `fx` values must be **2D effects** (Plasma 2D, Polar Lights, Fire 2D, Sunrise 2D, Drift 2D, Color Waves 2D, Matrix 2D, etc.) — not 1D effects. 1D effects on a zigzag-wired panel render as scrambled lines, defeating the entire spatial model.

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

### 2D matrix provisioning (once, at add-wall)
At the same `/json/cfg` write, app also sets the 2D matrix configuration: grid `width` × `height` in LEDs, `serpentine: true` (zigzag), origin bottom-left. This and the UDP sync settings are batched into a single config write — flash is written once per wall lifecycle, not per session. Re-issuing `cfg` on every app launch wears the flash and is a hard-banned pattern.

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
- [ ] Scene params match `assets/scenes.json` shape: `fx`, `pal`, `bri`, `sx`, `ix`, optional `col`, `transition` (default 14), `compatibility` (`universal`/`landscape`/`portrait`).
- [ ] `fx` value is a 2D effect ID — never a 1D effect.
- [ ] Scene gallery shows all 18 scenes regardless of wall aspect; sorts mismatched to bottom with badge, never hides or disables.

### Spatial model
- [ ] Wall is provisioned to WLED as 2D matrix at add-wall time (`/json/cfg` with serpentine config).
- [ ] `cfg` is written once per wall lifecycle, never on app launch.
- [ ] `Wall` model carries `gridWidth`, `gridHeight`, `aspectClass`, `serialNumber` — populated from QR scan.
- [ ] No code path branches on tier (`M` / `L` / `custom`). Tier is not a runtime concept.
- [ ] QR payload validated against ratio range 1:3–3:1 and 200mm-increment size envelope before accepting.

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
9. **Do not treat walls as 1D strips.** Every wall must be provisioned as a WLED 2D matrix via `/json/cfg`. Without it, scene rendering on zigzag wiring is visually scrambled.
10. **Do not branch app code on tier (M / L / custom).** App reads grid dims from QR; tier is a production/marketing concept, not a runtime concept.
11. **Do not accept walls outside the 1:3–3:1 aspect range** (derived from physical mm) or outside the 400–2400mm × 400–1600mm envelope. Reject at QR scan with a clear error.
12. **Do not re-write `/json/cfg` on every app launch.** Config writes hit flash — only on add-wall or explicit "Konfigurasi ulang".
13. **Do not derive aspect class from grid LED count.** Vertical pitch (5cm) differs from horizontal (1.67cm), so grid ratio ≠ visual aspect. Always pass physical mm to `aspectClassFor`.

---

## Sprint plan reference

8-week plan, ~1-2 developers. See `docs/development-brief.html` section 10 for detail.

| Week | Focus |
|---|---|
| 1 | Foundation: theme, models (incl. grid fields), drift schema |
| 2 | WLED API client + WebSocket + 2D matrix `/json/cfg` payload builder |
| 3 | Discovery + Onboarding (S01–S04) + QR scan step |
| 4 | Dashboard + Room (S05, S07) |
| 5 | Wall Control + Pick Scene with aspect-class sort + badge (S06, S08, S09) |
| 6 | Group control + UDP sync setup |
| 7 | Add Wall (with QR) + Add Room flows |
| 8 | Scene tuning on hardware across 3 aspect classes + tier L validation + polish |

Risk gates:
- Week 3: iOS captive portal + QR scan camera permission must work on real device
- Week 8: hardware spec final, all 18 scenes tuned as 2D effects, tier L validated (or fallback adopted)

**Note:** All 8 weeks were already implemented under the old 1D-strip assumption. The shift to 2D matrix + QR provisioning is a **refactor branch** on top of completed work, not a fresh greenfield sprint. See Current status for the refactor plan.

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

**Where we are:** Sprint weeks 1–8 implemented end-to-end on `sprint/week-1-foundation`, **but under the old 1D-strip assumption.** Foundation, WLED HTTP + WebSocket, discovery, onboarding (4-step), Dashboard, Room, Wall Control, Pick Scene, group control, Add Wall + Add Room, and polish (connectivity, wall settings, IP refresh) are all wired. Follow-up fixes hardened discovery, brightness curve, wall-control hero, and iOS WiFi guide.

**Active decision (this commit):** Pivot to **WLED 2D Matrix + per-unit QR provisioning**. See [Product model](#product-model) and [Spatial model — the 2D matrix](#spatial-model--the-2d-matrix). This is a refactor of in-place code, not greenfield work.

**Next concrete step:** Open `feature/2d-matrix-refactor` branch. Break work into 5 atomic PRs:

1. **Models + schema** — `Wall` gains `gridWidth`/`gridHeight`/`aspectClass`/`serialNumber`/`lengthMm`/`heightMm`; `Scene` gains `compatibility`; drift migration; updated `assets/scenes.json`.
2. **WLED 2D config** — `WledClient.configureMatrix()` sends 2D matrix dims + serpentine + udpn via `/json/cfg`. One-shot, never re-issued.
3. **QR scan integration** — `mobile_scanner` install, camera permissions (iOS `NSCameraUsageDescription`, Android `CAMERA`), QR scan step inserted into onboarding (between Discovery and Name & Place) and add-wall (between Discovery and Name).
4. **Scene gallery aspect filter** — sort-and-badge by aspect class match, never hide.
5. **Hardware validation pass** — notes + final scene tuning, no code changes.

**Parallel hardware track:**
- Validate tier L (~7,800 LED on ESP32-S3) sustains ≥30 FPS on 2D effects (Plasma 2D, Polar Lights especially). If not, adopt fallback ladder (cap LED count, dual-controller with E1.31 sync, or 30/m density on L).
- Tune all 18 scenes on a reference M-sized panel under 2D matrix mode. Document final `fx` + `pal` + parameter values per scene per aspect class.
- Update `assets/scenes.json` from tuning output — replaces current best-guess defaults.
- Coordinate with production team on QR label generation pipeline — app expects a specific URL payload format and validation rules.

**Risks to watch:**
- **Tier L hardware capacity** — blocker for marketing L as ready-stock. Marked `tentative` in [Product model](#product-model) until proven.
- **Refactor scope** — Wall model migration touches every consumer; resist temptation to bundle UI changes into the same PR.
- **Production dependency** — QR provisioning only works if production actually prints valid QR labels. Coordinate before app code expects them.
