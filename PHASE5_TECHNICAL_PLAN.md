# VideoEditorKit — Plano Técnico da Fase 5

## Objetivo

Entregar o contrato temporal observável que permitirá à timeline e ao preview dependerem de uma única fonte de verdade de playhead, cobrindo:

- publicação de `currentTime`, `duration` e `isPlaying`
- `seek` sempre clampado ao `selectedTimeRange`
- reação imediata a mudanças de range
- parada do playback ao atingir o fim do range selecionado
- carregamento de duração real via `AVAsset`
- testes unitários que travem o comportamento antes das fases 8 e 9

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

Nesta fase, as skills orientam principalmente:

- uso correto de `@Observable` e `@MainActor`
- separação entre estado observável e regra temporal testável
- Swift moderno com APIs async do sistema
- evitar lógica temporal em views futuras

Não há desvio relevante das skills nesta fase.

## Dependências de entrada

A Fase 5 assume concluídos:

- `TimeRangeEngine`
- `TimeRangeResult`
- `EditorState`
- `VideoEditorError`

## Escopo da Fase 5

### Core

Implementar:

- `PlayerEngine`

### Testes

Cobrir pelo menos:

- `load(duration:)` publica a duração
- `seek` abaixo do range vai para `lowerBound`
- `seek` acima do range vai para `upperBound`
- `seek` dentro do range preserva o valor
- ao reduzir `selectedTimeRange`, `currentTime` é clampado imediatamente
- ao expandir o range de volta para `original`, `currentTime` não é expandido automaticamente
- update de playback não ultrapassa `selectedTimeRange.upperBound`
- ao atingir o fim do range, playback pausa

## Decisões de implementação

### 1. `PlayerEngine` como estado observável central

Contrato base:

```swift
@MainActor
@Observable
final class PlayerEngine {
    var currentTime: Double = 0
    var duration: Double = 0
    var isPlaying: Bool = false
}
```

Motivo:

- a fase 9 poderá ligar timeline e preview diretamente nesse estado sem duplicar playhead em view state

### 2. Range selecionado interno e consumido, não decidido

Decisão:

- a engine armazena internamente o `selectedTimeRange` mais recente apenas para conseguir aplicar clamp consistente
- a origem do range continua externa (`TimeRangeEngine` e estado do projeto)

Consequência:

- `PlayerEngine` continua consumindo o range já resolvido
- `play()` e updates de playback conseguem respeitar o limite superior atual

### 3. Helper explícito para progresso de playback

API adicional adotada:

```swift
func handlePlaybackTimeUpdate(_ time: Double)
```

Motivo:

- o plano da fase pede que playback nunca ultrapasse o `selectedTimeRange.upperBound`
- sem um helper explícito, essa regra ficaria implícita demais e difícil de testar sem introduzir `AVPlayer` já nesta fase

Consequência:

- a integração futura com `AVPlayer` só precisa encaminhar o tempo periódico para essa API
- a regra de parada/clamp fica coberta por testes unitários puros

### 4. Carga de duração

Duas entradas:

- `load(duration:)` para TDD e uso interno
- `load(asset:) async throws` como adapter para `AVAsset`

Regras:

- duração negativa, não finita ou inválida falha com `invalidVideoDuration`
- ao carregar nova duração, `isPlaying` volta para `false`
- `currentTime` e `selectedTimeRange` interno são normalizados para o novo domínio `0...duration`

### 5. Regras de clamp

- `seek(to:in:)` sempre normaliza o range recebido e clampa o tempo
- `handleSelectedTimeRangeChange(_:)` clampa imediatamente `currentTime`
- `handlePlaybackTimeUpdate(_:)` estaciona em `upperBound` e pausa quando o progresso tenta sair do range

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    PlayerEngine.swift

VideoEditorKitTests/
  Core/
    PlayerEngineTests.swift
```

## Sequência TDD

1. criar testes de `PlayerEngine`
2. executar a compilação de testes e observar falha inicial
3. implementar o mínimo de `PlayerEngine`
4. executar a suíte completa até verde
5. revisar edge cases de carga e clamp

## Contrato implementado

```swift
@MainActor
@Observable
final class PlayerEngine {
    var currentTime: Double
    var duration: Double
    var isPlaying: Bool

    func load(duration: Double) throws
    func load(asset: AVAsset) async throws
    func play()
    func pause()
    func seek(to time: Double, in selectedTimeRange: ClosedRange<Double>)
    func handleSelectedTimeRangeChange(_ selectedTimeRange: ClosedRange<Double>)
    func handlePlaybackTimeUpdate(_ time: Double)
}
```

## Critérios de aceite

- `PlayerEngine` é a única fonte de verdade do playhead
- `seek` nunca produz `currentTime` fora do range selecionado
- mudanças de range não deixam `currentTime` inválido
- playback estaciona no fim do range e pausa
- carga de duração via `AVAsset` já fica pronta para integração futura

## Fora do escopo desta fase

- controle direto de `AVPlayer`
- observadores periódicos reais de playback
- sincronização de áudio/vídeo
- UI de timeline e scrub
