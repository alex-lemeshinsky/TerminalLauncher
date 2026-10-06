# App Group spike findings

Date: 2026-10-06. Throwaway spike (spec section 10); the spike code is deleted.

## Answers

- **Q1, CLI access to the group container: YES.** `spikecli` was run twice from the
  human's own Terminal. Both runs printed the container path and a `written ...` line
  (`written 2026-10-06T18:53:33Z`, then `written 2026-10-06T18:53:40Z`). No privacy
  dialog appeared.
- **Q2, widget reads the file the CLI wrote: YES.** The medium spike widget on the
  desktop showed `written 2026-10-06T18:53:40Z`, the second CLI run's value.
- **Q3, widget appears in Edit Widgets: YES.** It was found and added while the app was
  installed in `~/Applications`.

## Container path

`/Users/alex/Library/Group Containers/A5STTR22DU.com.alex.TerminalLauncher/`
(the file used by the spike was `spike.txt` in that directory).

## Team ID correction

The team ID is **A5STTR22DU**, a free Personal Team. It is the signing certificate's OU.
`4DTV898H25` is only the CN suffix in "Apple Development: a.lemeshinsky@gmail.com
(4DTV898H25)" and is not a team ID; using it fails with
`No Account for Team "4DTV898H25"`. The App Group is therefore
`A5STTR22DU.com.alex.TerminalLauncher`. Caveats: certificates expire 2027-03-09, and
free-team provisioning profiles may expire sooner.

## Signing settings that worked

Automatic signing worked for all three targets. The Manual fallback was not needed.

Global (`settings.base`): `DEVELOPMENT_TEAM: A5STTR22DU`, `CODE_SIGN_STYLE: Automatic`,
`SWIFT_VERSION: "6.0"`, deployment target macOS 27.0.

- **App (application)**: bundle ID `com.alex.TerminalLauncher.Spike`. Entitlements:
  `com.apple.security.application-groups: [A5STTR22DU.com.alex.TerminalLauncher]` only,
  no sandbox. Dependencies:
  - widget: `embed: true`
  - CLI tool: `embed: true`, `codeSign: false`, `copy: {destination: executables}`
    (lands in `Contents/MacOS`)
- **Widget (app-extension)**: bundle ID `com.alex.TerminalLauncher.Spike.Widget`.
  Entitlements: `com.apple.security.app-sandbox: true` plus the same App Group. Nothing
  beyond Automatic signing and the team.
- **CLI (tool)**:
  - `PRODUCT_BUNDLE_IDENTIFIER: com.alex.TerminalLauncher.spikecli`
  - `PRODUCT_NAME: spikecli`
  - `ENABLE_HARDENED_RUNTIME: YES`
  - `OTHER_CODE_SIGN_FLAGS: "--identifier com.alex.TerminalLauncher.spikecli"`
  - entitlement: the same App Group

Tool-signing findings:

- A tool has no Info.plist, so its codesign identifier defaults to the product name
  (`spikecli`). `OTHER_CODE_SIGN_FLAGS "--identifier ..."` on the tool target fixes the
  identifier of the built product.
- With `codeSign: true` on the embed/copy phase, Xcode re-signs the copy and resets the
  identifier to `spikecli`. Use `codeSign: false` on the embed copy so the proper
  signature is kept.
- After changing `codeSign`, an incremental build failed with "nested code is modified
  or invalid". A clean build (`rm -rf build`) fixed it. Do a clean build after such a
  change.
- Release builds carry `get-task-allow=true`, injected by Xcode for Apple Development
  signing.

Verification: `codesign --verify --deep --strict` printed OK on the build and on the
installed copy. All three binaries had `TeamIdentifier=A5STTR22DU`.

## Decision

Proceed with approach A (CLI writes into the App Group container, widget reads it).
Install the app to `~/Applications` (confirmed to work for widget discovery; no need
for `/Applications`). Tasks 8 and 10 must use team `A5STTR22DU` and group
`A5STTR22DU.com.alex.TerminalLauncher`, and copy the signing settings above.
