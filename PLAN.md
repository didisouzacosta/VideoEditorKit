# VideoEditorKit — Plano Técnico Consolidado

## Visão geral

`VideoEditorKit` será uma biblioteca modular para iOS, construída com SwiftUI + Swift 6, com foco em edição de vídeo no estilo do editor nativo da Apple.

A biblioteca deve:

- seguir o design visual e o fluxo do editor atual da Apple
- oferecer preview WYSIWYG
- suportar legendas estilizadas
- permitir posicionamento livre ou por presets
- exportar para `Original`, `Instagram`, `YouTube` e `TikTok`
- tratar restrições de duração por preset já no preview, scrub e export
- desacoplar totalmente IA da geração e tradução de legendas
- operar com edição não destrutiva
- permitir persistência via snapshot
- expor erros públicos consistentes
- ser validada apenas com testes unitários
- aplicar TDD no início de cada fase do roadmap
- sempre usar `@Observable` para estado observável da biblioteca
- exigir o uso combinado das skills `swiftui-pro` e `swiftui-expert-skill` durante a implementação

---

# 1. Objetivo do produto

Criar uma biblioteca reutilizável que possa ser integrada em múltiplos apps, oferecendo:

- preview em tempo real
- timeline com scrub
- escolha de preset de exportação
- legendas com estilo customizável
- integração externa para geração e tradução de legendas
- export consistente com o preview

A biblioteca não deve depender de um provider específico de IA e não deve implementar transcrição internamente.

---

# 2. Princípios arquiteturais

## 2.1 Preview = Export

Toda decisão visual e temporal deve ser compartilhada entre preview e export.

Isso inclui:

- aspect ratio
- crop
- fit/fill
- duração válida
- posição da legenda
- safe area de legenda

## 2.2 Edição não destrutiva

O vídeo original nunca é modificado.

Preset, range, crop, posição, estilo e legendas são apenas instruções de edição. O export gera um novo arquivo.

## 2.3 IA desacoplada

O editor não transcreve, não traduz e não conhece provider de IA.

Ele apenas expõe eventos assíncronos para que o app host forneça legendas.

## 2.4 Coordenadas normalizadas

Toda legenda usa posição normalizada no frame final renderizado do vídeo, no intervalo `0...1`.

## 2.5 Layout centralizado

`LayoutEngine` é a única fonte de verdade para:

- rotação
- escala
- crop
- frame final
- render size

## 2.6 Tempo centralizado

`PlayerEngine` é a fonte de verdade do tempo atual.

Timeline, scrub, overlays e export dependem dessa lógica.

## 2.7 Preset controla resolução e duração

Cada preset define:

- resolução de render
- aspect ratio
- safe area
- duração mínima
- duração máxima
- comportamento do scrub
- validação de export

## 2.8 UI fina, lógica nas engines

As views devem ser leves. Regras de negócio e cálculos devem ficar em engines e modelos testáveis.

## 2.9 Sempre usar @Observable

Todo estado observável da biblioteca deve usar `@Observable`.

Regras:

- não usar `ObservableObject` como padrão da arquitetura
- não depender de `@Published` para estado central da lib
- models de runtime e controllers observáveis devem seguir a abordagem do framework Observation
- views SwiftUI devem observar o estado via os mecanismos compatíveis com `@Observable`

Objetivo:

- alinhar a biblioteca com a arquitetura moderna da Apple
- reduzir boilerplate
- melhorar consistência entre estado e UI
- simplificar manutenção em Swift 6

## 2.10 Uso obrigatório das skills swiftui-pro e swiftui-expert-skill

Toda implementação do `VideoEditorKit` deve usar obrigatoriamente as skills `swiftui-pro` e `swiftui-expert-skill` como referência técnica de desenvolvimento.

Objetivos:

- alinhar a implementação com padrões modernos de desenvolvimento iOS
- reforçar consistência com SwiftUI e Apple HIG
- melhorar decisões de safe area, navegação, acessibilidade, Dynamic Type e Dark Mode
- padronizar a qualidade técnica do projeto durante o desenvolvimento
- combinar revisão de qualidade com orientação prática de implementação em SwiftUI moderno

Regras obrigatórias:

- nenhuma fase de implementação deve começar sem ambas as skills estarem instaladas e disponíveis no ambiente
- decisões de UI e UX devem ser validadas à luz das duas skills
- componentes SwiftUI devem seguir as recomendações convergentes das duas skills, priorizando APIs modernas e comportamento nativo
- qualquer desvio relevante da orientação das skills deve ser documentado no projeto

As skills devem ser tratadas como referência obrigatória especialmente em:

- SwiftUI
- safe areas
- acessibilidade
- Dark Mode
- padrões nativos Apple
- consistência de interface
- estado observável com `@Observable`
- concorrência moderna em Swift
- performance e composição de views

---

# 3. Escopo do MVP

## 3.1 Incluído

- preview WYSIWYG
- presets de exportação
- timeline com scrub
- selected time range
- legendas com:
  - texto
  - cor
  - background
  - fonte
  - tamanho
  - padding
  - corner radius
- posicionamento:
  - livre
  - top
  - middle
  - bottom
- integração async para captions
- export com crop e layout consistente
- persistência via snapshot
- validação e erros públicos

## 3.2 Fora do MVP

- animações de legenda
- filtros de vídeo
- templates avançados
- undo/redo completo
- testes de interface
- transcrição embutida
- tradução embutida
- export concorrente por instância
- edição multilayer complexa estilo CapCut

---

