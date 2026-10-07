# Repository Guidelines

## Project Structure & Module Organization

TerminalLauncher is a macOS 27 app with a WidgetKit extension and the `tl` CLI. `App/` handles URLs and Terminal launching; `Widget/` contains timelines and SwiftUI views; `CLI/main.swift` is the CLI entry point. Shared logic lives in `Packages/LauncherKit/Sources/PathStore/` and `Sources/TLCommands/`, with matching test targets under `Packages/LauncherKit/Tests/`. Icons are in `App/Assets.xcassets/`; design notes are in `docs/superpowers/`.

Edit `project.yml` for target configuration. `TerminalLauncher.xcodeproj` is generated and ignored by Git.

## Build, Test, and Development Commands

Use Xcode 27 (Swift 6.4), macOS 27+, and XcodeGen. Signed builds require an Apple ID configured in Xcode.

```bash
# Run package tests from the repository root.
swift test --package-path Packages/LauncherKit
# Run one suite.
swift test --package-path Packages/LauncherKit --filter AddTests
# Generate and build all targets without installing.
xcodegen generate
xcodebuild -project TerminalLauncher.xcodeproj -scheme TerminalLauncher \
  -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
# Build Release, install, link tl, and launch the app.
scripts/install.sh
```

For Xcode development, open the generated project. Widget previews live in `Widget/PathsWidgetView.swift`.

## Coding Style & Naming Conventions

Follow existing Swift style: four-space indentation, `UpperCamelCase` types, and `lowerCamelCase` methods and properties. Name files after their principal type. Keep platform targets thin; put testable behavior in LauncherKit and inject side effects through `Commands` dependencies. No formatter or linter is configured.

## Testing Guidelines

Use Swift Testing (`@Suite`, `@Test`, `#expect`). Name files `*Tests.swift`, suites by behavior, and methods descriptively, such as `addExistingMovesToTop`. Use temporary stores and fake dependencies. Cover changed behavior and error cases; no numeric coverage threshold is configured. Run the full package suite before submitting. For UI changes, install and check widget sizes, folder clicks, and refresh behavior manually.

## Commit & Pull Request Guidelines

Follow history: `feat:`, `fix:`, `docs:`, or `chore:`, with optional scopes such as `feat(widget):`. Use concise imperative subjects. PRs should describe behavior changes, link relevant issues, and record verification commands and results. Include screenshots for widget or icon changes.

## Architecture & Configuration Rules

Keep the CLI as the only writer of `paths.json`; preserve atomic writes and never overwrite unreadable or unsupported data. Preserve logical symlink paths and require exact stored-path matches before opening Terminal. Change signing IDs together in `project.yml`, all three entitlement files, and `PathStore.appGroupID`; clear `build/` after signing changes.
