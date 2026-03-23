# VideoEditorKit — Plano Técnico da Fase 11

## Objetivo

Entregar a edição direta de legenda no preview, fechando o ciclo mínimo de manipulação visual do MVP sem quebrar a regra de `Preview = Export`.

Ao final da fase 11, a UI deve permitir:

- selecionar a legenda ativa diretamente sobre o preview
- destacar visualmente a legenda selecionada
- arrastar a legenda selecionada dentro do safe frame
- converter automaticamente legendas em preset para `.freeform` no primeiro drag
- manter a regra de negócio do reposicionamento fora das views

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

As duas skills guiam principalmente:

- composição de views pequenas, estáveis e com responsabilidades claras
- uso de APIs modernas (`Button`, `foregroundStyle`, `clipShape`)
- preservação de `@Observable` no estado de edição
- acessibilidade básica para seleção da legenda
- manutenção da lógica de interação em modelos e engines testáveis

### Desvios documentados

- `DragGesture` continuará sendo usado no overlay por necessidade funcional de posicionamento direto no preview. O gesto ficará restrito ao componente de legenda e toda a conversão de coordenadas será delegada para uma engine pura.
- Não será adotado Liquid Glass porque não foi solicitado e não agrega ao objetivo funcional desta fase.

## Problema que a fase 11 resolve

A fase 10 fechou preview, timeline e ações assíncronas, mas a legenda ainda é apenas leitura no preview.

Hoje existe uma lacuna objetiva:

- `EditorState.selectedCaptionID` ainda não é exposto como affordance visual
- legendas ativas não podem ser selecionadas nem reposicionadas pela UI
- a regra "drag em legenda com preset converte automaticamente para `.freeform`" ainda não está integrada ao fluxo real do editor

Isso deixa o editor visualmente incompleto para o caso principal de ajuste fino da legenda.

## Escopo da Fase 11

### 1. Engine pura de interação de legenda

Adicionar:

- `CaptionDragEngine`

Responsabilidades:

- converter ponto de drag no espaço do preview para coordenadas do render
- clamp do centro da legenda ao safe frame
- gerar a nova posição normalizada `0...1`
- converter a legenda para `.freeform` quando o drag começa em um preset

### 2. Mutations do controller

Adicionar no `VideoEditorController`:

- seleção explícita de legenda
- atualização de posição de legenda a partir do drag no preview

Regras:

- seleção inválida limpa `selectedCaptionID`
- drag de legenda desconhecida não altera o projeto
- drag bem-sucedido atualiza `project.captions` e mantém a legenda selecionada

### 3. Overlay interativo no preview

Evoluir `CaptionOverlayView` para:

- tratar cada legenda ativa como affordance interativa
- permitir seleção por toque
- destacar a legenda selecionada com borda visual
- propagar eventos de drag sem mover cálculo de layout para a view

### 4. Integração em `VideoEditorView`

`VideoEditorView` passa a:

- ligar `selectedCaptionID` ao overlay
- encaminhar seleção e drag para `VideoEditorController`
- preservar `Preview = Export`, usando `VideoEditorPreviewBuilder` e `CaptionSafeFrameResolver` como fonte de verdade

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    CaptionDragEngine.swift
  Public/
    VideoEditorController.swift
  UI/
    CaptionOverlayView.swift
    VideoEditorView.swift

VideoEditorKitTests/
  Core/
    CaptionDragEngineTests.swift
  Public/
    VideoEditorControllerEditingTests.swift
```

## Sequência TDD

1. escrever testes da engine de drag
2. estender testes do controller para seleção e reposicionamento
3. rodar a suíte relevante e confirmar falha inicial
4. implementar engine e mutations do controller
5. integrar o overlay interativo nas views SwiftUI
6. rodar a suíte novamente até verde

## Critérios de aceite

- tocar em uma legenda ativa seleciona a legenda correta
- a legenda selecionada recebe feedback visual claro
- drag atualiza a posição normalizada sem sair do safe frame
- legenda em `.preset` vira `.freeform` no primeiro drag
- nenhuma regra de conversão de coordenadas fica no `body`
- toda view alterada mantém `#Preview` funcional

## Fora do escopo

- edição de texto da legenda
- resize da caixa de legenda
- drag simultâneo de múltiplas legendas
- snapping magnético além do clamp no safe frame
- testes de interface
