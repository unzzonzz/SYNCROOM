# SYNCROOM

A live-performance app for iOS 26, built in SwiftUI.

Artists broadcast a room, viewers watch and chat, and other musicians can ask to
join the room and play along. Twenty-five screens, no backend.

---

## Requirements

| | |
|---|---|
| Xcode | 26.x (built and verified against 26.6, iOS SDK 26.5) |
| Deployment target | **iOS 26.0** |
| Language | Swift 6, strict concurrency, default actor isolation `MainActor` |
| Dependencies | none |

### Why the floor is iOS 26.0

The app is built on the Liquid Glass API set, and every one of these was
introduced in iOS 26 with no back-deployment:

- `TabView` + `Tab(_:systemImage:value:)` with `.tabBarMinimizeBehavior(.onScrollDown)`
- `.tabViewBottomAccessory` and `\.tabViewBottomAccessoryPlacement`
- `GlassEffectContainer`, `.glassEffect(_:in:)`, `.glassEffectID(_:in:)`, `.glassEffectUnion(id:namespace:)`
- `.buttonStyle(.glass)` / `.glassProminent`
- `ToolbarSpacer` and `.sharedBackgroundVisibility(_:)`
- `.searchToolbarBehavior(.minimize)`
- `.scrollEdgeEffectStyle(_:for:)`

Lowering the target would mean reimplementing all of it by hand, which is
exactly what this project does not do. Every signature above was verified
against the installed SDK before use, not assumed.

One API needed a version check rather than a lower floor:
`tabViewBottomAccessory(isEnabled:content:)` arrived in **26.1**. On 26.0 the
accessory is attached only while a room is playing, because returning an empty
view from the closure still leaves the system drawing an empty glass capsule
above the tab bar. See `MiniPlayerAccessory` in `App/RootView.swift`.

---

## Running it

Open `SYNCROOM.xcodeproj`, pick any iPhone simulator, run. There is no network
and no configuration.

The app opens **signed in**, on the home screen, the way a returning user finds
it. The sign-in and onboarding screens (S5–S8) are reached the way a real user
reaches them — Settings → 로그아웃.

---

## Architecture

```
SYNCROOM/
├─ App/              composition root, tab shell, navigation and session state
├─ DesignSystem/     tokens, type scale, formatters, and the component library
│   └─ Components/
├─ Features/         one folder per area, one View + one @Observable model per screen
│   ├─ Auth/         S5–S8
│   ├─ Home/         S1, S9
│   ├─ Search/       S2, S14, S15
│   ├─ Profile/      S3, S16–S20
│   ├─ LiveViewer/   S4, S21, S23, S24, S25
│   └─ LiveHost/     S10–S13, S22
├─ Models/           plain value types, Foundation only
├─ Services/         the DataSource seam, fixtures, playback and audio
└─ Resources/        Localizable.xcstrings
```

State is `@Observable` throughout; there is no Combine and no
`ObservableObject`. Four objects live in the environment, created once in
`SYNCROOMApp`:

| Object | Holds |
|---|---|
| `SessionModel` | who is signed in, onboarding stage, unread count |
| `AppRouter` | selected tab, a `NavigationPath` per tab, the host-flow presentation |
| `PlaybackController` | the room being watched — the single source behind the mini player |
| `SettingsStore` | notification, audio and playback preferences |

Each tab keeps its own path, so switching tabs preserves where you were.

---

## Swapping the mock for a real API

Everything the UI needs goes through one protocol:

```swift
@MainActor
protocol DataSource: AnyObject {
    func homeFeed() async throws -> HomeFeed
    func search(query: String, scope: SearchScope) async throws -> SearchResults
    …
}
```

**`Services/DataSource.swift`** is the whole contract — methods and payload
types. **`Services/MockDataSource.swift`** is the only implementation, and
**`Services/Fixtures.swift`** is the data it serves.

To move to a live backend:

1. Write `APIDataSource: DataSource`.
2. Change the default in each view model's `init`, or inject at the call site —
   the seam is `init(dataSource: any DataSource = MockDataSource.shared)`.

No view or view model knows where its data comes from. `MockDataSource` also
takes a `behaviour` (`.populated` / `.empty` / `.failing` / `.loading`), which is
how every empty, error and loading state in the app is demonstrated in previews
without special-casing view code.

Media URLs in the fixtures are deliberately `nil`, so every image goes down the
`AsyncImage` placeholder path and the app makes no network requests at all.

---

## Design system

Two languages, deliberately kept apart:

- **System UI** — tab bar, navigation bar, toolbars, sheets, floating controls:
  native Liquid Glass, untouched. Nothing in this app paints a bar background,
  and there is not one `.ultraThinMaterial`, custom blur, or translucent
  rectangle imitating glass.
- **Content UI** — everything inside the content column: opaque, typographic,
  wide-margined. Hierarchy comes from type scale and whitespace, not from
  borders, cards, gradients or shadows.

