# Plano Tecnico de Customizacao de Estilos de Transcricao

## Objetivo tecnico

Implementar customizacao de estilo de transcricao como configuracao runtime fornecida pelo app host, sem criar UI interna no `VideoEditorKit` e sem persistir tipos do host dentro de `VideoEditingConfiguration`.

O comportamento atual deve continuar sendo o fallback:

- texto branco
- contorno preto
- alinhamento centralizado
- uma palavra ativa por vez

## Principios de implementacao

- A API publica deve ser baseada em protocolos simples.
- O provider do host deve entrar por `VideoEditorConfiguration.TranscriptionConfiguration`.
- O package deve resolver o protocolo para um modelo concreto antes de preview/export.
- `VideoEditingConfiguration` nao deve armazenar provider, closures ou existentials.
- Preview e export devem consumir a mesma politica resolvida.
- A mudanca deve manter compatibilidade com snapshots antigos de transcricao.
- Novos testes devem usar Swift Testing.
- Validacao oficial deve seguir o runtime de iOS Simulator.

## Arquivos-alvo

Contratos publicos:

- `Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift`
- novo arquivo sugerido: `Sources/VideoEditorKit/Transcription/VideoTranscriptStyleProvider.swift`
- `Sources/VideoEditorKit/Transcription/TranscriptModels.swift`
- `Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md`

Runtime do editor:

- `Sources/VideoEditorKit/Views/Editor/VideoEditorView+Runtime.swift`
- `Sources/VideoEditorKit/Internal/ViewModels/EditorViewModel.swift`
- `Sources/VideoEditorKit/Internal/Editing/HostedVideoEditorPlayerStageCoordinator.swift`
- `Sources/VideoEditorKit/Views/Player/PlayerHolderView.swift`

Preview/layout:

- `Sources/VideoEditorKit/Transcription/TranscriptOverlayPreview.swift`
- `Sources/VideoEditorKit/Transcription/TranscriptOverlayLayoutResolver.swift`
- `Sources/VideoEditorKit/Transcription/TranscriptTextStyleResolver.swift`
- novo arquivo sugerido: `Sources/VideoEditorKit/Transcription/TranscriptWordWindowResolver.swift`

Export:

- `Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift`
- `Sources/VideoEditorKit/Views/Export/VideoExporterContainerView.swift`
- `Sources/VideoEditorKit/Internal/ViewModels/ExporterViewModel.swift`
- `Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift`

Testes:

- novo arquivo sugerido: `Tests/VideoEditorKitTests/Transcription/VideoTranscriptStyleResolverTests.swift`
- novo arquivo sugerido: `Tests/VideoEditorKitTests/Transcription/TranscriptWordWindowResolverTests.swift`
- `Tests/VideoEditorKitTests/TranscriptOverlayLayoutResolverTests.swift`
- `Tests/VideoEditorKitTests/TranscriptTextStyleResolverTests.swift`
- testes de export helpers em `Tests/VideoEditorKitTests/Models/` se o helper ficar em `VideoEditor`.

## Contratos publicos propostos

Adicionar um provider host-facing:

```swift
public protocol VideoTranscriptStyleProvider: Sendable {
    func transcriptStyle(
        for context: VideoTranscriptStyleContext
    ) -> any VideoTranscriptStyleModel
}
```

Adicionar o modelo que o host implementa:

```swift
public protocol VideoTranscriptStyleModel: Sendable {
    var identifier: String { get }
    var displayName: String { get }
    var font: VideoTranscriptFontDescriptor { get }
    var textColor: RGBAColor { get }
    var textAlignment: TranscriptTextAlignment { get }
    var stroke: VideoTranscriptStroke? { get }
    var wordsPerCaption: Int { get }
    var highlightsActiveWord: Bool { get }
    var activeWordTextColor: RGBAColor? { get }
}
```

Adicionar o contexto de resolucao:

```swift
public struct VideoTranscriptStyleContext: Hashable, Sendable {
    public let preferredLocale: String?
}
```

Adicionar descritores concretos:

```swift
public enum VideoTranscriptFontDescriptor: Hashable, Sendable {
    case system(weight: TranscriptFontWeight)
    case roundedSystem(weight: TranscriptFontWeight)
    case custom(name: String, fallbackWeight: TranscriptFontWeight)
}

public struct VideoTranscriptStroke: Hashable, Sendable {
    public var color: RGBAColor
    public var width: CGFloat
}
```

