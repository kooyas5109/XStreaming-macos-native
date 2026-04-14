# Native macOS Architecture

## Goal

Rebuild `XStreaming-desktop` as a native macOS application with typed module boundaries, testable business logic, and an incremental migration path away from Electron and Nextron.

## Scope

This document defines the target architecture for the native macOS implementation. It does not describe every UI detail. It focuses on ownership, dependency rules, state boundaries, migration seams, and testing strategy.

## Review Checklist

- [x] module graph
- [x] dependency rules
- [x] auth ownership
- [x] streaming engine abstraction
- [x] persistence strategy
- [x] test pyramid

## Principles

- Prefer SwiftUI-first application structure, with focused AppKit wrappers only where native platform APIs require it.
- Treat the current Electron app as behavioral reference material, not as architecture to preserve.
- Move all business logic out of screens and into typed services, repositories, and view models.
- Standardize on MSAL-first authentication for native code.
- Keep streaming transport behind a protocol so we can ship a compatibility engine before full native WebRTC parity.
- Make every new module independently testable with fixtures and in-memory doubles.

## Module Graph

```text
AppShell
|- AuthFeature
|- SettingsFeature
|- ConsoleFeature
|- CatalogFeature
|- StreamingFeature
|- SupportKit
|- SharedDomain
|- PersistenceKit
`- NetworkingKit

AuthFeature
|- SharedDomain
|- PersistenceKit
`- NetworkingKit

SettingsFeature
|- SharedDomain
`- PersistenceKit

ConsoleFeature
|- SharedDomain
|- PersistenceKit
`- NetworkingKit

CatalogFeature
|- SharedDomain
|- PersistenceKit
`- NetworkingKit

StreamingFeature
|- SharedDomain
|- PersistenceKit
|- NetworkingKit
`- SupportKit

PersistenceKit
`- SharedDomain