# 4. Estrutura da biblioteca

    VideoEditorKit
     ├── Core
     │    ├── PlayerEngine
     │    ├── TimeRangeEngine
     │    ├── LayoutEngine
     │    ├── CaptionEngine
     │    ├── CaptionMergeEngine
     │    ├── CaptionPositionResolver
     │    ├── CaptionSafeFrameResolver
     │    ├── SnapshotCoder
     │    ├── ProjectValidator
     │    └── ExportEngine
     │
     ├── Models
     │    ├── VideoProject
     │    ├── EditorState
     │    ├── Caption
     │    ├── CaptionStyle
     │    ├── CaptionPlacementMode
     │    ├── CaptionPlacementPreset
     │    ├── CaptionSafeArea
     │    ├── ExportPreset
     │    ├── ExportConfiguration
     │    ├── CaptionRequestContext
     │    ├── CaptionAction
     │    ├── CaptionApplyStrategy
     │    ├── CaptionState
     │    ├── TimeRangeResult
     │    ├── ValidationResult
     │    ├── ExportState
     │    └── VideoEditorError
     │
     ├── Persistence
     │    ├── VideoProjectSnapshot
     │    ├── CaptionSnapshot
     │    ├── CaptionStyleSnapshot
     │    ├── CaptionPositionSnapshot
     │    ├── ExportPresetSnapshot
     │    └── VideoGravitySnapshot
     │
     ├── UI
     │    ├── VideoEditorView
     │    ├── PresetToolbarView
     │    ├── TimelineView
     │    ├── TimelineRangeSelectorView
     │    ├── CaptionOverlayView
     │    └── CaptionActionButtonView
     │
     └── Public API
          ├── VideoEditorView
          ├── VideoEditorConfig
          ├── VideoEditorController
          └── VideoProjectSnapshotCoding

---

# 5. Design e UX

## 5.1 Referência visual

A UX deve seguir o editor atual da Apple:

- preview central em destaque
- ambiente minimalista
- dark mode como padrão visual
- toolbar simples
- timeline horizontal inferior
- seletor de range com janela destacada sobre thumbnails
- feedback imediato ao alterar preset
- ícones SF Symbols quando necessário
- microanimações suaves e discretas

## 5.2 Toolbar

A toolbar deve conter apenas os presets:

- Original
- Instagram
- YouTube
- TikTok

Trocar preset deve atualizar imediatamente:

- layout
- safe area
- duração válida
- scrub
- selected time range
- legendas visíveis e exportáveis

## 5.3 Timeline range selector

O componente principal da timeline deve seguir o comportamento visual do seletor de range mostrado na referência:

- a faixa horizontal mostra thumbnails do vídeo inteiro
- existe uma janela de seleção destacada representando o `selectedTimeRange`
- a área fora da seleção continua visível, porém escurecida
- a seleção possui duas alças laterais independentes para ajustar início e fim
- o playhead/scrub é um elemento separado visualmente da seleção
- a timeline deve exibir os tempos de início e fim do range selecionado

Regras obrigatórias:

- a timeline pode mostrar o vídeo inteiro, mesmo quando apenas parte dele é editável
- `selectedTimeRange` é a fonte de verdade da janela destacada
- `currentTime` é independente da janela, mas toda navegação deve ser clampada ao `selectedTimeRange`
- trocar preset deve reduzir a seleção quando necessário, sem expandi-la automaticamente ao voltar para `original`
- arrastar a alça esquerda altera apenas o `lowerBound`
- arrastar a alça direita altera apenas o `upperBound`
- o trecho fora do range continua legível para contexto, mas não interativo quando estiver fora do `validRange`

## 5.4 Posição da legenda

O usuário deve poder escolher entre:

- posição livre por drag
- preset `top`
- preset `middle`
- preset `bottom`

Ao arrastar uma legenda que está em preset, o editor deve convertê-la automaticamente para `.freeform`.

---

# 6. Modelos principais

## 6.1 VideoProject

    public struct VideoProject {
        public let sourceVideoURL: URL
        public var captions: [Caption]
        public var preset: ExportPreset
        public var gravity: VideoGravity
        public var selectedTimeRange: ClosedRange<Double>
    }

### Regras

- `sourceVideoURL` é imutável durante a sessão
- o projeto representa instruções de edição, não mídia alterada
- `selectedTimeRange` deve sempre caber no range válido do preset atual

## 6.2 EditorState

    @Observable
    public final class EditorState {
        public var currentTime: Double = 0
        public var isPlaying: Bool = false
        public var selectedCaptionID: UUID?
        public var captionState: CaptionState = .idle
        public var exportState: ExportState = .idle

        public init() {}
    }

## 6.3 Caption

    public struct Caption: Identifiable, Equatable {
        public let id: UUID
        public var text: String
        public var startTime: Double
        public var endTime: Double
        public var position: CGPoint
        public var placementMode: CaptionPlacementMode
        public var style: CaptionStyle
    }

### Regras

- `startTime < endTime`
- `position` é normalizada no frame final
- legenda deve ser sanitizada para o `selectedTimeRange`
- se for inválida após sanitização, deve ser removida

## 6.4 CaptionStyle

    public struct CaptionStyle: Equatable {
        public var fontName: String
        public var fontSize: CGFloat
        public var textColor: UIColor
        public var backgroundColor: UIColor?
        public var padding: CGFloat
        public var cornerRadius: CGFloat
    }

    public extension CaptionStyle {
        func resolvedFont() -> UIFont {
            UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        }
    }

## 6.5 CaptionPlacementMode

    public enum CaptionPlacementMode: Equatable {
        case freeform
        case preset(CaptionPlacementPreset)
    }

## 6.6 CaptionPlacementPreset

    public enum CaptionPlacementPreset: Equatable, CaseIterable {
        case top
        case middle
        case bottom
    }

