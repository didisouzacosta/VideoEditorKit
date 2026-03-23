# VideoEditorKit — Plano Técnico da Fase 7

## Objetivo

Entregar a camada central de validação e a integração assíncrona externa de legendas, cobrindo:

- validação única do projeto antes do export
- produção centralizada de `errors` e `warnings`
- contratos mínimos para ações externas de legenda
- aplicação determinística de captions recebidas do app host
- atualização segura de estado observável no `MainActor`
- testes unitários que travem as regras antes da fase 8

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

Nesta fase, as skills orientam principalmente:

- uso consistente de `@Observable` e `@MainActor` para estado que impacta UI
- separação entre lógica de negócio testável e camada SwiftUI futura
- manutenção do princípio de callbacks async desacoplados de provider
- preservação da regra de UI fina, deixando merge, sanitização e validação fora das views

Não há desvio relevante das skills nesta fase.

## Dependências de entrada

A Fase 7 assume concluídos:

- `VideoProject`
- `EditorState`
- `Caption`
- `CaptionStyle`
- `CaptionEngine`
- `CaptionMergeEngine`
- `TimeRangeEngine`
- `TimeRangeResult`
- `SnapshotCoder`
- `VideoEditorError`

## Escopo da Fase 7

### Modelos

Implementar:

- `ValidationResult`
- `CaptionRequestContext`
- `CaptionAction`
- `VideoEditorConfig`
- `VideoEditorController`

### Core

Implementar:

- `ProjectValidator`

### Testes

Cobrir pelo menos:

- projeto válido exporta sem erros
- vídeo curto demais para o preset bloqueia export
- `selectedTimeRange` divergente do range resolvido bloqueia export
- vídeo acima do máximo gera warning de truncamento
- captions que seriam truncadas/removidas geram warning
- fonte inexistente gera warning de fallback
- callback externo ausente falha com erro controlado
- callback async aplica captions com sanitização
- `CaptionApplyStrategy` afeta corretamente o resultado final
- seleção ativa é limpa quando a legenda selecionada deixa de existir
- erro do provider vira `captionProviderFailed`
- chamada concorrente de caption action é bloqueada

## Decisões de implementação

### 1. `ProjectValidator` retorna diagnóstico, não exceção

Contrato adotado:

```swift
struct ProjectValidator {
    static func validateProject(
        project: VideoProject,
        videoDuration: Double,
        timeRange: TimeRangeResult
    ) -> ValidationResult
}
```

Motivo:

- o export da fase 8 poderá decidir como mapear `errors` para `VideoEditorError`
- a UI da fase 9 poderá exibir warnings sem duplicar regra

### 2. Resultado de validação é pequeno e determinístico

`ValidationResult` terá:

- `canExport`
- `warnings`
- `errors`

Regra:

- `canExport` é derivado da ausência de erros

Consequência:

- o contrato fica impossível de representar em estado inconsistente

### 3. Validação central cobre bloqueios e avisos do roadmap

Bloqueiam export:

- asset/source inválido
- duração inválida
- vídeo curto demais para o preset
- `selectedTimeRange` inválido para o range resolvido

Geram warning:

- vídeo será truncado pelo preset
- captions precisarão ser sanitizadas pelo range selecionado
- fonte inexistente usará fallback

### 4. Integração de captions continua totalmente desacoplada de IA

Contrato adotado:

```swift
struct VideoEditorConfig {
    var onCaptionAction: ((CaptionAction, CaptionRequestContext) async throws -> [Caption])?
    var captionApplyStrategy: CaptionApplyStrategy
    var onExportProgress: ((Double) -> Void)?
}
```

Consequência:

- a biblioteca continua sem conhecer provider, prompt, transcrição ou tradução
- o app host mantém total controle sobre a origem das captions

### 5. `VideoEditorController` centraliza o fluxo async de captions

Responsabilidades desta fase:

- impedir chamadas concorrentes de caption action
- publicar `captionState`
- montar `CaptionRequestContext`
- sanitizar captions recebidas com `CaptionEngine`
- aplicar `CaptionApplyStrategy`
- normalizar o resultado final
- limpar `selectedCaptionID` se a legenda sumir

Decisão:

- o método async recebe `videoDuration` como argumento

Motivo:

- evita acoplar a fase 7 diretamente ao `PlayerEngine`
- a fase 8/9 poderá fornecer a duração real já carregada

### 6. Pipeline de captions externas é fixo

Ordem adotada:

1. chamar callback externo
2. sanitizar incoming pelo `selectedTimeRange`
3. aplicar strategy sobre captions atuais
4. normalizar o conjunto final novamente
5. atualizar `project.captions`
6. validar `selectedCaptionID`

Consequência:

- o comportamento fica previsível mesmo quando existirem captions antigas inválidas

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    ProjectValidator.swift
  Models/
    ValidationResult.swift
    CaptionRequestContext.swift
    CaptionAction.swift
    VideoEditorConfig.swift
  Public/
    VideoEditorController.swift

VideoEditorKitTests/
  Core/
    ProjectValidatorTests.swift
  Public/
    VideoEditorControllerCaptionActionTests.swift
```

## Sequência TDD

1. escrever `ProjectValidatorTests`
2. executar a suíte relevante e observar falha inicial
3. implementar `ValidationResult` e `ProjectValidator`
4. escrever testes de caption action do controller
5. implementar `CaptionRequestContext`, `CaptionAction`, `VideoEditorConfig` e `VideoEditorController`
6. rodar a suíte relevante até verde
7. revisar regras de concorrência e sanitização final

## Critérios de aceite

- `ProjectValidator` concentra bloqueios e warnings do roadmap
- o resultado de validação é determinístico e testável
- captions externas passam por sanitização antes e depois da strategy
- provider ausente ou com falha gera erro público consistente
- `captionState` reflete loading, idle e failure no `MainActor`
- seleção ativa não aponta para legenda removida

## Fora do escopo desta fase

- export efetivo de arquivo
- composição AVFoundation
- UI de botões de caption
- transcrição, tradução ou provider embutido
- retry policy, cancelamento manual ou fila de ações de caption
