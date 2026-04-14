# XStreaming macOS Native Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild `XStreaming-desktop` as a modular macOS-native app with a typed architecture, test coverage, and an incremental migration path that preserves Xbox auth, console discovery, xCloud catalog, settings, and streaming workflows.

**Architecture:** Build a new Swift Package based application architecture around a native macOS app target instead of continuing to evolve the current Electron/Nextron shell. Keep the existing TypeScript app as a behavior reference during migration, but move product logic into explicit native modules: AppShell, Auth, Streaming, Catalog, Consoles, Settings, Persistence, and Shared Domain. De-risk the migration by shipping a native shell and typed services first, then isolating streaming transport behind a protocol so we can start with a compatibility bridge and later replace it with a fully native WebRTC implementation.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Observation, Swift Package Manager, XCTest, Swift Testing, URLSession, WebKit, Keychain Services, GameController, AVFoundation, OSLog, optional WebRTC native SDK, reference guidance from `@build-macos-apps`

**Execution status tracking:** See `docs/plans/2026-04-15-native-refactor-status.md` for the current "done / partial / not started" snapshot so demo-shell work is not confused with fully live product behavior.

---

## Existing System Summary

Current project facts to preserve during migration:

- Electron lifecycle and IPC orchestration live in `main/application.ts`, `main/ipc.ts`, and `main/ipc/*`.
- Xbox auth has two code paths: `main/authentication.ts` and `main/MsalAuthentication.ts`.
- Streaming session management is centralized in `main/helpers/streammanager.ts`.
- Xbox/xCloud HTTP calls live in `main/helpers/xcloudapi.ts`.
- Console discovery and commands live in `main/ipc/consoles.ts`.
- Game catalog and achievement enrichment live in `main/ipc/xcloud.ts` and `main/helpers/titlemanager.ts`.
- Settings currently span `renderer/context/userContext.tsx`, `renderer/context/userContext.defaults.ts`, and `main/ipc/settings.ts`.
- The UI layer is page-heavy and mixes rendering, local caching, focus management, and network orchestration in `renderer/pages/[locale]/home.tsx`, `renderer/pages/[locale]/xcloud.tsx`, `renderer/pages/[locale]/stream.tsx`, and `renderer/pages/[locale]/settings.tsx`.
- There is effectively no automated test baseline in the current repo.

## Target Native Architecture

Create a new native subtree and keep the existing Electron app intact until feature parity is proven:

- `native-macos/Package.swift`
- `native-macos/App/XStreamingMacApp.swift`
- `native-macos/Sources/AppShell`
- `native-macos/Sources/SharedDomain`
- `native-macos/Sources/AuthFeature`
- `native-macos/Sources/ConsoleFeature`
- `native-macos/Sources/CatalogFeature`
- `native-macos/Sources/StreamingFeature`
- `native-macos/Sources/SettingsFeature`
- `native-macos/Sources/PersistenceKit`
- `native-macos/Sources/NetworkingKit`
- `native-macos/Sources/SupportKit`
- `native-macos/Tests/...`
- `docs/architecture/native-macos.md`
- `docs/migration/electron-to-native-mapping.md`

Core boundaries:

- `SharedDomain`: typed entities such as `UserProfile`, `ConsoleDevice`, `CatalogTitle`, `AchievementSummary`, `StreamingSession`, `AppSettings`.
- `NetworkingKit`: HTTP client, request signing, endpoint definitions, retry/backoff, decoding, auth header injection.
- `PersistenceKit`: Keychain for tokens, `UserDefaults` or file-backed store for app settings, small cache store for consoles/catalog metadata.
- `AuthFeature`: MSAL-first Xbox auth flow, token refresh, token validity checks, user identity bootstrap.
- `ConsoleFeature`: console listing, power operations, text injection, auto-connect behavior.
- `CatalogFeature`: xCloud titles, recent titles, new titles, Game Pass catalog hydration.
- `StreamingFeature`: session creation, session polling, SDP/ICE exchange, keepalive, audio/video/input bridge.
- `AppShell`: app navigation, scene/window management, dependency injection, deep links, logging, error surfaces.