## 6.7 CaptionSafeArea

    public struct CaptionSafeArea: Equatable {
        public let topInset: CGFloat
        public let leftInset: CGFloat
        public let bottomInset: CGFloat
        public let rightInset: CGFloat
    }

## 6.8 VideoGravity

    public enum VideoGravity {
        case fit
        case fill
    }

## 6.9 ExportPreset

    public enum ExportPreset: CaseIterable {
        case original
        case instagram
        case youtube
        case tiktok
    }

    public extension ExportPreset {
        var title: String {
            switch self {
            case .original: return "Original"
            case .instagram: return "Instagram"
            case .youtube: return "YouTube"
            case .tiktok: return "TikTok"
            }
        }

        var minDuration: Double {
            switch self {
            case .original: return 0
            case .instagram: return 3
            case .youtube: return 1
            case .tiktok: return 3
            }
        }

        var maxDuration: Double {
            switch self {
            case .original: return .infinity
            case .instagram: return 90
            case .youtube: return 60
            case .tiktok: return 180
            }
        }

        var durationRange: ClosedRange<Double> {
            minDuration...maxDuration
        }

        func resolve(videoSize: CGSize) -> CGSize {
            switch self {
            case .original:
                return videoSize
            case .instagram, .youtube, .tiktok:
                return CGSize(width: 1080, height: 1920)
            }
        }

        var aspectRatio: CGFloat? {
            switch self {
            case .original:
                return nil
            case .instagram, .youtube, .tiktok:
                return 9.0 / 16.0
            }
        }

        var captionSafeArea: CaptionSafeArea {
            switch self {
            case .original:
                return CaptionSafeArea(
                    topInset: 24,
                    leftInset: 24,
                    bottomInset: 24,
                    rightInset: 24
                )
            case .instagram:
                return CaptionSafeArea(
                    topInset: 120,
                    leftInset: 32,
                    bottomInset: 260,
                    rightInset: 32
                )
            case .youtube:
                return CaptionSafeArea(
                    topInset: 100,
                    leftInset: 32,
                    bottomInset: 220,
                    rightInset: 32
                )
            case .tiktok:
                return CaptionSafeArea(
                    topInset: 100,
                    leftInset: 32,
                    bottomInset: 300,
                    rightInset: 80
                )
            }
        }
    }

## 6.10 ExportConfiguration

    public struct ExportConfiguration {
        public var fps: Int = 30
        public var bitrate: Int = 5_000_000
    }

## 6.11 CaptionRequestContext

    public struct CaptionRequestContext {
        public let videoURL: URL
        public let duration: Double
        public let selectedTimeRange: ClosedRange<Double>
    }

## 6.12 CaptionAction

    public enum CaptionAction {
        case generate
        case translate
    }

## 6.13 CaptionApplyStrategy

    public enum CaptionApplyStrategy: Equatable {
        case replaceAll
        case append
        case replaceIntersecting
    }

### Regras

#### replaceAll

- remove todas as legendas atuais
- aplica apenas as novas
- limpa seleção se a legenda selecionada deixar de existir

#### append

- mantém as legendas atuais
- adiciona as novas após sanitização

#### replaceIntersecting

- remove legendas atuais que intersectam temporalmente com as novas
- preserva as demais
- aplica as novas

## 6.14 CaptionState

    public enum CaptionState: Equatable {
        case idle
        case loading
        case failed(message: String)
    }

## 6.15 TimeRangeResult

    public struct TimeRangeResult {
        public let validRange: ClosedRange<Double>
        public let selectedRange: ClosedRange<Double>
        public let isVideoTooShort: Bool
        public let exceedsMaximum: Bool
    }

## 6.16 ValidationResult

    public struct ValidationResult {
        public let canExport: Bool
        public let warnings: [String]
        public let errors: [String]
    }

## 6.17 Public error model

    public enum VideoEditorError: Error, Equatable {
        case invalidAsset
        case invalidVideoDuration
        case invalidTimeRange
        case videoTooShortForPreset(minimum: Double, preset: String)
        case exportAlreadyInProgress
        case exportFailed(reason: String)
        case captionGenerationInProgress
        case captionProviderUnavailable
        case captionProviderFailed(reason: String)
        case snapshotEncodingFailed
        case snapshotDecodingFailed
    }

## 6.18 ExportState

    public enum ExportState: Equatable {
        case idle
        case exporting(progress: Double)
        case completed(URL)
        case failed(VideoEditorError)
    }

---

# 7. Persistência e snapshot

## 7.1 Objetivo

Permitir que o app host salve e recarregue um projeto sem depender de estado de runtime.

## 7.2 Snapshot persistente

    public struct VideoProjectSnapshot: Codable, Equatable {
        public var sourceVideoPath: String
        public var captions: [CaptionSnapshot]
        public var preset: ExportPresetSnapshot
        public var gravity: VideoGravitySnapshot
        public var selectedTimeRange: ClosedRange<Double>
    }

    public struct CaptionSnapshot: Codable, Equatable {
        public var id: UUID
        public var text: String
        public var startTime: Double
        public var endTime: Double
        public var position: CaptionPositionSnapshot
        public var style: CaptionStyleSnapshot
    }

    public struct CaptionPositionSnapshot: Codable, Equatable {
        public var mode: CaptionPlacementModeSnapshot
        public var normalizedX: Double
        public var normalizedY: Double
    }

    public struct CaptionStyleSnapshot: Codable, Equatable {
        public var fontName: String
        public var fontSize: Double
        public var textColorHex: String
        public var backgroundColorHex: String?
        public var padding: Double
        public var cornerRadius: Double
    }

## 7.3 Regras de persistência

