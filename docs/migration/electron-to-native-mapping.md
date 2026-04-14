# Electron To Native Mapping

## Purpose

This document maps the current Electron and Nextron implementation to the target native macOS modules. It is the handoff index for incremental migration work.

## Current To Target Mapping

| Current area | Current files | Native target | Notes |
| --- | --- | --- | --- |
| App lifecycle and window setup | `main/application.ts`, `main/helpers/create-window.ts`, `main/preload.ts` | `AppShell` | Move window lifecycle, fullscreen, route bootstrapping, and dependency wiring into native shell. |
| IPC registry | `main/ipc.ts`, `main/ipc/base.ts`, `main/ipc/*` | Direct feature service calls from `AppShell` | Native app should remove generic IPC and use typed in-process APIs. |
| Legacy auth flow | `main/authentication.ts`, `main/xal/*`, `main/helpers/tokenstore.ts` | `AuthFeature` + `PersistenceKit` | Keep as behavior reference only while standardizing native auth around MSAL-first flows. |
| MSAL auth flow | `main/MsalAuthentication.ts`, `main/xal/msal.ts` | `AuthFeature` | Preserve silent restore, device-code or provider-specific login flows, refresh, and profile bootstrap. |
| Auth state exposure | `main/ipc/app.ts` | `AuthFeature.AuthViewModel` + `AppShell` | Replace opaque IPC state with typed observable auth state. |
| Settings defaults | `renderer/context/userContext.defaults.ts` | `SharedDomain.AppSettings` | Convert all settings into typed native model defaults. |
| Settings persistence | `renderer/context/userContext.tsx`, `main/ipc/settings.ts` | `SettingsFeature` + `PersistenceKit.SettingsStore` | Remove split localStorage and Electron store ownership. |
| Console list and power actions | `main/ipc/consoles.ts` | `ConsoleFeature` | Preserve cache-then-refresh behavior and command APIs. |
| Game catalog and achievements | `main/ipc/xcloud.ts`, `main/helpers/titlemanager.ts`, `main/helpers/achivementmanager.ts` | `CatalogFeature` | Keep recent titles, new titles, Game Pass hydration, and achievement detail behavior. |
| Stream session orchestration | `main/ipc/streaming.ts`, `main/helpers/streammanager.ts` | `StreamingFeature.StreamingService` | Preserve session polling, queued states, failure states, and keepalive. |
| Xbox and xCloud HTTP transport | `main/helpers/xcloudapi.ts`, `main/helpers/http.ts`, `main/helpers/xhttp.ts` | `NetworkingKit` + feature repositories | Preserve endpoint semantics, headers, and response decoding. |
| Home page orchestration | `renderer/pages/[locale]/home.tsx` | `ConsoleFeature.ConsoleListViewModel` + `AppShell.HomeView` | Split auth restore, cache usage, navigation, and controller focus into separate modules. |
| Cloud page orchestration | `renderer/pages/[locale]/xcloud.tsx` | `CatalogFeature.CatalogViewModel` + `AppShell.CloudView` | Remove transport and cache logic from the screen. |
| Stream page orchestration | `renderer/pages/[locale]/stream.tsx` | `StreamingFeature.StreamViewModel` + `StreamContainerView` | Native shell owns overlays and stream engine configuration. |
| Settings page orchestration | `renderer/pages/[locale]/settings.tsx` | `SettingsFeature.SettingsViewModel` + `SettingsView` | Native settings screen becomes typed and testable. |
| Input and HID edge cases | `hid.js`, keyboard mapping in `renderer/context/userContext.defaults.ts`, focus logic in `renderer/pages/[locale]/home.tsx`, `renderer/pages/[locale]/xcloud.tsx`, `renderer/pages/[locale]/settings.tsx` | `SupportKit` + `StreamingFeature` | Split platform input monitoring from product-level stream input translation and rumble behavior. |
| Web fallback IPC bridge | `renderer/lib/ipc.ts`, `renderer/lib/websocket.ts` | none | Delete for native app. No generic transport bridge should remain in the final architecture. |
| Update checks | `main/helpers/updater.ts`, `renderer/lib/updater.ts` | `AppShell` or `SupportKit` | Reimplement macOS-friendly update mechanism separately from Electron conventions. |

