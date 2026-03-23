# VideoEditorKit — Plano Técnico da Fase 13

## Objetivo

Criar uma etapa de exemplo no app host para importar um vídeo real do device e, só então, abrir o editor.

Ao final da fase 13, o projeto deve permitir:

- iniciar a experiência em uma tela de entrada do app de exemplo
- selecionar um vídeo real da biblioteca do device
- materializar esse vídeo em uma URL local utilizável pela sandbox do app
- carregar metadados reais via `AVFoundationVideoAssetLoader`
- abrir `VideoEditorView` com `duration`, `presentationSize` e `preferredTransform` reais

Isso resolve o bloqueio atual de teste manual, em que o app depende de `sourceVideoURL` fake e de `duration` mockada em `ContentView`.

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

As duas skills orientam principalmente:

- manter a etapa de importação fora do core da biblioteca
- usar `@Observable` e estado no `@MainActor` para o fluxo do app host
- preferir APIs modernas de SwiftUI para seleção de mídia
- preservar views pequenas, acessíveis e sem regra de negócio no `body`

### Desvios documentados

- A skill `swiftui-pro` não estava disponível no caminho informado pelo ambiente durante esta execução. O plano foi estruturado com base em `swiftui-expert-skill` e no padrão já adotado no projeto.
- A importação de mídia usará APIs do app host. O core da biblioteca não conhecerá `PhotosPicker`, `PhotoKit` ou permissões do sistema.

## Problema que a fase 13 resolve

Hoje o app abre direto no editor com dados fixos:

- `sourceVideoURL` aponta para `/tmp/demo.mov`
- `duration` é carregada manualmente
- `videoSize` é fixa
- `preferredTransform` não vem de um asset real

Na prática, isso impede validar o fluxo real de uso do editor no device e mascara problemas de:

- rotação real do vídeo
- duração real para presets
- aspect ratio real do preview
- carregamento de asset antes do editor

## Princípio de arquitetura desta fase

Esta fase deve ficar no **app de exemplo**, não no núcleo da biblioteca.

Regra:

- `Core`, `Models`, `Public` e `UI` continuam independentes de importação de mídia do sistema
- a nova etapa só orquestra a criação de um `VideoProject` real antes de instanciar o editor

Motivo:

- preserva a biblioteca como componente reutilizável
- evita acoplamento do core com PhotoKit
- mantém o fluxo de teste manual como responsabilidade do host app

## Escopo da Fase 13

### 1. Shell de entrada do app de exemplo

Evoluir `ContentView` para um fluxo em duas etapas:

- etapa 1: tela de importação
- etapa 2: editor aberto com asset carregado

Estado proposto:

- `.idle`
- `.importing`
- `.ready(session)`
- `.failed(message)`

Esse estado deve viver em um objeto observável do app host, no `@MainActor`.

### 2. Serviço de importação para vídeo do device

Adicionar uma camada fina no app host para:

- receber a seleção do usuário
- obter acesso ao arquivo do vídeo
- copiar o vídeo para um local estável da sandbox do app
- devolver a `URL` local final

Decisão proposta:

- usar `PhotosPicker` com filtro de vídeos como caminho principal

Motivo:

- é a API moderna e nativa para mídia do usuário
- reduz boilerplate de UIKit
- encaixa melhor com SwiftUI moderno

Observação:

- a URL retornada pela seleção não deve ser usada de forma transitória; o fluxo deve copiar o arquivo para `tmp` ou `Application Support` antes de abrir o editor

### 3. Bootstrap do editor com asset real

Adicionar um builder/factory no app host para transformar a URL importada em uma sessão pronta para o editor.

Responsabilidades:

- chamar `AVFoundationVideoAssetLoader`
- montar `LoadedVideoAsset`
- criar `VideoProject` inicial
- instanciar `VideoEditorController`
- chamar `loadVideo(duration:)`
- expor `videoSize` e `preferredTransform` corretos para `VideoEditorView`

Sessão proposta:

- `controller`
- `loadedAsset`
- `projectSourceURL`

Regra importante:

- o editor só abre depois que o asset estiver validado e carregado

### 4. Tela de importação do app de exemplo

Adicionar uma view dedicada para a entrada do fluxo.

Essa view deve ter:

- título e explicação curta
- botão de importar vídeo
- estado de carregamento
- feedback de erro
- ação para trocar o vídeo depois que o editor estiver aberto

A view não deve conter lógica de cópia de arquivo nem de leitura de metadados.

### 5. Retorno e troca de vídeo

Adicionar uma affordance simples para voltar à etapa de importação.

Fluxo mínimo:

- usuário importa um vídeo
- editor abre
- usuário pode tocar em `Trocar vídeo`
- estado atual do editor de exemplo é descartado
- fluxo volta à etapa de entrada

Isso facilita testes repetidos no device sem recompilar o app.

## Estrutura proposta

```text
VideoEditorKit/
  ContentView.swift
  Example/
    ExampleRootState.swift
    ExampleEditorSession.swift
    ExampleVideoImportView.swift
    ExampleVideoImportCoordinator.swift
    ExampleVideoEditorFactory.swift

VideoEditorKitTests/
  Example/
    ExampleVideoImportCoordinatorTests.swift
    ExampleVideoEditorFactoryTests.swift
```

## Decisões de implementação

### 1. `PhotosPicker` fica restrito ao app host

`PhotosPicker` deve existir apenas na camada de exemplo.

Motivo:

- a biblioteca não deve depender do modo como o app host escolhe mídia
- no futuro, outro host pode abrir o editor a partir de `Files`, câmera, download remoto ou assets internos

### 2. Carregamento real continua centralizado em `AVFoundationVideoAssetLoader`

Não criar um caminho alternativo de leitura de asset.

Motivo:

- já existe uma abstração para carregar duração, tamanho e rotação
- evita duplicação de regra de validação
- aproxima o teste manual do fluxo real que será usado pelo editor

### 3. Sessão pronta antes de abrir a UI do editor

O editor não deve lidar com “asset ainda carregando”.

Motivo:

- mantém `VideoEditorView` focada em edição
- reduz branches de estado dentro da UI principal
- evita espalhar tratamento de erro de importação pela tela do editor

### 4. Estado do fluxo fica fora de `VideoEditorController`

Não expandir `VideoEditorController` para conhecer importação.

Motivo:

- `VideoEditorController` é o orquestrador de edição
- a importação de mídia é preocupação do host app
- isso preserva o limite arquitetural da biblioteca

## Sequência TDD

1. escrever testes da factory que transforma uma `URL` local em sessão pronta do editor
2. escrever testes do coordinator de importação usando doubles para staging e asset loading
3. validar a falha inicial da suíte nova
4. implementar coordinator, factory e estado do fluxo
5. integrar `ContentView` com a nova tela de importação
6. abrir o editor usando `LoadedVideoAsset` real
7. rodar a suíte relevante novamente até verde

## Critérios de aceite

- o app não depende mais de `/tmp/demo.mov` para abrir
- é possível escolher um vídeo real do device
- o vídeo selecionado é copiado para uma URL local estável antes da edição
- `VideoEditorView` recebe `videoSize` e `preferredTransform` reais do asset
- `VideoEditorController` recebe `duration` real antes de iniciar a edição
- erro de importação ou de asset inválido aparece na etapa de entrada, sem abrir o editor
- existe uma ação simples para trocar o vídeo e repetir o teste manual

## Fora do escopo

- importação por `Files`
- captura por câmera
- lista de vídeos recentes
- persistência da última sessão importada
- geração de thumbnail do vídeo na tela de entrada
- testes de interface
