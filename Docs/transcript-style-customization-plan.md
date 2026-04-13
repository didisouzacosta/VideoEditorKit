# Plano de Customizacao de Estilos de Transcricao

## Objetivo

Criar uma API simples, protocol-based, para que o app host que adota `VideoEditorKit` consiga definir o estilo das transcricoes sem depender de uma UI interna para criar ou editar estilos.

O plano tecnico detalhado esta documentado em [`Docs/transcript-style-customization-technical-plan.md`](transcript-style-customization-technical-plan.md).

O estilo atual continua sendo o fallback do package:

- fonte branca
- contorno preto
- alinhamento centralizado
- exibicao de uma palavra por vez

A evolucao deve permitir que o host controle:

- fonte e peso
- cor do texto
- contorno, cor e espessura do contorno
- alinhamento
- quantidade de palavras exibidas por vez
- destaque visual da palavra ativa
- cor de fundo da palavra ativa
- lista de estilos fornecidos pelo host para selecao no editor

## Estado atual relevante

O package ja tem uma base publica de transcricao:

- `VideoEditorConfiguration.TranscriptionConfiguration` injeta o provider de transcricao.
- `VideoEditorConfiguration` ainda nao tem uma sessao dedicada para estilos de transcricao.
- `TranscriptStyle` modela parte do estilo visual atual.
- `TranscriptTextStyleResolver` resolve atributos de texto para preview e export.
- `TranscriptOverlayLayoutResolver` calcula geometria de preview e export.
- `TranscriptOverlayPreview` renderiza o overlay no player.
- `VideoEditor` recria o overlay na exportacao com `CALayer`.

O gap atual e que a escolha de estilo ainda nao e uma politica host-facing:

- `PlayerHolderView` passa `style: nil` para `TranscriptOverlayPreview`.
- `VideoEditor.resolvedTranscriptStyle(for:)` sempre retorna `.defaultCaptionStyle`.
- a estrategia de exibicao de palavras fica acoplada ao modo atual de palavra ativa.
- `TranscriptToolView` hoje so expoe posicao e tamanho na secao layout.
- os campos legados de estilo em `TranscriptDocument` sao ignorados para compatibilidade.

## Decisao de arquitetura

Adicionar uma fronteira publica baseada em protocolos, mas resolver essa fronteira para um modelo concreto antes de entrar nos caminhos de preview/export.

Isso evita que existentials ou tipos do host vazem para:

- snapshots codaveis
- layout puro
- renderizacao com Core Animation
- testes de geometria

Direcao proposta:

```swift
public protocol VideoTranscriptStyleProvider: Sendable {
    func transcriptStyles(
        for context: VideoTranscriptStyleContext
    ) -> [any VideoTranscriptStyleModel]

    func defaultStyleIdentifier(
        for context: VideoTranscriptStyleContext
    ) -> String?
}

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

O package deve converter o modelo do host para:

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

## API publica proposta

### Provider

O host implementa um provider pequeno:

```swift
struct BrandTranscriptStyleProvider: VideoTranscriptStyleProvider {
    func transcriptStyles(
        for context: VideoTranscriptStyleContext
    ) -> [any VideoTranscriptStyleModel] {
        [
            BrandTranscriptStyle(),
            BrandCompactTranscriptStyle(),
        ]
    }

