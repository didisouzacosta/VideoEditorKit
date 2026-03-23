# VideoEditorKit — Plano Técnico da Fase 16

## Objetivo

Fechar o principal gap funcional do editor atual: substituir o preview estático por uma superfície real de reprodução de vídeo, sincronizada ao `PlayerEngine` e respeitando a arquitetura do projeto.

Ao final da fase 16, o editor deve:

- reproduzir o vídeo real importado dentro do preview
- manter `PlayerEngine` como fonte única de verdade do tempo
- refletir `play`, `pause`, `seek` e scrub da timeline no player real
- devolver atualizações periódicas do player para o `VideoEditorController`
- continuar compondo `safeFrame` e `CaptionOverlayView` por cima da superfície de vídeo

## Referências obrigatórias

- `swiftui-pro`
- `swiftui-expert-skill`

As duas skills orientam principalmente:

- manter a view SwiftUI fina e declarativa
- concentrar sincronização de playback fora do `body`
- usar `@State` apenas para posse local do coordenador de preview
- preservar acessibilidade, Dark Mode e APIs modernas

### Desvios documentados

- A reprodução visual real exige `AVPlayerLayer`, portanto esta fase usa um bridge UIKit fino via `UIViewRepresentable`. O uso é intencional e restrito ao host visual do player.
- O controle de playback real não será movido para `PlayerEngine`; ele continua como engine de tempo. O player nativo será apenas um executor sincronizado a essa fonte de verdade.

## Problema que a fase 16 resolve

Hoje o projeto já possui:

- importação real de vídeo
- `LoadedVideoAsset` com metadados válidos
- `PlayerEngine`
- timeline com scrub e play/pause
- overlay de legenda com paridade de layout

Mas o preview principal ainda é apenas uma superfície preta com overlays.

Consequências:

- não há validação visual real do vídeo durante a edição
- timeline e player não formam um ciclo de playback completo
- não é possível verificar se scrub, trim e playhead estão coerentes com um player nativo

## Escopo da Fase 16

### 1. Coordenador de playback do preview

Adicionar um coordenador dedicado para sincronizar:

- `sourceVideoURL`
- `currentTime`
- `isPlaying`

com um driver de player real.

Responsabilidades:

- carregar o vídeo apenas quando a URL muda
- evitar seeks redundantes em atualizações periódicas
- executar `play` e `pause` apenas quando o estado mudar
- encaminhar time updates do player para o controller

### 2. Driver testável para player real

Introduzir um protocolo fino para abstrair o player nativo.

Objetivo:

- permitir testes unitários do coordenador sem depender de playback real em teste
- manter `AVPlayer` isolado em uma implementação concreta

### 3. Superfície visual de preview

Adicionar uma view dedicada para o vídeo:

- `VideoPreviewSurfaceView`
- host visual via `AVPlayerLayer`
- mapeamento de `VideoGravity.fit/fill` para o `videoGravity` nativo

Essa view deve:

- hospedar o player real
- sincronizar o coordenador com o estado do editor
- não conter regra temporal além da ligação com o coordenador

### 4. Integração no `VideoEditorView`

Atualizar o card de preview para:

- renderizar a superfície real de vídeo no fundo
- manter `SafeFrameOverlay`
- manter `CaptionOverlayView`
- continuar exibindo metadata de preset e tempo atual

## Estrutura proposta

```text
VideoEditorKit/
  Core/
    VideoPreviewPlaybackCoordinator.swift
  UI/
    VideoPreviewSurfaceView.swift
    VideoEditorView.swift

VideoEditorKitTests/
  Core/
    VideoPreviewPlaybackCoordinatorTests.swift
```

## Sequência TDD

1. escrever testes do coordenador de playback
2. validar a falha inicial da suíte nova
3. implementar driver protocol e coordenador
4. implementar a superfície com `AVPlayerLayer`
5. integrar no `VideoEditorView`
6. rodar a suíte relevante novamente até verde

## Critérios de aceite

- o preview mostra o vídeo real do projeto quando a URL existe
- `play` e `pause` da timeline controlam o player real
- scrub e seeks do editor movem o player real
- time updates do player voltam para o controller sem loop de seek redundante
- a superfície de vídeo respeita `VideoGravity.fit` e `.fill`
- overlays de safe frame e legenda continuam sobrepostos ao vídeo
- toda view criada ou alterada possui `#Preview` funcional

## Fora do escopo

- controles nativos de player na superfície
- sincronização com áudio extra
- filtros e correções de cor em tempo real
- thumbnails reais da timeline
- fullscreen dedicado
- testes de interface
