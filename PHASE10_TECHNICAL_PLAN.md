# VideoEditorKit — Plano Técnico da Fase 10

## Objetivo

Fechar a superfície pública interativa do editor iniciada na fase 9, entregando a timeline editável do MVP e o conjunto mínimo de affordances para operações de legenda e leitura de estado do projeto.

Ao final da fase 10, a UI deve permitir:

- scrub do playhead pela timeline
- ajuste visual do `selectedTimeRange`
- leitura do estado válido do preset e do export
- disparo das ações assíncronas de legenda pela UI
- feedback imediato de loading, erro e warnings sem mover regra de negócio para as views

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

As duas skills guiam principalmente:

- uso de `@Observable` sem voltar para `ObservableObject`
- composição em subviews pequenas e estáveis
- uso de APIs modernas (`foregroundStyle`, `clipShape`, `Button`)
- acessibilidade básica da timeline e dos botões
- redução de lógica no `body`

### Desvios documentados

- A timeline usará `GeometryReader` localmente para converter gesto horizontal em tempo absoluto. O uso é intencional e restrito ao shell do componente, porque a largura real disponível é parte do contrato de interação.
- Handles de range usarão `DragGesture` por necessidade funcional. Para não perder acessibilidade, cada handle também expõe `accessibilityAdjustableAction`.

## Problema que a fase 10 resolve

A fase 9 abriu a UI do editor, mas deixou uma lacuna objetiva entre o plano e o código entregue:

- `TimelineView` não existe
- `TimelineRangeSelectorView` não existe
- `CaptionActionButtonView` não existe
- `VideoEditorView` ainda não expõe scrub, seleção visual de range nem feedback de validação do projeto

Em outras palavras, a UI mostra o preview, mas ainda não fecha o fluxo de edição temporal prometido pelo roadmap.

## Escopo da Fase 10

### 1. Base pura e testável da timeline

Adicionar dois componentes puros:

- `VideoEditorTimelineBuilder`
- `TimelineInteractionEngine`

Responsabilidades:

- resolver `validRange`, `selectedRange` e playhead normalizado
- converter captions em segmentos desenháveis da timeline
- consolidar `ValidationResult` para a camada visual
- transformar progresso horizontal em tempo absoluto
- ajustar handle esquerdo e direito sem cruzamento inválido

### 2. Modelos de snapshot para a timeline

Adicionar um snapshot dedicado:

- `VideoEditorTimelineSnapshot`
- `VideoEditorTimelineCaptionSegment`

Objetivo:

- evitar cálculos temporais no `body`
- tornar a timeline verificável com testes unitários
- manter a UI como camada declarativa sobre dados já resolvidos

### 3. Views SwiftUI da fase 10

Implementar:

- `TimelineView`
- `TimelineRangeSelectorView`
- `CaptionActionButtonView`

Comportamentos mínimos:

- scrub por arraste horizontal
- overlay escurecendo trechos fora do `selectedTimeRange`
- handles de início e fim do range
- indicador visual do playhead
- marcadores de segmentos de legenda
- botões de gerar e traduzir legendas
- estados de loading e erro de legenda

### 4. Integração final em `VideoEditorView`

`VideoEditorView` passa a:

- compor preview + toolbar + timeline + ações
- exibir warnings e erros relevantes de validação
- integrar `PlayerEngine` como fonte única de tempo
- delegar mutations para `VideoEditorController`

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    TimelineInteractionEngine.swift
    VideoEditorTimelineBuilder.swift
  Models/
    VideoEditorTimelineSnapshot.swift
  UI/
    TimelineView.swift
    TimelineRangeSelectorView.swift
    CaptionActionButtonView.swift
    VideoEditorView.swift

VideoEditorKitTests/
  Core/
    TimelineInteractionEngineTests.swift
    VideoEditorTimelineBuilderTests.swift
```

## Sequência TDD

1. escrever testes do builder de timeline
2. escrever testes do engine de interação
3. rodar a suíte relevante e confirmar falha inicial
4. implementar snapshots e engines puras
5. compor as views SwiftUI em cima dessa base
6. integrar `VideoEditorView` e `ContentView`
7. rodar a suíte novamente até verde

## Critérios de aceite

- a timeline reflete `validRange`, `selectedTimeRange` e `currentTime` sem recalcular regra de negócio no `body`
- scrub converte posição horizontal em tempo clampado no range válido
- ajuste do handle esquerdo nunca ultrapassa o direito
- ajuste do handle direito nunca ultrapassa o esquerdo
- captions aparecem como segmentos coerentes com sua duração
- warnings e bloqueios do projeto ficam visíveis na UI
- ações de legenda usam o callback assíncrono já exposto por `VideoEditorController`
- toda view criada ou alterada possui `#Preview` funcional

## Fora do escopo

- thumbnails reais do vídeo na timeline
- player AVFoundation embutido no preview
- drag livre da legenda diretamente sobre o preview
- file picker de export
- testes de interface
