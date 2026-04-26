# Export Background Lifecycle Plan

## Objetivo

Resolver o congelamento do processo de exportacao quando o editor vai para segundo plano durante um render.

O comportamento alvo deve ser previsivel para o usuario:

- export garante o save manual das alteracoes pendentes antes de renderizar a resolucao escolhida
- se o app continuar ativo ou apenas ficar temporariamente inativo, o export pode continuar
- se o app for para background, o export deve ser cancelado de forma explicita
- ao voltar, a UI deve sair do estado congelado e permitir tentar novamente

## Decisao recomendada

Nao implementar retomada real do mesmo export neste momento.

Como a implementacao nao deve usar UIKit, o caminho recomendado e cancelar quando o lifecycle SwiftUI indicar background:

1. Manter o export rodando em `.active`.
2. Nao cancelar em `.inactive`, porque esse estado pode representar transicoes e interrupcoes curtas.
3. Cancelar o export de forma explicita em `.background`.
4. Mostrar um erro especifico e permitir retry do zero.

Essa abordagem evita o estado congelado sem introduzir UIKit, background modes ou uma arquitetura de jobs persistidos antes de ela existir no projeto.

## Por que nao retomar agora

O pipeline atual em `VideoEditor.startRender(...)` usa `AVAssetExportSession` por estagios:

- composicao base
- correcoes de cor, quando aplicavel
- transcricao, quando aplicavel

Cada estagio gera um arquivo intermediario temporario e chama `AVAssetExportSession.export(...)`. A API nao oferece pausa e retomada confiavel dentro da mesma sessao. Se o processo for suspenso no meio de uma exportacao, nao ha um checkpoint nativo que permita continuar exatamente do mesmo ponto.

Retomada real exigiria um redesenho maior:

- snapshot imutavel de export
- job persistido em disco
- URLs intermediarias estaveis e recuperaveis
- identificacao do ultimo estagio concluido
- limpeza segura de arquivos parciais
- validacao de que o `Video` e a configuracao continuam compativeis
- protecao contra multiplos exports concorrentes

Esse custo nao e proporcional ao problema imediato. O melhor primeiro passo e tornar o cancelamento explicito e recuperavel.

## Estado atual

- `VideoExporterContainerView` cria e mantem um `ExporterViewModel` em `@State`.
- Antes de abrir a sheet de qualidade, o editor salva alteracoes pendentes e publica `onSavedVideo`.
- O save manual anterior ao export mostra loading no botao `Save`, bloqueia a superficie de edicao e pode ser cancelado pelo botao `Cancel`.
- `ExporterViewModel` guarda uma unica `exportTask`.
- `cancelExport()` ja cancela a task e retorna a UI para `.unknown`.
- `VideoEditor.export(...)` ja usa `withTaskCancellationHandler` e chama `AVAssetExportSession.cancelExport()` no cancelamento.
- Nao existe hoje tratamento de `scenePhase` no fluxo de exportacao.
- Nao deve ser introduzido `UIApplication.beginBackgroundTask` para esse fluxo.
- Se o app e suspenso durante o export, a UI pode continuar presa em `.loading` ao retornar.

## Comportamento esperado

### Active ou inactive

1. Usuario inicia export.
2. Se houver alteracoes pendentes, o editor executa save manual primeiro; durante esse save, a UI de edicao fica bloqueada e `Cancel` cancela o save.
3. App permanece `.active` ou passa brevemente por `.inactive`.
4. Export continua e, se concluir, chama `onExported`.

### Background

1. Usuario inicia export.
2. Se houver alteracoes pendentes, o editor executa save manual primeiro.
3. App vai para background.
4. O export e cancelado explicitamente.
5. `AVAssetExportSession.cancelExport()` e chamado pelo caminho de cancelamento ja existente.
6. Ao voltar, a UI mostra falha recuperavel com acao de retry.

### Cancelamento manual

1. Usuario toca em cancelar.
2. O export e cancelado.
3. A UI volta para estado inicial sem mostrar erro.

Cancelamento manual e cancelamento por interrupcao de background devem ser tratados como razoes diferentes.

## Rollout

### Fase 1

Objetivo: caracterizar o bug e proteger a decisao com testes.

Entregaveis:

- adicionar testes de `ExporterViewModel` para diferenciar:
  - cancelamento manual
  - cancelamento por background
  - retry apos cancelamento por background
- confirmar que `onExported` nao e chamado depois de cancelamento

Status:

- implementada
- `ExporterViewModel` agora diferencia cancelamento manual de cancelamento por interrupcao de background
- testes cobrem lifecycle ativo, lifecycle inativo, background e retry apos background
- execucoes antigas de export agora usam um identificador interno para nao sobrescrever o estado de uma tentativa nova

