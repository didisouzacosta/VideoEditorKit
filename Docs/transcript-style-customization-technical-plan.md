# Plano Tecnico de Customizacao de Estilos de Transcricao

## Objetivo tecnico

Implementar customizacao de estilo de transcricao como configuracao runtime fornecida pelo app host, sem criar UI interna de autoria de estilos no `VideoEditorKit` e sem persistir tipos do host dentro de `VideoEditingConfiguration`.

O comportamento atual deve continuar sendo o fallback:

- texto branco
- contorno preto
- alinhamento centralizado
- uma palavra ativa por vez

Com os novos requisitos, o editor deve:

- suportar cor de fundo na palavra ativa
- exibir um submenu de estilos na secao `Layout` da tela de transcricoes
- listar os estilos fornecidos pelo host com um exemplo visual
- persistir o identificador do estilo selecionado no snapshot

## Principios de implementacao

- A API publica deve ser baseada em protocolos simples.
- O provider de estilos do host deve entrar por uma sessao dedicada em `VideoEditorConfiguration`, separada de `TranscriptionConfiguration`.
- O package deve resolver o catalogo do provider para modelos concretos antes de preview/export.
- `VideoEditingConfiguration` nao deve armazenar provider, closures ou existentials.
- Preview e export devem consumir a mesma politica resolvida.
- A UI do editor pode selecionar um estilo, mas nao pode criar ou editar estilos.
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
- `Sources/VideoEditorKit/Internal/Editing/EditorInitialLoadCoordinator.swift`

Preview/layout:

- `Sources/VideoEditorKit/Transcription/TranscriptOverlayPreview.swift`
- `Sources/VideoEditorKit/Transcription/TranscriptOverlayLayoutResolver.swift`
- `Sources/VideoEditorKit/Transcription/TranscriptTextStyleResolver.swift`
- novo arquivo sugerido: `Sources/VideoEditorKit/Transcription/TranscriptWordWindowResolver.swift`
- novo arquivo sugerido: `Sources/VideoEditorKit/Views/Tools/Transcript/TranscriptStyleListRow.swift`

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
- novo arquivo sugerido: `Tests/VideoEditorKitTests/Views/TranscriptToolViewTests.swift`
- testes de export helpers em `Tests/VideoEditorKitTests/Models/` se o helper ficar em `VideoEditor`.

## Contratos publicos propostos

Adicionar um provider host-facing:

```swift
public protocol VideoTranscriptStyleProvider: Sendable {
    func transcriptStyles(
        for context: VideoTranscriptStyleContext
    ) -> [any VideoTranscriptStyleModel]

    func defaultStyleIdentifier(
        for context: VideoTranscriptStyleContext
    ) -> String?
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
    var activeWordBackgroundColor: RGBAColor? { get }
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
    public var activeWordBackgroundColor: RGBAColor?
}
```

Regras de normalizacao:

- `identifier` vazio cai para `"default"`.
- `displayName` vazio cai para `"Default"`.
- `wordsPerCaption` fica limitado a `1...8`.
- `stroke.width <= 0` remove o stroke.
- `activeWordTextColor == nil` cai para `textColor`.
- `activeWordBackgroundColor == nil` desabilita a camada de fundo da palavra ativa.
- fonte customizada inexistente cai para `fallbackWeight` com system font.

## Mudanca em `VideoEditorConfiguration`

Adicionar uma sessao dedicada:

```swift
public struct VideoEditorConfiguration {
    public struct TranscriptStyleConfiguration {
        public init(
            provider: (any VideoTranscriptStyleProvider)? = nil
        )

        public var provider: (any VideoTranscriptStyleProvider)?
    }
}
```

E evoluir o objeto principal:

```swift
public init(
    tools: [ToolAvailability] = ToolAvailability.enabled(ToolEnum.all),
    exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
    transcription: TranscriptionConfiguration? = nil,
    transcriptStyles: TranscriptStyleConfiguration? = nil,
    maximumVideoDuration: TimeInterval? = nil,
)
```

Na forma real do tipo, isso significa:

```swift
public let transcriptStyles: TranscriptStyleConfiguration?
public let transcription: TranscriptionConfiguration?
```

Manter compatibilidade:

- `TranscriptionConfiguration` continua responsavel apenas por provider e locale.
- `TranscriptStyleConfiguration` fica responsavel apenas pelo catalogo de estilos.
- quando `transcriptStyles == nil`, usar um catalogo com `ResolvedTranscriptStyle.defaultCaptionStyle`.

## Resolvedor de estilo

Criar um resolvedor puro:

```swift
public enum VideoTranscriptStyleResolver {
    public static func resolveStyles(
        provider: (any VideoTranscriptStyleProvider)?,
        context: VideoTranscriptStyleContext
    ) -> [ResolvedTranscriptStyle]

    public static func resolveSelectedStyle(
        availableStyles: [ResolvedTranscriptStyle],
        selectedStyleIdentifier: String?
    ) -> ResolvedTranscriptStyle
}
```

