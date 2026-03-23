# VideoEditorKit — Plano Técnico da Fase 2

## Objetivo

Entregar a base geométrica de legendas para preview e export, cobrindo:

- cálculo do frame seguro de legenda por preset
- resolução de posição efetiva para presets `top`, `middle` e `bottom`
- clamp de posições livres ao frame seguro
- testes unitários que travem o comportamento antes da Fase 3

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

Nesta fase, as skills orientam principalmente:

- consistência entre preview e export
- uso de modelos puros e testáveis
- decisões corretas de safe area
- aderência a comportamento nativo e previsível

## Dependências de entrada

A Fase 2 assume concluídos:

- `ExportPreset`
- `CaptionSafeArea`
- `Caption`
- `CaptionPlacementMode`
- `CaptionPlacementPreset`

## Escopo da Fase 2

### Core

Implementar:

- `CaptionSafeFrameResolver`
- `CaptionPositionResolver`

### Testes

Cobrir pelo menos:

- cálculo correto do safe frame em `.original`
- cálculo correto do safe frame em presets sociais
- pontos de preset para `top`
- pontos de preset para `middle`
- pontos de preset para `bottom`
- resolução de posição `.freeform` já dentro do safe frame
- clamp de posição `.freeform` fora do safe frame
- conversão de legenda preset para `.freeform` ao iniciar drag

## Decisões de implementação

### 1. `CaptionSafeFrameResolver`

Responsabilidade única:

- transformar `renderSize` e `CaptionSafeArea` em um `CGRect` seguro

Regra base:

```swift
CGRect(
    x: safeArea.leftInset,
    y: safeArea.topInset,
    width: max(0, renderSize.width - safeArea.leftInset - safeArea.rightInset),
    height: max(0, renderSize.height - safeArea.topInset - safeArea.bottomInset)
)
```

Consequências:

- o resultado sempre fica no espaço de coordenadas do frame final renderizado
- o cálculo é determinístico e independente de UI
- frames degenerados continuam representáveis e testáveis

### 2. `CaptionPositionResolver`

Responsabilidades:

- resolver o ponto real de uma legenda no frame final
- converter presets em pontos absolutos
- clamp de posição livre ao `safeFrame`

#### Presets

Regras:

- `top` usa `safeFrame.midX` e `safeFrame.minY`
- `middle` usa `safeFrame.midX` e `safeFrame.midY`
- `bottom` usa `safeFrame.midX` e `safeFrame.maxY`

Isso segue diretamente as regras do projeto:

- alinhamento horizontal central
- centro da legenda sempre dentro do `safeFrame`

#### Freeform

Regras:

- ler a posição da legenda e normalizar para o espaço do frame final
- clampar `x` e `y` aos limites do `safeFrame`
- retornar o ponto efetivo já seguro para preview e export

### 3. Nota de projeto sobre coordenadas normalizadas

Há uma tensão entre duas definições atuais:

- o projeto define coordenadas normalizadas no frame final renderizado
- a interface inicial de `CaptionPositionResolver.resolve` recebia apenas `caption` e `safeFrame`

Decisão aplicada na implementação da Fase 2:

- expandir a API do resolvedor para receber também o `renderSize`
- manter o `safeFrame` no espaço absoluto do frame final renderizado
- converter posição normalizada `0...1` em ponto absoluto antes do clamp

Essa mudança elimina ambiguidade entre preview e export e preserva a regra central do projeto sobre coordenadas normalizadas.

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    CaptionSafeFrameResolver.swift
    CaptionPositionResolver.swift

VideoEditorKitTests/
  Core/
    CaptionSafeFrameResolverTests.swift
    CaptionPositionResolverTests.swift
```

## Sequência TDD

1. criar testes de `CaptionSafeFrameResolver`
2. criar testes de `CaptionPositionResolver`
3. implementar o cálculo mínimo para fazer os testes falharem corretamente
4. ajustar a implementação até verde
5. revisar edge cases de clamp e degeneração de frame

## Contrato implementado

```swift
struct CaptionSafeFrameResolver {
    static func resolve(
        renderSize: CGSize,
        safeArea: CaptionSafeArea
    ) -> CGRect
}

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
```

Helper adicional usado para o fluxo de drag:

```swift
extension Caption {
    func beginningFreeformDrag(
        renderSize: CGSize,
        safeFrame: CGRect
    ) -> Caption
}
```

## Critérios de aceite

- `CaptionSafeFrameResolver` é puro e determinístico
- `CaptionPositionResolver` é puro e determinístico
- presets resolvem para pontos centrais corretos na safe area
- posição livre nunca sai do safe frame
- a base fica pronta para a Fase 3 sem mover regra geométrica para views

## Fora do escopo desta fase

- sanitização temporal de legendas
- merge de legendas
- drag gestures reais em SwiftUI
- layout completo de vídeo
- cálculo de tamanho visual do texto