Adicionar o tipo resolvido usado internamente:

```swift
public struct ResolvedTranscriptStyle: Hashable, Sendable {
    public var identifier: String
    public var displayName: String
    public var font: VideoTranscriptFontDescriptor
    public var textColor: RGBAColor
    public var textAlignment: TranscriptTextAlignment
    public var stroke: VideoTranscriptStroke?
    public var wordsPerCaption: Int
    public var highlightsActiveWord: Bool
    public var activeWordTextColor: RGBAColor?
}
```

Regras de normalizacao:

- `identifier` vazio cai para `"default"`.
- `displayName` vazio cai para `"Default"`.
- `wordsPerCaption` fica limitado a `1...8`.
- `stroke.width <= 0` remove o stroke.
- `activeWordTextColor == nil` cai para `textColor`.
- fonte customizada inexistente cai para `fallbackWeight` com system font.

## Mudanca em `VideoEditorConfiguration`

Evoluir `VideoEditorConfiguration.TranscriptionConfiguration`:

```swift
public init(
    provider: (any VideoTranscriptionProvider)? = nil,
    preferredLocale: String? = nil,
    styleProvider: (any VideoTranscriptStyleProvider)? = nil
)
```

Adicionar:

```swift
public var styleProvider: (any VideoTranscriptStyleProvider)? {
    explicitStyleProvider
}
```

Manter compatibilidade:

- o init atual continua funcionando porque `styleProvider` tem default `nil`.
- `.openAIWhisper(apiKey:preferredLocale:)` deve aceitar um overload ou parametro default opcional `styleProvider`.
- quando `styleProvider == nil`, usar `ResolvedTranscriptStyle.defaultCaptionStyle`.

## Resolvedor de estilo

Criar um resolvedor puro:

```swift
public enum VideoTranscriptStyleResolver {
    public static func resolve(
        provider: (any VideoTranscriptStyleProvider)?,
        context: VideoTranscriptStyleContext
    ) -> ResolvedTranscriptStyle
}
```

Responsabilidades:

- chamar o provider quando existir.
- converter `VideoTranscriptStyleModel` em `ResolvedTranscriptStyle`.
- aplicar normalizacao.
- retornar fallback quando nao houver provider.

Essa camada deve ser coberta por testes sem tocar em SwiftUI nem AVFoundation.

## Propagacao no runtime do editor

Em `VideoEditorView+Runtime.bootstrapEditorContent(...)`:

1. Ler `configuration.transcription?.styleProvider`.
2. Resolver com `VideoTranscriptStyleResolver`.
3. Passar para `EditorViewModel.configureTranscription(...)`.

Evoluir a assinatura de `EditorViewModel.configureTranscription`:

```swift
func configureTranscription(
    provider: (any VideoTranscriptionProvider)?,
    preferredLocale: String? = nil,
    style: ResolvedTranscriptStyle = .defaultCaptionStyle
)
```

Adicionar no `EditorViewModel`:

```swift
var transcriptStyle: ResolvedTranscriptStyle = .defaultCaptionStyle
```

Usar esse valor para preview e export. Ele e runtime state, nao snapshot persistido.

## Preview

Hoje `PlayerHolderView` chama `TranscriptOverlayPreview` com `style: nil`.

Mudanca:

- `HostedVideoEditorPlayerStageCoordinator.TranscriptOverlayContext` deve carregar `transcriptStyle`.
- `PlayerHolderView.transcriptOverlay` deve passar o estilo resolvido.
- `TranscriptOverlayPreview` deve trocar `TranscriptStyle?` por `ResolvedTranscriptStyle`.

O `TranscriptTextStyleResolver` deve aceitar `ResolvedTranscriptStyle` diretamente ou ter overloads:

```swift
public static func attributedString(
    text: String,
    style: ResolvedTranscriptStyle,
    fontSize: CGFloat,
    textColorOverride: RGBAColor? = nil,
    includesStroke: Bool = true,
    isWrapped: Bool = true
) -> NSAttributedString
```

Para reduzir risco, manter overloads existentes com `TranscriptStyle` durante a migracao.

## Agrupamento de palavras

Criar `TranscriptWordWindowResolver`:

