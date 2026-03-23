# VideoEditorKit — Plano Técnico da Fase 1

## Objetivo

Entregar a base funcional da biblioteca para modelagem de projeto e regras temporais iniciais, cobrindo:

- modelos mínimos de domínio para o editor
- `ExportPreset` com regras centrais de duração e layout base
- `TimeRangeEngine` como fonte inicial de verdade para faixas válidas e clamp temporal
- `EditorState` com Observation e isolamento no `@MainActor`
- testes unitários para validar o comportamento antes da expansão para as próximas fases

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

As duas skills guiam especialmente:

- uso de `@Observable`
- isolamento de estado no `@MainActor`
- separação entre lógica testável e UI
- uso de APIs modernas de Swift
- manutenção de views leves

## Escopo da Fase 1

### Modelos

Implementar os tipos necessários para iniciar o domínio do editor:

- `VideoProject`
- `EditorState`
- `VideoEditorError`
- `VideoGravity`
- `ExportPreset`
- `CaptionSafeArea`
- `CaptionPlacementPreset`
- `CaptionPlacementMode`
- `Caption`
- `CaptionStyle`
- `CaptionState`
- `ExportState`
- `TimeRangeResult`

### Core

Implementar:

- `TimeRangeEngine`

### Testes

Cobrir pelo menos:

- `ExportPreset.title`
- `ExportPreset.minDuration`
- `ExportPreset.maxDuration`
- `ExportPreset.aspectRatio`
- `ExportPreset.resolve(videoSize:)`
- `TimeRangeEngine.resolve(...)` para `.original`
- `TimeRangeEngine.resolve(...)` para presets sociais
- `TimeRangeEngine.resolve(...)` para vídeo curto demais
- `TimeRangeEngine.resolve(...)` ao reduzir seleção inválida
- `TimeRangeEngine.clampTime(...)`

## Decisões de implementação

### Estrutura

Criar a base dentro da app atual com a estrutura:

```text
VideoEditorKit/
  Core/
    TimeRangeEngine.swift
  Models/
    ...
```

### Regras temporais

- `validRange` será `0...min(videoDuration, preset.maxDuration)` para presets limitados
- `original` usará `0...videoDuration`
- `selectedRange` será clampado ao `validRange`
- se o clamp colapsar a seleção para um ponto inválido por falta de interseção, o resultado volta para o `validRange`
- `isVideoTooShort` será verdadeiro quando `videoDuration < preset.minDuration`
- `exceedsMaximum` será verdadeiro quando `videoDuration > preset.maxDuration`

### Limites desta fase

- nenhuma lógica de layout além do necessário em `ExportPreset`
- nenhuma sanitização de legendas ainda
- nenhum fluxo assíncrono de captions
- nenhuma UI nova além da base existente

## Sequência TDD

1. criar testes de `ExportPreset`
2. criar testes de `TimeRangeEngine`
3. executar testes e observar falha inicial
4. implementar modelos e engine no menor conjunto possível
5. executar testes até verde
6. revisar a base criada para servir às Fases 2 e 3 sem retrabalho estrutural

## Critérios de aceite

- testes unitários da Fase 1 verdes
- `EditorState` usando `@Observable`
- `EditorState` isolado no `@MainActor`
- `TimeRangeEngine` sem dependência de UI
- `ExportPreset` concentrando regras básicas de preset
- estrutura de pastas preparada para as próximas fases