- snapshot não deve depender diretamente de `UIColor`, `UIFont`, `CGPoint` ou `URL`
- toda conversão snapshot → runtime deve passar por validação
- toda conversão runtime → snapshot deve preservar apenas dados persistíveis
- snapshot inválido deve lançar `VideoEditorError.snapshotDecodingFailed`

## 7.4 API pública de snapshot

    public protocol VideoProjectSnapshotCoding {
        func makeSnapshot(from project: VideoProject) throws -> VideoProjectSnapshot
        func makeProject(from snapshot: VideoProjectSnapshot) throws -> VideoProject
    }

---

# 8. API pública

## 8.1 VideoEditorConfig

    public struct VideoEditorConfig {
        public var onCaptionAction: ((CaptionAction, CaptionRequestContext) async throws -> [Caption])?
        public var captionApplyStrategy: CaptionApplyStrategy
        public var onExportProgress: ((Double) -> Void)?

        public init(
            onCaptionAction: ((CaptionAction, CaptionRequestContext) async throws -> [Caption])? = nil,
            captionApplyStrategy: CaptionApplyStrategy = .replaceAll,
            onExportProgress: ((Double) -> Void)? = nil
        ) {
            self.onCaptionAction = onCaptionAction
            self.captionApplyStrategy = captionApplyStrategy
            self.onExportProgress = onExportProgress
        }
    }

## 8.2 VideoEditorView

    public struct VideoEditorView: View {
        @Binding var project: VideoProject

        public init(
            project: Binding<VideoProject>,
            config: VideoEditorConfig = .init()
        )
    }

## 8.3 VideoEditorController

Pode ser exposto como camada de controle programático para export e integração não visual.

Sugestão de modelagem:

    @Observable
    public final class VideoEditorController {
        public var editorState: EditorState
        public var project: VideoProject

        public init(project: VideoProject, editorState: EditorState = .init()) {
            self.project = project
            self.editorState = editorState
        }
    }

---

# 9. Engines centrais

## 9.1 PlayerEngine

### Responsabilidades

- carregar asset
- expor duração
- expor current time
- controlar play, pause e seek
- ser a fonte de verdade do tempo
- publicar estado suficiente para timeline e range selector
- reagir a mudanças de `selectedTimeRange` sem deixar `currentTime` inválido

    @MainActor
    @Observable
    final class PlayerEngine {
        var currentTime: Double = 0
        var duration: Double = 0
        var isPlaying: Bool = false
    }

### Regras

- `currentTime` sempre deve ser clampado no `selectedTimeRange`
- toda UI temporal depende do tempo do player
- `PlayerEngine` não decide o range; ele consome `selectedTimeRange` já resolvido
- o player é a única fonte de verdade do playhead
- timeline e preview apenas refletem o estado publicado pelo player

### Contrato técnico com timeline

`TimelineView` e `TimelineRangeSelectorView` devem consumir do `PlayerEngine` pelo menos:

- `currentTime`
- `duration`
- `isPlaying`

E devem consumir de `TimeRangeEngine`/estado do projeto:

- `validRange`
- `selectedTimeRange`

Operações esperadas do `PlayerEngine`:

    @MainActor
    @Observable
    final class PlayerEngine {
        var currentTime: Double
        var duration: Double
        var isPlaying: Bool

        func load(asset: AVAsset) async throws
        func play()
        func pause()
        func seek(to time: Double, in selectedTimeRange: ClosedRange<Double>)
        func handleSelectedTimeRangeChange(_ selectedTimeRange: ClosedRange<Double>)
    }

Regras obrigatórias da integração:

- `seek(to:in:)` sempre faz clamp no `selectedTimeRange`
- ao mudar `selectedTimeRange`, `handleSelectedTimeRangeChange` deve clampar `currentTime`
- `play()` nunca avança `currentTime` para fora do `selectedTimeRange`
- se playback atingir `selectedTimeRange.upperBound`, deve pausar ou estacionar no fim do range

### Contrato do range selector com PlayerEngine

O `TimelineRangeSelectorView`:

- nunca altera `currentTime` diretamente
- altera apenas `selectedTimeRange`
- pode solicitar clamp do playhead indiretamente após mudança de range

O `TimelineView`:

- desenha o playhead com base em `player.currentTime`
- desenha a janela de seleção com base em `selectedTimeRange`
- desenha regiões escurecidas com base em `validRange`

Separação obrigatória:

- `selectedTimeRange` representa a janela destacada
- `currentTime` representa a posição do playhead
- mover o playhead não altera o range
- mover as alças do range não deve redefinir o playhead, exceto quando o clamp for necessário

## 9.2 TimeRangeEngine

### Responsabilidades

- calcular faixa válida do preset
- ajustar selected time range
- resolver clamp para scrub
- refletir duração mínima e máxima

### Interface

    struct TimeRangeEngine {
        static func resolve(
            videoDuration: Double,
            currentSelection: ClosedRange<Double>,
            preset: ExportPreset
        ) -> TimeRangeResult

        static func clampTime(
            _ time: Double,
            to selectedRange: ClosedRange<Double>
        ) -> Double
    }

### Regras

- `original` usa duração completa
- presets sociais limitam máximo
- vídeo curto demais mantém preview funcional, mas bloqueia export
- scrub só navega dentro do `selectedTimeRange`

## 9.3 LayoutEngine

### Responsabilidades

- aplicar orientação real via metadata
- calcular fit e fill
- resolver crop
- unificar preview e export

### Resultado

    struct LayoutResult {
        let videoFrame: CGRect
        let renderSize: CGSize
        let transform: CGAffineTransform
    }

