# VideoEditorKit — Plano Técnico da Fase 3

## Objetivo

Entregar a camada temporal de legendas que prepara preview, importação externa e próximas fases, cobrindo:

- filtragem de legendas ativas no tempo atual
- normalização de legendas para o `selectedTimeRange`
- remoção de legendas inválidas
- merge determinístico entre legendas atuais e novas legendas
- testes unitários que travem o comportamento antes das fases 4 e 7

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

Nesta fase, as skills servem como referência arquitetural, mesmo sem UI nova:

- manter regra de negócio fora de views
- preservar modelos puros e testáveis
- seguir Swift moderno e previsível
- evitar acoplamento prematuro com estado observável ou camada visual

Não houve desvio relevante das skills nesta fase, porque o escopo é exclusivamente de core.

## Dependências de entrada

A Fase 3 assume concluídos:

- `Caption`
- `CaptionPlacementMode`
- `CaptionPositionResolver`
- `CaptionSafeFrameResolver`
- `TimeRangeEngine`

## Escopo da Fase 3

### Modelos

Implementar:

- `CaptionApplyStrategy`

### Core

Implementar:

- `CaptionEngine`
- `CaptionMergeEngine`

### Testes

Cobrir pelo menos:

- legenda válida permanece inalterada após normalização
- legenda parcialmente fora do range é truncada
- legenda totalmente fora do range é removida
- legenda com texto vazio ou apenas espaços é removida
- legenda inválida após truncamento é removida
- `activeCaptions` respeita `selectedTimeRange`
- `activeCaptions` respeita o intervalo temporal da legenda
- `replaceAll`
- `append`
- `replaceIntersecting`
- fronteira tocando sem interseção não remove legenda existente

## Decisões de implementação

### 1. `CaptionEngine.normalizeCaptions`

Responsabilidade única:

- sanitizar a lista de legendas para um `selectedTimeRange`

Regras aplicadas por legenda:

1. se `text.trimmingCharacters(in: .whitespacesAndNewlines)` estiver vazio, remover
2. se `endTime <= selectedRange.lowerBound`, remover
3. se `startTime >= selectedRange.upperBound`, remover
4. caso contrário, truncar:
   - `startTime = max(startTime, selectedRange.lowerBound)`
   - `endTime = min(endTime, selectedRange.upperBound)`
5. se após truncamento `startTime >= endTime`, remover

Consequências:

- preview e export partem da mesma sanitização temporal
- a ordem original das legendas válidas é preservada
- a engine não altera estilo, posição ou placement mode

### 2. `CaptionEngine.activeCaptions`

Responsabilidades:

- reaproveitar a sanitização temporal da engine
- retornar apenas legendas visíveis no instante atual

Regra de atividade adotada:

- o tempo precisa estar dentro do `selectedTimeRange`
- a legenda está ativa quando `startTime <= time` e `time < endTime`

Essa escolha trata legendas como intervalos semiabertos, coerente com a regra de remoção por:

- `endTime <= lowerBound`
- `startTime >= upperBound`

Isso evita dupla exibição em fronteiras exatas entre duas legendas adjacentes.

### 3. `CaptionMergeEngine`

Responsabilidade única:

- combinar `incoming` e `existing` conforme a estratégia já decidida fora da engine

Contrato:

- `replaceAll`: retorna apenas `incoming`
- `append`: retorna `existing + incoming`
- `replaceIntersecting`: remove de `existing` apenas itens que intersectam temporalmente qualquer item de `incoming`, depois adiciona `incoming`

Interseção temporal:

```swift
existing.startTime < incoming.endTime &&
incoming.startTime < existing.endTime
```

Consequência:

- intervalos que apenas se tocam na borda não contam como interseção

### 4. Limite intencional desta fase

A ordem correta do pipeline no app continua sendo:

1. receber legendas externas
2. sanitizar pelo `selectedTimeRange`
3. aplicar merge
4. normalizar o resultado final

`CaptionMergeEngine` não recebe `selectedTimeRange` de propósito. Ele assume que a sanitização temporal é responsabilidade de `CaptionEngine` ou da camada que orquestra o fluxo.

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    CaptionEngine.swift
    CaptionMergeEngine.swift
  Models/
    CaptionApplyStrategy.swift

VideoEditorKitTests/
  Core/
    CaptionEngineTests.swift
    CaptionMergeEngineTests.swift
```

## Sequência TDD

1. criar testes de `CaptionEngine`
2. criar testes de `CaptionMergeEngine`
3. executar testes e observar falha inicial
4. implementar `CaptionApplyStrategy`
5. implementar o mínimo de `CaptionEngine`
6. implementar o mínimo de `CaptionMergeEngine`
7. executar a suíte completa até verde
8. revisar edge cases de fronteira temporal

## Contrato implementado

```swift
enum CaptionApplyStrategy: Equatable {
    case replaceAll
    case append
    case replaceIntersecting
}

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

struct CaptionMergeEngine {
    static func apply(
        incoming: [Caption],
        to existing: [Caption],
        strategy: CaptionApplyStrategy
    ) -> [Caption]
}
```

## Critérios de aceite

- `CaptionEngine` é puro e determinístico
- `CaptionMergeEngine` é puro e determinístico
- textos vazios nunca sobrevivem à normalização
- legendas nunca saem do `selectedTimeRange` após normalização
- merge preserva a ordem relativa de legendas mantidas
- interseções temporais em bordas exatas não removem legendas existentes

## Fora do escopo desta fase

- integração async com provider de captions
- seleção de legenda na UI
- updates de `EditorState`
- persistência por snapshot
- layout de vídeo ou export