NetworkingKit
`- SharedDomain

SupportKit
`- SharedDomain
```

## Dependency Rules

- `SharedDomain` contains pure value types and feature-neutral protocols only.
- `NetworkingKit` knows nothing about SwiftUI, views, or app navigation.
- `PersistenceKit` exposes storage protocols and concrete Keychain or `UserDefaults` implementations.
- Feature modules may depend on `SharedDomain`, `NetworkingKit`, `PersistenceKit`, and `SupportKit`, but not on each other directly.
- Cross-feature reuse happens through protocol composition in `AppShell`, not through direct feature-to-feature imports.
- `AppShell` is the only place allowed to wire real implementations into the live environment.
- Streaming UI must depend on `StreamingEngineProtocol`, never on a concrete WebRTC or WebView engine type.

## App Shell

`AppShell` owns:

- app lifecycle
- scene and window setup
- route state
- dependency injection
- global alerts, sheets, and fullscreen coordination
- release-channel and app-update presentation

`AppShell` should expose one environment object or observation-backed container that contains:

- `AuthService`
- `SettingsStore`
- `ConsoleService`
- `CatalogService`
- `StreamingService`
- `Logger`

The shell should not implement Xbox or streaming logic itself. It only coordinates modules.

## Shared Domain

`SharedDomain` should define the stable language of the product:

- `UserProfile`
- `ConsoleDevice`
- `ConsolePowerState`
- `CatalogTitle`
- `AchievementSummary`
- `StreamingSession`
- `StreamingState`
- `AppSettings`
- `TurnServerConfiguration`
- `AuthState`

All domain models should conform to:

- `Codable`
- `Equatable`
- `Sendable`

Prefer domain enums over stringly typed status values. Raw payloads should be decoded into DTOs inside repositories and mapped into domain values before they reach view models.

## Auth Ownership

`AuthFeature` owns:

- sign-in flow
- silent restore
- token refresh
- token validity checks
- user profile bootstrap
- sign-out and local credential clearing

Auth storage rules:

- Xbox and MSAL tokens live in Keychain.
- session metadata and small cache timestamps may live in app storage.
- no auth state is allowed in view-local storage or ad-hoc serialized files.

Auth migration direction:

- native implementation is MSAL-first
- legacy XAL flow remains reference-only until full cutover
- repositories must hide provider-specific token mechanics from the UI

## Persistence Strategy

Use two persistence layers:

- `TokenStore`
  - Keychain-backed
  - stores auth, web, and streaming credential material
  - exposes typed load, save, clear operations
- `SettingsStore`
  - `UserDefaults` backed
  - stores typed `AppSettings`
  - includes migration support from legacy defaults where useful

Optional cache layer:

- `CacheStore`
  - file-backed or `UserDefaults` backed for consoles, catalog payloads, and last-known metadata
  - stores typed cache envelopes with timestamp and schema version

Persistence rules:

- cache entries may be stale and must be refreshable
- token entries may not be serialized into plain text debug logs
- settings mutations happen through typed APIs only

## Networking Strategy

`NetworkingKit` owns:

- request construction
- auth header injection
- retries for transient failures
- response decoding
- fixture-backed regression support

Repository modules own endpoint semantics:

- `AuthRepository`
- `ConsoleRepository`
- `CatalogRepository`
- `StreamingRepository`

Repository rules:

- decode transport DTOs close to the network boundary
- map DTOs into domain values before returning
- centralize header conventions so request parity is testable

## Feature Boundaries

### SettingsFeature

Owns:

- settings screen
- validation for bitrate, TURN server config, mapping preferences, debug flags
- reset and clear-cache actions

Does not own:

- token clearing logic
- app restart policy
- streaming implementation

### ConsoleFeature

Owns:

- console list loading
- power commands
- text injection
- auto-connect trigger state

Does not own:

- streaming session creation
- global route changes

### CatalogFeature

Owns:

- xCloud titles
- recent and new titles
- search and filtering
- Game Pass metadata hydration
- achievement summary and detail lookups

Does not own:

- stream session orchestration

### StreamingFeature

Owns:

- stream session creation and teardown
- stream state polling
- SDP and ICE exchange
- keepalive
- player-facing state machine
- overlay state for warnings, errors, performance panels, and audio controls

Does not own:

- app-wide routing
- auth token issuance
- settings persistence

### SupportKit

Owns:

- controller monitoring
- keyboard mapping
- focus coordination
- small platform adapters that are not product features by themselves

Does not own:

- business workflows
- network requests
- persistence policies

## Streaming Engine Abstraction

The native app must define:

```swift
protocol StreamingEngineProtocol: Sendable {
    var capabilities: StreamingEngineCapabilities { get }
    func prepare(configuration: StreamingConfiguration) async throws
    func createOffer() async throws -> SessionDescription
    func applyRemoteOffer(_ offer: SessionDescription) async throws
    func applyRemoteCandidates(_ candidates: [IceCandidate]) async throws
    func setLocalSettings(_ settings: StreamingRuntimeSettings) async
    func start() async throws
    func stop() async
}
```

Planned implementations:

- `WebViewStreamingEngine`
  - transition engine
  - uses native shell with a contained compatibility surface
- `NativeStreamingEngine`
  - target engine
  - native WebRTC, audio, input, rumble, and video rendering

This seam allows the product to ship a native shell without blocking on immediate full WebRTC rewrite.
The live preview app should switch to `NativeStreamingEngine` as soon as the shell can render a native video surface without depending on the compatibility bridge.

## Error Handling

Each feature should expose typed UI states:

- `idle`
- `loading`
- `loaded`
- `empty`
- `error`

Use user-facing error values that contain:

- short message
- optional recovery action
- underlying error category

Do not pass raw transport or Keychain errors directly into SwiftUI views.

## Observability

Use `OSLog` categories:

- `app`
- `auth`
- `settings`
- `consoles`
- `catalog`
- `streaming`
- `network`

Logging rules:

- redact tokens and credential material
- keep request IDs where possible
- include stream session IDs in streaming logs

## Test Pyramid

- Unit tests
  - models
  - stores
  - request builders
  - DTO mappers
  - state machines
  - view models
- Fixture regression tests
  - console list payloads
  - catalog payloads
  - stream state payloads
  - request parity for start session, SDP, ICE, keepalive
- Integration tests
  - auth restore
  - console refresh from cache then remote
  - catalog hydration flow
  - stream session bootstrap with mocked engine
- UI smoke tests
  - app launch
  - home to stream navigation
  - settings persistence
  - auth state transitions

## Migration Strategy

Stage the migration in this order:

1. create native app shell and module contracts
2. move shared types and persistence
3. move auth and settings
4. move console and catalog features
5. move stream session orchestration
6. add compatibility streaming engine
7. replace compatibility engine with native engine
8. cut over macOS release packaging

Electron remains buildable until:

- native app restores sessions
- native app loads consoles and catalog
- native app starts and stops streams reliably
- automated tests cover the new request and state boundaries

## Open Questions

- whether the initial compatibility engine should host a local asset bridge or a slimmer web transport shim
- how much of the existing `xstreaming-player` behavior must be matched before macOS native can become default
- whether a separate package should own controller rumble and low-level input handling
