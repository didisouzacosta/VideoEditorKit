# Export Watermark Viability Analysis Plan

**Goal:** analisar a viabilidade de adicionar uma logo/imagem como marca d'agua somente no export do `VideoEditorKit`.

**Context:** a marca d'agua deve ser opcional, controlada pelo host, aplicada somente no momento de exportar em qualquer qualidade, incluindo `.original`, posicionada em um dos quatro cantos com padding de 16 pixels, e renderizada exatamente com o tamanho do `UIImage` informado.

**Plugin:** Build iOS Apps deve ser usado nas proximas etapas de analise e implementacao.

---

## Decisions

- A marca d'agua deve ser configuracao runtime do host, nao estado persistido da edicao.
- A API recomendada e `VideoEditorConfiguration`, porque o host pode ligar/desligar a marca d'agua conforme plano do cliente sem alterar `VideoEditingConfiguration`.
- A logo deve usar exatamente o tamanho do `UIImage` informado. O SDK nao deve redimensionar, limitar por percentual, ou adaptar automaticamente ao tamanho do video nesta primeira versao.
- A marca d'agua deve entrar somente em exportacao explicita. Manual save, thumbnails de projeto salvo e estado de preview nao devem incluir a marca d'agua.
- Quando a marca d'agua estiver ativa, `.original` nao pode usar atalhos de video preparado/original sem renderizacao, porque isso pularia a aplicacao da logo.

## Recommended Architecture

Adicionar uma configuracao publica opcional:

```swift
public struct VideoWatermarkConfiguration {
    public let image: UIImage
    public let position: VideoWatermarkPosition
}

public enum VideoWatermarkPosition {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}
```

Adicionar `watermark: VideoWatermarkConfiguration? = nil` a `VideoEditorConfiguration`.

Passar essa configuracao do editor e do export sheet ate o caminho de renderizacao de export. A renderizacao deve aplicar um overlay final com `AVVideoCompositionCoreAnimationTool` sobre o arquivo exportado/intermediario, usando o `renderSize` final do video e frame calculado por:

```swift
let padding: CGFloat = 16
let imageSize = watermark.image.size
```

O frame deve ser:

- `topLeading`: `x = 16`, `y = 16`
- `topTrailing`: `x = renderWidth - imageWidth - 16`, `y = 16`
- `bottomLeading`: `x = 16`, `y = renderHeight - imageHeight - 16`
- `bottomTrailing`: `x = renderWidth - imageWidth - 16`, `y = renderHeight - imageHeight - 16`

## Analysis Tasks

### Task 1: Map Public API Surface

**Status:** done.

**Files reviewed:**

- `Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift`
- `Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift`
- `Sources/VideoEditorKit/Views/Export/VideoExportSheet.swift`
- `Sources/VideoEditorKit/Export/VideoExportSheetRequest.swift`
- `Sources/VideoEditorKit/Editing/VideoEditingConfiguration.swift`

**Findings:**

- `VideoEditorConfiguration` already owns host policy: tools, export qualities, transcription, blocked actions, and duration limit.
- `VideoEditingConfiguration` is persisted/resumable edit state. Adding `UIImage` there would be wrong because it is not `Codable`, would pollute saved projects, and would make Pro/no-Pro host policy look like an edit.
- `VideoEditorView.Configuration` is a typealias to `VideoEditorConfiguration`, so adding `watermark` there naturally exposes the feature to the main editor API.
- `VideoExportSheet` also receives `VideoEditorConfiguration`, so the same host policy can be used for external exports.
- `VideoExportSheetRequest` should probably not own the watermark, unless a future API needs per-request override independent from host configuration.
- The package imports `SwiftUI` in UI-facing files, and `UIImage` is available through SwiftUI on iOS. The implementation should keep following the local rule: use `import SwiftUI`, not direct `import UIKit`.

**Conclusion:** use `VideoEditorConfiguration.watermark` as the source of truth.

### Task 2: Map Export Data Flow

**Status:** pending.

Trace `VideoEditorConfiguration.watermark` from:

- `VideoEditorView.exportSheetContent`
- `VideoExportSheet.body`
- `VideoExporterContainerView`
- `ExporterViewModel`
- `VideoEditor.startRender`

Expected result: identify the smallest signature changes needed to pass optional watermark configuration only into export render calls.

### Task 3: Analyze `.original` Export Shortcuts

**Status:** pending.

Review:

- `VideoExportSheetPreparationResolver.preparationResult`
- `VideoEditorView.prepareCurrentExport`
- prepared original export reuse through `preparedOriginalExportVideo`
- initial source reuse for unedited `.original`

Expected result: define the condition that disables shortcut reuse when `watermark != nil`.

### Task 4: Analyze Render Integration Point

**Status:** pending.

Compare two implementation paths:

- Add a final watermark render stage after transcript/adjust/canvas stages.
- Merge watermark into the existing base animation tool when possible.

Expected result: choose the safest initial implementation. Current recommendation is a final stage because it guarantees the watermark is over the final output regardless of canvas, frame, crop, transcript, or quality.

### Task 5: Define Geometry Helper

**Status:** pending.

Design a pure helper that calculates the watermark frame from:

- render size
- image size
- corner position
- fixed padding of 16

Expected result: helper can be tested without rendering video.

### Task 6: Define Test Plan

**Status:** pending.

Add focused Swift Testing coverage for:

- `VideoEditorConfiguration` stores optional watermark.
- disabling watermark by passing `nil`.
- `.original` export shortcuts render instead of reusing prepared/original video when watermark exists.
- all four corner frames use padding 16.
- logo size equals `UIImage.size`.
- manual save path does not receive watermark.

### Task 7: Define Documentation Updates

**Status:** pending.

Update:

- `README.md`
- `Docs/FEATURES.md`
- `Docs/ARCHITECTURE.md`

Expected result: docs explicitly say watermark is export-only and does not affect manual save or preview.

## Risks

- Large `UIImage` values may exceed the video bounds. Because the current requirement says exact image size, the first implementation should not resize it. The frame helper should still clamp origin enough to keep calculations finite, but not mutate `image.size`.
- A final render stage adds another export pass. This is safer but may increase export time.
- Existing `.original` fast paths must be bypassed with watermark active.
- `UIImage` is not `Sendable`, so render signatures may need a small internal wrapper or main-actor extraction to `CGImage`/size before crossing async boundaries.

## Validation Commands

Format first:

```bash
scripts/format-swift.sh
```

Preferred full validation:

```bash
scripts/test-ios.sh
```

Targeted package validation:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```
