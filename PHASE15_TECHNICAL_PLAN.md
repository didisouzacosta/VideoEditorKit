# VideoEditorKit — Plano Técnico da Fase 15

## Objetivo

Analisar o funcionamento completo do repositório `taananas/VideoEditorSwiftUI` e definir um plano para atingir paridade funcional, mas reimplementando tudo com arquitetura e APIs modernas.

Esta fase muda o escopo do projeto.

O pedido de “ter tudo que existe nesse editor” vai além do MVP descrito em `AGENTS.md`, porque inclui:

- speed control
- crop/rotate/mirror
- texto livre com editor próprio
- áudio gravado e mixagem
- filtros
- correções de cor
- frames
- persistência de projetos com galeria
- export/save/share com múltiplas qualidades

Portanto, esta fase deve ser tratada como expansão de produto, não como simples continuação do MVP original.

Data da análise: `2026-03-23`.

---

## Referências analisadas

Repositório:

- [VideoEditorSwiftUI](https://github.com/taananas/VideoEditorSwiftUI)

Arquivos principais analisados:

- [README.md](https://github.com/taananas/VideoEditorSwiftUI/blob/main/README.md)
- [MainEditorView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/EditorView/MainEditorView.swift)
- [PlayerHolderView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/EditorView/PlayerHolderView.swift)
- [TimeLineView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/EditorView/TimeLineView.swift)
- [ToolsSectionView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/ToolsSectionView.swift)
- [EditorViewModel.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/ViewModels/EditorViewModel.swift)
- [TextEditorViewModel.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/ViewModels/TextEditorViewModel.swift)
- [FiltersViewModel.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/ViewModels/FiltersViewModel.swift)
- [ExporterViewModel.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/ViewModels/ExporterViewModel.swift)
- [Video.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Models/Video.swift)
- [ToolModel.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Models/ToolModel.swift)
- [TextBox.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Models/TextBox.swift)
- [AudioModel.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Models/AudioModel.swift)
- [VideoPlayerManager.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Service/Player/VideoPlayerManager.swift)
- [AudioRecorderManager.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Service/Recorder/AudioRecorderManager.swift)
- [ProjectEntity+Ext.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Service/CoreData/ProjectEntity%2BExt.swift)
- [RootView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/RootView/RootView.swift)
- [VideoEditor.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Utils/Helpers/VideoEditor.swift)
- [VideoExporterBottomSheetView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/EditorView/VideoExporterBottomSheetView.swift)
- [CropSheetView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Crop/CropSheetView.swift)
- [CropView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Crop/CropView.swift)
- [TextOverlayView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Text/TextOverlayView.swift)
- [TextToolsView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Text/TextToolsView.swift)
- [AudioSheetView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Audio/AudioSheetView.swift)
- [FiltersView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Filters/FiltersView.swift)
- [CorrectionsToolView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Corrections/CorrectionsToolView.swift)
- [FramesToolView.swift](https://github.com/taananas/VideoEditorSwiftUI/blob/main/VideoEditorSwiftUI/Views/ToolsView/Frames/FramesToolView.swift)

---

## Resumo funcional do editor de referência

O editor de referência entrega um produto com estas capacidades:

1. criar projeto novo a partir da biblioteca do device
2. listar projetos salvos e reabrir edição
3. reproduzir vídeo com preview e fullscreen parcial
4. cortar range temporal
5. alterar velocidade do vídeo
6. rotacionar e espelhar vídeo
7. adicionar textos com tempo, posição, escala, cópia e remoção
8. gravar áudio e mixar com o vídeo
9. controlar volume do vídeo e do áudio extra
10. aplicar filtros Core Image
11. aplicar correções de brilho, contraste e saturação
12. adicionar frames/bordas com cor e escala
13. exportar em qualidades diferentes
14. salvar na biblioteca ou compartilhar

Isso é funcionalmente muito mais amplo que o `VideoEditorKit` atual.

---

## Como o editor de referência funciona hoje

## 1. Root flow

Em `RootView.swift`, o app:

- lista projetos persistidos
- permite criar novo projeto com `PhotosPicker`
- abre `MainEditorView`

Problemas da implementação atual:

- estado de navegação espalhado em múltiplos `@State`
- dependência direta de Core Data na UI
- fluxo de carregamento pouco isolado

## 2. Modelo central

Em `Video.swift`, praticamente todo o estado de edição vive dentro de um único model:

- URL e `AVAsset`
- duração original e range selecionado
- thumbnails
- rate
- rotação
- mirror
- filter
- color correction
- frames
- text boxes
- áudio extra
- volume

Problema:

- esse model mistura concern de domínio, cache visual, estado temporário de UI e estado de export

## 3. Shell do editor

Em `MainEditorView.swift`, a tela principal compõe:

- header
- player
- play controls
- timeline
- tool tray
- export sheet
- modal de texto

Problema:

- o shell é útil visualmente, mas está altamente acoplado a view models antigos

## 4. Playback

Em `VideoPlayerManager.swift`, o projeto usa:

- `ObservableObject`
- `@Published`
- `AVPlayer`
- KVO publisher do `timeControlStatus`
- periodic time observer
- estado de scrub manual
- player separado para áudio extra

Pontos funcionais suportados:

- play/pause
- seek
- respeitar selected range
- playback rate
- mix com áudio adicional
- preview de filtros via `videoComposition`

Problemas:

- estado espalhado entre player, view model e view
- lógica temporal fora de um engine puro
- dependência de Combine para observação
- duplicação entre preview e export

## 5. Timeline

Em `TimeLineView.swift`, o editor mostra:

- thumbnails do vídeo
- playhead
- range selection
- faixa de texto quando o tool de texto está ativo
- trilha de áudio quando áudio está ativo

Problemas:

- timeline depende do tool ativo para mudar de forma
- dados são preparados dentro das views
- há acoplamento com `GeometryProxy` e estado do player

## 6. Cut

O tool `cut` funciona ajustando `rangeDuration` no model `Video` e refletindo isso na timeline e no export.

Valor funcional:

- trimming básico já existe no repositório de referência

## 7. Speed

O tool `speed` altera `rate` em `Video` e recalcula `rangeDuration`.

No export:

- `VideoEditor.swift` usa `scaleTimeRange` para alterar a velocidade

## 8. Crop / rotate / mirror

O tool de crop atual é limitado.

Em `CropSheetView.swift` e `CropView.swift`, o comportamento real é:

- rotate em incrementos de 90 graus
- mirror horizontal
- overlay visual de crop

Limitação importante:

- o crop visual parece mais affordance de UI do que recorte persistido e aplicado de forma robusta no export
- o export aplica resize, rotate, mirror e frame scale, mas não há uma modelagem clara de crop não destrutivo equivalente ao preview

Conclusão:

- rotate e mirror estão implementados de forma funcional
- crop verdadeiro parece incompleto

## 9. Text

Em `TextBox.swift`, `TextEditorViewModel.swift`, `TextToolsView.swift` e `TextOverlayView.swift`, o sistema de texto suporta:

- criar texto
- editar texto
- definir cor de fundo e cor da fonte
- definir tamanho da fonte
- definir time range
- selecionar texto
- arrastar posição
- pinçar para escalar
- copiar
- remover

No export:

- `VideoEditor.swift` cria `CATextLayer`
- posiciona no frame exportado
- aplica animação simples de aparecer/desaparecer

Problemas:

- coordenadas baseadas em offset de UI, não em layout normalizado robusto
- risco real de divergência preview/export
- edição e visualização fortemente acopladas

## 10. Audio

Em `AudioRecorderManager.swift` e `AudioSheetView.swift`, o app suporta:

- gravar narração
- anexar áudio extra ao projeto
- controlar volume do vídeo
- controlar volume do áudio extra
- reproduzir ambos sincronizados

No export:

- `VideoEditor.swift` adiciona trilha adicional de áudio na composição

Problemas:

- recorder, player e editor compartilham estado de maneira frágil
- não há engine dedicada para mixagem e timeline de áudio

## 11. Filters

Em `FiltersViewModel.swift` e `FiltersView.swift`, o app:

- gera previews de filtros Core Image
- aplica filtro selecionado ao preview
- exporta com os mesmos filtros

Pontos fortes:

- existe noção de preview e export relativamente alinhados

Problemas:

- filtros são gerados de forma oportunista na view model
- ausência de pipeline explícito e testável de filter graph

## 12. Corrections

Em `CorrectionsToolView.swift`, o app controla:

- brightness
- contrast
- saturation

No preview e export:

- esses ajustes entram no pipeline de Core Image

## 13. Frames

Em `FramesToolView.swift` e `VideoEditor.swift`, o app suporta:

- escolher cor de fundo
- diminuir escala do vídeo para gerar uma borda/frame

Isso não é “frame template”; é um matte/background com vídeo escalado dentro.

## 14. Persistência

Em `ProjectEntity+Ext.swift` e Core Data:

- projeto é salvo
- thumbnail é persistida
- parâmetros principais de edição são persistidos
- texto e áudio são persistidos

Problemas:

- Core Data está acoplado ao runtime model
- snapshots e validação são fracos
- depende de serialização implícita e entidades específicas do app

## 15. Export / save / share

Em `ExporterViewModel.swift`, `VideoQuality.swift`, `VideoExporterBottomSheetView.swift` e `VideoEditor.swift`, o app:

- renderiza vídeo com composição AVFoundation
- permite export em baixa, média e alta qualidade
- salva na biblioteca
- compartilha via `UIActivityViewController`

Problemas:

- estado de export centrado em view model
- share/save amarrados à UI
- presets de export baseados em qualidade genérica, não em presets de produto

---

## Gap em relação ao `VideoEditorKit` atual

Hoje o `VideoEditorKit` já está melhor em alguns fundamentos:

- `@Observable`
- `PlayerEngine`
- `LayoutEngine`
- snapshots de preview e timeline
- sanitização de captions
- persistência desacoplada por snapshots
- `Preview = Export` como princípio explícito

Mas ele ainda não cobre toda a superfície funcional do editor de referência.

Faltam, em termos de parity:

- galeria de projetos
- speed tool
- rotate / mirror tool
- sistema completo de texto livre
- gravação e mixagem de áudio
- filtros
- correções de cor
- frames/mattes
- export com save/share
- pipeline completo de player real no preview

---

## Diretrizes de modernização obrigatórias

Para atingir parity sem repetir os problemas do projeto de referência, a reimplementação deve seguir estas regras.

## 1. Observation no lugar de Combine-first

Substituir:

- `ObservableObject`
- `@Published`
- `@StateObject` como padrão arquitetural

Por:

- `@Observable`
- `@MainActor`
- objetos observáveis menores
- bindings derivados por `@Bindable` quando necessário

## 2. Engines puras por domínio

Em vez de um `Video` monolítico e view models grandes, separar:

- `TimelineEngine`
- `PlaybackEngine`
- `VideoAdjustmentEngine`
- `TextOverlayEngine`
- `AudioMixEngine`
- `FilterPipelineEngine`
- `ExportEngine`
- `ProjectSnapshotEngine`

## 3. Layout e tempo continuam centralizados

Mesmo com parity funcional, não abrir mão de:

- `LayoutEngine` como fonte única de geometria
- `PlayerEngine` ou sucessor equivalente como fonte única de tempo

Toda feature nova deve depender disso.

## 4. Preview = Export

O maior defeito estrutural do repositório de referência é que várias features parecem partir da UI e só depois tentar refletir no export.

No `VideoEditorKit`, a direção deve ser inversa:

- user intent -> model edit instruction -> engine snapshot -> preview
- a mesma instruction -> export renderer

## 5. Persistência por snapshot, não por runtime UI state

Não adotar Core Data como shape principal do domínio.

Persistência moderna proposta:

- snapshots `Codable`
- entities de storage opcionais acima disso
- validação snapshot <-> runtime
- host app decide backend de persistência

## 6. Export desacoplado da UI

Salvar e compartilhar são responsabilidades do host app ou de adaptadores, não do core da lib.

A biblioteca deve:

- gerar arquivo exportado
- emitir progresso
- retornar URL final

O host decide:

- salvar em Photos
- compartilhar
- enviar para backend

---

## Parity moderno proposto

## Bloco A — Shell e fluxo

Escopo:

- galeria de projetos no app host
- importação moderna com `PhotosPicker`
- abertura de editor por sessão
- shell de editor com preview, transport, timeline e tray

Implementação moderna:

- `NavigationStack`
- estado de fluxo do host em `@Observable`
- sessions explícitas
- views pequenas

## Bloco B — Playback e timeline

Escopo:

- player real
- selected range
- playhead
- thumbnails
- speed
- sincronização com áudio adicional

Implementação moderna:

- engine de playback + adaptador AVPlayer
- timeline snapshots puros
- geração de thumbnails fora da view

## Bloco C — Transformações visuais

Escopo:

- rotate
- mirror
- crop verdadeiro
- fit/fill
- frames

Implementação moderna:

- `LayoutEngine` expandido
- modelo não destrutivo de transformações
- export e preview usando o mesmo layout result

## Bloco D — Texto / captions livres

Escopo:

- texto livre
- estilo
- drag
- scale
- time range
- duplicate/delete

Implementação moderna:

- convergir com o sistema de `Caption` já existente
- evitar dois sistemas paralelos de texto
- usar coordenadas normalizadas e safe frame

Decisão importante:

- em vez de criar “TextBox” separado, o caminho certo é evoluir `Caption` para suportar o conjunto completo de edição livre

## Bloco E — Áudio

Escopo:

- gravação
- trilha adicional
- volume do vídeo
- volume da trilha extra
- preview sincronizado
- export com mix

Implementação moderna:

- `AudioMixEngine`
- recorder do host ou adaptador dedicado
- timeline de áudio separada do core visual

## Bloco F — Filters e corrections

Escopo:

- presets de filtros
- brightness
- contrast
- saturation
- preview/export consistentes

Implementação moderna:

- pipeline explícito de filtros
- preview thumbnails derivadas do pipeline
- export baseado na mesma descrição declarativa do graph

## Bloco G — Persistência

Escopo:

- salvar projeto
- listar projetos
- reabrir edição

Implementação moderna:

- snapshots `Codable`
- store adapter no host app
- thumbnail cache separada

## Bloco H — Export productizado

Escopo:

- presets de export
- progresso
- save/share delegáveis

Implementação moderna:

- `ExportPreset` continua controlando produto
- qualidade genérica pode virar subconfiguração, não eixo principal
- `ExportEngine` retorna arquivo, não dispara UI

---

## Ordem recomendada de implementação

## Etapa 1 — Rebaselinar o escopo

Atualizar `PLAN.md` e roadmap para deixar claro que o projeto saiu do MVP original.

## Etapa 2 — Player real e shell moderno

Sem isso, qualquer parity funcional fica frágil.

## Etapa 3 — Expandir o modelo de edição

Adicionar:

- speed
- rotate
- mirror
- frame/matte
- filter settings
- audio overlay

## Etapa 4 — Unificar texto com captions

Essa é a decisão estrutural mais importante para evitar duplicação de sistemas.

## Etapa 5 — Audio mix

Separar recorder, playback e export.

## Etapa 6 — Filter pipeline

Tornar preview/export testáveis e declarativos.

## Etapa 7 — Persistência do host app

Só depois que o modelo estiver estável.

## Etapa 8 — Export UX

Fechar progresso, save e share.

---

## Riscos principais

## 1. Duplicar sistema de texto e captions

Isso seria um erro.

Mitigação:

- evoluir `Caption` para cobrir texto livre

## 2. Repetir o model monolítico `Video`

Mitigação:

- separar estado editável por domínio

## 3. Crop continuar só visual

Mitigação:

- modelagem não destrutiva explícita no `LayoutEngine`

## 4. Filters e export divergirem

Mitigação:

- pipeline declarativo único para preview e export

## 5. Persistência acoplada ao host sample

Mitigação:

- snapshots no core; storage adapter no host

---

## Critérios de aceite desta expansão

- todas as features centrais do editor de referência passam a existir no `VideoEditorKit`
- nenhuma delas depende de `ObservableObject` como padrão arquitetural
- preview e export usam a mesma fonte de verdade para layout, tempo e ajustes
- persistência não depende de tipos UIKit/Core Data no core
- salvar e compartilhar permanecem desacoplados da biblioteca
- cada bloco novo tem cobertura unitária para engines e builders

---

## Próxima ação recomendada

Antes de implementar qualquer uma dessas features, abrir um documento de replanejamento do domínio com este recorte:

- `VideoProject` expandido
- novos models de adjustment/audio/filter/text
- fronteira entre core da biblioteca e host app

Sem isso, a parity funcional vai empurrar o projeto para a mesma arquitetura acoplada do repositório de referência.