Responsabilidades:

- chamar o provider quando existir.
- converter `[VideoTranscriptStyleModel]` em `[ResolvedTranscriptStyle]`.
- aplicar normalizacao.
- retornar fallback quando nao houver provider ou quando o catalogo vier vazio.
- escolher o estilo selecionado com base em `selectedStyleIdentifier` persistido no documento ou no `defaultStyleIdentifier`.

Essa camada deve ser coberta por testes sem tocar em SwiftUI nem AVFoundation.

## Propagacao no runtime do editor

Em `VideoEditorView+Runtime.bootstrapEditorContent(...)`:

1. Ler `configuration.transcriptStyles?.provider`.
2. Resolver o catalogo com `VideoTranscriptStyleResolver`.
3. Passar estilos resolvidos para `EditorViewModel.configureTranscription(...)`.

Evoluir a assinatura de `EditorViewModel.configureTranscription`:

```swift
func configureTranscription(
    provider: (any VideoTranscriptionProvider)?,
    preferredLocale: String? = nil,
    availableStyles: [ResolvedTranscriptStyle] = [.defaultCaptionStyle],
    defaultStyleIdentifier: String? = nil
)
```

Adicionar no `EditorViewModel`:

```swift
var transcriptStyle: ResolvedTranscriptStyle = .defaultCaptionStyle
var availableTranscriptStyles: [ResolvedTranscriptStyle] = [.defaultCaptionStyle]
```

O `EditorViewModel` tambem precisa expor uma action para selecao:

```swift
func updateSelectedTranscriptStyle(_ identifier: String)
```

Esse metodo deve:

- validar se o identificador existe no catalogo runtime
- atualizar `transcriptDraftDocument?.selectedStyleIdentifier`
- refletir a mudanca no preview imediatamente

Os estilos continuam sendo runtime state. O que vai para o snapshot e apenas o identificador selecionado.

## Preview

Hoje `PlayerHolderView` chama `TranscriptOverlayPreview` com `style: nil`.

Mudanca:

- `HostedVideoEditorPlayerStageCoordinator.TranscriptOverlayContext` deve carregar `transcriptStyle`.
- `PlayerHolderView.transcriptOverlay` deve passar o estilo resolvido.
- `TranscriptOverlayPreview` deve trocar `TranscriptStyle?` por `ResolvedTranscriptStyle`.
- o preview deve suportar fundo colorido para a palavra ativa quando configurado.

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

## Mudanca no `TranscriptDocument`

Adicionar persistencia do estilo selecionado:

```swift
public var selectedStyleIdentifier: String?
```

Regras:

- default `nil`, que significa usar o default do catalogo.
- ao decodificar snapshots antigos, continuar ignorando `availableStyles`.
- se houver `selectedStyleID` legado em UUID, converter para `uuidString` como fallback.
- nao persistir a lista de estilos, apenas o identificador selecionado.

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
- se `activeWordBackgroundColor != nil`, renderizar uma capsula ou retangulo arredondado atras da palavra ativa.

Evitar sincronizacao bidirecional com `@State`: o destaque deve ser derivado de `activeWordID`, `wordsPerCaption` e `ResolvedTranscriptStyle`.

## Submenu de estilos na tela de transcricoes

`TranscriptToolView` hoje ja tem uma secao `Layout` com `positionPicker` e `sizePicker`. A entrega deve ampliar essa secao com um submenu de estilos.

API esperada para a view:

```swift
let availableStyles: [ResolvedTranscriptStyle]
let onUpdateStyle: (String) -> Void
```

Comportamento:

- abaixo de posicao e tamanho, exibir uma linha `Styles`.
- ao tocar nessa linha, abrir um destino push ou submenu de lista.
- a lista deve mostrar todos os estilos do host.
- cada item deve exibir:
  - nome do estilo
  - preview visual com sample text
  - estado selecionado
- a acao da linha chama `onUpdateStyle(style.identifier)`.

Sample recomendado para preview:

- usar um texto curto fixo, por exemplo `"Hello brave world"`
- usar a palavra central como ativa no preview do item
- respeitar `wordsPerCaption`, highlight de texto e background highlight

Se `availableStyles.count <= 1`, a UI pode esconder o submenu e manter apenas o estilo unico.

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
- quando `activeWordBackgroundColor != nil`, desenhar tambem a camada de fundo da palavra ativa.

Decisao tecnica para menor risco:

- Fase 3A: export com `wordsPerCaption` e sem cor diferente por subrange, mantendo a janela inteira na cor base quando `highlightsActiveWord == false`.
- Fase 3B: adicionar destaque ativo no export usando composicao de camadas ou rasterizacao semelhante ao caminho de palavra ativa atual.
- Fase 3C: adicionar background highlight no export com shape rasterizada ou `CALayer` dedicada.

