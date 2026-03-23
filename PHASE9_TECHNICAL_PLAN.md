# VideoEditorKit — Plano Técnico da Fase 9

## Objetivo

Entregar a primeira camada de UI do editor em SwiftUI, mantendo a regra de `UI fina, lógica nas engines`, e integrar a superfície pública do editor com `PlayerEngine`, `LayoutEngine`, `CaptionEngine` e `ExportEngine`.

Nesta fase, a biblioteca deve começar a expor a experiência visual do editor:

- preview centralizado com base no mesmo layout usado no export
- overlay de legendas coerente com safe area e coordenadas normalizadas
- toolbar de presets com atualização imediata
- timeline e scrub apoiados em `PlayerEngine`
- ações de legenda e export refletidas na UI

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

As duas skills serão usadas principalmente para:

- composição de views pequenas e focadas
- uso correto de `@Observable`, `@Bindable` e estado no `@MainActor`
- aderência a APIs modernas de SwiftUI
- acessibilidade básica, Dynamic Type e Dark Mode
- evitar colocar regra de negócio em `body`

### Desvio documentado

- O preview usará `GeometryReader` localmente para obter o tamanho real do container. Aqui ele é justificável, porque a composição do preview depende do canvas efetivo para manter `Preview = Export`. O uso ficará restrito ao shell do preview.

## Dependências de entrada

A fase 9 assume concluídos:

- `TimeRangeEngine`
- `CaptionSafeFrameResolver`
- `CaptionPositionResolver`
- `CaptionEngine`
- `LayoutEngine`
- `PlayerEngine`
- `SnapshotCoder`
- `ProjectValidator`
- `ExportEngine`
- `VideoEditorController`

## Escopo da Fase 9

### UI pública

Implementar:

- `VideoEditorView`
- `PresetToolbarView`
- `TimelineView`
- `TimelineRangeSelectorView`
- `CaptionOverlayView`
- `CaptionActionButtonView`

### Base testável da UI

Adicionar suporte a:

- mutations do `VideoEditorController` para preset, seek e selected time range
- integração explícita com `PlayerEngine`
- builder puro de preview para transformar `VideoProject` + tempo atual + geometria em snapshot renderizável

### Demo local

Atualizar `ContentView` para exercitar a primeira composição da fase 9 com dados mockados.

## Decisões de implementação

### 1. `VideoEditorController` passa a orquestrar `PlayerEngine`

Contrato desejado:

- `loadVideo(duration:)`
- `selectPreset(_:)`
- `updateSelectedTimeRange(_:)`
- `seek(to:)`

Motivo:

- a fase 9 precisa ligar scrub, preset e preview sem mover lógica para as views
- o controller passa a ser o ponto de integração entre projeto editável e tempo reproduzido
- `PlayerEngine` continua sendo a fonte de verdade do tempo

### 2. Preview usará um snapshot puro

Modelo proposto:

- layout resolvido
- safe frame atual
- captions ativas já posicionadas em coordenadas absolutas do render

Motivo:

- facilita TDD sem UI tests
- mantém `VideoEditorView` como composição visual
- reduz duplicação entre preview, overlay e futuras iterações da timeline

### 3. Fase 9 será entregue em fatias

#### Fatia 1

- plano técnico
- mutations do controller para preset/range/seek
- builder de preview
- `VideoEditorView` inicial
- `PresetToolbarView`
- `CaptionOverlayView`

#### Fatia 2

- timeline visual
- range selector
- sincronização mais forte com playback contínuo

#### Fatia 3

- botões de ação de legenda
- affordances de export e estados finais
- refinamentos de acessibilidade e acabamento visual

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    VideoEditorPreviewBuilder.swift
  Models/
    VideoEditorPreviewSnapshot.swift
  Public/
    VideoEditorController.swift
  UI/
    VideoEditorView.swift
    PresetToolbarView.swift
    CaptionOverlayView.swift
    TimelineView.swift
    TimelineRangeSelectorView.swift
    CaptionActionButtonView.swift

VideoEditorKitTests/
  Core/
    VideoEditorPreviewBuilderTests.swift
  Public/
    VideoEditorControllerEditingTests.swift
```

## Sequência TDD

1. escrever testes de controller para preset/range/seek
2. escrever testes do builder de preview
3. executar a suíte relevante e observar falha inicial
4. implementar a base testável
5. compor as primeiras views SwiftUI em cima dessa base
6. rodar a suíte novamente até verde

## Critérios de aceite da fatia inicial

- trocar preset atualiza imediatamente `project.preset`
- trocar preset resolve `selectedTimeRange` com base em `PlayerEngine.duration`
- captions são re-sanitizadas quando o range muda
- seleção de legenda é limpa quando deixa de existir
- preview resolve safe area e posição das captions com as mesmas regras do export
- `VideoEditorView` inicial renderiza preview, toolbar e overlay sem lógica de negócio no `body`

## Fora do escopo desta primeira entrega

- UI final completa da timeline
- integração completa com player AVFoundation embutido no preview
- gestos avançados de drag/resize de legenda
- testes de interface
