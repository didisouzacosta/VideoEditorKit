# Plano Tecnico de Transcricao Multi-Provider

## Objetivo

Evoluir a feature de transcricao do editor para suportar mais de um backend, mantendo o fluxo atual do editor estavel e sem reintroduzir acoplamento entre UI, extracao de audio e tecnologia de speech-to-text.

A direcao alvo passa a ser:

- manter o backend remoto atual com OpenAI Whisper
- adicionar um segundo adapter com transcricao local do proprio sistema operacional
- permitir selecao e fallback de backend sem alterar o contrato consumido por `EditorViewModel`
- preservar `VideoTranscriptionResult` como formato interno unico para o editor

## Estado atual

O projeto ja possui:

- contrato de provider em `VideoTranscriptionProvider`
- contrato stateful em `VideoTranscriptionComponentProtocol`
- componente remoto concreto em `OpenAIWhisperTranscriptionComponent`
- injecao do provider via `VideoEditorView.Configuration.TranscriptionConfiguration`
- mapeamento do resultado para `TranscriptDocument` dentro do editor

Hoje a configuracao padrao ainda assume um unico backend concreto e `RootView` conhece diretamente a construcao do Whisper.

## Direcao de arquitetura

O editor deve continuar enxergando apenas:

- um provider que implementa `VideoTranscriptionProvider`
- opcionalmente um componente stateful que implementa `VideoTranscriptionComponentProtocol`
- um `VideoTranscriptionResult` padronizado

As decisoes de backend devem sair da UI e passar para uma camada pequena de resolucao em `TranscriptionKit`.

## Backends planejados

### 1. `openAIWhisper`

- backend remoto atual
- exige `OPENAI_API_KEY`
- continua usando extracao local de audio e upload multipart

### 2. `appleSpeech`

- backend local do OS
- deve usar o framework `Speech`
- para iOS 26+, a implementacao alvo deve priorizar `SpeechAnalyzer`, `SpeechTranscriber` e `AssetInventory`
- o resultado deve ser convertido para `VideoTranscriptionResult`

Referencias oficiais usadas para orientar a implementacao:

- [Speech framework](https://developer.apple.com/documentation/speech)
- [Bringing advanced speech-to-text capabilities to your app](https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app)
- [Bring advanced speech-to-text to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)

## Regras de compatibilidade

- `EditorViewModel` nao deve conhecer detalhes de Whisper nem da API nativa da Apple
- `TranscriptToolView` nao deve decidir backend
- `RootView` pode definir politica de preferencia, mas nao deve instanciar componentes concretos diretamente a longo prazo
- o formato persistido de transcript nao deve depender do backend de origem
- a ausencia de granularidade por palavra no backend local nao deve bloquear a primeira entrega, desde que `segments` funcionem corretamente

## Fases

### Fase 1

Objetivo:
criar a fundacao para multi-provider sem expor ainda um backend local incompleto.

Entregas:

- introduzir uma camada intermediaria para identificar o backend e resolver providers
- criar factories e um resolver temporario de provider em `TranscriptionKit`
- remover de `RootView` o conhecimento direto de `OpenAIWhisperTranscriptionComponent`
- estender `TranscriptionConfiguration` para carregar metadata intermediaria da resolucao
- adicionar a permissao `NSSpeechRecognitionUsageDescription` ao app para preparar a proxima fase
- documentar a nova estrategia oficial

Status atual:
concluida

Entregas realizadas:

- uma camada intermediaria de resolucao de backend
- `OpenAIWhisperTranscriptionProviderFactory.swift`
- `VideoEditorView.Configuration.TranscriptionConfiguration` passou a carregar metadata intermediaria da resolucao
- `RootView` passou a resolver providers via factory + resolver
- `NSSpeechRecognitionUsageDescription` adicionada ao target
- testes para resolver e factory do Whisper

Nota historica:

- essa camada intermediaria foi removida depois, quando a API publica passou a expor apenas `.appleSpeech(...)` e `.openAIWhisper(...)`

Verificacao:

- `xcodebuild test -project VideoEditor.xcodeproj -scheme VideoEditor -destination 'platform=iOS Simulator,id=48607FD1-353D-447C-968A-109A56036C2F' -only-testing:VideoEditorTests/VideoEditorConfigurationTests`

### Fase 2

Objetivo:
fazer um spike tecnico do backend local da Apple e validar o formato real dos resultados.

Entregas:

- criar `AppleSpeechTranscriptionComponent`
- validar consumo de arquivo de audio extraido
- validar disponibilidade de assets e locale
- validar se o resultado nativo fornece segmentos, palavras e tempos suficientes
- mapear gaps conhecidos da API nativa para o dominio do editor

Critero de saida:
ter uma prova concreta de viabilidade para transcricao local de video pregravado no target atual.

Status atual:
concluida

Entregas realizadas:

- `AppleSpeechTranscriptionComponent.swift`
- `AppleSpeechTranscriptionService.swift`
- `AppleSpeechTranscriptionResultMapper.swift`
- testes de caracterizacao para o mapper
- testes de ciclo de vida, erro e cancelamento do componente local

Descobertas tecnicas confirmadas:

- o SDK atual do target expoe `SpeechAnalyzer`, `SpeechTranscriber` e `AssetInventory`
- o backend local aceita audio pregravado a partir de `AVAudioFile`
- a resolucao de locale precisa passar por `SpeechTranscriber.supportedLocale(equivalentTo:)`
- a instalacao de assets pode precisar de `AssetInventory.assetInstallationRequest(supporting:)`
- os resultados nativos chegam como `SpeechTranscriber.Result`
- segmentos temporais sao diretamente derivados de `result.range`
- granularidade por palavra nao vem como lista pronta do framework
- os tempos por token podem ser extraidos de `AttributedString.audioTimeRange` quando o resultado vier segmentado em runs individuais
- quando um run temporizado cobre mais de uma palavra, a Fase 2 prefere preservar o `segment.text` e deixar `words` vazio em vez de inferir tempos artificiais

Escopo entregue nesta fase:

- o componente local ja extrai audio via `VideoAudioExtractionService`
- o servico Apple ja transcreve `.m4a` local e mapeia para `VideoTranscriptionResult`
- o componente local ja normaliza erros de source invalida, locale nao suportado, indisponibilidade do speech local e resultado vazio
- o componente local ja suporta cancelamento e limpeza do arquivo temporario extraido

Fora de escopo nesta fase:

- integrar o backend local ao resolver padrao do app
- definir a politica final de selecao exposta ao host
- executar validacao em device fisico

Verificacao:

- `xcodebuild test -project VideoEditor.xcodeproj -scheme VideoEditor -destination 'platform=iOS Simulator,id=48607FD1-353D-447C-968A-109A56036C2F' -only-testing:VideoEditorTests/AppleSpeechTranscriptionResultMapperTests -only-testing:VideoEditorTests/AppleSpeechTranscriptionComponentTests`

### Fase 3

Objetivo:
integrar o backend local ao resolver e habilitar selecao real de backend.

Entregas:

- adicionar `AppleSpeechTranscriptionProviderFactory`
- suportar resolucao por estrategia configuravel no app
- padronizar erros de permissao, indisponibilidade de asset e locale nao suportado
- manter cancelamento e `TranscriptFeatureState` consistentes

Status atual:
concluida

Entregas realizadas:

- `AppleSpeechTranscriptionProviderFactory.swift`
- uma estrategia intermediaria de resolucao explicita de provider
- `RootView` passou a publicar factories padrao para Apple local e Whisper remoto
- a infraestrutura do app passou a suportar selecao explicita de backend
- `RootView` tambem passou a expor helpers internos de resolucao durante a fase de transicao

Resultado pratico:

- o app passou a suportar backend Apple e backend Whisper como opcoes reais de resolucao
- durante essa fase, a resolucao podia ser baseada em prioridade ou explicitada pela camada chamadora
- o objetivo era viabilizar a migracao ate a API publica final simplificada por backend

Verificacao:

- testes de factory do Apple speech cobrindo disponibilidade e indisponibilidade
- testes da configuracao do `RootView` cobrindo backend explicito e regras de indisponibilidade

### Fase 4

Objetivo:
fechar cobertura de testes e paridade funcional minima.

Entregas:

- testes do componente local
- testes da camada intermediaria de resolucao durante a migracao
- testes do `EditorViewModel` usando o componente local
- verificacao de comportamento com e sem granularidade por palavra

Status atual:
concluida

Entregas realizadas:

- testes do `EditorViewModel` cobrindo `AppleSpeechTranscriptionComponent`
- cobertura explicita para resposta local com `segments` sem `words`
- cobertura explicita para resposta local com `words` temporizadas
- teste de mapping garantindo que o editor preserva o texto do segmento quando o provider nao expoe granularidade por palavra
- consolidacao da cobertura da camada de transcricao e do componente local no pacote de validacao da feature

Resultado pratico:

- o editor continua agnostico ao backend no fluxo de transcricao
- respostas do backend Apple sem word-level timing continuam editaveis e renderizaveis no editor
- quando o backend Apple fornecer `words`, elas entram no draft com `timelineRange` remapeado corretamente

Verificacao:

- `xcodebuild test -project VideoEditor.xcodeproj -scheme VideoEditor -destination 'platform=iOS Simulator,id=48607FD1-353D-447C-968A-109A56036C2F' -only-testing:VideoEditorTests/EditorViewModelTests -only-testing:VideoEditorTests/EditorTranscriptMappingCoordinatorTests -only-testing:VideoEditorTests/AppleSpeechTranscriptionComponentTests -only-testing:VideoEditorTests/AppleSpeechTranscriptionResultMapperTests`

### Fase 5

Objetivo:
decidir exposicao de produto.

Opcoes:

- exigir escolha explicita entre backend Apple e backend Whisper
- expor preferencia de backend em configuracao interna do host
- manter ordenacao por prioridade apenas como detalhe interno de infraestrutura, fora da configuracao do host

Status atual:
concluida

Decisao adotada:

- remover `.automatic` da configuracao exposta ao host
- expor preferencia de backend apenas em configuracao interna do host
- exigir que quem integra a transcricao escolha explicitamente entre `appleSpeech` e `openAIWhisper`
- nao expor seletor de backend na UI do editor nesta fase

Entregas realizadas:

- a configuracao de transcricao do editor agora pode expor factories simplificadas por backend
- `RootView` foi simplificada para assumir diretamente `transcription: .appleSpeech()`
- o fluxo de composicao da tela nao precisa mais montar resolver, strategy ou factories para o caso Apple-only
- `preferredLocale` continua parte da configuracao interna do host
- selecao explicita por backend nao faz mais fallback silencioso para outro provider quando o backend escolhido estiver indisponivel

Resultado pratico:

- o produto final continua simples para o usuario final
- quem integra a transcricao e obrigado a tomar uma decisao explicita de backend
- builds internas, QA ou integracoes futuras podem forcar backend sem alterar `EditorViewModel`
- quando o backend escolhido nao estiver disponivel, a configuracao fica sem provider em vez de trocar silenciosamente de tecnologia

Verificacao:

- testes do `RootView` cobrindo preferencia explicita por Apple Speech
- testes do `RootView` cobrindo preferencia explicita por OpenAI Whisper

## Riscos tecnicos principais

- a API local pode exigir assets especificos por locale antes da execucao
- granularidade por palavra pode variar por idioma ou disponibilidade de modelo
- o comportamento em simulator pode divergir de device real
- a API local pode impor requisitos de autorizacao mesmo para audio pregravado
- o custo de processamento local pode exigir limites de duracao ou estrategia de cancelamento mais rigorosa

## Estrategia de testes

Cobertura minima esperada ao final da implementacao multi-provider:

- a configuracao explicita do host cria o provider correto para o backend escolhido
- selecao explicita do host nao cai silenciosamente para outro backend
- factory do Whisper continua falhando de forma silenciosa quando a API key estiver ausente
- componente local mapeia resultados para `VideoTranscriptionResult`
- componente local propaga cancelamento corretamente
- `EditorViewModel` permanece agnostico ao backend

## Fonte de verdade

Este documento passa a ser a referencia oficial para a evolucao da feature de transcricao.

O documento `docs/transcription-feature-plan.md` continua valido como historico da entrega do backend remoto com Whisper, mas nao representa mais sozinho a estrategia futura da feature.