```swift
public enum TranscriptWordWindowResolver {
    public static func resolve(
        words: [EditableTranscriptWord],
        activeWordID: EditableTranscriptWord.ID?,
        wordsPerCaption: Int
    ) -> [EditableTranscriptWord]
}
```

Algoritmo recomendado:

1. Filtrar palavras com `editedText` nao vazio.
2. Normalizar `wordsPerCaption`.
3. Se `activeWordID == nil`, retornar a primeira janela de ate `wordsPerCaption`.
4. Encontrar o indice da palavra ativa.
5. Calcular uma janela centralizada ao redor da palavra ativa.
6. Ajustar inicio/fim para preencher a janela no comeco e no fim do segmento.
7. Retornar palavras na ordem original.

Exemplos:

- palavras `[a, b, c, d]`, ativa `b`, `wordsPerCaption = 1` -> `[b]`
- palavras `[a, b, c, d]`, ativa `b`, `wordsPerCaption = 3` -> `[a, b, c]`
- palavras `[a, b, c, d]`, ativa `d`, `wordsPerCaption = 3` -> `[b, c, d]`

## Destaque da palavra ativa

No preview:

- se `highlightsActiveWord == false`, renderizar todas as palavras da janela com `textColor`.
- se `highlightsActiveWord == true`, renderizar palavra ativa com `activeWordTextColor ?? textColor`.

Evitar sincronizacao bidirecional com `@State`: o destaque deve ser derivado de `activeWordID`, `wordsPerCaption` e `ResolvedTranscriptStyle`.

## Export

Hoje `VideoEditor.startRender(...)` recebe `VideoEditingConfiguration`, e o estilo e resolvido internamente como `.defaultCaptionStyle`.

Nao colocar provider dentro de `VideoEditingConfiguration`. Em vez disso, adicionar parametro runtime com default:

```swift
static func startRender(
    video: Video,
    editingConfiguration: VideoEditingConfiguration = .initial,
    transcriptStyle: ResolvedTranscriptStyle = .defaultCaptionStyle,
    videoQuality: VideoQuality,
    onProgress: ProgressHandler? = nil
) async throws -> URL
```

Propagar esse parametro por:

- `VideoExporterContainerView`
- `ExporterViewModel.RenderVideo`
- `ExporterViewModel.init`
- chamada a `VideoEditor.startRender`

Em `VideoEditor.applyTranscriptOperation(...)`:

- receber `transcriptStyle`.
- passar para `resolvedTranscriptRenderSegmentsForExport`.
- remover o fallback fixo de `resolvedTranscriptStyle(for:)`.

Em `resolvedTranscriptRenderUnits(...)`:

- usar `TranscriptWordWindowResolver` para formar as unidades de renderizacao.
- preservar modo bloco para segmentos sem words.
- quando `wordsPerCaption == 1`, manter comportamento equivalente ao atual.
- quando `wordsPerCaption > 1`, criar render units com texto composto por janela de palavras.
- quando `highlightsActiveWord == true`, carregar metadados suficientes para pintar a palavra ativa dentro da janela, ou usar camadas separadas para base + palavra ativa.

Decisao tecnica para menor risco:

- Fase 3A: export com `wordsPerCaption` e sem cor diferente por subrange, mantendo a janela inteira na cor base quando `highlightsActiveWord == false`.
- Fase 3B: adicionar destaque ativo no export usando composicao de camadas ou rasterizacao semelhante ao caminho de palavra ativa atual.

## Persistencia

Nao alterar `VideoEditingConfiguration` na primeira entrega.

Manter:

- `TranscriptDocument.segments`
- `TranscriptDocument.overlayPosition`
- `TranscriptDocument.overlaySize`

Nao persistir:

- `VideoTranscriptStyleProvider`
- `VideoTranscriptStyleModel`
- closures ou existentials
- fonte runtime customizada resolvida

Futuro opcional:

- se o host precisar multiplos estilos por projeto, persistir apenas `styleIdentifier` em `TranscriptDocument` e o host continua responsavel por resolver esse identificador para um modelo.

## Testes tecnicos

Criar `VideoTranscriptStyleResolverTests`:

- `resolveUsesDefaultStyleWhenProviderIsNil`
- `resolveNormalizesEmptyIdentifierAndDisplayName`
- `resolveClampsWordsPerCaption`
- `resolveDropsInvalidStrokeWidth`
- `resolveUsesBaseTextColorWhenActiveWordColorIsNil`
- `resolvePreservesCustomFontDescriptor`

