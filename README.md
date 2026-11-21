# Kumyk Keyboard for iOS

A native iOS keyboard for the Kumyk language (Къумукъ тил), developed by
[LekiTech](https://github.com/LekiTech) on the shared
**General Keyboard** engine, next to the Avar, Lezgi and Dargwa keyboards.

## The keyboard

- **The LekiTech Kumyk layout** (a proposal, designed from corpus data;
  not an Apple layout): the Russian iOS layout with one key changed. The
  hard sign **ъ**, 3.8 % of all Kumyk characters because of **къ** and
  **гъ**, has its own key where Russian has щ.

  ```
  й ц у к е н г ш ъ з х
  ф ы в а п р о л д ж э
  ⇧ я ч с м и т ь б ю ⌫
  ```

- Long press: г → гъ гь · к → къ · н → нг · о → оь · у → уь · е → ё ·
  ш → щ · ь → ъ. The six digraph letters are ordinary Cyrillic sequences
  and can also be typed key by key. Why this layout, the numbers and the
  alternatives: [docs/LAYOUT.md](docs/LAYOUT.md).
- Word suggestions from an offline dictionary of 38,956 Kumyk words and
  43,995 word pairs, plus the words and word pairs it learns from your own
  typing, including next-word suggestions. See
  [docs/DICTIONARY.md](docs/DICTIONARY.md).
- Matches the native iOS keyboard (Apple's measured iPhone grid, key
  previews, callout menus with swipe selection, caps lock,
  auto-capitalization, spacebar cursor control, hold-to-repeat delete),
  light and dark mode, the emoji page, an in-keyboard settings panel.
- Private by design: never asks for Full Access and sends nothing anywhere.
  Learned words live in the keyboard's own storage and can be managed and
  reset from the keyboard's gear key.

Status: **ready for App Store handoff, not released yet.** Tested on an
iPhone by the project owner. Feedback from Kumyk speakers on the layout's
open questions is welcome ([docs/LAYOUT.md](docs/LAYOUT.md#open-questions)),
and the keyboard's key names and settings panel use Russian text until a
Kumyk translation is reviewed
([docs/LOCALIZATION.md](docs/LOCALIZATION.md)).

## Building

The keyboard engine is the shared **General Keyboard** Swift Package
([LekiTech/GeneralKeyboard-iOS](https://github.com/LekiTech/GeneralKeyboard-iOS)),
linked as a local package found next to this checkout. Clone both
repositories side by side, under any parent directory, on their `main`
branches:

```bash
git clone https://github.com/LekiTech/GeneralKeyboard-iOS.git
git clone https://github.com/LekiTech/KumykKeyboard-iOS.git
```

```
<workspace>/
  GeneralKeyboard-iOS/   the engine package
  KumykKeyboard-iOS/     this repository
```

The Xcode project references the package as `../../GeneralKeyboard-iOS`
(relative to `KumykKeyboard/KumykKeyboard.xcodeproj`) and the test
package as `../GeneralKeyboard-iOS`; nothing else is required (no tokens,
no package registry). Open **`KumykKeyboard/KumykKeyboard.xcodeproj`**
in Xcode 27, pick the **`KumykKeyboard`** scheme (it builds and embeds the
`KumykKeyboardExtension` target) and run on a simulator or an iPhone.

```bash
xcodebuild build -project KumykKeyboard/KumykKeyboard.xcodeproj -scheme KumykKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
xcodebuild test -scheme KumykCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

## Identity

Provisional until the first release.

| | Debug (development) | Release (App Store) |
|---|---|---|
| App bundle ID | `org.lekitech.kumykkeyboard.dev` | `org.lekitech.kumykkeyboard` |
| Keyboard extension bundle ID | `org.lekitech.kumykkeyboard.dev.KumykKeyboardExtension` | `org.lekitech.kumykkeyboard.KumykKeyboardExtension` |
| App Group (both targets) | `group.org.lekitech.kumykkeyboard.dev` | `group.org.lekitech.kumykkeyboard` |
| Signing | automatic, the developer's own team | manual: the distribution team adds its team and App Store profiles |

Both targets carry the App Groups entitlement; the group's identifier is
the `KUMYK_APP_GROUP_ID` build setting of each configuration. Release
signing needs the two App IDs registered with the App Groups capability
and the App Group created in the distribution team's account; the Release
configuration ships with an empty team and empty profile names on purpose.
Details and the device-install steps: [docs/BUILDING.md](docs/BUILDING.md).

## Release and App Store handoff

Debug builds run as they are under the developer's team. The Release
configuration is prepared but deliberately unsigned: it carries the App
Store identifiers, manual signing with `Apple Distribution`, and an empty
team and empty profile names. To archive for the App Store, the
distribution team:

1. Registers the App IDs `org.lekitech.kumykkeyboard` and
   `org.lekitech.kumykkeyboard.KumykKeyboardExtension`, creates the App
   Group `group.org.lekitech.kumykkeyboard`, and enables the App Groups
   capability with that group on both App IDs.
2. Creates an App Store provisioning profile for each of the two App IDs.
3. In the **Release** configuration of both targets (`KumykKeyboard` and
   `KumykKeyboardExtension`) sets `DEVELOPMENT_TEAM` and
   `PROVISIONING_PROFILE_SPECIFIER` (Signing & Capabilities → Release, or
   the build settings). Debug stays as it is.
4. Sets the version in both targets, the same values in each:
   `MARKETING_VERSION` (now 1.0.0) and `CURRENT_PROJECT_VERSION` (now 1).
5. Archives the `KumykKeyboard` scheme (Product → Archive; it archives the
   Release configuration and embeds the extension) and uploads the archive
   to App Store Connect.

Before signing is set up, this checks that Release compiles:

```bash
xcodebuild build -project KumykKeyboard/KumykKeyboard.xcodeproj -scheme KumykKeyboard \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

For the App Store listing: the keyboard does not request Full Access
(`RequestsOpenAccess` is false) and sends nothing anywhere, and
`ITSAppUsesNonExemptEncryption` is NO. The bundle identifiers and the App
Group are provisional until the first upload and must not change after it.
More detail: [docs/BUILDING.md](docs/BUILDING.md).

## Repository

```
KumykKeyboard/
  KumykKeyboard.xcodeproj            two targets: the app and the keyboard extension
  KumykKeyboard/                     containing app (SwiftUI): install steps, layout,
                                     long-press guide, settings info
  KumykKeyboardExtension/            the keyboard: KumykDefinition (with the Kumyk
                                     normalization profile), KumykLayout, KumykStrings,
                                     KumykIdentity, KeyboardViewController, Info.plist,
                                     kumyk_words.sqlite, kumyk_bigrams.sqlite
Package.swift, Tests/KumykCoreTests/ product-layer tests through the real engine
  Fixtures/agisight/                 pinned upstream files (MIT) the layout tests read
scripts/build_dictionary.py          reproducible dictionary build from the v0 data
scripts/analyze_layout.py            letter statistics and the layout comparison
scripts/make_icon.py                 installs the app icon from docs/branding/
docs/                                LAYOUT (+ layout/analysis.json), DICTIONARY
                                     (+ dictionary/review/), LOCALIZATION, BUILDING,
                                     branding/ (the icon artwork as delivered)
```

The engine itself (model, views, storage, normalization pipeline,
settings, emoji) is not in this repository; see `GeneralKeyboard-iOS/docs/`.

## Organization

Developed by [LekiTech](https://github.com/LekiTech), a team building
digital tools for the languages of Dagestan.

## License

All rights reserved, see [LICENSE](LICENSE). Third-party material and its
licenses are listed there.