Migration rules:

- Treat the current Electron app as the source of truth for behavior only, not architecture.
- Move to strict native types before feature parity UI work.
- Prefer protocol-first services and isolated view models over singleton state.
- All new native modules must have unit tests before integration.
- Preserve network behavior with golden fixtures before rewriting request flow.

## Decision Log To Lock Early

These decisions should be made explicitly in the first iteration and recorded in `docs/architecture/native-macos.md`:

1. Native app shell will be SwiftUI-first with targeted AppKit wrappers only where SwiftUI is insufficient.
2. Auth will standardize on MSAL-style token handling; legacy XAL flow is only a temporary reference during migration.
3. Streaming transport will be hidden behind `StreamingEngineProtocol`.
4. Initial streaming engine may use a compatibility layer if native WebRTC parity is not ready; the shell and session logic remain native either way.
5. Settings and tokens move out of ad-hoc JS storage into Keychain plus typed persistence.
6. The old Electron project remains buildable until native MVP parity is complete.

## Implementation Phases

- Phase 0: Discovery and parity mapping
- Phase 1: Native project scaffold and domain contracts
- Phase 2: Auth and settings migration
- Phase 3: Consoles and catalog migration
- Phase 4: Streaming session core and compatibility engine
- Phase 5: Native streaming UI and input stack
- Phase 6: Full native WebRTC engine replacement
- Phase 7: QA hardening, telemetry, packaging, and deprecation of Electron path

### Task 1: Write the migration architecture documents

**Files:**
- Create: `docs/architecture/native-macos.md`
- Create: `docs/migration/electron-to-native-mapping.md`
- Modify: `README.md`
- Modify: `README.zh_CN.md`
- Reference: `main/application.ts`
- Reference: `main/helpers/streammanager.ts`
- Reference: `main/helpers/xcloudapi.ts`
- Reference: `renderer/pages/[locale]/home.tsx`
- Reference: `renderer/pages/[locale]/xcloud.tsx`
- Reference: `renderer/pages/[locale]/stream.tsx`

**Step 1: Write the failing doc review checklist**

Create a checklist in `docs/architecture/native-macos.md` that fails review until it includes:

```md
- [ ] module graph
- [ ] dependency rules
- [ ] auth ownership
- [ ] streaming engine abstraction
- [ ] persistence strategy
- [ ] test pyramid
```

**Step 2: Run doc lint review manually**

Run: `rg -n "module graph|dependency rules|streaming engine abstraction" docs/architecture/native-macos.md`
Expected: missing matches before the document is complete

**Step 3: Write the minimal architecture docs**

Document:

- native module layout
- service and repository protocols
- state ownership rules
- migration sequence from Electron files to native packages
- mapping table from old files to new modules

**Step 4: Run doc validation**

Run: `rg -n "SharedDomain|NetworkingKit|StreamingEngineProtocol|MSAL" docs/architecture/native-macos.md docs/migration/electron-to-native-mapping.md`
Expected: all terms found

**Step 5: Commit**

```bash
git add docs/architecture/native-macos.md docs/migration/electron-to-native-mapping.md README.md README.zh_CN.md
git commit -m "docs: add native macOS migration architecture"
```

### Task 2: Scaffold the native macOS workspace

**Files:**
- Create: `native-macos/Package.swift`
- Create: `native-macos/App/XStreamingMacApp.swift`
- Create: `native-macos/Sources/AppShell/AppEnvironment.swift`
- Create: `native-macos/Sources/AppShell/AppRouter.swift`
- Create: `native-macos/Sources/AppShell/RootView.swift`
- Create: `native-macos/Sources/SupportKit/Logging/Logger.swift`
- Create: `native-macos/Tests/AppShellTests/AppBootstrapTests.swift`

**Step 1: Write the failing bootstrap test**

