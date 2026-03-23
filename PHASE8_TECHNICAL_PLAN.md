# VideoEditorKit — Plano Técnico da Fase 8

## Objetivo

Entregar a camada de export efetivo do SDK, cobrindo:

- orquestração centralizada de export em `ExportEngine`
- congelamento determinístico do snapshot de export no início do processo
- aplicação consistente de `LayoutEngine`, `TimeRangeEngine` e `CaptionEngine`
- publicação de progresso durante o export
- bloqueio de export concorrente por instância
- integração do fluxo público via `VideoEditorController`

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

Nesta fase, as skills orientam principalmente:

- preservação de `@Observable` e `@MainActor` apenas na camada que impacta UI
- separação entre estado observável (`EditorState`) e lógica de export testável
- manutenção do princípio de UI fina, deixando o fluxo de export fora das views
- aderência a padrões modernos de concorrência em Swift 6

Não há desvio relevante das skills nesta fase.

## Dependências de entrada

A Fase 8 assume concluídos:

- `TimeRangeEngine`
- `LayoutEngine`
- `CaptionEngine`
- `CaptionPositionResolver`
- `CaptionSafeFrameResolver`
- `ProjectValidator`
- `VideoEditorController`
- `VideoEditorError`

## Escopo da Fase 8

### Core

Implementar:

- `ExportEngine`
- loader de asset via AVFoundation
- renderer de export via AVFoundation

### Modelos auxiliares

Implementar:

- snapshot runtime congelado para export
- request interno de render
- asset carregado com metadados necessários ao layout/export

### Integração pública

Implementar:

- `performExport(to:)` em `VideoEditorController`
- atualização de `editorState.exportState`
- forwarding de `onExportProgress`

### Testes

Cobrir pelo menos:

- bloqueio de export concorrente por instância
- sanitização de captions no snapshot congelado
- uso do `selectedTimeRange` resolvido no request interno
- falha correta para asset inválido
- publicação de progresso e estado final no controller
- uso de snapshot congelado mesmo com mutações posteriores no controller

## Decisões de implementação

### 1. `ExportEngine` será uma classe `@MainActor`

Contrato adotado:

```swift
@MainActor
final class ExportEngine {
    func export(
        project: VideoProject,
        destinationURL: URL,
        progressHandler: ExportProgressHandler?
    ) async throws -> URL
}
```

Motivo:

- a coordenação do fluxo permanece coerente com o restante do estado observável da lib
- o bloqueio de concorrência fica simples e determinístico
- loader e renderer continuam não isolados, então o trabalho pesado segue fora da UI

### 2. Snapshot congelado será runtime, não persistente

Modelo adotado:

- `sourceVideoURL`
- `preset`
- `gravity`
- `selectedTimeRange` já resolvido
- `captions` já sanitizadas

Motivo:

- a fase 8 precisa exportar, não serializar
- evita encode/decode desnecessário no hot path
- mantém explícito o dado realmente usado pelo renderer

### 3. `ProjectValidator` continua sendo a porta única de validação

Fluxo adotado:

1. carregar asset e duração
2. resolver `TimeRangeResult`
3. validar projeto
4. mapear bloqueios para `VideoEditorError`

Consequência:

- a fase 8 não duplica regra de duração, range ou sanitização
- warnings continuam centralizados para uso futuro pela UI

### 4. Layout de export usa o mesmo núcleo da fase 4

Decisão:

- o `containerSize` de export será o canvas final resolvido pelo preset
- `LayoutEngine.computeLayout` continua sendo a fonte única do transform

Consequência:

- preview e export seguem a mesma regra geométrica
- crop e gravity permanecem coerentes entre fases

### 5. Renderer AVFoundation fica atrás de protocolos pequenos

Contratos adotados:

```swift
protocol VideoAssetLoading {
    func loadAsset(from sourceVideoURL: URL) async throws -> LoadedVideoAsset
}

protocol VideoExportRendering {
    func export(
        request: ExportRenderRequest,
        progressHandler: ExportProgressHandler?
    ) async throws -> URL
}
```

Motivo:

- viabiliza TDD puro sem depender de arquivo de vídeo real nos testes
- permite inspecionar o request congelado
- isola AVFoundation da regra de negócio central

### 6. `VideoEditorController` só publica estado

Responsabilidades desta fase:

- impedir que um segundo export altere o estado do export em andamento
- publicar `.exporting(progress:)`, `.completed(URL)` e `.failed(VideoEditorError)`
- encaminhar progresso para `config.onExportProgress`

Consequência:

- a API pública fica pronta para a fase 9 sem colocar lógica nas views

## Pipeline final

1. receber `project` atual e `destinationURL`
2. bloquear concorrência na instância de `ExportEngine`
3. carregar asset e metadados
4. resolver `TimeRangeResult`
5. validar projeto
6. congelar snapshot runtime com captions sanitizadas
7. resolver layout final
8. montar composição AVFoundation
9. aplicar transform e overlays de legenda
10. exportar com progresso
11. publicar estado final no controller

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    ExportEngine.swift
    AVFoundationVideoAssetLoader.swift
    AVFoundationExportRenderer.swift
    VideoAssetLoading.swift
    VideoExportRendering.swift
  Models/
    FrozenExportProject.swift
    LoadedVideoAsset.swift
    ExportRenderRequest.swift
  Public/
    VideoEditorController.swift

VideoEditorKitTests/
  Core/
    ExportEngineTests.swift
  Public/
    VideoEditorControllerExportTests.swift
```

## Sequência TDD

1. escrever `ExportEngineTests`
2. escrever `VideoEditorControllerExportTests`
3. executar a suíte relevante e observar falha inicial
4. implementar modelos auxiliares e protocolos
5. implementar `ExportEngine`
6. integrar `performExport(to:)` no controller
7. rodar a suíte relevante até verde
8. revisar concorrência, progresso e snapshot congelado

## Critérios de aceite

- `ExportEngine` bloqueia export concorrente por instância
- o request de export usa snapshot congelado e captions sanitizadas
- `selectedTimeRange` efetivamente aplicado é o range resolvido
- asset inválido gera erro público consistente
- `VideoEditorController` publica progresso e estado final corretamente

## Fora do escopo desta fase

- UI de export
- cancelamento manual de export
- fila de múltiplos exports
- retry policy
- otimizações avançadas de renderização de legenda
