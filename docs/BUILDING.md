# Building, signing, running on a device

## Requirements

- Xcode 27 (the project was created with 27.2); iOS 18.0 deployment target.
- `GeneralKeyboard-iOS` checked out next to this repository (`main`). The
  project references it as a local Swift package (`../../GeneralKeyboard-iOS`
  from the `.xcodeproj`); no tokens or registries.

## Targets and identity

| | Debug (development) | Release (App Store) |
|---|---|---|
| App bundle ID | `org.lekitech.kumykkeyboard.dev` | `org.lekitech.kumykkeyboard` |
| Extension bundle ID | `org.lekitech.kumykkeyboard.dev.KumykKeyboardExtension` | `org.lekitech.kumykkeyboard.KumykKeyboardExtension` |
| App Group (`KUMYK_APP_GROUP_ID`, both entitlements) | `group.org.lekitech.kumykkeyboard.dev` | `group.org.lekitech.kumykkeyboard` |
| Signing | Automatic, team `RC94H8KQYA` | Manual, `Apple Distribution`, team and profiles empty |
| Display name | app: Kumyk / Къумукъ тил · keyboard: Kumyk / Кумыкский | same |

Debug and Release use different identifiers on purpose: bundle IDs and App
Groups are unique across Apple developer teams, so a Debug build registered
under the developer's team must not take the production identifiers away
from the distribution team. `KumykIdentity.swift` selects the App Group
with `#if DEBUG` to match. The learned-word store (`learned.sqlite`),
settings (`UserDefaults.standard` of the extension) and recent emojis live
in the extension's own container, keyed by its bundle ID, so Kumyk never
shares or touches Avar's, Lezgi's or Dargwa's data. The App Group only carries the
inert contribution bridge.

The keyboard definition id (`KeyboardDefinition.id`) is the Release
extension bundle ID and never changes.

## Development build on a physical iPhone

1. Open `KumykKeyboard/KumykKeyboard.xcodeproj`, scheme `KumykKeyboard`,
   configuration Debug (the scheme's default).
2. Select the iPhone as the run destination and press Run. Automatic
   signing with team `RC94H8KQYA` creates the two App IDs, the App Group
   `group.org.lekitech.kumykkeyboard.dev` and the development profiles
   on first use (Xcode asks once; a paid team, so no 7-day expiry).
3. On the phone: Settings → General → Keyboard → Keyboards → Add New
   Keyboard → **Kumyk**. Then hold 🌐 in any text field and pick Kumyk.
   The app's own screen repeats these steps and opens Settings.
4. Full Access is never requested and must stay off.

Command line, for a connected device (replace the id with
`xcrun devicectl list devices`):

```bash
xcodebuild build -project KumykKeyboard/KumykKeyboard.xcodeproj -scheme KumykKeyboard \
  -configuration Debug -destination 'id=<device udid>' -allowProvisioningUpdates
```

## Simulator

```bash
xcodebuild build -project KumykKeyboard/KumykKeyboard.xcodeproj -scheme KumykKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

Install the built `.app`, enable the keyboard in the simulator's Settings as
above, then type in any text field (Reminders, Safari).

## Tests

```bash
xcodebuild test -scheme KumykCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

`Package.swift` compiles the product files of the extension into
`KumykCore` and runs them through the real engine: the definition, the
normalization profile and the project identity (`KumykDefinitionTests`),
the layout against the pinned Russian baseline and Kumyk long-press mapping
and against the dictionary's letter frequencies (`KumykLayoutTests`), the
shipped artifacts (`DictionaryTests`), typing, digraph insertion in every
case, accepted suggestions, learning, persistence and settings
(`TypingAndLearningTests`). 41 tests.

## Release signing (later, by the distribution owner)

The Release configuration carries the App Store identifiers and manual
signing with an empty team and empty profile names. Before the first
archive the distribution team must:

1. register the App IDs `org.lekitech.kumykkeyboard` and
   `org.lekitech.kumykkeyboard.KumykKeyboardExtension` and the App Group
   `group.org.lekitech.kumykkeyboard` in its developer account, with the
   App Groups capability on both App IDs;
2. create two App Store provisioning profiles and set, in the Release
   configuration of each target, `DEVELOPMENT_TEAM[sdk=iphoneos*]` and
   `PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]` (as Avar and Lezgi do);
3. keep Debug untouched, so development builds stay under the developer's
   own team.

Nothing here uses another developer's credentials, and no profile is
committed.

## Conventions

Exactly two targets. No sticker extension, no messenger integrations, no
third-party packages (General Keyboard `docs/ADDING_A_KEYBOARD.md`). Engine
changes go to `GeneralKeyboard-iOS` first; this repository holds only the
Kumyk definition, resources, tests and documentation. No engine change was
needed for Kumyk.
