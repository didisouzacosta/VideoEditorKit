# VideoEditorKit — Plano Técnico da Fase 6

## Objetivo

Entregar a infraestrutura de persistência por snapshot da biblioteca, cobrindo:

- serialização determinística do projeto de edição para tipos `Codable`
- reconstrução segura do runtime a partir de snapshots persistidos
- isolamento dos tipos persistíveis em uma camada própria, sem dependência de `URL`, `CGPoint`, `UIColor` ou `UIFont`
- falha consistente com `snapshotDecodingFailed` quando o snapshot estiver inválido
- testes unitários que travem o contrato antes das fases 7 e 8

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

Nesta fase, as skills orientam principalmente:

- separação clara entre estado/runtime e tipos de persistência
- uso de Swift moderno com tipos pequenos, previsíveis e testáveis
- manutenção do princípio de UI fina e lógica fora das views
- preservação de decisões arquiteturais que serão consumidas por SwiftUI na fase 9

Não há desvio relevante das skills nesta fase, porque o escopo continua concentrado em core, modelos de valor e validação de dados.

## Dependências de entrada

A Fase 6 assume concluídos:

- `VideoProject`
- `Caption`
- `CaptionStyle`
- `ExportPreset`
- `VideoGravity`
- `CaptionPlacementMode`
- `CaptionPlacementPreset`
- `TimeRangeEngine`
- `PlayerEngine`
- `VideoEditorError`

## Escopo da Fase 6

### Persistence

Implementar:

- `VideoProjectSnapshot`
- `CaptionSnapshot`
- `CaptionPositionSnapshot`
- `CaptionStyleSnapshot`
- `ExportPresetSnapshot`
- `VideoGravitySnapshot`
- `CaptionPlacementModeSnapshot`
- `CaptionPlacementPresetSnapshot`

### Core

Implementar:

- `SnapshotCoder`
- `VideoProjectSnapshotCoding`

### Testes

Cobrir pelo menos:

- runtime → snapshot preservando:
  - `sourceVideoPath`
  - `preset`
  - `gravity`
  - `selectedTimeRange`
  - `placementMode`
  - `position`
  - `style`
- snapshot → runtime reconstruindo corretamente o projeto
- round-trip `project -> data -> project`
- falha ao reconstruir snapshot com:
  - caminho vazio
  - cor inválida
  - posição normalizada fora de `0...1`
  - range temporal inválido

## Decisões de implementação

### 1. Snapshots como camada pura de persistência

Decisão:

- todo tipo persistível fica em `Persistence/`
- snapshots usam apenas `String`, `Double`, `UUID`, arrays e enums `Codable`

Consequência:

- a persistência fica independente de UIKit e CoreGraphics no payload
- o app host poderá serializar snapshots em JSON sem depender de tipos gráficos

### 2. `sourceVideoURL` vira `sourceVideoPath`

Decisão:

- o runtime continua usando `URL`
- o snapshot persiste apenas `sourceVideoPath: String`

Consequência:

- o payload não depende de `URL`
- `SnapshotCoder` passa a ser responsável por converter entre `URL(fileURLWithPath:)` e `String`
- runtime com `URL` não persistível para arquivo local falha com `snapshotEncodingFailed`

### 3. Enums de snapshot independentes do runtime

Decisão:

- `ExportPreset`, `VideoGravity`, `CaptionPlacementMode` e `CaptionPlacementPreset` terão equivalentes `Codable` próprios

Motivo:

- isso evita acoplar a estabilidade do payload à evolução futura dos tipos de runtime

Consequência:

- o contrato persistido fica explícito
- migrações futuras podem ser tratadas na borda de conversão, sem contaminar o domínio

### 4. Cor persistida em hexadecimal

Decisão:

- `CaptionStyleSnapshot` persiste cores como `String` em hexadecimal RGBA

Regras:

- `textColorHex` é obrigatório
- `backgroundColorHex` é opcional
- a codificação gera formato uppercase de 8 dígitos
- a decodificação aceita payload válido e falha com `snapshotDecodingFailed` para cor malformada

Consequência:

- o snapshot continua puro
- a reconstrução preserva alpha sem depender de archiving de `UIColor`

### 5. Validação local nesta fase, extração na fase 7

Decisão:

- `SnapshotCoder` faz a validação mínima necessária para reconstruir o runtime com segurança

Regras validadas:

- `sourceVideoPath` não vazio
- `selectedTimeRange` finito e ordenado
- tempos das captions finitos e com `startTime < endTime`
- `normalizedX` e `normalizedY` dentro de `0...1`
- métricas de estilo finitas e não negativas
- cores decodificáveis

Consequência:

- a regra “snapshot → runtime sempre passa por validação” já começa a valer na Fase 6
- a Fase 7 poderá centralizar e expandir essa validação em `ProjectValidator` sem quebrar o contrato

### 6. `SnapshotCoder` como fronteira de conversão e serialização

Contrato adotado:

```swift
protocol VideoProjectSnapshotCoding {
    func makeSnapshot(from project: VideoProject) throws -> VideoProjectSnapshot
    func makeProject(from snapshot: VideoProjectSnapshot) throws -> VideoProject
}

struct SnapshotCoder: VideoProjectSnapshotCoding {
    func makeSnapshot(from project: VideoProject) throws -> VideoProjectSnapshot
    func makeProject(from snapshot: VideoProjectSnapshot) throws -> VideoProject
    func encode(_ project: VideoProject) throws -> Data
    func decodeProject(from data: Data) throws -> VideoProject
    func encode(snapshot: VideoProjectSnapshot) throws -> Data
    func decodeSnapshot(from data: Data) throws -> VideoProjectSnapshot
}
```

Consequência:

- a fase cobre tanto conversão de modelos quanto codificação real em `Data`
- export e persistência futura podem congelar snapshots sem lógica duplicada

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    SnapshotCoder.swift
  Persistence/
    VideoProjectSnapshot.swift
    CaptionSnapshot.swift
    CaptionPositionSnapshot.swift
    CaptionStyleSnapshot.swift
    ExportPresetSnapshot.swift
    VideoGravitySnapshot.swift
    CaptionPlacementModeSnapshot.swift
    CaptionPlacementPresetSnapshot.swift
    VideoProjectSnapshotCoding.swift

VideoEditorKitTests/
  Core/
    SnapshotCoderTests.swift
```

## Sequência TDD

1. criar `SnapshotCoderTests`
2. executar os testes e observar falha inicial
3. implementar snapshots `Codable`
4. implementar o mínimo de `SnapshotCoder`
5. executar a suíte relevante até verde
6. revisar regras de validação e round-trip

## Critérios de aceite

- o projeto pode ser serializado para `Data` sem carregar tipos gráficos no payload
- `SnapshotCoder` reconstrói o runtime preservando preset, gravity, range, placement mode, posição e style
- snapshot inválido falha com `snapshotDecodingFailed`
- snapshots ficam isolados em `Persistence/`
- a suíte unitária da fase 6 cobre round-trip e casos inválidos principais

## Fora do escopo desta fase

- migração/versionamento de snapshot
- persistência em disco
- `ProjectValidator` completo
- export efetivo usando snapshot congelado
- UI para salvar ou restaurar projeto