### Fase 2

Objetivo: introduzir a politica de lifecycle sem UIKit.

Entregaveis:

- criar um coordenador pequeno e puro para lifecycle de export
- injetar o coordenador no `ExporterViewModel`
- adicionar uma razao de cancelamento, por exemplo:
  - `.user`
  - `.backgroundInterruption`
- manter cancelamento manual silencioso
- transformar cancelamento por background em falha recuperavel com mensagem especifica

Status:

- implementada
- `ExportLifecycleCoordinator` resolve uma razao de cancelamento somente quando ha export em andamento e o lifecycle recebido e `.background`
- `.active` e `.inactive` nao cancelam exports em andamento
- a politica e pura e nao usa UIKit

### Fase 3

Objetivo: conectar o fluxo SwiftUI ao lifecycle do app.

Entregaveis:

- adicionar `@Environment(\.scenePhase)` em `VideoExporterContainerView`
- em `.background`, avisar o `ExporterViewModel` para cancelar se houver export em andamento
- em `.active`, manter o export sem acao extra
- evitar cancelar em `.inactive`, porque esse estado tambem aparece em interrupcoes curtas e transicoes temporarias

Status:

- implementada
- `VideoExporterContainerView` observa `@Environment(\.scenePhase)` e repassa mudancas para o `ExporterViewModel`
- o mapeamento entre `ScenePhase` e `ExportLifecycleState` fica isolado em uma extensao pequena baseada em SwiftUI
- `.background` agora aciona o cancelamento recuperavel implementado na Fase 2, sem usar UIKit
- a leitura de `scenePhase` tambem foi hoistada para `VideoEditorView` e repassada para a sheet por `Binding`, porque a validacao manual mostrou que a sheet dinamica pode nao processar `.background` antes da suspensao
- existe um fallback SwiftUI-only: `inactive` nao cancela imediatamente, mas um retorno para `.active` apos uma interrupcao inativa longa cancela o export como falha recuperavel

### Fase 4

Objetivo: validar no runtime oficial do projeto.

Entregaveis:

- rodar formatacao Swift do projeto
- rodar `scripts/test-ios.sh`
- validar manualmente no Simulator:
  - export com background curto
  - export com background longo ate expiracao
  - cancelamento manual
  - retry depois de cancelamento por background

Status:

- implementada parcialmente no runtime
- formatacao Swift executada com sucesso
- `scripts/test-ios.sh` executado com sucesso no iOS Simulator
- testes unitarios cobrem:
  - `.active` mantendo export
  - `.inactive` curto mantendo export
  - `.background` cancelando com falha recuperavel
  - retorno para `.active` apos interrupcao inativa longa cancelando com falha recuperavel
  - retry apos cancelamento por background
- validacao manual no Simulator:
  - app abriu no Simulator
  - midia de fixture `preview.mp4` foi adicionada ao Photos do Simulator
  - fluxo de importacao, editor e sheet de exportacao foi acessado
  - o botao Home colocou o app no SpringBoard
  - a tentativa manual mostrou que, nesse caminho automatizado, o callback direto de `.background` pode nao ser processado antes da suspensao; por isso o fallback por interrupcao inativa longa foi adicionado e coberto por testes

## Mensagens de UI

Recomendacao de copy para o erro especifico:

```text
The export was cancelled because the app moved to the background. Please try again.
```

Essa mensagem deve ser distinta do erro generico de exportacao, porque o usuario consegue resolver o problema mantendo o app em primeiro plano ou tentando novamente.

## Riscos e cuidados

- Nao usar UIKit para pedir tempo extra de background nesse fluxo.
- Nao cancelar em `.inactive`.
- Nao mostrar alerta de alteracoes nao salvas quando o usuario toca em `Cancel` durante um save manual; nesse caso, cancelar o save em andamento.
- Nao disparar `onExported` se a task foi cancelada depois que o arquivo ficou pronto, mas antes do callback.
- Nao apagar a copia editada salva quando um export posterior e cancelado por lifecycle.
- Limpar arquivos intermediarios no caminho de erro, preservando o comportamento atual de `VideoEditor.startRender(...)`.
- Nao adicionar `UIBackgroundModes` para video export; isso nao e o mesmo caso de audio/background processing continuo e pode criar uma expectativa falsa de execucao indefinida.

## Trabalho futuro

Retomada real pode ser considerada depois, mas deve entrar como uma evolucao de arquitetura de export job, nao como ajuste local no `ExporterViewModel`.

Pre-requisitos para essa fase futura:

- snapshot imutavel de export
- job persistido com identificador
- stage graph explicito
- arquivos intermediarios persistentes com estrategia de cleanup
- guarda contra export concorrente
- testes de recuperacao apos relaunch do app