## Responsibility Breakup By Feature

### AppShell

Source behavior references:

- `main/application.ts`
- `main/helpers/create-window.ts`
- `renderer/pages/_app.tsx`
- `renderer/components/Layout.tsx`
- `renderer/components/Nav.tsx`

Native responsibilities:

- launch and bootstrap
- navigation state
- fullscreen
- global overlays
- dependency injection

### AuthFeature

Source behavior references:

- `main/authentication.ts`
- `main/MsalAuthentication.ts`
- `main/ipc/app.ts`

Native responsibilities:

- login
- restore session
- refresh session
- sign-out
- current user summary

### SettingsFeature

Source behavior references:

- `renderer/context/userContext.defaults.ts`
- `renderer/context/userContext.tsx`
- `renderer/pages/[locale]/settings.tsx`
- `main/ipc/settings.ts`

Native responsibilities:

- settings screen
- settings validation
- reset
- clear cache
- persistence coordination

### ConsoleFeature

Source behavior references:

- `main/ipc/consoles.ts`
- `renderer/pages/[locale]/home.tsx`

Native responsibilities:

- list consoles
- cache then refresh
- power commands
- auto-connect decision

### CatalogFeature

Source behavior references:

- `main/ipc/xcloud.ts`
- `main/helpers/titlemanager.ts`
- `renderer/pages/[locale]/xcloud.tsx`
- `renderer/pages/[locale]/achivements.tsx`

Native responsibilities:

- titles
- recents
- new games
- search
- achievements

### StreamingFeature

Source behavior references:

- `main/ipc/streaming.ts`
- `main/helpers/streammanager.ts`
- `main/helpers/xcloudapi.ts`
- `renderer/pages/[locale]/stream.tsx`
- `renderer/components/Display.tsx`
- `renderer/components/FSRDisplay.tsx`
- `renderer/components/Audio.tsx`
- `renderer/components/Perform.tsx`

Native responsibilities:

- session bootstrap
- stream state machine
- player engine abstraction
- audio and video configuration
- overlays and performance panels
- keyboard and controller integration

## Hotspots To Untangle First

These are the current files with the most cross-cutting logic and the highest migration value:

1. `renderer/pages/[locale]/stream.tsx`
   - currently mixes player config, router parsing, ICE and SDP exchange, connection state, overlays, and user preferences
2. `renderer/pages/[locale]/home.tsx`
   - currently mixes auth restore, local cache, focus control, gamepad polling, and navigation
3. `renderer/pages/[locale]/xcloud.tsx`
   - currently mixes cache, title hydration, filtering, and focus handling
4. `main/helpers/streammanager.ts`
   - central behavior reference for session lifecycle and state transitions
5. `main/helpers/xcloudapi.ts`
   - central behavior reference for request shape and endpoint semantics

## Deletion Candidates After Native Cutover

Delete only after macOS native parity is validated:

- `main/*`
- `renderer/*`
- `nextron.config.js`
- `electron-builder.yml`
- Electron-specific build scripts in `package.json`
- preload and IPC bridge types

Keep temporarily during migration:

- network fixtures and example payloads derived from Electron behavior
- user-facing screenshots and localized strings as reference content
- release notes and README installation instructions until macOS native becomes the default path

## Migration Checks Per Feature

Before marking a feature migrated, verify:

- there is a typed domain model
- there is a repository protocol
- there is a tested concrete implementation
- there is a view model that owns state transitions
- the screen does not talk directly to transport or storage
- at least one regression test covers legacy request or payload parity

## Notes On Sequencing

- Move contracts before implementations.
- Move repositories before screens.
- Keep the first native stream path behind a compatibility engine if native WebRTC is not ready.
- Avoid partial rewrites inside Electron. New architecture should land inside `native-macos/`.