### Interface

    func computeLayout(
        videoSize: CGSize,
        containerSize: CGSize,
        preset: ExportPreset,
        gravity: VideoGravity
    ) -> LayoutResult

## 9.4 CaptionSafeFrameResolver

### Responsabilidades

Resolver o frame seguro para legendas com base em:

- render size
- safe area do preset

### Interface

    struct CaptionSafeFrameResolver {
        static func resolve(
            renderSize: CGSize,
            safeArea: CaptionSafeArea
        ) -> CGRect
    }

## 9.5 CaptionPositionResolver

### Responsabilidades

- resolver posição efetiva da legenda
- converter preset `top`, `middle`, `bottom` em ponto real
- clampar freeform ao safe frame

### Interface

    struct CaptionPositionResolver {
        static func resolve(
            caption: Caption,
            renderSize: CGSize,
            safeFrame: CGRect
        ) -> CGPoint

        static func presetPoint(
            _ preset: CaptionPlacementPreset,
            in safeFrame: CGRect
        ) -> CGPoint

        static func normalizedPosition(
            for point: CGPoint,
            in renderSize: CGSize
        ) -> CGPoint
    }

### Regras

- `top`, `middle`, `bottom` usam alinhamento horizontal central
- `freeform` mantém posição normalizada
- `resolve` converte posição normalizada em ponto absoluto usando `renderSize`
- o centro da legenda deve ficar dentro do safe frame
- iniciar drag em legenda preset converte para `.freeform`

## 9.6 CaptionEngine

### Responsabilidades

- filtrar legendas ativas
- normalizar legendas ao trocar preset ou range
- remover legendas inválidas
- sanitizar dados recebidos externamente

### Interface

    struct CaptionEngine {
        static func activeCaptions(
            from captions: [Caption],
            at time: Double,
            in selectedRange: ClosedRange<Double>
        ) -> [Caption]

        static func normalizeCaptions(
            _ captions: [Caption],
            to selectedRange: ClosedRange<Double>
        ) -> [Caption]
    }

### Regras de normalização

Para cada legenda:

- se `text` for vazio ou só espaços, remover
- se `endTime <= selectedRange.lowerBound`, remover
- se `startTime >= selectedRange.upperBound`, remover
- se intersecta parcialmente:
  - `startTime = max(startTime, selectedRange.lowerBound)`
  - `endTime = min(endTime, selectedRange.upperBound)`
- se após clamp `startTime >= endTime`, remover

## 9.7 CaptionMergeEngine

### Responsabilidades

Aplicar novas legendas ao projeto segundo a estratégia escolhida.

### Interface

    struct CaptionMergeEngine {
        static func apply(
            incoming: [Caption],
            to existing: [Caption],
            strategy: CaptionApplyStrategy
        ) -> [Caption]
    }

### Ordem correta

Sempre:

1. receber legendas externas
2. sanitizar pelo selected time range
3. aplicar estratégia
4. normalizar resultado final
5. atualizar seleção

## 9.8 ProjectValidator

### Responsabilidades

- validar projeto antes de export
- produzir erros e warnings centralizados

### Interface

    func validateProject(
        project: VideoProject,
        videoDuration: Double,
        timeRange: TimeRangeResult
    ) -> ValidationResult

## 9.9 ExportEngine

### Responsabilidades

- montar composição
- aplicar layout
- aplicar selected time range
- renderizar legendas válidas
- exportar novo arquivo
- publicar progresso
- impedir export concorrente por instância

### Pipeline

1. carregar asset
2. validar asset e duração
3. resolver layout
4. resolver faixa temporal
5. congelar snapshot do projeto
6. sanitizar captions
7. criar composição
8. aplicar transform
9. criar layers de legenda
10. exportar

### Regra de snapshot

No início do export, congelar:

- preset
- gravity
- selectedTimeRange
- captions sanitizadas
- config de export

Mudanças posteriores afetam apenas o próximo export.

---

# 10. Preview, scrub e timeline

## 10.1 Preview

O preview deve refletir exatamente:

- preset atual
- crop atual
- safe area atual
- selected time range
- legendas ativas e válidas

## 10.2 Scrub

Scrub é o arraste contínuo na timeline para navegar no vídeo.

## 10.3 Regras da timeline

A timeline pode representar o vídeo inteiro visualmente, mas apenas a faixa válida e editável é interativa.

Exemplo:

- trecho válido: normal
- trecho inválido ou excedente: escurecido

O componente visual da timeline deve ter:

- strip contínuo de thumbnails do vídeo inteiro
- janela de seleção destacada para o `selectedTimeRange`
- alça esquerda para ajustar início
- alça direita para ajustar fim
- labels de tempo do range selecionado
- playhead independente da janela de seleção

Regras adicionais:

- o range selecionado continua visível mesmo enquanto o usuário move o playhead
- o playhead pode se mover dentro da janela sem alterar o range
- arrastar as alças não move o playhead automaticamente, salvo necessidade de clamp
- o trecho fora da seleção deve fornecer contexto visual, sem parecer removido da timeline

## 10.4 Clamp obrigatório

Toda tentativa de seek por scrub deve ser clampada ao `selectedTimeRange`.

Isso inclui:

- drag do playhead na timeline
- taps na faixa de thumbnails
- seeks programáticos acionados pela UI
- continuação do playback após troca de preset ou mudança de range

## 10.5 Selected time range

`selectedTimeRange` representa o intervalo realmente editável e exportável no preset atual.

### Regras

- deve caber em `validRange`
- ao trocar preset, pode ser reduzido
- ao voltar para `original`, não deve expandir automaticamente; preserva a intenção do usuário
- representa exatamente a janela destacada no seletor de range
- deve ser ajustado por duas alças independentes na timeline
- deve continuar visível em contraste com o restante do strip de thumbnails