Criar `TranscriptWordWindowResolverTests`:

- `resolveReturnsActiveWordWhenWordsPerCaptionIsOne`
- `resolveCentersWindowAroundActiveWord`
- `resolveBackfillsWindowAtStart`
- `resolveBackfillsWindowAtEnd`
- `resolveIgnoresEmptyWords`
- `resolveReturnsInitialWindowWhenActiveWordIsNil`

Atualizar `TranscriptOverlayLayoutResolverTests`:

- garantir que `wordsPerCaption == 1` preserva layout atual.
- garantir que `wordsPerCaption > 1` gera layout para uma janela de palavras.

Atualizar testes de export helpers:

- `resolvedTranscriptRenderUnits` usa fallback default.
- `resolvedTranscriptRenderUnits` agrupa palavras conforme `wordsPerCaption`.
- `resolvedTranscriptRenderUnits` preserva blocos para segmentos sem word timings.

Atualizar teste de configuracao publica:

- `TranscriptionConfiguration` preserva provider existente.
- `TranscriptionConfiguration` aceita `styleProvider`.
- `.openAIWhisper` aceita estilo sem exigir provider customizado de transcricao.

## Ordem de implementacao

### Etapa 1: API e resolvedor

1. Criar `VideoTranscriptStyleProvider.swift`.
2. Adicionar `ResolvedTranscriptStyle.defaultCaptionStyle`.
3. Implementar `VideoTranscriptStyleResolver`.
4. Evoluir `TranscriptionConfiguration`.
5. Adicionar testes unitarios da API.

### Etapa 2: Runtime e preview

1. Guardar `transcriptStyle` em `EditorViewModel`.
2. Propagar estilo pelo bootstrap.
3. Adicionar estilo ao `TranscriptOverlayContext`.
4. Atualizar `PlayerHolderView`.
5. Atualizar `TranscriptOverlayPreview`.
6. Manter overloads legados para `TranscriptStyle`.

### Etapa 3: Janela de palavras

1. Criar `TranscriptWordWindowResolver`.
2. Usar no preview.
3. Ajustar `TranscriptOverlayLayoutResolver`.
4. Adicionar testes de layout e resolver.

### Etapa 4: Export

1. Adicionar `transcriptStyle` ao fluxo do exporter.
2. Passar o estilo ate `VideoEditor.startRender`.
3. Remover fallback fixo em `resolvedTranscriptStyle(for:)`.
4. Usar janela de palavras na geracao de render units.
5. Cobrir comportamento com testes de helpers.

### Etapa 5: Documentacao e validacao

1. Atualizar README com exemplos finais da API implementada.
2. Atualizar DocC com os novos tipos publicos.
3. Rodar `scripts/format-swift.sh`.
4. Rodar `scripts/test-ios.sh`.

## Riscos e mitigacoes

- Risco: quebrar preview/export parity.
  Mitigacao: usar o mesmo `ResolvedTranscriptStyle` e o mesmo `TranscriptWordWindowResolver` nos dois caminhos.

- Risco: vazar provider do host para snapshot codavel.
  Mitigacao: manter provider apenas em `VideoEditorConfiguration` e runtime state.

- Risco: fonte customizada inexistente causar render inconsistente.
  Mitigacao: resolver fonte com fallback system em `TranscriptTextStyleResolver`.

- Risco: highlight parcial no export ficar complexo.
  Mitigacao: entregar primeiro a janela de palavras e manter a cor base, depois adicionar destaque ativo por camada/rasterizacao com testes.

- Risco: regressao em snapshots antigos.
  Mitigacao: manter decode legado de `TranscriptStyle` e nao reintroduzir campos obrigatorios em `TranscriptDocument`.

## Criterios de aceite tecnicos

- O host consegue passar `styleProvider` via `VideoEditorConfiguration.TranscriptionConfiguration`.
- Sem provider, a transcricao continua igual ao comportamento atual.
- `wordsPerCaption` controla a quantidade de palavras visiveis no preview.
- `highlightsActiveWord` controla o destaque no preview.
- Export recebe o mesmo estilo resolvido do preview.
- `VideoEditingConfiguration` continua codavel sem provider.
- Testes de resolver, janela de palavras, preview layout e export helpers passam.
- Validacao iOS Simulator passa com `scripts/test-ios.sh`.
