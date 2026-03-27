# Managers Modernization Roadmap

## Objetivo

Modernizar `VideoPlayerManager`, `AudioRecorderManager` e `CameraManager` de forma incremental, preservando o comportamento real do app sempre que possivel e cobrindo cada etapa com testes unitarios ou testes de caracterizacao antes dos refactors.

## Fase 1

Status atual: concluida.

Escopo seguro, com baixo risco de regressao comportamental:

- estabilizar o ciclo de vida de `AVPlayer` e `AVPlayerItem` no `VideoPlayerManager`
- evitar recriacao desnecessaria do player auxiliar de audio quando a URL nao mudou
- trocar a limpeza do audio auxiliar para `replaceCurrentItem(with: nil)` em vez de reinstanciar `AVPlayer`
- gerar um arquivo unico por gravacao no `AudioRecorderManager`, evitando sobrescrita entre projetos
- corrigir detalhes de robustez no `CameraManager`
  - garantir `commitConfiguration()` com `defer`
  - limpar corretamente o timer ao encerrar gravacao
  - alinhar o `cameraPosition` inicial com a configuracao real usada hoje

Entregaveis esperados:

- testes unitarios para as novas garantias de reuso/identidade e geracao segura de arquivo
- atualizacao do comportamento real documentado quando necessario

## Fase 2

Status atual: concluida.

Modernizacao de fluxo e concorrencia, ainda sem redesenhar a arquitetura:

- substituir countdowns e polling por `Task` cancelavel e `ContinuousClock` onde fizer sentido
- usar APIs nativas de duracao maxima da gravacao (`record(forDuration:)` e `maxRecordedDuration`) em vez de depender apenas de `Timer`
- explicitar melhor o isolamento de estado entre main thread e filas de captura
- revisar a regra de cancelamento do audio para distinguir claramente `stop` de `cancel`
- reduzir `Task { @MainActor ... }` redundantes quando o callback ja estiver no contexto correto

Entregaveis esperados:

- managers mais previsiveis em Swift 6
- menos estado mutavel espalhado por timers e callbacks

## Fase 3

Status atual: concluida.

Consolidacao e preparacao para evolucoes maiores:

- extrair pequenas dependencias injetaveis para sessao de audio, relogio e captura
- melhorar testabilidade dos managers sem depender de hardware real
- revisar paridade entre estado publico observado e recursos AVFoundation subjacentes
- preparar terreno para futura centralizacao de regras em camadas mais puras, se o projeto evoluir alem do app monolitico atual

Entregaveis esperados:

- seams de teste mais limpos
- menor acoplamento entre UI, managers e AVFoundation

Entregaveis implementados:

- `AudioRecorderManager` agora recebe dependencias injetaveis para configuracao da sessao de audio, criacao do arquivo, fabrica do recorder, sleeper async e remocao de arquivos
- `CameraManager` agora recebe output de gravacao, sleeper async, `temporaryURLProvider`, `AVCaptureSession` e flag de `autoConfigure`, permitindo testes sem tocar hardware real
- os testes dos managers passaram a validar essas seams com doubles proprios, cobrindo publicacao de estado, regras de cancelamento, URLs temporarias e sincronizacao do estado observado com os recursos injetados
- a API publica usada pelas views foi preservada, mantendo a modernizacao incremental e com baixo impacto no fluxo atual do app