---

# 11. Fluxos principais

## 11.1 Troca de preset

Ao trocar preset:

1. recalcular `TimeRangeResult`
2. atualizar `project.preset`
3. ajustar `project.selectedTimeRange`
4. clampar `editorState.currentTime`
5. normalizar legendas
6. recalcular layout
7. atualizar preview imediatamente

## 11.2 Recebimento de captions externas

Fluxo:

1. usuário toca em ação
2. editor chama callback async externo
3. recebe `[Caption]`
4. sanitiza
5. aplica `CaptionApplyStrategy`
6. normaliza resultado
7. atualiza `project.captions`
8. valida seleção ativa

## 11.3 Drag de legenda

Fluxo:

1. localizar legenda
2. converter `placementMode` para `.freeform`
3. atualizar posição normalizada
4. clampar ao safe frame

## 11.4 Export

Fluxo:

1. validar estado
2. impedir export concorrente
3. congelar snapshot
4. exportar com progresso
5. publicar `ExportState`

## 11.5 Regra de processo com as skills swiftui-pro e swiftui-expert-skill

Antes de iniciar qualquer fase:

1. garantir que as skills `swiftui-pro` e `swiftui-expert-skill` estejam instaladas
2. revisar a fase à luz das recomendações combinadas das skills
3. implementar mantendo aderência a padrões iOS nativos
4. documentar qualquer exceção arquitetural relevante

---

# 12. Regras de posicionamento da legenda

## 12.1 Modo livre

- arraste permitido
- posição persistida em coordenadas normalizadas
- centro da legenda deve permanecer dentro do safe frame

## 12.2 Modo top

- posição calculada automaticamente no topo da safe area
- centralizada horizontalmente

## 12.3 Modo middle

- posição calculada automaticamente no centro vertical da safe area
- centralizada horizontalmente

## 12.4 Modo bottom

- posição calculada automaticamente próximo à base da safe area
- centralizada horizontalmente

## 12.5 Regra de conversão no drag

Ao iniciar drag em uma legenda com preset, o SDK deve convertê-la automaticamente para `.freeform`.

---

# 13. Edge cases e solução

## 13.1 Vídeo menor que o mínimo do preset

Exemplo:

- vídeo 2s
- Instagram exige 3s

### Solução

- preview continua funcional
- scrub funciona no vídeo real
- export fica bloqueado
- erro público: `videoTooShortForPreset`

## 13.2 Vídeo maior que o máximo do preset

Exemplo:

- vídeo 240s
- YouTube limitado a 60s

### Solução

- `validRange = 0...60`
- timeline mostra excedente escurecido
- timeline mantém o vídeo inteiro visível para contexto
- seletor de range destaca apenas o trecho exportável/editável
- scrub fora do range é bloqueado
- export usa apenas o range permitido

## 13.3 currentTime fora do novo range após trocar preset

### Solução

Clamp para o ponto válido mais próximo.

## 13.4 Legenda totalmente fora do range

### Solução

Remover.

## 13.5 Legenda parcialmente fora do range

### Solução

Truncar.

## 13.6 Legenda inválida após truncamento

### Solução

Remover se `startTime >= endTime`.

## 13.7 Texto vazio

### Solução

Remover antes de render e export.

## 13.8 Fonte inexistente

### Solução

Fallback para `systemFont`.

## 13.9 Resultado externo com tempos negativos

### Solução

Clamp e revalidação.

## 13.10 Export durante caption loading

### Solução

Bloquear com erro controlado.

## 13.11 Preset alterado durante export

### Solução

O export usa snapshot congelado.

## 13.12 Scrub durante export

### Solução

Permitido. O preview é independente do export.

## 13.13 Legenda selecionada deixa de existir

### Solução

`selectedCaptionID = nil`.

## 13.14 Snapshot inválido

### Solução

Falha com `snapshotDecodingFailed`.

---

# 14. Concorrência e thread safety

## Regras

- UI e estado de edição no `MainActor`
- callbacks que impactam UI devem voltar ao `MainActor`
- export pode executar fora da main thread
- apenas um export por vez por instância
- tipos observáveis devem usar `@Observable`

## Consequências

- reduz risco de corrida entre scrub, troca de preset e atualização de captions
- torna a API previsível em Swift 6
- padroniza observação de estado em toda a biblioteca

---

# 15. Validação central

Criar um validador único:

    func validateProject(
        project: VideoProject,
        videoDuration: Double,
        timeRange: TimeRangeResult
    ) -> ValidationResult

## Bloqueiam export

- asset inválido
- duração inválida
- vídeo curto demais para o preset
- selected time range inválido
- export já em andamento

## Warning, mas exportam

- vídeo será truncado pelo preset
- legendas foram truncadas
- fonte inexistente com fallback

---

# 16. Estratégia de testes

## Regra geral

Não deve haver nenhum teste de interface.

A estratégia de qualidade será composta apenas por testes unitários e deverá seguir TDD.

## Regra principal

Cada etapa de implementação deve começar pelos testes unitários da engine ou componente correspondente.

Fluxo obrigatório por etapa:

1. escrever os testes unitários
2. executar os testes e validar falha inicial
3. implementar o código mínimo para passar
4. refatorar preservando os testes verdes

## Objetivo

Garantir que:

- regras de negócio sejam definidas antes da implementação
- edge cases sejam cobertos desde o início
- o SDK evolua com segurança
- regressões sejam detectadas cedo

## 16.1 Testes unitários obrigatórios por componente

### TimeRangeEngine

Validar:

- range em `.original`
- range em presets sociais
- clamp de tempo
- vídeo curto demais
- vídeo maior que o máximo
- troca de preset com seleção inválida