```swift
import Testing
@testable import AppShell

@Test func appEnvironmentBuildsDefaultDependencies() throws {
    let environment = AppEnvironment.makePreview()
    #expect(environment.router != nil)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos`
Expected: FAIL because package and modules do not exist yet

**Step 3: Write minimal package scaffold**

Implement:

- a Swift package with executable app support files
- `AppEnvironment`
- `AppRouter`
- a root SwiftUI view that can launch
- `Logger` wrapper around `OSLog`

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos`
Expected: PASS for bootstrap tests

**Step 5: Commit**

```bash
git add native-macos/Package.swift native-macos/App native-macos/Sources/AppShell native-macos/Sources/SupportKit native-macos/Tests/AppShellTests
git commit -m "feat: scaffold native macOS workspace"
```

### Task 3: Define typed shared domain models

**Files:**
- Create: `native-macos/Sources/SharedDomain/Models/UserProfile.swift`
- Create: `native-macos/Sources/SharedDomain/Models/ConsoleDevice.swift`
- Create: `native-macos/Sources/SharedDomain/Models/CatalogTitle.swift`
- Create: `native-macos/Sources/SharedDomain/Models/StreamingSession.swift`
- Create: `native-macos/Sources/SharedDomain/Models/AppSettings.swift`
- Create: `native-macos/Sources/SharedDomain/Protocols/RepositoryProtocols.swift`
- Create: `native-macos/Tests/SharedDomainTests/ModelCodableTests.swift`
- Reference: `renderer/context/userContext.defaults.ts`
- Reference: `main/ipc/consoles.ts`
- Reference: `main/ipc/xcloud.ts`
- Reference: `main/helpers/streammanager.ts`

**Step 1: Write the failing model round-trip tests**

```swift
import Testing
@testable import SharedDomain

