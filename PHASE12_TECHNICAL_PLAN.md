# VideoEditorKit — Plano Técnico da Fase 12

## Objetivo

Fechar a regra de posicionamento de legenda com paridade real entre preview, drag e export.

Ao final da fase 12, o editor deve:

- resolver `top`, `middle` e `bottom` com a mesma semântica visual usada no export
- manter a caixa da legenda dentro do `safeFrame` no preview e no export
- converter presets para `.freeform` preservando a posição visual final
- escalar tipografia e caixa da legenda no preview de acordo com o render real

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

As duas skills orientam principalmente:

- manter a view SwiftUI fina, sem cálculo de layout pesado no `body`
- preservar a lógica de posicionamento em engine pura e testável
- usar APIs modernas de SwiftUI no overlay
- manter consistência visual, Dark Mode e acessibilidade básica

### Desvios documentados

- A skill `swiftui-pro` não estava disponível no caminho informado pelo ambiente durante esta execução. A implementação seguiu `swiftui-expert-skill` e manteve aderência ao padrão já estabelecido no projeto.
- O overlay continua usando `DragGesture` por necessidade funcional de reposicionamento direto. A conversão de coordenadas e o clamp permanecem fora da view.

## Problema que a fase 12 resolve

A fase 11 deixou o drag funcional, mas ainda existia uma divergência estrutural:

- o preview tratava o ponto resolvido da legenda como `center` em todos os modos
- o export tratava `top` e `bottom` com âncoras próprias e clamp por caixa
- o estilo do preview não era escalado pelo tamanho real do preview

Na prática, isso quebrava a regra principal do projeto: `Preview = Export`.

## Escopo da Fase 12

### 1. Fonte única de layout da legenda

Evoluir `CaptionPositionResolver` para também resolver:

- `frame` final da legenda no render
- medição de caixa com fonte e padding
- semântica de âncora por `placementMode`
- clamp final da caixa ao `safeFrame`

### 2. Preview alinhado ao export

Atualizar `VideoEditorPreviewBuilder` e `CaptionOverlayView` para:

- consumir `frame` resolvido em vez de apenas um ponto
- desenhar a legenda no preview com o mesmo envelope visual usado no export
- escalar fonte, padding e corner radius conforme a relação `displaySize / renderSize`

### 3. Drag alinhado ao layout final

Atualizar `CaptionDragEngine` para:

- converter o ponto do gesto para coordenada de render
- normalizar a nova posição
- reexecutar o resolver para persistir a posição final compatível com o frame clampado

### 4. Export sem lógica duplicada

Reduzir duplicação em `AVFoundationExportRenderer` para que a camada de export reuse o `frame` resolvido pela engine compartilhada.

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    CaptionPositionResolver.swift
    CaptionDragEngine.swift
    VideoEditorPreviewBuilder.swift
    AVFoundationExportRenderer.swift
  Models/
    VideoEditorPreviewSnapshot.swift
  UI/
    CaptionOverlayView.swift

VideoEditorKitTests/
  Core/
    CaptionPositionResolverTests.swift
    CaptionDragEngineTests.swift
    VideoEditorPreviewBuilderTests.swift
  Public/
    VideoEditorControllerEditingTests.swift
```

## Sequência TDD

1. ajustar testes de resolver, preview e drag para refletir a caixa real da legenda
2. confirmar quebra inicial da suíte relevante
3. implementar `resolveFrame` como fonte única de layout
4. migrar preview e export para o frame compartilhado
5. ajustar o drag para persistir a posição final compatível com o layout
6. rerodar a suíte relevante

## Critérios de aceite

- `top`, `middle` e `bottom` aparecem no preview com a mesma lógica visual do export
- o frame final da legenda permanece dentro do `safeFrame`
- iniciar drag em preset converte para `.freeform` sem salto visual
- o preview usa escala visual coerente com `renderSize`
- nenhuma regra de posicionamento fica duplicada entre preview e export

## Fora do escopo

- resize manual da legenda
- snapping magnético
- edição inline do texto
- animações de legenda
- testes de interface