### CaptionEngine.normalizeCaptions

Validar:

- legenda totalmente válida
- legenda parcialmente fora do range
- legenda totalmente fora do range
- legenda com texto vazio
- legenda inválida após truncamento

### CaptionMergeEngine

Validar:

- `replaceAll`
- `append`
- `replaceIntersecting`

### CaptionPositionResolver

Validar:

- cálculo de `top`
- cálculo de `middle`
- cálculo de `bottom`
- `freeform` dentro do safe frame
- clamp de posição fora do frame seguro
- drag convertendo preset em `.freeform`

### CaptionSafeFrameResolver

Validar:

- cálculo correto do frame seguro por preset
- comportamento em `original`
- comportamento em presets sociais

### LayoutEngine

Validar:

- fit
- fill
- orientação real por metadata
- aspect ratio original
- aspect ratio social

### SnapshotCoder e persistência

Validar:

- runtime → snapshot
- snapshot → runtime
- preservação de:
  - preset
  - selectedTimeRange
  - style
  - position
  - placement mode
- snapshot inválido gerando erro correto

### ProjectValidator

Validar:

- vídeo curto demais
- selected range inválido
- asset inválido
- warnings corretos para truncamento

### ExportEngine

Validar:

- bloqueio de export concorrente
- uso de snapshot congelado
- aplicação correta do selected time range
- falha correta ao exportar asset inválido

## 16.2 Sem testes de interface

Não haverá:

- UI tests
- snapshot tests visuais
- testes de interação de tela

Toda a confiança do SDK deve vir dos testes unitários e da separação clara das engines.

## 16.3 Regra adicional de validação com as skills swiftui-pro e swiftui-expert-skill

Ao abrir cada fase, os testes e a implementação devem ser confrontados com as diretrizes das skills `swiftui-pro` e `swiftui-expert-skill`, principalmente em:

- safe areas
- padrões de interface iOS
- acessibilidade
- Dark Mode
- comportamento visual nativo
- state management com `@Observable`
- uso de APIs modernas de SwiftUI
- performance e estruturação de views

---

# 17. Roadmap de implementação

## Regra do roadmap

Cada fase deve seguir TDD.

Ou seja, para cada etapa:

1. escrever testes unitários da fase
2. implementar a engine ou componente
3. refatorar
4. avançar para a próxima fase

## Pré-requisito do roadmap

Antes da Fase 1, o ambiente de desenvolvimento deve estar configurado para usar as skills `swiftui-pro` e `swiftui-expert-skill`.

Nenhuma fase deve começar sem esse pré-requisito atendido.

## Fase 1

### TDD

- testes unitários de `TimeRangeEngine`
- testes unitários de regras básicas de `ExportPreset`

### Implementação

- modelos principais
- `ExportPreset`
- `VideoProject`
- `EditorState`
- `VideoEditorError`
- `TimeRangeEngine`

## Fase 2

### TDD

- testes unitários de `CaptionSafeFrameResolver`
- testes unitários de `CaptionPositionResolver`

### Implementação

- `CaptionSafeFrameResolver`
- `CaptionPositionResolver`

## Fase 3

### TDD

- testes unitários de `CaptionEngine`
- testes unitários de `CaptionMergeEngine`

### Implementação

- `CaptionEngine`
- `CaptionMergeEngine`

## Fase 4

### TDD

- testes unitários de `LayoutEngine`

### Implementação

- `LayoutEngine`

## Fase 5

### TDD

- testes unitários de `PlayerEngine` nas regras que puderem ser isoladas
- testes unitários de validações relacionadas ao tempo atual e clamp
- testes unitários do contrato entre `PlayerEngine` e `selectedTimeRange`
- testes unitários do comportamento do playhead ao tocar os limites do range

### Implementação

- `PlayerEngine`

### Escopo detalhado

Implementar o contrato temporal que permitirá à timeline operar sem lógica própria de tempo:

- carregamento de duração real do asset
- publicação de `currentTime`, `duration` e `isPlaying`
- `seek` com clamp obrigatório no `selectedTimeRange`
- reação a troca de preset e mudança de range
- parada/clamp ao atingir o fim do range selecionado

### Casos obrigatórios de teste

- `seek` abaixo do range vai para `lowerBound`
- `seek` acima do range vai para `upperBound`
- `seek` dentro do range preserva o valor
- ao reduzir `selectedTimeRange`, `currentTime` é clampado imediatamente
- ao voltar para `original`, `currentTime` permanece válido sem expansão automática do range
- playback não ultrapassa `selectedTimeRange.upperBound`
- timeline pode desenhar o playhead apenas lendo o estado publicado pelo player

### Resultado esperado da fase

Ao final da Fase 5, deve existir um contrato estável para a UI:

- `PlayerEngine` controla o playhead
- `TimeRangeEngine` controla os limites
- a Fase 9 pode implementar `TimelineView` sem reintroduzir regras temporais em SwiftUI

## Fase 6

### TDD

- testes unitários de `SnapshotCoder`
- testes unitários de persistência e reconstrução do projeto

### Implementação

- `VideoProjectSnapshot`
- `SnapshotCoder`

## Fase 7

### TDD

- testes unitários de `ProjectValidator`
- testes unitários das regras de aplicação de captions externas

### Implementação

- validação central
- integração async de captions
- aplicação de strategy

## Fase 8

### TDD

- testes unitários de `ExportEngine`

### Implementação

- `ExportEngine`
- progresso de export
- bloqueio de concorrência

## Fase 9

### TDD contínuo