@Test func appSettingsRoundTripsThroughJSON() throws {
    let value = AppSettings.defaults
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(decoded == value)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter SharedDomainTests`
Expected: FAIL because models are missing

**Step 3: Write minimal typed models**

Implement:

- `Equatable`, `Codable`, `Sendable` models
- normalized enums for console type, power state, streaming state
- typed defaults migrated from `renderer/context/userContext.defaults.ts`
- repository protocols with no implementation yet

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter SharedDomainTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/SharedDomain native-macos/Tests/SharedDomainTests
git commit -m "feat: add shared domain contracts for native app"
```

### Task 4: Build persistence and secure token storage

**Files:**
- Create: `native-macos/Sources/PersistenceKit/SettingsStore.swift`
- Create: `native-macos/Sources/PersistenceKit/TokenStore.swift`
- Create: `native-macos/Sources/PersistenceKit/CacheStore.swift`
- Create: `native-macos/Tests/PersistenceKitTests/SettingsStoreTests.swift`
- Create: `native-macos/Tests/PersistenceKitTests/TokenStoreTests.swift`
- Reference: `main/helpers/tokenstore.ts`
- Reference: `main/helpers/streamTokenStore.ts`
- Reference: `main/helpers/webTokenStore.ts`
- Reference: `renderer/context/userContext.tsx`

**Step 1: Write the failing persistence tests**

```swift
import Testing
@testable import PersistenceKit
@testable import SharedDomain

@Test func settingsStoreReturnsDefaultsOnFirstLaunch() throws {
    let store = InMemorySettingsStore()
    #expect(try store.load() == .defaults)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter PersistenceKitTests`
Expected: FAIL because stores are missing

**Step 3: Write minimal persistence implementations**

Implement:

- Keychain-backed token store
- `UserDefaults` backed settings store
- cache store for consoles and catalog
- test doubles that support deterministic unit tests

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter PersistenceKitTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/PersistenceKit native-macos/Tests/PersistenceKitTests
git commit -m "feat: add native persistence and token storage"
```

### Task 5: Implement typed networking infrastructure

**Files:**
- Create: `native-macos/Sources/NetworkingKit/HTTPClient.swift`
- Create: `native-macos/Sources/NetworkingKit/Endpoint.swift`
- Create: `native-macos/Sources/NetworkingKit/RequestBuilder.swift`
- Create: `native-macos/Sources/NetworkingKit/RetryPolicy.swift`
- Create: `native-macos/Sources/NetworkingKit/JSONDecoderFactory.swift`
- Create: `native-macos/Tests/NetworkingKitTests/RequestBuilderTests.swift`
- Create: `native-macos/Tests/NetworkingKitTests/RetryPolicyTests.swift`
- Reference: `main/helpers/xcloudapi.ts`
- Reference: `main/helpers/http.ts`
- Reference: `main/helpers/xhttp.ts`

**Step 1: Write the failing request construction tests**

```swift
import Foundation
import Testing
@testable import NetworkingKit

@Test func requestBuilderInjectsBearerToken() throws {
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v2/titles",
        token: "abc"
    )
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter NetworkingKitTests`
Expected: FAIL because networking layer is missing

**Step 3: Write minimal networking layer**

Implement:

- typed endpoint protocol
- auth header injection
- JSON encode/decode support
- retry for transient failures
- testable URLSession abstraction

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter NetworkingKitTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/NetworkingKit native-macos/Tests/NetworkingKitTests
git commit -m "feat: add typed networking infrastructure"
```

### Task 6: Standardize auth around a native MSAL-first service

**Files:**
- Create: `native-macos/Sources/AuthFeature/AuthService.swift`
- Create: `native-macos/Sources/AuthFeature/AuthRepository.swift`
- Create: `native-macos/Sources/AuthFeature/AuthViewModel.swift`
- Create: `native-macos/Sources/AuthFeature/AuthModels.swift`
- Create: `native-macos/Sources/AuthFeature/AuthView.swift`
- Create: `native-macos/Tests/AuthFeatureTests/AuthServiceTests.swift`
- Create: `native-macos/Tests/AuthFeatureTests/AuthViewModelTests.swift`
- Reference: `main/authentication.ts`
- Reference: `main/MsalAuthentication.ts`
- Reference: `main/ipc/app.ts`

**Step 1: Write the failing auth service test**

```swift
import Testing
@testable import AuthFeature

@Test func authServiceReportsSignedOutWithoutTokens() async throws {
    let service = AuthService.previewSignedOut()
    let state = try await service.restoreSession()
    #expect(state.isSignedIn == false)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter AuthFeatureTests`
Expected: FAIL because auth modules are missing

**Step 3: Write minimal native auth flow**

Implement:

- protocol for auth provider
- restore session
- refresh tokens
- Keychain persistence
- view model for signed-in state and login commands
- temporary seam for legacy auth behavior parity

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter AuthFeatureTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/AuthFeature native-macos/Tests/AuthFeatureTests
git commit -m "feat: add native auth service and view model"
```

### Task 7: Migrate settings into typed native state

**Files:**
- Create: `native-macos/Sources/SettingsFeature/SettingsViewModel.swift`
- Create: `native-macos/Sources/SettingsFeature/SettingsView.swift`
- Create: `native-macos/Sources/SettingsFeature/SettingsMapper.swift`
- Create: `native-macos/Tests/SettingsFeatureTests/SettingsViewModelTests.swift`
- Reference: `renderer/context/userContext.defaults.ts`
- Reference: `renderer/context/userContext.tsx`
- Reference: `renderer/pages/[locale]/settings.tsx`
- Reference: `main/ipc/settings.ts`

**Step 1: Write the failing settings mutation test**

```swift
import Testing
@testable import SettingsFeature
@testable import SharedDomain

@Test func savingTurnServerUpdatesSettingsStore() async throws {
    let model = try await SettingsViewModel.preview()
    model.serverURL = "turn:relay.example.com"
    try await model.save()
    #expect(model.toastMessage == "Saved")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter SettingsFeatureTests`
Expected: FAIL because settings feature is missing

**Step 3: Write minimal settings feature**

Implement:

- typed settings screen
- settings validation
- mapping from legacy defaults to native model
- save/reset/cache-clear commands

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter SettingsFeatureTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/SettingsFeature native-macos/Tests/SettingsFeatureTests
git commit -m "feat: add native settings feature"
```

### Task 8: Build the console discovery and command module

**Files:**
- Create: `native-macos/Sources/ConsoleFeature/ConsoleRepository.swift`
- Create: `native-macos/Sources/ConsoleFeature/ConsoleService.swift`
- Create: `native-macos/Sources/ConsoleFeature/ConsoleListViewModel.swift`
- Create: `native-macos/Sources/ConsoleFeature/ConsoleListView.swift`
- Create: `native-macos/Tests/ConsoleFeatureTests/ConsoleRepositoryTests.swift`
- Create: `native-macos/Tests/ConsoleFeatureTests/ConsoleListViewModelTests.swift`
- Reference: `main/ipc/consoles.ts`
- Reference: `renderer/pages/[locale]/home.tsx`

**Step 1: Write the failing console list test**

```swift
import Testing
@testable import ConsoleFeature

@Test func consoleListLoadsCachedThenRemoteConsoles() async throws {
    let model = ConsoleListViewModel.preview()
    try await model.load()
    #expect(model.consoles.count == 2)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter ConsoleFeatureTests`
Expected: FAIL because console feature is missing

**Step 3: Write minimal console feature**

Implement:

- repository methods for list, power on, power off, send text
- local cache then refresh behavior
- auto-connect support
- typed loading and error states

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter ConsoleFeatureTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/ConsoleFeature native-macos/Tests/ConsoleFeatureTests
git commit -m "feat: add native console discovery and commands"
```

### Task 9: Build the xCloud catalog and achievement module

**Files:**
- Create: `native-macos/Sources/CatalogFeature/CatalogRepository.swift`
- Create: `native-macos/Sources/CatalogFeature/CatalogService.swift`
- Create: `native-macos/Sources/CatalogFeature/CatalogViewModel.swift`
- Create: `native-macos/Sources/CatalogFeature/CatalogView.swift`
- Create: `native-macos/Sources/CatalogFeature/AchievementRepository.swift`
- Create: `native-macos/Tests/CatalogFeatureTests/CatalogRepositoryTests.swift`
- Create: `native-macos/Tests/CatalogFeatureTests/CatalogViewModelTests.swift`
- Reference: `main/ipc/xcloud.ts`
- Reference: `main/helpers/titlemanager.ts`
- Reference: `renderer/pages/[locale]/xcloud.tsx`

**Step 1: Write the failing catalog cache test**

```swift
import Testing
@testable import CatalogFeature

@Test func catalogLoadsCachedTitlesBeforeRefreshingRemoteData() async throws {
    let model = CatalogViewModel.preview()
    try await model.load()
    #expect(model.sections.isEmpty == false)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter CatalogFeatureTests`
Expected: FAIL because catalog feature is missing

**Step 3: Write minimal catalog feature**

Implement:

- titles, recent titles, new titles, search
- Game Pass product hydration
- cache-then-refresh strategy
- typed limitation state for xCloud level access

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter CatalogFeatureTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/CatalogFeature native-macos/Tests/CatalogFeatureTests
git commit -m "feat: add native xcloud catalog feature"
```

### Task 10: Build the streaming session core without UI coupling

**Files:**
- Create: `native-macos/Sources/StreamingFeature/StreamingRepository.swift`
- Create: `native-macos/Sources/StreamingFeature/StreamingService.swift`
- Create: `native-macos/Sources/StreamingFeature/StreamingEngineProtocol.swift`
- Create: `native-macos/Sources/StreamingFeature/StreamingSessionMonitor.swift`
- Create: `native-macos/Sources/StreamingFeature/StreamingStateMachine.swift`
- Create: `native-macos/Tests/StreamingFeatureTests/StreamingStateMachineTests.swift`
- Create: `native-macos/Tests/StreamingFeatureTests/StreamingServiceTests.swift`
- Reference: `main/helpers/streammanager.ts`
- Reference: `main/helpers/xcloudapi.ts`
- Reference: `main/ipc/streaming.ts`

**Step 1: Write the failing state machine test**

```swift
import Testing
@testable import StreamingFeature

@Test func waitingForResourcesTransitionsToQueued() throws {
    var state = StreamingStateMachine.State.pending
    state = StreamingStateMachine.reduce(state, event: .remoteStateChanged("WaitingForResources"))
    #expect(state == .queued)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter StreamingFeatureTests`
Expected: FAIL because streaming core is missing

**Step 3: Write minimal session core**

Implement:

- native repository for play, stop, state polling, SDP, ICE, keepalive
- state machine separate from views
- `StreamingEngineProtocol` abstraction
- session monitor for polling and timeout handling

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter StreamingFeatureTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/StreamingFeature native-macos/Tests/StreamingFeatureTests
git commit -m "feat: add native streaming session core"
```

### Task 11: Add a compatibility streaming engine for early parity

**Files:**
- Create: `native-macos/Sources/StreamingFeature/Compatibility/WebViewStreamingEngine.swift`
- Create: `native-macos/Sources/StreamingFeature/Compatibility/StreamingWebView.swift`
- Create: `native-macos/Sources/StreamingFeature/Compatibility/BridgeScript.js`
- Create: `native-macos/Tests/StreamingFeatureTests/WebViewStreamingEngineTests.swift`
- Reference: `renderer/pages/[locale]/stream.tsx`
- Reference: `renderer/public/js/FSR.js`

**Step 1: Write the failing engine contract test**

```swift
import Testing
@testable import StreamingFeature

@Test func compatibilityEngineImplementsStreamingProtocol() throws {
    let engine: any StreamingEngineProtocol = WebViewStreamingEngine.preview()
    #expect(engine.capabilities.supportsVideo == true)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter WebViewStreamingEngineTests`
Expected: FAIL because compatibility engine is missing

**Step 3: Write minimal compatibility engine**

Implement:

- a `WKWebView` host isolated behind the streaming protocol
- JS bridge for offer/answer/ICE if needed
- input, fullscreen, and overlay hooks owned by native code

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter WebViewStreamingEngineTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/StreamingFeature/Compatibility native-macos/Tests/StreamingFeatureTests
git commit -m "feat: add compatibility streaming engine for native shell"
```

### Task 12: Build the native shell navigation and feature screens

**Files:**
- Create: `native-macos/Sources/AppShell/Home/HomeView.swift`
- Create: `native-macos/Sources/AppShell/Home/HomeViewModel.swift`
- Create: `native-macos/Sources/AppShell/Cloud/CloudView.swift`
- Create: `native-macos/Sources/AppShell/Stream/StreamContainerView.swift`
- Create: `native-macos/Sources/AppShell/Settings/SettingsContainerView.swift`
- Create: `native-macos/Tests/AppShellTests/NavigationFlowTests.swift`
- Reference: `renderer/pages/[locale]/home.tsx`
- Reference: `renderer/pages/[locale]/xcloud.tsx`
- Reference: `renderer/pages/[locale]/settings.tsx`

**Step 1: Write the failing navigation flow test**

```swift
import Testing
@testable import AppShell

@Test func selectingConsoleRoutesToStreamScreen() throws {
    let router = AppRouter()
    router.route(to: .streamConsole(id: "console-1"))
    #expect(router.currentRoute == .streamConsole(id: "console-1"))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter AppShellTests`
Expected: FAIL if route types or screens are incomplete

**Step 3: Write minimal native screens**

Implement:

- home screen bound to console feature
- cloud screen bound to catalog feature
- settings screen bound to settings feature
- stream container bound to streaming feature

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter AppShellTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/AppShell native-macos/Tests/AppShellTests
git commit -m "feat: add native shell navigation and screens"
```

### Task 13: Add native input, focus, and game controller handling

**Files:**
- Create: `native-macos/Sources/SupportKit/Input/GameControllerMonitor.swift`
- Create: `native-macos/Sources/SupportKit/Input/KeyboardMapper.swift`
- Create: `native-macos/Sources/SupportKit/Input/FocusCoordinator.swift`
- Create: `native-macos/Tests/SupportKitTests/KeyboardMapperTests.swift`
- Create: `native-macos/Tests/SupportKitTests/FocusCoordinatorTests.swift`
- Reference: `renderer/pages/[locale]/home.tsx`
- Reference: `renderer/pages/[locale]/xcloud.tsx`
- Reference: `renderer/pages/[locale]/settings.tsx`
- Reference: `renderer/context/userContext.defaults.ts`

**Step 1: Write the failing keyboard mapping test**

```swift
import Testing
@testable import SupportKit

@Test func keyboardMapperReturnsAForEnter() throws {
    let mapper = KeyboardMapper.default
    #expect(mapper.action(for: "Enter") == .buttonA)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter SupportKitTests`
Expected: FAIL because input support is missing

**Step 3: Write minimal input support**

Implement:

- keyboard mapping from legacy defaults
- controller connect/disconnect monitor
- focus coordinator for remote/gamepad navigation

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter SupportKitTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/SupportKit/Input native-macos/Tests/SupportKitTests
git commit -m "feat: add native input and focus support"
```

### Task 14: Replace the compatibility engine with a native streaming engine

**Files:**
- Create: `native-macos/Sources/StreamingFeature/Native/NativeStreamingEngine.swift`
- Create: `native-macos/Sources/StreamingFeature/Native/WebRTCSession.swift`
- Create: `native-macos/Sources/StreamingFeature/Native/AudioSessionCoordinator.swift`
- Create: `native-macos/Sources/StreamingFeature/Native/VideoRenderer.swift`
- Create: `native-macos/Tests/StreamingFeatureTests/NativeStreamingEngineTests.swift`
- Modify: `docs/architecture/native-macos.md`
- Reference: `main/helpers/xcloudapi.ts`
- Reference: `renderer/pages/[locale]/stream.tsx`

**Step 1: Write the failing native engine contract test**

```swift
import Testing
@testable import StreamingFeature

@Test func nativeEngineExposesSameCapabilitiesAsCompatibilityEngine() throws {
    let engine: any StreamingEngineProtocol = NativeStreamingEngine.preview()
    #expect(engine.capabilities.supportsRumble == true)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter NativeStreamingEngineTests`
Expected: FAIL because native engine is missing

**Step 3: Write minimal native engine**

Implement:

- native WebRTC session wrapper
- audio/video render pipeline
- controller input and rumble pathway
- parity-focused API matching the protocol

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter NativeStreamingEngineTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Sources/StreamingFeature/Native native-macos/Tests/StreamingFeatureTests docs/architecture/native-macos.md
git commit -m "feat: add native streaming engine"
```

### Task 15: Add fixture-driven regression tests for request parity

**Files:**
- Create: `native-macos/Tests/Fixtures/console-list.json`
- Create: `native-macos/Tests/Fixtures/catalog-titles.json`
- Create: `native-macos/Tests/Fixtures/stream-state-ready.json`
- Create: `native-macos/Tests/RegressionTests/EndpointParityTests.swift`
- Create: `native-macos/Tests/RegressionTests/DecodingParityTests.swift`
- Reference: `main/helpers/xcloudapi.ts`
- Reference: `main/ipc/consoles.ts`
- Reference: `main/ipc/xcloud.ts`

**Step 1: Write the failing fixture regression test**

```swift
import Testing
@testable import NetworkingKit

@Test func titlesFixtureDecodesIntoCatalogResponse() throws {
    let data = try Fixtures.load("catalog-titles.json")
    let response = try JSONDecoder().decode(CatalogResponse.self, from: data)
    #expect(response.results.isEmpty == false)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path native-macos --filter RegressionTests`
Expected: FAIL because fixtures or models are incomplete

**Step 3: Write minimal fixtures and parity tests**

Implement:

- fixture loader
- decoders for representative payloads
- request shape assertions for auth, consoles, titles, stream start, SDP, ICE

**Step 4: Run test to verify it passes**

Run: `swift test --package-path native-macos --filter RegressionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add native-macos/Tests/Fixtures native-macos/Tests/RegressionTests
git commit -m "test: add fixture-driven regression coverage"
```

### Task 16: Add integration tests and packaging pipeline

**Files:**
- Create: `native-macos/Tests/IntegrationTests/AppLaunchTests.swift`
- Create: `.github/workflows/native-macos.yml`
- Modify: `.github/workflows/build.yml`
- Modify: `README.md`
- Modify: `README.zh_CN.md`

**Step 1: Write the failing CI test checklist**

```md
- [ ] swift build
- [ ] swift test
- [ ] app launch smoke test
- [ ] archive signing placeholder
```

**Step 2: Run local command to verify the workflow is incomplete**

Run: `rg -n "native-macos|swift test|swift build" .github/workflows`
Expected: missing coverage for native build before workflow is added

**Step 3: Write minimal CI pipeline**

Implement:

- GitHub Actions workflow for native build and tests
- smoke test target
- documentation for local build and run

**Step 4: Run validation**

Run: `rg -n "swift build|swift test|native-macos" .github/workflows/native-macos.yml README.md README.zh_CN.md`
Expected: all terms found

**Step 5: Commit**

```bash
git add .github/workflows/native-macos.yml .github/workflows/build.yml README.md README.zh_CN.md native-macos/Tests/IntegrationTests
git commit -m "ci: add native macOS build and test pipeline"
```

## Testing Strategy

- Unit tests: models, stores, request builders, state machines, view models.
- Fixture regression tests: decode legacy-like payloads and verify request parity with current Electron behavior.
- Integration tests: auth session restore, console list, catalog fetch, stream session bootstrap using mocks.
- UI smoke tests: app launch, route transitions, settings persistence, stream shell presentation.
- Manual tests:
  - sign in with clean install
  - resume session from saved tokens
  - list consoles
  - power on and power off console
  - browse cloud catalog
  - start cloud stream
  - start home stream
  - test keyboard/controller input
  - test fullscreen and background behavior

## Migration Cutover Criteria

Do not deprecate Electron until all of the following are true:

- Native app passes `swift test` on CI.
- Native app can complete login and restore session.
- Native app supports settings persistence and TURN configuration.
- Native app can list consoles and xCloud titles.
- Native app can create, monitor, and stop streaming sessions.
- Native app has either compatibility streaming parity or native engine parity accepted by manual QA.
- README and release workflows describe the native app as the primary macOS path.

## Risks And Mitigations

- Risk: Native WebRTC parity takes longer than expected.
  - Mitigation: ship the compatibility engine first behind `StreamingEngineProtocol`.
- Risk: Legacy auth behavior is subtle and poorly documented.
  - Mitigation: create fixture-based auth/session restoration tests before replacing network code.
- Risk: Current Electron pages hide business rules in UI side effects.
  - Mitigation: map each page responsibility into repositories and view models before writing screens.
- Risk: Type migration exposes inconsistent payload shapes.
  - Mitigation: decode real fixtures and use tolerant DTO-to-domain mappers.
- Risk: Migration stalls if Electron and native implementations drift.
  - Mitigation: keep a parity mapping document and require every native feature to cite its source file lineage.

## Suggested Milestone Order

1. Docs and native scaffold
2. Shared domain and persistence
3. Networking and auth
4. Settings and home/console flows
5. Catalog flow
6. Streaming session core
7. Compatibility engine and native shell
8. Native engine replacement
9. CI, packaging, and cutover

Plan complete and saved to `docs/plans/2026-04-14-xstreaming-macos-native-refactor.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
