# VideoEditorKit — Plano Técnico da Fase 4

## Objetivo

Entregar a base de layout única para preview e export, cobrindo:

- aplicação da orientação real do vídeo via metadata
- cálculo determinístico de `fit` e `fill`
- definição consistente do canvas final por preset
- geração de transform para export coerente com o preview
- testes unitários que travem o comportamento antes das fases 5, 8 e 9

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

Nesta fase, as skills servem como referência arquitetural mesmo sem UI nova:

- preservar regra de negócio e geometria fora de views
- manter a engine pura e testável
- evitar dependência de UIKit ou `AVAssetTrack` dentro da API central
- garantir uma base única para preview, safe area e export

Não há desvio relevante das skills nesta fase, porque o escopo continua concentrado em core e modelos de valor.

## Dependências de entrada

A Fase 4 assume concluídos:

- `ExportPreset`
- `VideoGravity`
- `CaptionSafeFrameResolver`
- `CaptionPositionResolver`
- `CaptionEngine`

## Escopo da Fase 4

### Modelos

Implementar:

- `LayoutResult`

### Core

Implementar:

- `LayoutEngine`

### Testes

Cobrir pelo menos:

- `fit` em canvas vertical
- `fill` em canvas vertical
- `original` preservando o aspect ratio orientado do vídeo
- preset social usando render size fixo
- orientação real aplicada por `preferredTransform`
- `transform` final produzindo o mesmo enquadramento esperado no export

## Decisões de implementação

### 1. `LayoutResult`

Responsabilidade:

- encapsular o resultado geométrico necessário para preview e export

Contrato:

- `videoFrame`: frame do vídeo no espaço do canvas de preview recebido em `containerSize`
- `renderSize`: tamanho final do canvas de export para o preset atual
- `transform`: transformação do vídeo original para o espaço do `renderSize`

Consequência:

- preview e export passam a compartilhar a mesma lógica de enquadramento, variando apenas a escala do canvas de destino

### 2. `LayoutEngine.computeLayout`

Responsabilidade única:

- resolver um layout coerente para preview e export a partir do mesmo conjunto de regras

API adotada:

```swift
struct LayoutEngine {
    static func computeLayout(
        videoSize: CGSize,
        containerSize: CGSize,
        preset: ExportPreset,
        gravity: VideoGravity,
        preferredTransform: CGAffineTransform = .identity
    ) -> LayoutResult
}
```

Nota:

- o `preferredTransform` entra como parâmetro opcional/default para atender a regra de orientação real por metadata sem acoplar a engine a `AVAssetTrack`
- isso preserva a API original da fase para chamadas simples e adiciona o dado mínimo necessário para export correto

### 3. Canvas de preview vs canvas de export

Decisão:

- `containerSize` representa o canvas de preview já decidido pela camada de UI
- `renderSize` representa o canvas final de export definido pelo preset

Consequência:

- a engine não decide layout de tela
- a UI continua fina e só informa qual é o canvas de preview disponível
- o mesmo algoritmo de enquadramento é aplicado duas vezes:
  - uma para preview (`containerSize`)
  - outra para export (`renderSize`)

### 4. Orientação real

Regra:

- o vídeo sempre começa no `videoSize` original
- `preferredTransform` é aplicado para obter o bounding box orientado
- o tamanho orientado é derivado do retângulo transformado e normalizado

Consequência:

- vídeos gravados em portrait com `naturalSize` landscape passam a ter layout correto sem lógica duplicada em preview/export

### 5. Regra de escala

Para um alvo qualquer (`containerSize` ou `renderSize`):

- `fit`: usa `min(target.width / oriented.width, target.height / oriented.height)`
- `fill`: usa `max(target.width / oriented.width, target.height / oriented.height)`

Depois:

- centralizar no canvas
- permitir origem negativa em `fill`, pois isso representa crop real

### 6. Regra do transform final

Pipeline aplicado ao vídeo original:

1. aplicar `preferredTransform`
2. traduzir para que o bounding box orientado comece em `(0, 0)`
3. aplicar a escala calculada para `renderSize`
4. traduzir para o frame final dentro do canvas de export

Consequência:

- o rect transformado do vídeo original coincide com o enquadramento esperado no export
- preview e export compartilham o mesmo crop lógico

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    LayoutEngine.swift
  Models/
    LayoutResult.swift

VideoEditorKitTests/
  Core/
    LayoutEngineTests.swift
```

## Sequência TDD

1. criar testes de `LayoutEngine`
2. executar testes e observar falha inicial
3. implementar `LayoutResult`
4. implementar o mínimo de `LayoutEngine`
5. executar a suíte completa até verde
6. revisar edge cases de rotação e crop

## Contrato implementado

```swift
struct LayoutResult: Equatable {
    let videoFrame: CGRect
    let renderSize: CGSize
    let transform: CGAffineTransform
}

struct LayoutEngine {
    static func computeLayout(
        videoSize: CGSize,
        containerSize: CGSize,
        preset: ExportPreset,
        gravity: VideoGravity,
        preferredTransform: CGAffineTransform = .identity
    ) -> LayoutResult
}
```

## Critérios de aceite

- `LayoutEngine` é puro e determinístico
- `renderSize` reflete corretamente o preset atual
- `videoFrame` respeita `fit` e `fill` no canvas de preview
- vídeos com metadata de rotação produzem layout orientado corretamente
- `transform` do export gera o mesmo enquadramento lógico do preview

## Fora do escopo desta fase

- leitura direta de `AVAsset` ou `AVAssetTrack`
- composição de `AVMutableVideoComposition`
- safe area de legenda aplicada em views
- player, scrub e timeline
- export efetivo de arquivo