- complementar cobertura de regressão
- adicionar testes unitários para bugs encontrados durante integração da UI
- adicionar testes unitários de mapeamento entre coordenadas da timeline e tempo/range
- adicionar testes unitários de interação fina do `TimelineRangeSelectorView` em modelos/helpers puros

### Implementação

- `VideoEditorView`
- `PresetToolbarView`
- `TimelineView`
- `TimelineRangeSelectorView`
- `CaptionOverlayView`

### Escopo detalhado de timeline

`TimelineView` deve ser a composição visual de três responsabilidades distintas:

- strip de thumbnails do vídeo inteiro
- playhead baseado em `PlayerEngine.currentTime`
- janela de seleção baseada em `selectedTimeRange`

`TimelineRangeSelectorView` deve ser o componente responsável por:

- desenhar a seleção destacada
- desenhar as duas alças laterais
- escurecer o trecho fora da seleção
- transformar gesto horizontal em atualização de `lowerBound` ou `upperBound`
- respeitar `validRange` e as restrições do preset

### Contrato técnico de `TimelineView`

Entradas mínimas:

    struct TimelineView: View {
        let thumbnails: [TimelineThumbnail]
        let duration: Double
        let currentTime: Double
        let validRange: ClosedRange<Double>
        let selectedTimeRange: ClosedRange<Double>
        let onScrub: (Double) -> Void
        let onSelectedRangeChange: (ClosedRange<Double>) -> Void
    }

Regras:

- thumbnails representam o vídeo inteiro, não apenas o range
- `currentTime` é renderizado como playhead independente
- `selectedTimeRange` é renderizado como janela destacada
- regiões fora de `selectedTimeRange` são escurecidas, mas continuam visíveis
- regiões fora de `validRange` são não interativas

### Contrato técnico de `TimelineRangeSelectorView`

Entradas mínimas:

    struct TimelineRangeSelectorView: View {
        let duration: Double
        let validRange: ClosedRange<Double>
        let selectedTimeRange: ClosedRange<Double>
        let minimumSelectionDuration: Double
        let maximumSelectionDuration: Double?
        let onChange: (ClosedRange<Double>) -> Void
    }

Regras:

- alça esquerda altera somente `lowerBound`
- alça direita altera somente `upperBound`
- o range nunca sai de `validRange`
- o range nunca colapsa abaixo da duração mínima permitida
- se existir duração máxima de seleção, ela deve ser respeitada durante o drag
- o componente não controla playback
- o componente não controla thumbnails
- o componente não recalcula regras de preset por conta própria

### Helpers puros recomendados

Para manter a UI fina, a Fase 9 deve introduzir helpers testáveis, por exemplo:

- `TimelineGeometryMapper`
- `TimelineRangeSelectionEngine`

Responsabilidades desses helpers:

- converter `x` em tempo
- converter tempo em `x`
- calcular frames do playhead e da janela de seleção
- aplicar clamp de drag antes de enviar o novo range à view

### Resultado esperado da fase

Ao final da Fase 9:

- `TimelineView` apenas apresenta estado e repassa eventos
- `TimelineRangeSelectorView` é um componente visual fino
- `PlayerEngine` continua sendo a fonte de verdade do playhead
- `TimeRangeEngine` continua sendo a fonte de verdade dos limites do range

## Observação importante

A UI não será validada com testes de interface.

As views devem permanecer o mais finas possível, delegando regras para engines já cobertas por testes unitários e seguindo a referência das skills `swiftui-pro` e `swiftui-expert-skill`.

---

# 18. Convenções de implementação com Observation

## Regras obrigatórias

- usar `@Observable` em todo tipo que representa estado mutável observado pela UI
- preferir classes `final` para objetos observáveis de runtime
- não usar `ObservableObject` salvo necessidade técnica excepcional e documentada
- não usar `@Published` como estratégia principal de observação
- manter structs para modelos de valor quando não precisarem observação direta
- separar claramente:
  - modelos de valor
  - estado observável
  - engines puras

## Exemplos esperados

### Estado observável

    @Observable
    final class PlayerEngine {
        var currentTime: Double = 0
        var duration: Double = 0
        var isPlaying: Bool = false
    }

### Modelo de valor

    struct TimeRangeResult {
        let validRange: ClosedRange<Double>
        let selectedRange: ClosedRange<Double>
        let isVideoTooShort: Bool
        let exceedsMaximum: Bool
    }

## Benefício arquitetural

Essa separação mantém:

- engines puras mais fáceis de testar
- estado reativo mais claro
- integração SwiftUI mais moderna
- menos boilerplate na biblioteca

## Regra adicional de implementação

Além do uso obrigatório de `@Observable`, toda implementação deve consultar e seguir as skills `swiftui-pro` e `swiftui-expert-skill` como referência técnica principal para desenvolvimento iOS.

---

# 19. TL;DR

`VideoEditorKit` será um SDK de edição de vídeo com:

- design inspirado no editor atual da Apple
- preview WYSIWYG
- presets `Original`, `Instagram`, `YouTube`, `TikTok`
- restrições temporais refletidas no scrub e no export
- legendas livres ou por presets `top`, `middle`, `bottom`
- safe area por plataforma
- integração assíncrona externa para captions
- edição não destrutiva
- persistência por snapshot
- modelo público de erros
- apenas testes unitários
- TDD no início de cada fase
- uso obrigatório de `@Observable` para estado observável
- uso obrigatório das skills `swiftui-pro` e `swiftui-expert-skill` como referência de implementação iOS

O núcleo de confiabilidade do projeto está em:

- `TimeRangeEngine`
- `LayoutEngine`
- `CaptionEngine`
- `CaptionPositionResolver`
- `ExportEngine`

Status do plano: pronto para implementação.