    func defaultStyleIdentifier(
        for context: VideoTranscriptStyleContext
    ) -> String? {
        BrandTranscriptStyle().identifier
    }
}
```

### Modelo

O host implementa o modelo de estilo:

```swift
struct BrandTranscriptStyle: VideoTranscriptStyleModel {
    let identifier = "brand.default"
    let displayName = "Brand Default"
    let font = VideoTranscriptFontDescriptor.custom(
        name: "AvenirNext-Heavy",
        fallbackWeight: .heavy
    )
    let textColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    let textAlignment = TranscriptTextAlignment.center
    let stroke = VideoTranscriptStroke(
        color: RGBAColor(red: 0, green: 0, blue: 0, alpha: 1),
        width: 4
    )
    let wordsPerCaption = 3
    let highlightsActiveWord = true
    let activeWordTextColor = RGBAColor(red: 1, green: 0.92, blue: 0.2, alpha: 1)
    let activeWordBackgroundColor = RGBAColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 0.82)
}
```

### Configuracao

Adicionar uma sessao dedicada de estilos na configuracao do editor:

```swift
let configuration = VideoEditorConfiguration(
    transcriptStyles: .init(
        provider: BrandTranscriptStyleProvider()
    ),
    transcription: .init(
        provider: MyTranscriptionProvider(),
        preferredLocale: "pt-BR"
    )
)
```

Os estilos continuam sendo definidos pelo host. O `VideoEditorKit` nao precisa oferecer uma UI para criar ou editar estilos, mas deve exibir uma UI para selecionar entre os estilos fornecidos pelo host.

## Modelo de dados recomendado

Novos tipos publicos:

- `VideoTranscriptStyleProvider`
- `VideoTranscriptStyleModel`
- `VideoTranscriptStyleContext`
- `VideoTranscriptFontDescriptor`
- `VideoTranscriptStroke`
- `ResolvedTranscriptStyle`
- `TranscriptWordDisplayPolicy` se a equipe preferir modelar `wordsPerCaption` como enum em vez de `Int`

Regras:

- `wordsPerCaption` deve ser normalizado para um intervalo seguro, por exemplo `1...8`.
- `wordsPerCaption == 1` preserva o comportamento atual.
- `highlightsActiveWord == false` renderiza todas as palavras visiveis com o estilo base.
- `activeWordTextColor == nil` usa `textColor` mesmo quando `highlightsActiveWord == true`.
- `activeWordBackgroundColor == nil` desabilita a marcacao de fundo da palavra ativa.
- fonte customizada deve cair para fonte system quando o nome nao existir no runtime.
- o provider nao deve ser codificado dentro de `VideoEditingConfiguration`.
- o identificador do estilo selecionado deve ser persistido por projeto.

## Fluxo de preview

1. `VideoEditorView` recebe `VideoEditorConfiguration`.
2. A runtime config resolve o catalogo do `VideoTranscriptStyleProvider` a partir de `configuration.transcriptStyles`.
3. `EditorViewModel` ou um coordinator dedicado guarda os estilos resolvidos da sessao e o estilo selecionado.
4. `PlayerHolderView` passa o estilo resolvido selecionado para `TranscriptOverlayPreview`.
5. `TranscriptOverlayLayoutResolver` recebe `wordsPerCaption` e monta uma janela de palavras ao redor da palavra ativa.
6. `TranscriptOverlayPreview` renderiza:
   - a palavra ativa isolada quando `wordsPerCaption == 1`
   - a janela de palavras quando `wordsPerCaption > 1`
   - destaque da palavra ativa apenas quando `highlightsActiveWord == true`
   - fundo colorido da palavra ativa quando `activeWordBackgroundColor != nil`

## Fluxo de selecao no editor

Na tela de transcricoes, a secao `Layout` deve ganhar um submenu de estilos.

Esse submenu deve:

- listar todos os estilos fornecidos pelo host
- mostrar um exemplo visual de cada estilo
- destacar o estilo atualmente selecionado
- aplicar a selecao imediatamente no preview
- persistir apenas o `selectedStyleIdentifier`

Se o provider nao retornar estilos, o submenu nao aparece e o fallback default continua ativo.

## Fluxo de exportacao

O export precisa receber exatamente a mesma configuracao resolvida usada no preview.

Direcao recomendada:

- evoluir a entrada de export para carregar o estilo selecionado e o catalogo resolvido quando necessario
- remover o fallback interno fixo em `resolvedTranscriptStyle(for:)`
- fazer `resolvedTranscriptRenderUnits` agrupar palavras por janela, nao apenas por palavra individual
- manter um unico helper puro para gerar os render units usados por preview e export sempre que possivel

Essa etapa e importante porque a paridade preview/export ainda nao e centralizada no projeto atual.

## Agrupamento de palavras

Adicionar um resolvedor puro, testavel, por exemplo:

```swift
enum TranscriptWordWindowResolver {
    static func resolve(
        words: [EditableTranscriptWord],
        activeWordID: EditableTranscriptWord.ID?,
        wordsPerCaption: Int
    ) -> [EditableTranscriptWord]
}
```

Regras:

- com `wordsPerCaption == 1`, retornar apenas a palavra ativa.
- com `wordsPerCaption > 1`, retornar uma janela estavel contendo a palavra ativa.
- preferir preencher palavras antes e depois da ativa sem trocar a janela a cada frame quando isso causar flicker.
- se nao houver `activeWordID`, usar uma janela inicial ou cair para o bloco do segmento.
- ignorar palavras vazias.

## Persistencia

Como nao ha UI de selecao de estilo, o primeiro passo nao precisa persistir estilos customizados por projeto.

Regras recomendadas:

- o provider continua sendo uma dependencia runtime do host.
- `VideoEditingConfiguration` guarda o texto/transcricao, posicao/tamanho do overlay e o identificador do estilo selecionado.
- a lista de estilos continua vindo do host, nunca do snapshot persistido.
- manter compatibilidade com os campos legados de estilo em `TranscriptDocument`.

## Testes obrigatorios

Usar Swift Testing.

Cobertura minima:

- normalizacao de `wordsPerCaption`.
- fallback para `.defaultCaptionStyle` quando nao ha provider.
- resolucao de catalogo vazio para fallback default.
- resolucao de fonte customizada com fallback seguro.
- preview render plan para `wordsPerCaption == 1`.
- preview render plan para `wordsPerCaption > 1`.
- destaque ativo ligado e desligado.
- fundo ativo ligado e desligado.
- export render units agrupados pela mesma politica do preview.
- compatibilidade de decode de snapshots antigos com campos legados de estilo.
- persistencia de `selectedStyleIdentifier`.
- submenu de estilos renderizando lista com preview.
- validacao de que `VideoEditingConfiguration` nao tenta codificar o provider.

Validacao oficial:

```bash
scripts/format-swift.sh
scripts/test-ios.sh
```

Para agentes com `xcodebuildmcp`, preferir `build_sim` e `test_sim`.

## Plano incremental

### Fase 1: Contratos publicos

- criar os protocolos e modelos concretos resolvidos.
- adicionar uma sessao `VideoEditorConfiguration.TranscriptStyleConfiguration`.
- manter fallback para o estilo atual.
- persistir `selectedStyleIdentifier`.
- adicionar testes de normalizacao e fallback.

### Fase 2: Preview

- passar o estilo resolvido ate `TranscriptOverlayPreview`.
- criar `TranscriptWordWindowResolver`.
- atualizar `TranscriptOverlayLayoutResolver` para aceitar politica de palavras visiveis.
- adicionar o submenu de estilos dentro da secao `Layout` da tela de transcricoes.
- renderizar preview por item da lista usando os estilos do host.
- cobrir preview com testes unitarios de layout.

### Fase 3: Export

- passar o estilo resolvido para o pipeline de exportacao.
- substituir `resolvedTranscriptStyle(for:)` fixo.
- agrupar render units conforme `wordsPerCaption`.
- suportar highlight com cor de fundo da palavra ativa.
- cobrir preview/export com testes do mesmo resolvedor puro.

### Fase 4: Documentacao

- atualizar `README.md` com exemplos de provider e modelo.
- atualizar a documentacao DocC com os novos tipos publicos.
- documentar que a customizacao nao aparece como UI interna do editor.

### Fase 5: Limpeza

- remover constantes de highlight que ficarem duplicadas depois do modelo novo.
- garantir que `TranscriptStyle` antigo continue decodificando snapshots legados.
- rodar formatter e validacao iOS Simulator.

## Criterios de aceite

- O host consegue customizar fonte, cor, stroke, alinhamento, quantidade de palavras visiveis, destaque ativo e fundo da palavra ativa implementando protocolos publicos dentro de uma sessao dedicada de estilos.
- O editor continua funcionando sem nenhuma configuracao extra.
- A UI do VideoEditorKit exibe um submenu de selecao de estilos, mas nao cria nem edita estilos.
- Preview e export usam a mesma politica resolvida.
- O estilo selecionado permanece salvo por projeto.
- Snapshots antigos continuam carregando.
- Os testes iOS passam no scheme oficial.
