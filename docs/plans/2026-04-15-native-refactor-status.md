# Native Refactor Status Snapshot

Last updated: 2026-04-15

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
- Native auth shell entry with silent-restore and device-code sign-in state flow

## Implemented But Still Demo-Oriented

These areas exist and are useful for architecture validation, but should not be treated as production-complete behavior:

- Settings persistence for language, fullscreen, performance style, display options, bitrate, codec, vibration, native mouse and keyboard, and mouse sensitivity
- Stream page controls for display, audio, microphone, fullscreen, performance visibility, send text, Nexus actions, and disconnect actions
- Native streaming surface preview and stream session state transitions
- Console list and cloud catalog preview data

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
  - Real Microsoft/Xbox sign-in provider is not fully wired
- StreamingFeature
  - Session core and engine abstractions exist
  - Preview/native shell works
  - Full production streaming transport is not fully connected
- Input support
  - Keyboard mapping, focus coordination, and controller monitoring exist
  - Real gameplay input pipeline is not fully wired through the live stream path
- Console and catalog services
  - Preview and cache semantics exist
  - Real remote repositories are not fully connected across the entire product path

## Not Done Yet

These areas should still be treated as open:

- Real MSAL-first login flow for the native app
- Real Xbox token refresh and authenticated session bootstrap
- Real console discovery and live console operations over the native stack
- Real xCloud catalog and session creation flow over native repositories
- Real SDP and ICE exchange driving a production-capable streaming session
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