## Persistencia

Alterar `VideoEditingConfiguration` apenas para persistir o identificador do estilo selecionado.

Manter:

- `TranscriptDocument.segments`
- `TranscriptDocument.overlayPosition`
- `TranscriptDocument.overlaySize`
- `TranscriptDocument.selectedStyleIdentifier`

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
- `resolvePreservesActiveWordBackgroundColor`
- `resolvePreservesCustomFontDescriptor`
- `resolveFallsBackWhenSelectedIdentifierDoesNotExist`

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
- garantir que a palavra ativa pode reservar fundo visual sem quebrar alinhamento.

Criar `TranscriptToolViewTests`:

- renderiza submenu de estilos quando ha mais de um estilo
- esconde submenu quando ha um unico estilo
- mostra preview por item
- marca o item selecionado

Atualizar testes de export helpers:

- `resolvedTranscriptRenderUnits` usa fallback default.
- `resolvedTranscriptRenderUnits` agrupa palavras conforme `wordsPerCaption`.
- `resolvedTranscriptRenderUnits` preserva blocos para segmentos sem word timings.

Atualizar teste de configuracao publica:

- `TranscriptionConfiguration` preserva provider e locale existentes.
- `TranscriptStyleConfiguration` aceita o provider de estilos.
- `.openAIWhisper` continua focado apenas em transcricao.

## Ordem de implementacao

### Etapa 1: API e resolvedor

1. Criar `VideoTranscriptStyleProvider.swift`.
2. Adicionar `ResolvedTranscriptStyle.defaultCaptionStyle`.
3. Implementar `VideoTranscriptStyleResolver`.
4. Criar `TranscriptStyleConfiguration` em `VideoEditorConfiguration`.
5. Adicionar `selectedStyleIdentifier` em `TranscriptDocument`.
6. Adicionar testes unitarios da API.

### Etapa 2: Runtime e preview

1. Guardar `transcriptStyle` em `EditorViewModel`.
2. Guardar `availableTranscriptStyles` em `EditorViewModel`.
3. Propagar estilos pelo bootstrap.
4. Adicionar estilo ao `TranscriptOverlayContext`.
5. Atualizar `PlayerHolderView`.
6. Atualizar `TranscriptOverlayPreview`.
7. Manter overloads legados para `TranscriptStyle`.

### Etapa 3: Janela de palavras

1. Criar `TranscriptWordWindowResolver`.
2. Usar no preview.
3. Ajustar `TranscriptOverlayLayoutResolver`.
4. Adicionar fundo da palavra ativa.
5. Adicionar testes de layout e resolver.

### Etapa 4: Tela de estilos

1. Evoluir `TranscriptToolView`.
2. Criar row de preview de estilo.
3. Integrar selecao com `EditorViewModel.updateSelectedTranscriptStyle`.
4. Cobrir submenu com testes da view.

### Etapa 5: Export

1. Adicionar `transcriptStyle` ao fluxo do exporter.
2. Passar o estilo ate `VideoEditor.startRender`.
3. Remover fallback fixo em `resolvedTranscriptStyle(for:)`.
4. Usar janela de palavras na geracao de render units.
5. Adicionar background highlight no export.
6. Cobrir comportamento com testes de helpers.

### Etapa 6: Documentacao e validacao

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

- Risco: submenu de estilos criar estado duplicado entre UI e snapshot.
  Mitigacao: usar `selectedStyleIdentifier` em `TranscriptDocument` como unica fonte persistida.

- Risco: highlight parcial no export ficar complexo.
  Mitigacao: entregar primeiro a janela de palavras e manter a cor base, depois adicionar destaque ativo por camada/rasterizacao com testes.

- Risco: background highlight no export gerar geometria diferente do preview.
  Mitigacao: compartilhar metrica base de texto/fundo entre preview e export sempre que possivel.

- Risco: regressao em snapshots antigos.
  Mitigacao: manter decode legado de `TranscriptStyle` e nao reintroduzir campos obrigatorios em `TranscriptDocument`.

## Criterios de aceite tecnicos

- O host consegue passar o provider de estilos via uma sessao dedicada de estilos em `VideoEditorConfiguration`.
- Sem provider, a transcricao continua igual ao comportamento atual.
- `wordsPerCaption` controla a quantidade de palavras visiveis no preview.
- `highlightsActiveWord` controla o destaque no preview.
- `activeWordBackgroundColor` controla o fundo da palavra ativa no preview.
- A tela de transcricoes exibe submenu de estilos com lista e preview.
- O estilo selecionado fica salvo em `selectedStyleIdentifier`.
- Export recebe o mesmo estilo resolvido do preview.
- `VideoEditingConfiguration` continua codavel sem provider e sem catalogo persistido.
- Testes de resolver, janela de palavras, preview layout, submenu de estilos e export helpers passam.
- Validacao iOS Simulator passa com `scripts/test-ios.sh`.
