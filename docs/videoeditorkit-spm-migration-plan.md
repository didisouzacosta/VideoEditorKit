# VideoEditorKit SPM Migration Plan

## Summary

This plan migrates the repository to a split structure where:

- `Packages/VideoEditorKit` becomes the isolated SPM package
- the current iOS app becomes `VideoEditor`
- `VideoEditor` imports `VideoEditorKit` as a real host integration example

The key change from the earlier approach is that the package will no longer be created on top of the current `VideoEditorKit/` app directory. Instead, phase 1 starts by creating a new isolated package directory so the package and the app shell do not compete for the same source tree.

## Goals

1. Create a local SPM package named `VideoEditorKit`.
2. Keep the current app alive during the migration.
3. Turn the current app into `VideoEditor`, a host app and example integration.
4. Move editor-owned code into the package incrementally.
5. Keep app-shell concerns out of the package.

## Non-Goals

- Do not redesign the editor into a fully pure engine architecture in phase 1.
- Do not move the full app into the package.
- Do not require freeform crop export support before packaging.
- Do not split the package into many targets immediately.
- Do not rename the app target in the same change that only scaffolds the package.

## Tooling Rule

All iOS build, test, simulator, and host-app validation steps in this migration should use the [@build-ios-apps](plugin://build-ios-apps@openai-curated) plugin as the default execution path.

That means:

- use the plugin for iOS project discovery, scheme inspection, build, test, simulator run, and app validation
- prefer the plugin workflow over ad hoc `xcodebuild` or simulator shell commands when the task involves the app target or iOS integration behavior
- keep `swift test` for pure SPM package validation when the work is confined to the isolated package and does not require the host app

This rule exists to keep the rollout consistent, reduce environment drift, and make every host-app validation step reproducible through one iOS-native toolchain path.

## Why Use an Isolated Package Directory

Creating the package directly inside the current `VideoEditorKit/` app directory would work, but it creates fragile coupling:

- app-shell files and package files remain mixed
- `Package.swift` would depend on many `exclude` rules
- the app could accidentally compile the same sources both directly and through the package
- resource ownership becomes unclear

Using `Packages/VideoEditorKit` solves those issues earlier:

- package code lives in its own directory
- package resources are isolated from app resources
- the future publishable package layout already exists
- the host app can adopt the package through a clean local dependency

## Current State

Today the repository is still app-first:

- [VideoEditorApp.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/VideoEditorApp.swift) defines the app entry point
- [RootView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/RootView.swift) behaves as the app shell
- [EditedVideoProjectsStore.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Persistence/EditedVideoProjectsStore.swift) owns SwiftData persistence
- [VideoEditorView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/API/VideoEditorView.swift) is now the public editor entry point that the app shell presents directly
- the editor implementation, playback managers, tool views, and export pipeline now live under `Packages/VideoEditorKit/Sources/VideoEditorKit`

That means the correct package boundary is around the editor feature, not around the current app target.

## Target Structure

### Transitional Structure

```text
Packages/
  VideoEditorKit/
    Package.swift
    Sources/
      VideoEditorKit/
    Tests/
      VideoEditorKitTests/

VideoEditor/
VideoEditor.xcodeproj          # current Xcode project during transition
VideoEditorTests/
docs/
scripts/
```

### Final Intended Structure

```text
Packages/
  VideoEditorKit/
    Package.swift
    Sources/
      VideoEditorKit/
    Tests/
      VideoEditorKitTests/

VideoEditor/
VideoEditor.xcodeproj
VideoEditorTests/
docs/
scripts/
```

The repository now uses the final host-directory naming for the app and test targets. The remaining migration work is focused on moving more editor-owned code into the package, not on host identity cleanup.

## Ownership Boundary

### Package-Owned Scope

The package should own:

- `VideoEditorView`
- editor-facing configuration, session, and callbacks
- editing models and mappers
- timeline, crop, canvas, transcript, and thumbnail logic used by the editor
- playback and recording managers used by the editor
- export pipeline
- transcription components that are editor feature dependencies

### Host-App-Owned Scope

The host app should own:

- app entry point
- home screen and gallery
- project persistence with SwiftData
- reopen flows
- share sheet policy
- API key and host environment bootstrapping
- premium feature gating and paywall policy

Current host-owned candidates include:

- [VideoEditorApp.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/VideoEditorApp.swift)
- [RootView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/RootView.swift)
- [EditedVideoProjectsStore.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Persistence/EditedVideoProjectsStore.swift)
- [EditedVideoProject.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Persistence/EditedVideoProject.swift)
- [VideoShareSheet.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Sharing/VideoShareSheet.swift)

## Public API Direction

The package should expose a minimal host-facing API centered on the embeddable editor:

```swift
import VideoEditorKit

VideoEditorView(
    "Editor",
    session: session,
    configuration: configuration,
    callbacks: callbacks
)
```

The first public API allowlist should be intentionally small:

- `VideoEditorView`
- `VideoEditorView.Session`
- `VideoEditorView.Configuration`
- `VideoEditorView.Callbacks`
- `VideoEditingConfiguration`
- `VideoQuality`
- `ExportedVideo` only if the host actually needs it

Everything else should stay `internal` until the host integration proves a broader API is necessary.

## Known Edge Cases and Recommended Solutions

### 1. Mixed app and package sources

Problem:
The current app directory mixes editor feature code with app-shell code.

Solution:
Do not build the package from the current `VideoEditorKit/` app directory. Create `Packages/VideoEditorKit` and move or copy only package-owned sources into it incrementally.

### 2. Package and app compiling the same sources

Problem:
If the app still compiles the editor sources directly while also importing the package, duplicate symbols and ownership confusion can happen.

Solution:
Treat this as a migration gate:

1. package compiles on its own
2. app stops compiling package-owned sources directly
3. app starts importing `VideoEditorKit`

Phase 1 only covers step 1.

### 3. Resources mixed with app resources

Problem:
[Assets.xcassets](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Resources/Assets.xcassets) currently contains app-only assets such as `AppIcon`.

Solution:
Keep package resources in the isolated package tree. App-only resources remain in the app target. `AppIcon` must never move into the package.

### 4. `PhotosPickerItem` in the public API

Problem:
[VideoEditorView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/API/VideoEditorView.swift) exposes the session boundary publicly, and the host still creates sessions from app-owned import flows.

Solution:
Move the package toward a source abstraction that is host-neutral, such as:

- `fileURL(URL)`
- an async imported-file resolver returning `URL`

If PhotosUI helpers remain useful, keep them in the host app or in a later optional adapter target.

### 5. `Transferable` import helpers leaking into the boundary

Problem:
[VideoItem.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/VideoItem.swift) currently couples import flow to a specific transfer mechanism.

Solution:
Treat import helpers as adapters, not as part of the durable package API. The package should operate on resolved file URLs whenever possible.

### 6. `Bundle.main` assumptions

Problem:
[RootView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/RootView.swift) currently resolves transcription config from host app state.

Solution:
Move host configuration lookup to the app. The package should receive configuration values through injected `VideoEditorView.Configuration`.

### 7. Export pipeline is still iOS-heavy

Problem:
[VideoEditor.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Enums/VideoEditor.swift) depends on AVFoundation, CoreImage, and UIKit.

Solution:
Accept this in version 1 of the package. The first milestone is an embeddable iOS package, not a platform-neutral core.

### 8. Access control can widen too quickly

Problem:
Converting a local codebase into a package often tempts broad `public` promotion.

Solution:
Use a documented API allowlist and promote access only for host-required types.

### 9. Test ownership during migration

Problem:
Package tests and host-app tests will coexist for some time.

Solution:
Move editor-domain and package behavior tests into the package over time, but keep host integration, SwiftData, and shell tests in the app until the host rename is complete.

### 10. Rename churn for the host app

Problem:
Renaming the app target, app sources, and project identity too early adds noisy churn.

Solution:
Postpone the rename until the package skeleton exists and the extraction boundary is clearer.

## Technical Rollout

### Phase 1

Goal:
Create the isolated package skeleton in `Packages/VideoEditorKit`.

Deliverables:

- create `Packages/VideoEditorKit/Package.swift`
- create `Sources/VideoEditorKit/`
- create `Tests/VideoEditorKitTests/`
- add a minimal package entry file
- add a minimal Swift Testing test target
- keep the current app unchanged as the source of truth while extraction has not started

Exit criteria:

- the package directory exists
- the package manifest is valid
- the package has at least one buildable target and one test target
- no app-host files have been renamed yet

### Phase 2

Goal:
Extract the first package-owned slice from the app into the isolated package.

Recommended first slice:

- package-only foundational types that do not depend on the app shell
- small pure model or configuration types

Deliverables:

- move the first safe editor-owned source files into `Packages/VideoEditorKit/Sources/VideoEditorKit`
- move or recreate the corresponding tests in `Packages/VideoEditorKit/Tests/VideoEditorKitTests`
- keep the app building while still using local sources until the package integration step begins

Exit criteria:

- at least one real editor-owned feature slice lives in the package
- the package is no longer only a scaffold

Current implementation notes:

- the first extracted slice is the crop and safe-area rules layer
- the package now contains:
  - minimal `VideoEditingConfiguration` support types required by the extracted slice
  - `VideoCropFormatPreset`
  - `VideoCropPreviewLayout`
  - `SocialPlatformSafeArea` and related safe-area guide types
- package tests now cover the extracted slice directly

### Phase 3

Goal:
Continue extracting package-owned editor code until the embeddable editor boundary is usable.

Priority order:

1. models and configuration
2. pure coordinators/resolvers
3. editor view and its direct support graph
4. export pipeline
5. optional transcription and media adapters

Deliverables:

- package contains the code necessary for the editor feature
- app-shell files remain outside the package

Current implementation notes:

- the canvas core has been extracted into the package
- the package now contains:
  - `VideoCanvasPreset`
  - `VideoCanvasTransform`
  - `VideoCanvasSnapshot`
  - `VideoCanvasLayout`
  - `VideoCanvasRenderRequest` and related descriptor types
  - `VideoCanvasMappingActor`
- the package manifest now declares minimum platforms compatible with the extracted canvas code:
  - iOS 16
- package tests now validate the extracted canvas mapping rules directly

### Phase 4

Goal:
Adopt the local package inside the current app target.

Deliverables:

- add the local package dependency from `Packages/VideoEditorKit`
- stop compiling extracted package-owned sources directly in the app target
- import `VideoEditorKit` from the app
- validate host-app integration through [@build-ios-apps](plugin://build-ios-apps@openai-curated)

Exit criteria:

- the app no longer compiles package-owned implementation files directly
- the app uses the package as a client

Current implementation notes:

- the Xcode project now includes the local package dependency from `Packages/VideoEditorKit`
- the host app includes a package smoke import to validate local package adoption
- the host app now uses the module name `VideoEditor`, fully separated from the package identity
- the package now uses the final module identity `VideoEditorKit` for both the library product and the internal target
- the package now owns the extracted rule layers for:
  - crop presets and crop preview layout
  - safe-area guides
  - canvas mapping
  - editing configuration and transcript models
  - playback and transcript mapping coordinators
  - toolbar selection and toolbar layout
  - crop editing state and crop presentation-state resolution
  - transcript word highlight constants
- the host app no longer compiles the extracted implementation files directly for those slices
- the host keeps thin compatibility wrappers only where the app still adds local behavior on top of package-owned types, such as crop application rules that still inspect the local `Video` model
- host-app validation now succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated)
  - targeted Xcode test validation for `AppShellTranscriptionConfigurationTests`
  - targeted Xcode test validation for package-adoption seams including:
    - `VideoEditorKitPackageSmokeTests`
    - `VideoEditingPresentationStateResolverTests`
    - `EditorCropEditingCoordinatorTests`
    - `EditorInitialLoadCoordinatorTests`
    - `EditorCropPresentationStateTests`
    - `TranscriptOverlayLayoutResolverTests`

Phase 4 status:

- completed
- deeper extractions that still depend on the local `Video` runtime model can continue after the host rename without blocking package adoption

### Phase 5

Goal:
Rename the current app into `VideoEditor`.

Deliverables:

- rename app target to `VideoEditor`
- rename scheme to `VideoEditor`
- update product naming and identifiers as needed
- update docs and references
- validate the renamed host app through [@build-ios-apps](plugin://build-ios-apps@openai-curated)

Exit criteria:

- the host identity is clearly separate from the package identity

Current implementation notes:

- the host project file is now [VideoEditor.xcodeproj](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor.xcodeproj/project.pbxproj)
- the shared scheme is now `VideoEditor`
- the app target name is now `VideoEditor`
- the unit-test target name is now `VideoEditorTests`
- the host Swift module name is now `VideoEditor`
- host tests now import `@testable import VideoEditor`
- the app entry point is now [VideoEditorApp.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/VideoEditorApp.swift)
- host validation now succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for `VideoEditorTests` with the renamed host identity

Phase 5 status:

- completed
- the host product identity exposed to Xcode and the simulator is now `VideoEditor`

### Phase 6

Goal:
Refine package API and optional adapters.

Deliverables:

- remove `PhotosPickerItem` from public API
- move host-specific defaults out of package internals
- split optional adapter targets only if they are justified

Current implementation notes:

- the package now owns a host-neutral session boundary through:
  - [VideoEditorSessionSource.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Session/VideoEditorSessionSource.swift)
  - [VideoEditorSessionBootstrapCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Session/VideoEditorSessionBootstrapCoordinator.swift)
- `VideoEditorView.Session.Source` now aliases the package-owned `VideoEditorSessionSource`
- `PhotosPickerItem` is no longer part of the editor-facing session API
- the host app keeps `PhotosUI` only inside the adapter layer in:
  - [VideoEditorSessionSourceResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Photos/VideoEditorSessionSourceResolver.swift)
  - [RootView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/RootView.swift)
- package validation now succeeds with:
  - `swift test` in `Packages/VideoEditorKit` covering the new session boundary and bootstrap behavior
- host validation now succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `VideoEditorSessionSourceResolverTests`
    - `VideoEditorSessionBootstrapCoordinatorTests`
    - `RootViewModelTests`
    - `EnumAndHelperTests`
    - `VideoEditorKitPackageSmokeTests`

Phase 6 status:

- completed
- `PhotosPickerItem` has been removed from the editor-facing API boundary
- the editor-facing `TranscriptionConfiguration` is now a neutral provider container and no longer constructs backend-specific providers on its own
- backend-specific transcription factories now live in the host app shell through:
  - [AppShellTranscriptionConfiguration.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Transcription/AppShellTranscriptionConfiguration.swift)
- `PhotosUI` source adaptation now lives in the host app shell through:
  - [VideoEditorSessionSourceResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Photos/VideoEditorSessionSourceResolver.swift)
- host validation now also succeeds for transcription-boundary coverage including:
  - `EnumAndHelperTests`
  - `RootViewModelTests`
  - `EditorViewModelTests`
- no extra package adapter target was introduced in this phase because the remaining adapters are still host-specific integration details and are cleaner as explicit app-shell code than as premature optional package products

### Phase 7

Goal:
Normalize the host filesystem layout to match the renamed `VideoEditor` identity.

Deliverables:

- rename the app source directory from `VideoEditorKit/` to `VideoEditor/`
- rename the host test directory from `VideoEditorKitTests/` to `VideoEditorTests/`
- update Xcode project root-group paths and `Info.plist` references
- update internal docs and repo instructions that still reference the transitional host paths
- validate the normalized host layout through [@build-ios-apps](plugin://build-ios-apps@openai-curated)

Exit criteria:

- the host filesystem layout matches the `VideoEditor` app identity
- `VideoEditor.xcodeproj` resolves the new source and test roots without transitional path names

Current implementation notes:

- the app source directory is now `VideoEditor/`
- the host test directory is now `VideoEditorTests/`
- [project.pbxproj](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor.xcodeproj/project.pbxproj) now points its synchronized root groups at `VideoEditor/` and `VideoEditorTests/`
- the app target now resolves its `Info.plist` from [Info.plist](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Info.plist)
- repository guidance in [AGENTS.md](/Users/adrianocosta/Documents/Projects/VideoEditorKit/AGENTS.md) and [CLAUDE.md](/Users/adrianocosta/Documents/Projects/VideoEditorKit/CLAUDE.md) now references the normalized host layout

Phase 7 status:

- completed
- package validation succeeds with `swift test` in `Packages/VideoEditorKit`
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `VideoEditorKitPackageSmokeTests`
    - `RootViewModelTests`
    - `EnumAndHelperTests`
- the host validation for this phase was intentionally targeted at the rename-sensitive seams instead of the full simulator suite because the full `test_sim` run exceeded the plugin's default wait window; this was treated as an execution-time limitation, not as a functional regression signal
- the active host build and test path already runs through [VideoEditor.xcodeproj](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor.xcodeproj/project.pbxproj); the later repository cleanup in Phase 8 removes the leftover legacy project directory

### Phase 8

Goal:
Clean up the remaining repository residue from the host rename.

Deliverables:

- remove the legacy `VideoEditorKit.xcodeproj`
- update operational docs that still instruct people to run tests through the old project, scheme, or host test target name
- revalidate that the active host path still builds and tests through `VideoEditor.xcodeproj`

Exit criteria:

- the repository no longer contains the legacy `VideoEditorKit.xcodeproj`
- active operational docs no longer point to the old project or host test target names
- host validation still succeeds through [VideoEditor.xcodeproj](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor.xcodeproj/project.pbxproj)

Current implementation notes:

- the legacy `VideoEditorKit.xcodeproj` has been removed from the workspace
- actionable verification commands in [multi-provider-transcription-plan.md](/Users/adrianocosta/Documents/Projects/VideoEditorKit/docs/multi-provider-transcription-plan.md) now reference `VideoEditor.xcodeproj`, scheme `VideoEditor`, and target `VideoEditorTests`
- remaining mentions of `VideoEditorKitTests` in this document refer only to the package test target under `Packages/VideoEditorKit/Tests/VideoEditorKitTests`, not to the host app test target
- historical documents may still mention legacy names when they are describing past architecture or earlier phases rather than giving current operational instructions

Phase 8 status:

- completed
- the active host project path is now only [VideoEditor.xcodeproj](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor.xcodeproj/project.pbxproj)
- repository cleanup was validated by rebuilding and rerunning targeted host tests through [@build-ios-apps](plugin://build-ios-apps@openai-curated)

### Phase 9

Goal:
Normalize the package module identity and remove the temporary internal target name.

Deliverables:

- rename the package target from `VideoEditorKitSPM` to `VideoEditorKit`
- update package tests to import the final module name
- update host integration wrappers and smoke seams to import `VideoEditorKit`
- keep the host package alias bridge only where it still reduces churn during extraction

Exit criteria:

- the package no longer uses the temporary internal module name
- package validation succeeds through the final module identity
- host validation succeeds while importing the final package module identity

Current implementation notes:

- [Package.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Package.swift) now declares the target as `VideoEditorKit`
- package tests under `Packages/VideoEditorKit/Tests/VideoEditorKitTests/` now import `@testable import VideoEditorKit`
- host integration seams such as [VideoEditorKitPackageAliases.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageAliases.swift), [VideoEditorKitPackageSmoke.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageSmoke.swift), and [VideoEditorSessionBootstrapCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/VideoEditorSessionBootstrapCoordinator.swift) now import the final package module name

Phase 9 status:

- completed
- package validation succeeds through `swift test` in `Packages/VideoEditorKit`
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `VideoEditorKitPackageSmokeTests`
    - `RootViewModelTests`
    - `EnumAndHelperTests`
- the temporary internal module name has been removed from the package and host integration seams

### Phase 10

Goal:
Move the editor-facing API models into the package while keeping the host-owned `VideoEditorView` implementation stable.

Deliverables:

- extract public editor API types for save state, session, callbacks, and configuration into the package
- extract `VideoQuality` and `ExportQualityAvailability` into the package so the editor-facing configuration can live entirely on the package side
- update `VideoEditorView` to consume the package-owned API types through typealiases instead of local nested implementations
- exclude the host-local `VideoQuality.swift` from the app target once the package version becomes the active one

Exit criteria:

- the package owns the editor-facing API models used at the `VideoEditorView` boundary
- the host app builds against the package-owned API models
- package and host validation both succeed after the API move

Current implementation notes:

- the package now owns:
  - [VideoEditorPublicTypes.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift)
  - [VideoQuality.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Export/VideoQuality.swift)
- [VideoEditorView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/API/VideoEditorView.swift) now owns the package-facing namespace for `SaveState`, `Session`, `Callbacks`, and `Configuration`
- the host alias bridge in [VideoEditorKitPackageAliases.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageAliases.swift) now also maps `VideoQuality`, `ExportQualityAvailability`, and the extracted editor API types from the package
- [project.pbxproj](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor.xcodeproj/project.pbxproj) now excludes the host-local [VideoQuality.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/VideoQuality.swift) from the app target
- the package now has direct coverage for the extracted API models in [VideoEditorPublicTypesTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/VideoEditorPublicTypesTests.swift)

Phase 10 status:

- completed
- package validation succeeds through `swift test` in `Packages/VideoEditorKit` with the extracted editor API models and `VideoQuality`
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `VideoEditorKitPackageSmokeTests`
    - `RootViewModelTests`
    - `EnumAndHelperTests`
- the host still keeps a broad alias bridge for extracted package types, but the editor-facing API models at the `VideoEditorView` boundary are now package-owned

### Phase 11

Goal:
Start reducing the broad host alias bridge by switching selected consumers to direct package imports.

Deliverables:

- remove the alias-bridge entries for the newly extracted editor API types and `VideoQuality`
- update the immediate host consumers to import `VideoEditorKit` directly
- update the most relevant host tests to import `VideoEditorKit` directly where they exercise the extracted package types

Exit criteria:

- the first wave of consumers no longer depends on aliases for the extracted editor API types or `VideoQuality`
- host build and targeted simulator tests still pass after the alias reduction

Current implementation notes:

- [RootView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/RootView.swift) now imports `VideoEditorKit` directly and presents the package-owned `VideoEditorView` instead of going through a host-side editor wrapper
- host consumers of `VideoQuality` and `ExportQualityAvailability`, including:
  - [RootView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/RootView.swift)
  - [EditedVideoProjectsStore.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Persistence/EditedVideoProjectsStore.swift)
  now import `VideoEditorKit` directly
- host tests covering those extracted types, including:
  - [ViewModifierSmokeTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Extensions/ViewModifierSmokeTests.swift)
  - [EnumAndHelperTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Enums/EnumAndHelperTests.swift)
  now import `VideoEditorKit` directly
- [VideoEditorKitPackageAliases.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageAliases.swift) no longer carries aliases for `VideoEditorCallbacks`, `VideoEditorConfiguration`, `VideoEditorSaveState`, `VideoEditorSession`, `VideoQuality`, or `ExportQualityAvailability`

Phase 11 status:

- completed
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `VideoEditorKitPackageSmokeTests`
    - `RootViewModelTests`
    - `EnumAndHelperTests`
    - `ViewModifierSmokeTests`
- the alias bridge remains in place for older extracted rule/model slices that still have many host consumers, but the newest API and quality types are now on direct imports

### Phase 12

Goal:
Continue reducing the alias bridge around the package-owned session boundary.

Deliverables:

- remove alias-bridge entries for `VideoEditorSessionSource` and related imported-file session types
- update the host-side session adapter and the most relevant host tests to import `VideoEditorKit` directly for session-source usage

Exit criteria:

- the session boundary no longer relies on top-level host aliases
- host build and targeted simulator tests still pass after the alias removal

Current implementation notes:

- [VideoEditorSessionSourceResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Photos/VideoEditorSessionSourceResolver.swift) now imports `VideoEditorKit` directly
- [RootViewModelTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/ViewModels/RootViewModelTests.swift) now imports `VideoEditorKit` directly for session-source coverage
- [VideoEditorKitPackageAliases.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageAliases.swift) no longer carries aliases for `VideoEditorSessionSource` or `VideoEditorImportedFileSource`

Phase 12 status:

- completed
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `RootViewModelTests`
    - `VideoEditorKitPackageSmokeTests`
- the alias bridge remains for older high-churn model and coordinator slices, but the session boundary itself now resolves its package types by direct import

### Phase 13

Goal:
Continue reducing the alias bridge around package-owned editing tools by moving `ToolEnum` and `ToolAvailability` consumers to direct package imports.

Deliverables:

- remove alias-bridge entries for `ToolEnum` and `ToolAvailability`
- update the most relevant host editing coordinators, view models, views, and tests to import `VideoEditorKit` directly
- resolve any direct-import ambiguities in host tests without re-expanding the alias bridge

Exit criteria:

- `ToolEnum` and `ToolAvailability` no longer depend on top-level host aliases
- host build and targeted simulator tests still pass after the alias removal

Current implementation notes:

- host consumers that now import `VideoEditorKit` directly for tool modeling include:
  - [EditorAudioEditingCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/EditorAudioEditingCoordinator.swift)
  - [EditorInitialLoadCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/EditorInitialLoadCoordinator.swift)
  - [EditorPlaybackEditingCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/EditorPlaybackEditingCoordinator.swift)
  - [EditorSessionCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/EditorSessionCoordinator.swift)
  - [EditorToolbarItemPresentationResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/EditorToolbarItemPresentationResolver.swift)
  - [VideoEditingConfigurationMapper.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/VideoEditingConfigurationMapper.swift)
  - [Video.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Video.swift)
  - [EditorPresentationState.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/ViewModels/EditorPresentationState.swift)
  - [EditorTaskCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/ViewModels/EditorTaskCoordinator.swift)
  - [EditorViewModel.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/ViewModels/EditorViewModel.swift)
  - [PagedToolsRow.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/PagedToolsRow.swift)
  - [ToolsSectionView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/ToolsSectionView.swift)
- host tests that now import `VideoEditorKit` directly for tool modeling include:
  - [EditorInitialLoadCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorInitialLoadCoordinatorTests.swift)
  - [EditorToolbarItemPresentationResolverTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorToolbarItemPresentationResolverTests.swift)
  - [VideoModelTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoModelTests.swift)
  - [EditorViewModelTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/ViewModels/EditorViewModelTests.swift)
- [VideoEditorKitPackageAliases.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageAliases.swift) no longer carries aliases for `ToolEnum` or `ToolAvailability`
- [EditorViewModelTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/ViewModels/EditorViewModelTests.swift) now qualifies `VideoEditorKit.VideoTranscriptionInput` explicitly in its test doubles to avoid a direct-import ambiguity with the transitional host transcription surface

Phase 13 status:

- completed
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `EditorViewModelTests`
    - `EditorInitialLoadCoordinatorTests`
    - `EditorToolbarItemPresentationResolverTests`
    - `VideoModelTests`
    - `VideoEditorKitPackageSmokeTests`
- the alias bridge is now smaller around the core editing-tool layer, while higher-churn extracted types such as `VideoEditingConfiguration` still remain on the transitional seam

### Phase 14

Goal:
Reduce the alias bridge around package-owned editing configuration, canvas, crop, safe-area, and playback rule types.

Deliverables:

- move the remaining host consumers of `VideoEditingConfiguration`, crop presets, canvas snapshots, safe-area guides, and `PlaybackTimeMapping` to direct `VideoEditorKit` imports
- remove the corresponding alias entries from the host seam
- keep wrapper-vs-package ambiguities explicit in tests where the host still owns a thin forwarding layer

Exit criteria:

- the host no longer depends on top-level aliases for the configuration/canvas/crop/safe-area/playback slice
- host build and targeted simulator tests still pass after the alias removal

Current implementation notes:

- direct `VideoEditorKit` imports now cover host consumers such as:
  - [EditedVideoProject.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Persistence/EditedVideoProject.swift)
  - [EditedVideoProjectsStore.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Persistence/EditedVideoProjectsStore.swift)
  - [VideoPlayerManager.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Managers/Player/VideoPlayerManager.swift)
  - [EditorCropPresentationResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/EditorCropPresentationResolver.swift)
  - [VideoEditorLayoutResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/VideoEditorLayoutResolver.swift)
  - [VideoEditorSaveEmissionCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/VideoEditorSaveEmissionCoordinator.swift)
  - [VideoEditingThumbnailRenderer.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Utils/VideoEditingThumbnailRenderer.swift)
  - [VideoEditingThumbnailTimestampResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Utils/VideoEditingThumbnailTimestampResolver.swift)
  - [EditorCropPresentationState.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/ViewModels/EditorCropPresentationState.swift)
  - [RootViewModel.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/ViewModels/RootViewModel.swift)
  - [VideoCanvasEditorState.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/ViewModels/VideoCanvasEditorState.swift)
  - [PlayerHolderView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/EditorView/PlayerHolderView.swift)
  - [VideoCanvasPreviewView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/EditorView/VideoCanvasPreviewView.swift)
  - [EditedVideoProjectCard.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/EditedVideoProjectCard.swift)
  - [VideoAudioToolView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/Audio/VideoAudioToolView.swift)
  - [ThumbnailsSliderView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/CutView/ThumbnailsSliderView.swift)
  - [CropView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/Presets/CropView.swift)
  - [PresentToolView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/Presets/PresentToolView.swift)
- the host tests covering this slice now import `VideoEditorKit` directly, including:
  - [EditedVideoProjectsStoreTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/AppShell/EditedVideoProjectsStoreTests.swift)
  - [EditorCropEditingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorCropEditingCoordinatorTests.swift)
  - [EditorSessionCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorSessionCoordinatorTests.swift)
  - [SocialPlatformSafeAreaTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/SocialPlatformSafeAreaTests.swift)
  - [VideoCanvasMappingActorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoCanvasMappingActorTests.swift)
  - [VideoCropFormatPresetTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoCropFormatPresetTests.swift)
  - [VideoCropPreviewLayoutTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoCropPreviewLayoutTests.swift)
  - [VideoEditingConfigurationTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoEditingConfigurationTests.swift)
  - [VideoEditingPresentationStateResolverTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoEditingPresentationStateResolverTests.swift)
  - [VideoEditorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoEditorTests.swift)
  - [CoreUtilityCharacterizationTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Utils/CoreUtilityCharacterizationTests.swift)
  - [PlaybackTimeMappingTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Utils/PlaybackTimeMappingTests.swift)
  - [VideoEditingThumbnailRendererTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Utils/VideoEditingThumbnailRendererTests.swift)
  - [EditorCropPresentationStateTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/ViewModels/EditorCropPresentationStateTests.swift)
  - [ExporterViewModelTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/ViewModels/ExporterViewModelTests.swift)
  - [VideoCanvasPreviewViewTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Views/VideoCanvasPreviewViewTests.swift)
- the host seam no longer aliases:
  - `EditorCropEditingState`
  - `PlaybackTimeMapping`
  - `ResolvedVideoEditingPresentationState`
  - `SafeAreaGuideLayout`
  - `SafeAreaGuideProfile`
  - `SafeAreaGuideRegion`
  - `SafeAreaInsets`
  - `SocialPlatform`
  - `VideoCanvasExportMapping`
  - `VideoCanvasLayout`
  - `VideoCanvasMappingActor`
  - `VideoCanvasPreset`
  - `VideoCanvasRenderRequest`
  - `VideoCanvasResolvedPreset`
  - `VideoCanvasSnapshot`
  - `VideoCanvasSourceDescriptor`
  - `VideoCanvasTransform`
  - `VideoCropFormatPreset`
  - `VideoCropPreviewLayout`
  - `VideoEditingConfiguration`
- [EditorCropEditingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorCropEditingCoordinatorTests.swift) now exercises package-owned crop-selection APIs directly while keeping the host-specific `shouldApplyPresetTool` coverage on the host wrapper
- [VideoEditingPresentationStateResolverTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/VideoEditingPresentationStateResolverTests.swift) now targets the package-owned resolver directly because the host layer there is a pure forwarding seam

Phase 14 status:

- completed
- the duplicate host copies of `VideoEditingConfiguration`, crop presets, canvas models, transcript models, and `PlaybackTimeMapping` have been removed from `VideoEditor/Core`
- the app shell now reaches the editor only through [VideoEditorView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/API/VideoEditorView.swift)
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation in two batches for:
    - `EditedVideoProjectsStoreTests`
    - `EditorCropEditingCoordinatorTests`
    - `EditorSessionCoordinatorTests`
    - `SocialPlatformSafeAreaTests`
    - `VideoCanvasMappingActorTests`
    - `VideoCropFormatPresetTests`
    - `VideoCropPreviewLayoutTests`
    - `VideoEditingPresentationStateResolverTests`
    - `EditorCropPresentationStateTests`
    - `VideoCanvasPreviewViewTests`
    - `VideoEditingConfigurationTests`
    - `VideoEditorTests`
    - `CoreUtilityCharacterizationTests`
    - `PlaybackTimeMappingTests`
    - `VideoEditingThumbnailRendererTests`
    - `ExporterViewModelTests`
    - `VideoEditorKitPackageSmokeTests`
- one host suite, `VideoEditorSaveEmissionCoordinatorTests`, still exceeds the plugin's runtime window when run in isolation after this change, so the phase closes with successful build coverage plus adjacent suite coverage rather than a clean pass from that single isolated suite

### Phase 15

Goal:
Finish removing the temporary host alias bridge by moving the remaining toolbar and transcription surfaces to direct `VideoEditorKit` imports.

Deliverables:

- move toolbar rule tests to direct package imports
- move transcript overlay, transcript editing, and transcription component consumers to direct package imports
- remove the alias bridge file entirely once no host or test code depends on it

Exit criteria:

- the temporary alias bridge is fully removed from the host app
- host build and targeted simulator tests still pass for the toolbar and transcription slices

Current implementation notes:

- direct `VideoEditorKit` imports now cover the remaining toolbar and transcription consumers, including:
  - [TranscriptOverlayLayoutResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Transcription/TranscriptOverlayLayoutResolver.swift)
  - [TranscriptTextStyleResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Transcription/TranscriptTextStyleResolver.swift)
  - [TranscriptOverlayPreview.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/EditorView/TranscriptOverlayPreview.swift)
  - [TranscriptSegmentEditView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/Transcript/TranscriptSegmentEditView.swift)
  - [TranscriptSegmentRow.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/Transcript/TranscriptSegmentRow.swift)
  - [TranscriptToolView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/Transcript/TranscriptToolView.swift)
  - [OpenAIWhisperTranscriptionComponent.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/OpenAIWhisperTranscriptionComponent.swift)
  - [OpenAIWhisperAPIClient.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/OpenAIWhisperAPIClient.swift)
  - [OpenAIWhisperMultipartFormDataBuilder.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/OpenAIWhisperMultipartFormDataBuilder.swift)
  - [OpenAIWhisperResponseDTO.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/OpenAIWhisperResponseDTO.swift)
  - [OpenAIWhisperResponseMapper.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/OpenAIWhisperResponseMapper.swift)
  - [VideoAudioExtractionService.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/VideoAudioExtractionService.swift)
- direct `VideoEditorKit` imports now cover the remaining toolbar and transcription tests, including:
  - [EditorToolSelectionCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorToolSelectionCoordinatorTests.swift)
  - [EditorToolbarLayoutResolverTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorToolbarLayoutResolverTests.swift)
  - [EditorTranscriptMappingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorTranscriptMappingCoordinatorTests.swift)
  - [EditorTranscriptRemappingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/EditorTranscriptRemappingCoordinatorTests.swift)
  - [TranscriptDocumentTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/TranscriptDocumentTests.swift)
  - [TranscriptOverlayLayoutResolverTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/TranscriptOverlayLayoutResolverTests.swift)
  - [TranscriptTextStyleResolverTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/TranscriptTextStyleResolverTests.swift)
  - [TranscriptTimeMapperTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/TranscriptTimeMapperTests.swift)
  - [TranscriptWordEditingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/Models/TranscriptWordEditingCoordinatorTests.swift)
  - [OpenAIWhisperTranscriptionComponentTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/Transcription/OpenAIWhisperTranscriptionComponentTests.swift)
- the temporary alias seam file at `VideoEditor/AppShell/Integration/VideoEditorKitPackageAliases.swift` was deleted

Phase 15 status:

- completed
- host validation succeeds with:
  - simulator build through [@build-ios-apps](plugin://build-ios-apps@openai-curated) for scheme `VideoEditor`
  - targeted simulator test validation for:
    - `EditorToolSelectionCoordinatorTests`
    - `EditorToolbarLayoutResolverTests`
    - `EditorTranscriptMappingCoordinatorTests`
    - `EditorTranscriptRemappingCoordinatorTests`
    - `TranscriptDocumentTests`
    - `TranscriptOverlayLayoutResolverTests`
    - `TranscriptTextStyleResolverTests`
    - `TranscriptTimeMapperTests`
    - `TranscriptWordEditingCoordinatorTests`
    - `OpenAIWhisperTranscriptionComponentTests`
    - `VideoEditorKitPackageSmokeTests`
- the host no longer relies on the alias bridge at all; direct package imports now cover every migrated slice still in active use by the app and tests

## Testing Strategy

Every extraction step should preserve the current rule that behavior changes require tests in the same cycle.

Recommended validation order:

1. add characterization coverage before moving risky code
2. move the code into the package
3. validate package tests
4. validate the host app still builds

The package and the host app will temporarily need different test scopes:

- package tests for editor logic and package-owned behavior
- app tests for SwiftData, gallery, reopen flow, and host integration

Execution policy:

- use `swift test` inside `Packages/VideoEditorKit` for package-only validation
- use [@build-ios-apps](plugin://build-ios-apps@openai-curated) for any validation that touches the Xcode project, app target, scheme, simulator, or integration smoke tests

## Phase 1 Checklist

- [x] `Packages/VideoEditorKit/` exists
- [x] `Packages/VideoEditorKit/Package.swift` exists
- [x] `Packages/VideoEditorKit/Sources/VideoEditorKit/` exists
- [x] `Packages/VideoEditorKit/Tests/VideoEditorKitTests/` exists
- [x] package contains a minimal entry point
- [x] package contains a minimal Swift Testing test
- [x] document phase 1 completion status in this file

## Current Status

### Phase 1

Status:
started

Artifacts created:

- [Package.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Package.swift)
- [VideoEditorKit.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/VideoEditorKit.swift)
- [VideoEditorKitPackageTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/VideoEditorKitPackageTests.swift)

Notes:

- the plan now assumes an isolated package under `Packages/VideoEditorKit`
- package scaffolding was created as the first implementation step
- the current app remains unchanged until the package skeleton is in place
- the scaffold was validated with `swift test` outside the sandbox because SwiftPM manifest validation hit cache and `sandbox-exec` restrictions in the local environment

### Phase 2

Status:
completed

Artifacts created:

- [VideoEditingConfiguration.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Editing/VideoEditingConfiguration.swift)
- [VideoCropFormatPreset.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Editing/VideoCropFormatPreset.swift)
- [VideoCropPreviewLayout.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Editing/VideoCropPreviewLayout.swift)
- [SocialPlatformSafeArea.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/SafeArea/SocialPlatformSafeArea.swift)
- [VideoCropFormatPresetTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/VideoCropFormatPresetTests.swift)
- [VideoCropPreviewLayoutTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/VideoCropPreviewLayoutTests.swift)
- [SocialPlatformSafeAreaTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/SocialPlatformSafeAreaTests.swift)

Notes:

- the package now contains a real editor-owned feature slice and is no longer only a scaffold
- the extracted slice was validated with `swift test`
- the current app source tree remains unchanged and still acts as the reference implementation while extraction continues

### Phase 3

Status:
in progress

Artifacts created:

- [VideoCanvasPreset.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Canvas/VideoCanvasPreset.swift)
- [VideoCanvasState.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Canvas/VideoCanvasState.swift)
- [VideoCanvasLayout.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Canvas/VideoCanvasLayout.swift)
- [VideoCanvasRenderRequest.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Canvas/VideoCanvasRenderRequest.swift)
- [VideoCanvasMappingActor.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Canvas/VideoCanvasMappingActor.swift)
- [VideoCanvasMappingActorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/VideoCanvasMappingActorTests.swift)

Notes:

- the package now owns a second real editor slice beyond crop and safe-area rules
- package validation now passes with 35 tests
- the package manifest was updated with explicit platform declarations to support the extracted SwiftUI `Angle` dependency used by the canvas mapping layer

### Phase 4

Status:
in progress

Artifacts created:

- local package reference added to [project.pbxproj](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor.xcodeproj/project.pbxproj)
- temporary package smoke import in [VideoEditorKitPackageSmoke.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageSmoke.swift)
- package target rename bridge in [Package.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Package.swift)
- real package-owned configuration model in [VideoEditingConfiguration.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Editing/VideoEditingConfiguration.swift)
- supporting package-owned editing model in [ToolModel.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Editing/ToolModel.swift)
- supporting package-owned transcript model set in [TranscriptModels.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/TranscriptModels.swift)
- package-owned playback utility in [PlaybackTimeMapping.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Playback/PlaybackTimeMapping.swift)
- package-owned transcript time mapper in [TranscriptTimeMapper.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/TranscriptTimeMapper.swift)
- package-owned transcript word coordinator in [TranscriptWordEditingCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/TranscriptWordEditingCoordinator.swift)
- package-owned transcript remapping coordinator in [EditorTranscriptRemappingCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/EditorTranscriptRemappingCoordinator.swift)
- package-owned transcript mapping coordinator in [EditorTranscriptMappingCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/EditorTranscriptMappingCoordinator.swift)
- package-owned transcription contracts in [VideoTranscriptionProvider.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Transcription/VideoTranscriptionProvider.swift)
- package-owned tool selection coordinator in [EditorToolSelectionCoordinator.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Editing/EditorToolSelectionCoordinator.swift)
- package-owned toolbar layout resolver in [EditorToolbarLayoutResolver.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/Editing/EditorToolbarLayoutResolver.swift)
- package validation coverage in [VideoEditingConfigurationTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/VideoEditingConfigurationTests.swift)
- package validation coverage in [TranscriptDocumentTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/TranscriptDocumentTests.swift)
- package validation coverage in [PlaybackTimeMappingTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/PlaybackTimeMappingTests.swift)
- package validation coverage in [TranscriptTimeMapperTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/TranscriptTimeMapperTests.swift)
- package validation coverage in [TranscriptWordEditingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/TranscriptWordEditingCoordinatorTests.swift)
- package validation coverage in [EditorTranscriptRemappingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/EditorTranscriptRemappingCoordinatorTests.swift)
- package validation coverage in [EditorTranscriptMappingCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/EditorTranscriptMappingCoordinatorTests.swift)
- package validation coverage in [EditorToolSelectionCoordinatorTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/EditorToolSelectionCoordinatorTests.swift)
- package validation coverage in [EditorToolbarLayoutResolverTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Tests/VideoEditorKitTests/EditorToolbarLayoutResolverTests.swift)
- host-app integration smoke in [VideoEditorKitPackageSmokeTests.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorTests/AppShell/VideoEditorKitPackageSmokeTests.swift)
- host-app package alias bridge in [VideoEditorKitPackageAliases.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Integration/VideoEditorKitPackageAliases.swift)

Notes:

- the app host now builds with the local package linked into the Xcode project
- the package now exposes a first useful public host-facing surface around `VideoEditingConfiguration`, transcript snapshot models, `ToolEnum`, `VideoCanvasPreset`, `VideoCanvasTransform`, and `VideoCanvasSnapshot`
- the app target no longer compiles local copies of this first extracted source set:
  - `VideoEditingConfiguration`
  - `ToolModel`
  - `TranscriptModels`
  - `PlaybackTimeMapping`
  - `TranscriptTimeMapper`
  - `TranscriptWordEditingCoordinator`
  - `EditorTranscriptRemappingCoordinator`
  - `EditorTranscriptMappingCoordinator`
  - `VideoTranscriptionProvider`
  - `EditorToolSelectionCoordinator`
  - `EditorToolbarLayoutResolver`
  - `VideoCropFormatPreset`
  - `VideoCropPreviewLayout`
  - `SocialPlatformSafeArea`
  - `VideoCanvasPreset`
  - `VideoCanvasState`
  - `VideoCanvasLayout`
  - `VideoCanvasRenderRequest`
  - `VideoCanvasMappingActor`
- the current host cutover uses a temporary alias seam so the app can resolve package-owned types without forcing immediate `import` churn across the whole app source tree
- the host package smoke now validates more than package linkage:
  - package identity
  - current editing schema version
  - access to the package-provided initial editing configuration
- the package continues to pass `swift test` after replacing the placeholder configuration with the real serialized editing graph and transcript models
- the package now also owns the first transcript-time and transcript-remapping rule layer above the raw transcript models
- the package now also owns the first toolbar selection/layout rule layer
- during this extraction, the toolbar layout contract was aligned with the current UI and tests by resolving toolbar item height to `104`
- the host-app simulator build succeeded through [@build-ios-apps](plugin://build-ios-apps@openai-curated)
- targeted iOS test validation now succeeds for:
  - `VideoEditorKitPackageSmokeTests`
  - `AppShellTranscriptionConfigurationTests`
- additional targeted iOS test validation now succeeds for the host-side rule suites that rely on package-owned types:
  - `VideoEditingConfigurationTests`
  - `VideoCropFormatPresetTests`
  - `VideoCropPreviewLayoutTests`
  - `VideoCanvasMappingActorTests`
  - `SocialPlatformSafeAreaTests`
  - `TranscriptDocumentTests`
- additional targeted iOS test validation also succeeds for the second extracted transcript/playback slice:
  - `PlaybackTimeMappingTests`
  - `TranscriptTimeMapperTests`
  - `TranscriptWordEditingCoordinatorTests`
  - `EditorTranscriptRemappingCoordinatorTests`
  - `EditorTranscriptMappingCoordinatorTests`
- targeted iOS test validation now also succeeds for the extracted toolbar rule slice:
  - `EditorToolSelectionCoordinatorTests`
  - `EditorToolbarLayoutResolverTests`
- phase 4 is not complete yet because the host still relies on the temporary alias seam and because deeper editor coordinators, resolvers, and runtime support types still need to be extracted before the app can use the package as the primary owner of the editor feature end-to-end

## Acceptance Criteria

The migration is successful when:

- `Packages/VideoEditorKit` is a working local SPM package
- the current app has become `VideoEditor`
- `VideoEditor` imports `VideoEditorKit`
- app-shell responsibilities stay outside the package
- the package exposes a small editor-centered API
- package and host resources are clearly separated