All values live in `DesignSystem/Tokens.swift` (`Palette`, `Space`, `Radius`,
`Metric`, `Motion`) and `Typography.swift`. No view hardcodes a colour, size or
spacing.

### Colour

Colours are asset-catalog colour sets carrying **light, dark, and high-contrast
variants for each**, so Dark Mode and Increase Contrast are resolved by the
system rather than by branching in view code.

The ink ramp is three levels, measured against the page ground:

| Token | Contrast on `surface` | Used for |
|---|---|---|
| `ink` | 19.2:1 | primary text, primary geometry |
| `inkSecondary` | 4.70:1 | secondary text — meets AA at body size |
| `inkTertiary` | 3.14:1 | non-text glyphs and placeholders — meets the 3:1 floor |

There is **one accent**, `signalLive` (#FF5A3D), and it means *live*. It is also
used for destructive actions. The other three signals are used only where they
carry meaning: `signalCaution` (a warning), `signalSuccess` (confirmed),
`signalSpecial` (currently performing). Every signal is a **fill** carrying
`onSignal` text — none is legible as small text on the page ground, so none is
ever used that way. Navigation chrome is ink, never accent: the accent is
information, not branding.

### Formatting

One helper set, `DesignSystem/Formatters.swift`, so the same value never appears
in two shapes:

| Input | Output |
|---|---|
| `8_304` | `8,304` |
| `120_000` | `12만` |
| `1_204_392` | `120만` |
| `15_000` | `1.5만` |
| `10_000` (money) | `10,000원` |
| `5_047` (seconds) | `01:24:07` |

Counts below 10,000 group; at or above, they collapse to the Korean
ten-thousand unit, keeping one decimal below 10만 so `1.5만` does not round away
to `1만`.

### Strings

Every user-facing string is either a `Text("…")` literal — a `LocalizedStringKey`
the String Catalog collects — or `String(localized:comment:)`.
`Text(verbatim:)` is reserved for things that are not language: a handle, a
number, the mark `LIVE`. Source language is Korean;
`Resources/Localizable.xcstrings` is populated by the build.

---

## Screen flow

```
                          ┌─────────── AuthFlowView (signed out) ───────────┐
                          │  S5 로그인 → S6 회원가입 → S7 프로필 설정 → S8 팔로우  │
                          └────────────────────┬───────────────────────────┘
                                               ▼  signed in
    ┌──────────────────────── RootView · TabView + bottom accessory ────────────────────────┐
    │                                                                                        │
    │   홈 (S1)                    탐색 (S2)                     프로필 (S3)                  │
    │    │                          │                              │                         │
    │    ├─ S9  알림함              ├─ S14 검색 결과                ├─ S16 프로필 공유 (sheet)  │
    │    └─ 라이브 시작 ──┐          └─ S15 해시태그 상세            ├─ S17 프로필 수정          │
    │                    │                                        ├─ S18 팔로워 · 팔로잉      │
    │                    │                                        ├─ S19 설정                │
    │                    │                                        ├─ S20 타인 프로필          │
    │                    │                                        └─ 시청 기록 / 내 라이브 /   │
    │                    │                                            후원 내역              │
    │                    │                                                                   │
    │   MiniPlayerBar ── tabViewBottomAccessory, visible on every tab while watching ────────│
    └────────┬───────────┴──────────────────────────────────────────────────────────────────┘
             │                                        │
             ▼ fullScreenCover                        ▼ fullScreenCover
    HostFlowView                              S4 라이브 상세 (시청자)
      S10 라이브 개설                              ├─ S21 참여 신청 (sheet)
       └ S11 오디오 점검                           ├─ S23 참여자 목록 (sheet)
          └ S12 라이브 송출 ── S22 참여 요청 (sheet) ├─ S24 후원 (sheet)
             └ S13 종료 요약                        └─ S25 더보기 (dialog)
```

The mini player and the full-screen room are two presentations of one session:
dismissing S4 calls `playback.minimize()`, which hands the session to the
accessory; tapping the accessory calls `expand()`. The same pattern as the
system music player.

---

## States

Every screen resolves through one shape, `LoadState<Value>` — `.loading`,
`.loaded`, `.failed` — and previews cover each. The edge cases the design has to
survive, and where to see them:

| Case | Where |
|---|---|
| Empty | home with no shelves, notification inbox, past broadcasts, no search results |
| Loading | home shelf skeletons (`.redacted(.placeholder)`), stream buffering |
| Error | any screen's `.failing` preview — `ErrorStateView` with retry; `InlineBanner` for a lost connection |
| Ended live | S4 with `Fixtures.endedRoom` |
| Long text | `Fixtures.longform` — a 20-character handle, six hashtags, a two-line title |
| Large numbers | `Fixtures.longformRoom` at 1,204,392 viewers |
| Dark mode | every screen preview has a dark variant |
| Dynamic Type | previews at `.accessibility3`; the type scale is `@ScaledMetric`-driven and scales tracking with size |
| Reduce Transparency / Increase Contrast | handled by the system — high-contrast colour-set variants, and native glass rather than imitations |
| Avatar colour stability | `Fixtures.allArtists` rendered twice in one preview: the same person must match, and must survive a relaunch |
| Reduce Motion | `.motion(value:)` wraps every animation and yields to the setting |

---

## Why search does not use `.searchToolbarBehavior(.minimize)`

The brief asked for the minimising search field, and it was built that way. Its
dismiss transition is visibly broken, and the break is Apple's rather than ours.

Recording the simulator at 30fps with slow animations on and stepping through the
frames shows the field emptying to a blank pill, a stray chevron appearing, the
bar going empty for about a sixth of a second, and the button then popping in —
where the *expand* direction is a clean continuous morph. The two directions do
not mirror.

The control that settles it: a bare `List` with nothing but `.navigationTitle`,
`.searchable` and `.searchToolbarBehavior(.minimize)` — none of this app's code —
reproduces the same dip, more pronounced. There is no API in the iOS 26 SDK to
tune that transition.

So the search field now sits in a navigation bar drawer with
`displayMode: .always`. A field that never collapses has no transition to get
wrong, and it matches the original Search artboard, which draws the field
permanently beneath the title.

## Separators

Sections are separated by space, not rules — that is the design system's default
and it holds throughout. Inside a run of like-for-like rows, though, a separator
does real work: it says where one row ends and the next begins when both are the
same shape. `RowSeparator` wraps the system `Divider`, so it inherits the
platform's hairline weight and its light/dark behaviour, and it is used in the
three places that are genuinely lists of identical rows — 내 정보, 시청 기록 and
후원 내역 — and nowhere else.

## How the hashtag block wraps

`HashtagChipRow` measures the width it was given and computes its rows in Swift,
rather than doing the wrapping inside a custom `Layout`.

A `Layout` is asked for its size before its container knows how wide it will be,
and neither answer to an unbounded proposal is right: report the full single-line
width and every ancestor sizes itself to fit all the chips on one line, so the
card overflows its slot in the shelf; report less and the row gets *placed* at a
width that disagrees with what it measured, so the second line draws on top of
whatever sits below it. Both failures were visible on the six-hashtag card, and
instrumenting `placeSubviews` showed the row being handed a bounds width of
**zero** — SwiftUI probing for a minimum, and taking the honest answer literally.

Reading the real width once with `onGeometryChange` and laying the rows out from
that number cannot disagree with itself. Two overflow behaviours are built on it:

- `.clip` — wrap, then stop. Used wherever hashtags sit around a name.
- `.count` — one line, ending in a quiet `+N`. Used on `LiveCard`. `N` is
  measured, not estimated, and the count is deliberately not a chip: no `#`, no
  fill, lighter ink, not tappable, so it never reads as another tag. If even one
  tag is wider than the row, that tag is shown truncated rather than leaving the
  line blank.

## Card height in a shelf

A card sized from its parent's proposal cannot have a stable height, because
everything inside it re-wraps as the proposal changes. Shelf cards therefore
carry an explicit width (`Metric.liveCardWidth`), not a fraction of the
container.

The title takes up to two lines but only as tall as it actually is. Reserving
both lines unconditionally does make every card identical, but it puts the slack
*between* the title and the metadata line — the one place a gap reads as a bug.
A shelf takes its height from its tallest card instead, so slack lands at the
bottom of the shorter ones, where it is simply margin.

The thumbnail keeps its 2:1 ratio by absorbing leftover height, so the card is
sized to its ideal height (`fixedSize(vertical:)`) — otherwise a taller neighbour
squashes it and one shelf ends up with different-sized thumbnails.

## Avatars

There is no native API that generates a portrait for someone who has not
uploaded one, so the default is the platform's own `person.crop.circle.fill`
rendered hierarchically, not an invented illustration.

Its tint comes from `Palette.avatarTint(for:)`, an explicit FNV-1a hash of the
person's handle. `String.hashValue` would have been the obvious choice and is
wrong here: it is seeded per process, so the same person would change colour on
every launch. The palette is six low-chroma tints of its own, deliberately not
the signal colours — an avatar identifies someone, it does not signal anything,
and it must never compete with the one accent.

Loading and failure both fall back to the same mark, so a slow or broken image
never leaves a hole. Uploading a photo (S7, S17) is unaffected; this is only what
stands in before one exists.

## Notes on deliberate departures from the static mockups## Notes on deliberate departures from the static mockups

The four `design/*.dc.html` artboards are HTML, so they had to draw their own
tab bar, mini player and search field. In the app all three are system surfaces:
the tab bar and the mini-player accessory are real Liquid Glass, and search is
`.searchable`. Painting the mockup's opaque panels there would have meant faking
the material — the one thing the brief rules out.

The hero banner carries its room's name and live state rather than sitting empty
as it does in the artboard. A carousel slide that says nothing is decoration,
and decoration is what this design system spends its budget avoiding.
