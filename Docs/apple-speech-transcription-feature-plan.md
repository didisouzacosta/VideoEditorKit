# Plano de Integracao de Transcricao com Apple Speech

> Status atualizado
> Este plano esta obsoleto para a estrategia atual do produto.
> A migracao para suporte a `iOS 18.6` nao deve seguir com Apple Speech baseado em `SpeechAnalyzer`.
> Consultar `docs/ios-18-6-support-technical-plan.md` como fonte de verdade para a decisao atual.

> Nota
> Este documento define o plano de implementacao de um provider nativo baseado em Apple Speech.
> Ele deve coexistir com a integracao atual de OpenAI Whisper em `Sources/VideoEditorKit/Transcription/`.
> O objetivo nao e substituir o Whisper imediatamente, mas adicionar um caminho nativo e permitir uma estrategia hibrida quando a maior assertividade for prioridade.

## Objetivo

Adicionar ao package um componente de transcricao nativo que:

- use Apple Speech como provider local do `VideoTranscriptionProvider`
- extraia o audio do video local automaticamente
- gere segmentos com texto e range temporal
- preencha palavras temporizadas quando a API retornar granularidade suficiente
- preserve o contrato atual `VideoTranscriptionResult`
- exponha disponibilidade por locale antes de disparar o fluxo
- permita fallback opcional para o `OpenAIWhisperTranscriptionComponent`
- mantenha a `EditorViewModel` apenas como ponto de orquestracao do editor

## Status de implementacao

- planejamento documentado
- Fase 1 concluida
- Fase 2 concluida
- Fase 3 concluida
- Fase 4 concluida

## Estado atual relevante

O projeto ja tem a superficie necessaria para adicionar um novo backend sem alterar a UI principal:

- contrato `VideoTranscriptionProvider`
- contrato stateful `VideoTranscriptionComponentProtocol`
- tipos `VideoTranscriptionInput`, `VideoTranscriptionResult`, `TranscriptionSegment` e `TranscriptionWord`
- componente existente `OpenAIWhisperTranscriptionComponent`
- servico reutilizavel `VideoAudioExtractionService`
- mapeamento final via `EditorTranscriptMappingCoordinator`
- injecao publica via `VideoEditorConfiguration.TranscriptionConfiguration`

O package roda apenas em iOS 26+, entao o caminho principal deve usar a API moderna `SpeechAnalyzer` + `SpeechTranscriber`, sem adicionar guards de disponibilidade para versoes abaixo do deployment target.

## Decisao de arquitetura

Criar um componente novo no package:

- `AppleSpeechTranscriptionComponent`

Esse componente deve:

- conformar `VideoTranscriptionComponentProtocol`
- receber `VideoTranscriptionInput`
- validar a origem do video
- extrair audio com `VideoAudioExtractionService`
- resolver o locale suportado
- executar a transcricao com Apple Speech
- mapear resultados de `SpeechTranscriber` para `VideoTranscriptionResult`
- limpar o audio temporario ao final, em erro e em cancelamento
- publicar estado `idle`, `loading`, `loaded` e `failed`

O componente nao deve conhecer UI, SwiftData, Core Data, preview, export ou detalhes de `EditorViewModel`.

## Estrategia para maior assertividade

Usar Apple Speech como provider nativo principal, mas nao assumir que ele sempre sera o melhor resultado para todo audio, idioma ou ambiente.

Regras recomendadas:

- usar `SpeechTranscriber` com preset time-indexed quando a transcricao precisar de ranges temporais
- solicitar atributos de `audioTimeRange` e `transcriptionConfidence`
- usar `preferredLocale` como hint, mas resolver para um locale suportado pela API
- falhar cedo com `TranscriptError.unavailable(message:)` quando o locale nao for suportado ou nao houver modelo disponivel
- aguardar resultados finais antes de montar o documento persistivel
- descartar segmentos vazios, ranges invalidos e tempos negativos
- manter alternativas retornadas pela API apenas para re-ranking interno nesta fase
- selecionar o texto principal com base em range valido, texto nao vazio e confianca quando disponivel
- preencher `TranscriptionWord` a partir dos runs temporizados do `AttributedString` quando houver `audioTimeRange`
- cair para segmento sem words quando o range existir apenas no nivel do resultado
- opcionalmente acionar fallback para Whisper quando Apple Speech retornar vazio, baixa confianca agregada, locale indisponivel ou erro de reconhecimento recuperavel

