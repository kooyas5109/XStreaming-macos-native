# Native Refactor Status Snapshot

Last updated: 2026-04-16

This document is the working status baseline for the native macOS rebuild. Its purpose is to keep a clear separation between:

- work that is fully implemented and verified
- work that exists only as a typed seam or demo shell
- work that is still missing

Use this file as the first checkpoint before starting the next refactor task.

## Completed Foundations

These areas are implemented, committed, and verified by tests:

- Native Swift Package workspace scaffold
- App shell, router, dependency container, and preview environment
- Shared typed domain models
- Persistence layer for settings, tokens, and cache
- Networking foundation and endpoint parity fixtures
- Feature skeletons for auth, settings, consoles, catalog, and streaming
- Compatibility streaming engine and native streaming engine preview shell
- Native shell pages for Home, Cloud, Settings, and Stream
- Bilingual shell support for English and Simplified Chinese
- CI workflow and integration smoke tests
- Native command menu and stream quick actions for demo flows
- Simplified Chinese is the first-launch default shell language
- Native auth shell entry with silent-restore and device-code sign-in state flow
- Live auth mode can complete Microsoft/Xbox device-code login and fetch real profile settings
- Live auth restore can refresh Microsoft/Xbox web and streaming tokens from the stored refresh token
- Live console inventory can fetch real Xbox devices through the xccs smartglass API
- Live xhome session creation and state polling are wired into the native streaming repository
- Live xhome session connect now exchanges the Microsoft refresh token for a console transfer token and posts it to `/connect`
- Live streaming repository can exchange SDP offers and ICE candidates through the Xbox `/sdp` and `/ice` signaling endpoints
- ICE exchange now posts browser/native-style candidate arrays, polls exchange responses, normalizes remote candidates, expands Teredo host candidates, and appends `a=end-of-candidates`
- Native streaming engine now receives the service-level signaling client and performs a testable SDP/ICE exchange before activating the local preview pipeline
- Stream controls now produce typed control events for Nexus, text, microphone, and mapped digital game actions
- Stream control events now also produce stable Codable payloads and JSON frames for the WebRTC input data channel seam

## Implemented But Still Demo-Oriented

These areas exist and are useful for architecture validation, but should not be treated as production-complete behavior:

- Settings persistence for language, fullscreen, performance style, display options, bitrate, codec, vibration, native mouse and keyboard, and mouse sensitivity
- Stream page controls for display, audio, microphone, fullscreen, performance visibility, send text, Nexus actions, and disconnect actions
- Native streaming surface preview and stream session state transitions
- Native control event queue for stream actions and digital button mapping
- Stable control payload shapes for button, text, and microphone events
- Cloud catalog preview data

Important constraint:

- Many of these settings currently affect preview UI, persisted state, or demo shell behavior only.
- They do not yet guarantee real Xbox auth, real xCloud session negotiation, real native WebRTC parameter application, or real input injection end to end.

## Partially Implemented

These areas have structure in place, but the real product path is not fully connected yet:

- AuthFeature
  - Typed service and view model exist
  - Native device-code sign-in flow is modeled and visible in the shell
  - Live auth provider and endpoint seam now exist for Microsoft and Xbox token requests
  - App shell can now switch between preview and live auth mode
  - Real Microsoft/Xbox device-code sign-in and profile fetch are wired
  - Startup restore can refresh stored Microsoft/Xbox tokens when the web/profile token is stale
  - Proactive/background token refresh still needs to be added
- StreamingFeature
  - Session core and engine abstractions exist
  - Preview/native shell works
  - Live xhome `/play`, `/state`, `/keepalive`, and `/delete` session calls are wired
  - Live xhome `/connect` transfer-token handshake is wired after `ReadyToConnect`
  - Live `/sdp` and `/ice` signaling request/response seams are wired and tested with closer parity to the original Electron flow
  - Native engine now routes startup through the SDP/ICE signaling seam, but still uses placeholder local SDP/ICE generation instead of a production WebRTC media stack
- Native engine can accept typed control events, build stable payloads, and write JSON frames through an injected WebRTC input data channel writer
  - Full production streaming transport is not fully connected
- Input support
  - Keyboard mapping, focus coordination, and controller monitoring exist
  - Digital game actions can be translated into typed stream control events
  - Real gameplay input serialization and delivery over the live stream path is not fully wired
- Console and catalog services
  - Console preview, cache semantics, and live xccs inventory are wired
  - Console power/text command request shapes exist, but need live interaction verification
  - Catalog is still preview-only

## Not Done Yet

These areas should still be treated as open:

- Proactive Xbox token refresh before expiry during long-running sessions
- Live console power/text operations verified against a real device
- Real xCloud catalog and session creation flow over native repositories
- Real SDP and ICE exchange backed by a production-capable native WebRTC engine and media renderer
- Binding the injected WebRTC input data channel writer to the production native WebRTC SDK data channel
- Real controller, keyboard, mouse, rumble, and text input injection during live streaming
- Theme system, background keepalive, FSR, and other non-core settings parity
- Packaging, signing, entitlements, and notarization readiness

## Current Product Truth

Today, the native app is best described as:

- a strong modular native architecture baseline
- a polished demo shell that reflects much of the original product shape
- a partial migration with good test coverage
- not yet a feature-complete replacement for the original Electron app

## Priority Order From This Point

The next implementation sequence should prioritize the core product path before more settings or polish:

1. Real login
2. Real streaming session establishment
3. Real control and input path
4. Only then continue migrating lower-priority settings and extras

## Immediate Next Track

The next active track is:

- stop expanding demo-only settings unless they directly help the core path
- use the original Electron project as the behavior reference
- focus on the shortest path to "login -> start stream -> control stream"

## Working Rules

When updating this repository:

- Mark a task as complete only if it is wired into the real runtime path, not just preview state
- When a feature is shell-only or demo-only, say that explicitly in docs and commits
- Keep referencing the original Electron implementation before changing behavior
- Update this file whenever the project changes phase or a major capability becomes truly live
