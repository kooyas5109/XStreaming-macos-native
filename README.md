# XStreaming macOS Native

Native macOS rewrite of the XStreaming desktop client.

## Status

This repository is the isolated home for the macOS-native rebuild. It is intentionally separate from the original Electron/Nextron project so the native architecture, tooling, and release flow can evolve without destabilizing the existing desktop app.

Current focus:

- define the native architecture baseline
- map Electron behavior into native modules
- execute the phased migration plan

## Repository Docs

- Architecture baseline: [docs/architecture/native-macos.md](./docs/architecture/native-macos.md)
- Electron to native mapping: [docs/migration/electron-to-native-mapping.md](./docs/migration/electron-to-native-mapping.md)
- Execution plan: [docs/plans/2026-04-14-xstreaming-macos-native-refactor.md](./docs/plans/2026-04-14-xstreaming-macos-native-refactor.md)
- Execution status snapshot: [docs/plans/2026-04-15-native-refactor-status.md](./docs/plans/2026-04-15-native-refactor-status.md)

## Local Build And Run

```bash
swift build --package-path native-macos
swift test --package-path native-macos
swift run --package-path native-macos XStreamingMacApp
```

Current preview behavior:

- launches the native shell
- shows Home, Cloud, Settings, and Stream routes
- renders the native streaming preview surface through `NativeStreamingEngine`

## CI

GitHub Actions workflow:

- `.github/workflows/native-macos.yml`
- runs `swift build --package-path native-macos`
- runs `swift test --package-path native-macos`
- runs an app launch smoke test through `IntegrationTests`

## Relationship To The Original Project

- Original desktop project: behavior reference and current release path
- This repository: native macOS rebuild using SwiftUI, Swift Package Manager, typed modules, and automated tests

## Near-Term Milestones

1. Scaffold the native macOS workspace.
2. Define shared domain types and persistence.
3. Implement auth, console, catalog, and streaming service seams.
4. Ship a native shell before replacing the streaming engine.
5. Add CI, integration coverage, and packaging scaffolding for the native app.