O fallback para Whisper deve ser configuravel. Ele nao deve acontecer silenciosamente se o host escolher um modo Apple-only por motivos de privacidade, custo ou comportamento offline.

## Provider hibrido opcional

Para a maior assertividade, criar tambem um pequeno coordenador opcional:

- `FallbackVideoTranscriptionComponent`

Responsabilidade:

- tentar o provider primario
- avaliar se o resultado e aceitavel
- chamar o provider secundario quando a politica permitir
- preservar o mesmo contrato `VideoTranscriptionComponentProtocol`

Configuracao sugerida:

- primario: `AppleSpeechTranscriptionComponent`
- secundario: `OpenAIWhisperTranscriptionComponent`
- politica: `fallbackOnUnavailable`, `fallbackOnEmptyResult`, `fallbackOnLowConfidence`

Essa camada evita colocar conhecimento sobre Whisper dentro do componente Apple Speech.

## Estrutura proposta

Arquivos esperados em `Sources/VideoEditorKit/Transcription/`:

- `AppleSpeechTranscriptionComponent.swift`
- `AppleSpeechTranscriptionMapper.swift`
- `AppleSpeechAvailabilityResolver.swift`
- `AppleSpeechTranscriptionResultEvaluator.swift`
- `FallbackVideoTranscriptionComponent.swift`

Arquivos de teste esperados em `Tests/VideoEditorKitTests/Transcription/`:

- `AppleSpeechTranscriptionMapperTests.swift`
- `AppleSpeechAvailabilityResolverTests.swift`
- `AppleSpeechTranscriptionResultEvaluatorTests.swift`
- `AppleSpeechTranscriptionComponentTests.swift`
- `FallbackVideoTranscriptionComponentTests.swift`

## Responsabilidades

### 1. Disponibilidade

`AppleSpeechAvailabilityResolver` deve:

- resolver `preferredLocale`
- consultar locales suportados por `SpeechTranscriber`
- diferenciar locale indisponivel de erro operacional
- retornar `nil` quando o provider puder rodar
- retornar `TranscriptError.unavailable(message:)` quando nao puder

### 2. Transcricao

`AppleSpeechTranscriptionComponent` deve:

- validar `VideoTranscriptionSource.fileURL`
- extrair audio para arquivo temporario
- abrir o audio como entrada compativel com `SpeechAnalyzer`
- criar `SpeechTranscriber` com locale resolvido
- configurar transcricao time-indexed
- consumir `transcriber.results`
- respeitar cancelamento da task atual
- limpar arquivo temporario em todos os caminhos de saida

### 3. Mapeamento

`AppleSpeechTranscriptionMapper` deve:

- converter cada resultado final para `TranscriptionSegment`
- transformar `CMTimeRange` em segundos `Double`
- normalizar texto e espacos
- descartar resultados sem texto
- garantir `endTime >= startTime`
- ordenar segmentos por `startTime` e `endTime`
- extrair words quando houver runs com `audioTimeRange`
- manter fallback para um unico segmento quando houver texto agregado, mas sem words

### 4. Avaliacao de assertividade

`AppleSpeechTranscriptionResultEvaluator` deve:

- calcular se o resultado e utilizavel
- marcar resultado vazio como inaceitavel
- marcar ranges totalmente zerados como suspeitos
- considerar confianca agregada quando disponivel
- permitir thresholds configuraveis sem acoplar UI

Essa avaliacao serve apenas para fallback e diagnostico. A primeira versao nao deve bloquear um resultado Apple Speech valido apenas por nao ter word-level timing.

## API publica sugerida

Adicionar factories em `VideoEditorConfiguration.TranscriptionConfiguration`:

```swift
public static func appleSpeech(
    preferredLocale: String? = nil
) -> Self
```

E, quando a estrategia hibrida for desejada:

```swift
public static func appleSpeechWithWhisperFallback(
    openAIAPIKey: String,
    preferredLocale: String? = nil
) -> Self
```

Regras:

- `appleSpeech` nao exige segredo
- `appleSpeechWithWhisperFallback` so configura o fallback quando a chave do Whisper existir
- se a chave vier vazia, a configuracao deve continuar com Apple Speech como provider primario
- o README deve documentar claramente que fallback remoto envia audio para a OpenAI

