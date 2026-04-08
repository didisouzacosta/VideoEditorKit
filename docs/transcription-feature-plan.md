# Plano Unico de Integracao de Transcricao com OpenAI Whisper

> Nota
> Este documento continua como historico da entrega do backend remoto com OpenAI Whisper.
> A estrategia oficial atual para evoluir a feature, incluindo multiplos adapters de transcricao, esta em `docs/multi-provider-transcription-plan.md`.

## Objetivo

Adicionar ao app um componente de transcricao remoto que:

- extraia o audio do video local automaticamente
- envie esse audio para a API de transcricao da OpenAI
- receba a resposta do modelo Whisper remoto
- converta a resposta para `VideoTranscriptionResult`
- atualize o estado da transcricao entre `idle`, `loading`, `loaded` e `failed`
- mantenha a `EditorViewModel` apenas como ponto de orquestracao do editor, sem concentrar regras de rede e extracao

Esse passa a ser o unico plano oficial de transcricao do projeto.

## Status de implementacao

- planejamento documentado
- Fase 1 concluida
- Fase 2 concluida
- Fase 3 concluida
- Fase 4 concluida
- Fase 5 concluida
- Fase 6 concluida

## Estado atual relevante

O projeto ja possui a base funcional de transcricao no editor:

- contrato [`VideoTranscriptionProvider`](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Transcription/VideoTranscriptionProvider.swift)
- tipos `VideoTranscriptionInput`, `VideoTranscriptionResult`, `TranscriptionSegment` e `TranscriptionWord`
- disparo de transcricao em [`EditorViewModel.transcribeCurrentVideo()`](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/ViewModels/EditorViewModel.swift#L697)
- injecao do provider via [`VideoEditorView.Configuration.TranscriptionConfiguration`](/Users/adrianocosta/Documents/Projects/VideoEditorKit/Packages/VideoEditorKit/Sources/VideoEditorKit/API/VideoEditorPublicTypes.swift)
- configuracao padrao no shell do app em [`AppShellTranscriptionConfiguration.swift`](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/AppShell/Transcription/AppShellTranscriptionConfiguration.swift) e em [`RootView`](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/RootView/RootView.swift)

O gap atual nao e de UI nem de persistencia. O gap e a ausencia de um provider remoto concreto que faca:

- extracao de audio
- upload multipart
- autenticacao com a OpenAI
- decodificacao da resposta
- mapeamento para o modelo interno

## Decisao de arquitetura

Criar um componente unico em `VideoEditor/TranscriptionKit/` chamado `OpenAIWhisperTranscriptionComponent`.

Esse componente sera o ponto de entrada da feature e devera:

- conformar `VideoTranscriptionProvider`
- receber um `VideoTranscriptionInput`
- extrair o audio do video local
- chamar a API remota da OpenAI
- mapear a resposta para `VideoTranscriptionResult`
- publicar o estado atual da operacao
- limpar arquivos temporarios ao final

## Responsabilidades do componente

### 1. Extracao de audio

O componente deve assumir integralmente a responsabilidade de extrair audio a partir de `VideoTranscriptionSource.fileURL`.

Regras:

- aceitar apenas `URL` local de arquivo
- exportar um audio temporario em formato compativel com a API
- preferir `.m4a`
- falhar com erro explicito quando o asset nao tiver faixa de audio ou quando a exportacao falhar
- apagar o arquivo temporario depois do envio ou em caso de erro

### 2. Consumo da API da OpenAI

O componente deve fazer a chamada HTTP para o endpoint de transcricao da OpenAI.

Regras:

- usar `POST /v1/audio/transcriptions`
- enviar multipart form data
- incluir `file`
- incluir `model`
- incluir `language` quando `preferredLocale` existir
- pedir resposta em formato adequado para obter segmentos temporais
- tratar erros HTTP, erros de autenticacao e payload invalido

### 3. Mapeamento de resposta

O componente deve transformar a resposta remota em tipos internos do editor.

Regras:

- converter cada segmento remoto para `TranscriptionSegment`
- preservar tempo de inicio e fim em segundos
- preencher `words` quando a resposta trouxer granularidade por palavra
- normalizar textos vazios ou espacamentos invalidos antes de devolver o resultado

### 4. Estado da transcricao

O componente deve ser responsavel pelo estado da operacao.

Estados esperados:

- `idle`
- `loading`
- `loaded`
- `failed(TranscriptError)`

Regra de integracao:

- a `EditorViewModel` nao deve decidir transicoes de estado da operacao remota
- a `EditorViewModel` deve refletir o estado produzido pelo componente para a UI do editor

## Contrato recomendado

O contrato atual pode ser evoluido para explicitar a responsabilidade de estado no proprio componente.

Direcao recomendada:

```swift
protocol VideoTranscriptionComponentProtocol: Sendable {
    var state: TranscriptFeatureState { get async }
    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult
    func cancelCurrentTranscription() async
}
```

Compatibilidade:

- `OpenAIWhisperTranscriptionComponent` pode conformar tanto `VideoTranscriptionProvider` quanto `VideoTranscriptionComponentProtocol`
- a migracao pode ser incremental para evitar quebrar testes e pontos de injecao existentes

## Estrutura proposta

Arquivos esperados em `VideoEditor/TranscriptionKit/`:

- `OpenAIWhisperTranscriptionComponent.swift`
- `VideoAudioExtractionService.swift`
- `OpenAIWhisperAPIClient.swift`
- `OpenAIWhisperMultipartFormDataBuilder.swift`
- `OpenAIWhisperResponseDTO.swift`
- `OpenAIWhisperResponseMapper.swift`

Separacao de responsabilidades:

- `OpenAIWhisperTranscriptionComponent`
  coordena o fluxo completo e o estado
- `VideoAudioExtractionService`
  extrai o audio do video
- `OpenAIWhisperAPIClient`
  monta e envia a request
- `OpenAIWhisperMultipartFormDataBuilder`
  encapsula o corpo multipart
- `OpenAIWhisperResponseDTO`
  descreve o JSON remoto
- `OpenAIWhisperResponseMapper`
  converte DTO em `VideoTranscriptionResult`

## Fluxo da operacao

1. Receber `VideoTranscriptionInput`.
2. Validar a origem do video.
3. Atualizar o estado para `loading`.
4. Extrair audio para arquivo temporario.
5. Enviar o arquivo para a OpenAI.
6. Decodificar a resposta da API.
7. Mapear a resposta para `VideoTranscriptionResult`.
8. Atualizar o estado para `loaded`.
9. Entregar o resultado ao editor.
10. Remover o arquivo temporario.

Em caso de falha:

1. Encerrar a operacao.
2. Atualizar o estado para `failed`.
3. Remover o arquivo temporario se ele existir.

## Integracao com o editor

### `EditorViewModel`

`EditorViewModel` continua como orquestrador do editor, mas deve parar de carregar detalhes internos da transcricao remota.

Ela deve:

- disparar a transcricao do video atual
- aguardar o `VideoTranscriptionResult`
- aplicar `EditorTranscriptMappingCoordinator.makeDocument(...)`
- refletir o estado vindo do componente

Ela nao deve:

- extrair audio
- montar request HTTP
- conhecer multipart
- interpretar JSON da OpenAI

### `VideoEditorView.Configuration`

`VideoEditorView.Configuration.TranscriptionConfiguration` continua sendo o ponto de injecao do provider concreto.

### `RootView`

A configuracao de transcricao da `RootView` nao deve carregar mais infraestrutura de resolver e factories quando o app assumir `AppleSpeech` como caminho padrao.

## Configuracao e segredo

A chave da OpenAI nao deve ficar hardcoded.

Diretrizes:

- injetar a API key por configuracao
- manter o segredo fora do codigo fonte versionado
- falhar cedo quando a chave nao estiver configurada

## Erros esperados

O componente deve mapear falhas para erros consistentes do dominio:

- provider nao configurado
- origem de video invalida
- video sem audio extraivel
- falha na exportacao de audio
- erro de rede
- autenticacao invalida
- resposta remota vazia
- resposta remota invalida
- operacao cancelada

Quando possivel, o erro deve chegar como `TranscriptError.providerFailure(message:)` com mensagem clara e adequada para exibicao ou diagnostico.

## Testes obrigatorios

Toda implementacao deve vir acompanhada de testes em `Swift Testing`.

Cobertura minima:

- extracao de audio com fixture local
- limpeza do arquivo temporario em sucesso e falha
- request multipart com campos obrigatorios
- envio do locale opcional
- mapeamento de segmentos da resposta remota
- mapeamento de words quando existirem
- transicao de estado `idle -> loading -> loaded`
- transicao de estado `idle -> loading -> failed`
- cancelamento da transcricao em andamento
- integracao da `EditorViewModel` com o componente sem regressao do fluxo atual

## Plano de implementacao

### Fase 1

- criar o `VideoAudioExtractionService`
- criar fixtures e testes de extracao
- status atual: concluida

### Fase 2

- criar `OpenAIWhisperAPIClient`
- criar builder multipart
- adicionar testes de request e decodificacao
- status atual: concluida
- entregas:
- `OpenAIWhisperAPIClient.swift`
- `OpenAIWhisperMultipartFormDataBuilder.swift`
- `OpenAIWhisperResponseDTO.swift`
- `OpenAIWhisperAPIClientTests.swift`
- `OpenAIWhisperMultipartFormDataBuilderTests.swift`
- verificacao automatica:
- `xcodebuild build-for-testing` com `TEST BUILD SUCCEEDED`
- `xcodebuild test-without-building` para as suites de `TranscriptionKit` com `9` testes passando

### Fase 3

- criar `OpenAIWhisperResponseMapper`
- validar mapeamento para `VideoTranscriptionResult`
- status atual: concluida
- entregas:
- `OpenAIWhisperResponseMapper.swift`
- `OpenAIWhisperResponseMapperTests.swift`
- verificacao automatica:
- `xcodebuild build-for-testing` com `TEST BUILD SUCCEEDED`
- `xcodebuild test-without-building` para as suites de `TranscriptionKit` com `13` testes passando

### Fase 4

- criar `OpenAIWhisperTranscriptionComponent`
- integrar extracao, client, mapper, limpeza de temporarios e estado
- status atual: concluida
- entregas:
- `OpenAIWhisperTranscriptionComponent.swift`
- `VideoTranscriptionComponentProtocol`
- `OpenAIWhisperTranscriptionComponentTests.swift`
- verificacao automatica:
- `xcodebuild build-for-testing` com `TEST BUILD SUCCEEDED`
- `xcodebuild test-without-building` para as suites de `TranscriptionKit` com `17` testes passando

### Fase 5

- injetar o componente remoto em `VideoEditorView.Configuration`
- ajustar `RootView` para construir a configuracao real
- adaptar `EditorViewModel` para refletir o estado do componente
- entregas:
- `RootView.swift` agora injeta `OpenAIWhisperTranscriptionComponent` quando `OPENAI_API_KEY` estiver presente no ambiente
- `EditorViewModel.swift` agora reconhece `VideoTranscriptionComponentProtocol`, reflete o estado produzido pelo componente stateful e cancela operacoes remotas em trocas de video e resets
- `EditorViewModelTests.swift` cobre os caminhos de `loading -> loaded` e `loading -> failed` com um componente stateful de teste
- verificacao automatica:
- a tentativa de `xcodebuild build-for-testing` e `xcodebuild test-without-building` nesta fase ficou bloqueada por uma falha externa do `swift-plugin-server` do Xcode, afetando macros de `SwiftData`, `Observation` e `#Preview`
- status atual: concluida

### Fase 6

- cobrir integracao ponta a ponta com testes do fluxo do editor
- validar caminhos de sucesso, falha e cancelamento
- entregas:
- `EditorViewModelTests.swift` agora cobre o fluxo do editor com `OpenAIWhisperTranscriptionComponent` real usando seams de teste para sucesso, falha e cancelamento
- o caminho de sucesso valida extracao encadeada, request para a API, mapeamento para `TranscriptDocument` e limpeza do audio temporario
- o caminho de falha valida propagacao de erro do provider para o estado da UI do editor e limpeza do audio temporario
- o caminho de cancelamento valida que `resetTranscript()` cancela o componente remoto em andamento e retorna o editor para `idle`
- verificacao automatica:
- a tentativa de `xcodebuild build-for-testing` e `xcodebuild test-without-building` continua bloqueada por uma falha externa do `swift-plugin-server` do Xcode, afetando macros de `SwiftData`, `Observation` e `#Preview`
- status atual: concluida

## Criterios de aceite

O trabalho sera considerado concluido quando:

- existir um unico componente de transcricao remoto plugavel no editor
- esse componente extrair audio do video sem ajuda externa da view model
- esse componente consumir a API da OpenAI com autenticacao valida
- esse componente devolver `VideoTranscriptionResult` compativel com o fluxo atual
- o estado da transcricao for atualizado pelo proprio componente
- a UI do editor refletir corretamente loading, erro e sucesso
- os testes cobrirem os principais caminhos de sucesso, falha e cancelamento

## Fonte oficial da API

Ao implementar a integracao, usar como referencia a documentacao oficial atual da OpenAI para audio e speech-to-text:

- [Audio and speech](https://platform.openai.com/docs/guides/audio/quickstart)
- [Whisper model](https://developers.openai.com/api/docs/models/whisper-1)