## Fluxo da operacao

1. Receber `VideoTranscriptionInput`.
2. Cancelar operacao anterior em andamento.
3. Validar que a source e `fileURL` local.
4. Resolver disponibilidade e locale.
5. Atualizar estado para `loading`.
6. Extrair audio temporario.
7. Executar Apple Speech.
8. Coletar resultados finais.
9. Mapear para `VideoTranscriptionResult`.
10. Avaliar se o resultado e aceitavel.
11. Acionar fallback opcional se a politica permitir.
12. Atualizar estado para `loaded`.
13. Remover arquivo temporario.
14. Entregar o resultado para `EditorViewModel`.

Em caso de falha:

1. Encerrar ou cancelar a operacao atual.
2. Remover arquivo temporario.
3. Mapear erro para `TranscriptError`.
4. Atualizar estado para `failed`.

## Integracao com o editor

`EditorViewModel` nao deve mudar de responsabilidade.

Ela deve continuar:

- disparando `transcribeCurrentVideo()`
- lendo o provider da configuracao publica
- refletindo `TranscriptFeatureState`
- aplicando `EditorTranscriptMappingCoordinator.makeDocument(...)`

Ela nao deve:

- conhecer `SpeechAnalyzer`
- resolver locale
- interpretar `AttributedString`
- decidir fallback entre Apple Speech e Whisper

## Testes obrigatorios

Usar Swift Testing.

Cobertura minima:

- mapper converte `CMTimeRange` para `TranscriptionSegment`
- mapper descarta texto vazio
- mapper normaliza ranges negativos ou invertidos
- mapper ordena segmentos fora de ordem
- mapper extrai words quando runs temporizados existirem
- evaluator aceita resultado com texto e range valido
- evaluator rejeita resultado vazio
- availability retorna erro quando locale nao e suportado
- component transita `idle -> loading -> loaded`
- component transita `idle -> loading -> failed`
- component limpa audio temporario em sucesso
- component limpa audio temporario em falha
- component respeita cancelamento
- fallback chama Whisper quando Apple Speech retorna vazio
- fallback nao chama Whisper quando Apple Speech retorna resultado aceitavel
- factories publicas preservam `preferredLocale`

## Validacao

Como o repositorio e iOS-only, a validacao oficial deve continuar no runtime de iOS Simulator.

Comandos recomendados:

- `scripts/format-swift.sh`
- `scripts/test-ios.sh`

Para agentes com `xcodebuildmcp`:

- `build_sim`
- `test_sim`

## Fases de implementacao

### Fase 1

- criar `AppleSpeechTranscriptionMapper`
- criar testes puros de mapeamento
- validar normalizacao de texto, ranges e ordenacao
- status atual: concluida

### Fase 2

- criar `AppleSpeechAvailabilityResolver`
- criar testes para locale suportado, locale equivalente e locale indisponivel
- integrar `availabilityError(preferredLocale:)`
- status atual: concluida

### Fase 3

- criar `AppleSpeechTranscriptionComponent`
- reutilizar `VideoAudioExtractionService`
- adicionar seams de teste para extracao, transcricao e limpeza
- cobrir sucesso, falha e cancelamento
- status atual: concluida

### Fase 4

- adicionar factory publica `appleSpeech(preferredLocale:)`
- atualizar testes de `VideoEditorTranscriptionConfigurationTests`
- atualizar README e DocC
- status atual: concluida

### Fase 5

- criar `AppleSpeechTranscriptionResultEvaluator`
- criar `FallbackVideoTranscriptionComponent`
- adicionar factory publica `appleSpeechWithWhisperFallback(openAIAPIKey:preferredLocale:)`
- cobrir fallback e nao-fallback

### Fase 6

- rodar formatacao
- rodar validacao iOS oficial
- atualizar este plano com status das fases concluidas

## Fontes oficiais

- Apple Speech framework: https://developer.apple.com/documentation/speech
- SpeechAnalyzer: https://developer.apple.com/documentation/speech/speechanalyzer
- SpeechTranscriber: https://developer.apple.com/documentation/speech/speechtranscriber
- SFTranscriptionSegment: https://developer.apple.com/documentation/speech/sftranscriptionsegment
- WWDC25 SpeechAnalyzer: https://developer.apple.com/videos/play/wwdc2025/277/
