# VideoEditorKit — CLAUDE.md

## Estado atual do projeto

`VideoEditorKit` hoje é um **app iOS SwiftUI**, não um SDK modular pronto para integração host.

O nome do target continua `VideoEditorKit`, mas a base atual implementa um editor de vídeo monolítico com:

- importação de vídeo via `PhotosPicker`
- persistência local com `CoreData`
- edição de corte, velocidade, rotação/espelho, áudio, texto, filtros, correções e moldura
- exportação assíncrona para arquivo `.mp4`

O código ainda não segue a arquitetura alvo descrita em `AGENTS.md` e no `CLAUDE.md` antigo. Não existem hoje `Core/`, `LayoutEngine`, `PlayerEngine`, `ExportEngine` ou snapshots codáveis separados.

---

## Stack real

- SwiftUI
- Observation (`@Observable`)
- AVFoundation / AVKit
- PhotosUI
- Core Image
- Core Data
- UIKit bridges (`UITextView`, `AVPlayerViewController`, `AVCaptureVideoPreviewLayer`, `UIActivityViewController`)

Build settings atuais:

- app target: iOS 26.0
- tests target: iOS 26.0
- app em Swift 6
- tests em Swift 6

---

## Estrutura real do repositório

```text
VideoEditorKit/
  Models/        — modelos de domínio leves (`Video`, `TextBox`, `Audio`, `VideoQuality`)
  ViewModels/    — estado observável da UI (`RootViewModel`, `EditorViewModel`, etc.)
  Service/       — player, câmera, gravador de áudio, Core Data
  Views/         — telas e componentes SwiftUI do editor
  Utils/         — helpers de exportação, filtros, extensões e utilitários
  VideoEditorKitApp.swift

VideoEditorKitTests/
  — testes unitários pontuais para formatação, texto e modelo `Video`
```

Não há separação atual entre camada de domínio pura, engines testáveis e UI fina. A maior parte da lógica está distribuída entre `ViewModels`, `Service` e `Utils/Helpers/VideoEditor.swift`.

---

## Fluxo principal do app

### 1. Entrada

- `VideoEditorKitApp` inicializa `RootView` com `RootViewModel`.
- `RootView` lista projetos salvos em Core Data.
- O usuário pode criar projeto importando um vídeo com `PhotosPicker`.

### 2. Importação

- `VideoItem: Transferable` copia o vídeo escolhido para `Documents/<uuid>.mp4`.
- `RootView` navega para `MainEditorView(selectedVideoURl:)`.

### 3. Criação e carregamento de projeto

- `EditorViewModel.setNewVideo` cria um `Video`, gera thumbnails e cria um `ProjectEntity`.
- `EditorViewModel.setProject` restaura do Core Data:
  - range selecionado
  - velocidade
  - rotação
  - espelho
  - filtro
  - correções
  - moldura
  - textos
  - áudio gravado

### 4. Edição

- `MainEditorView` compõe:
  - header
  - player/preview
  - controles de timeline
  - grade de ferramentas ou bottom sheet da ferramenta ativa
- `VideoPlayerManager` controla reprodução, scrub, filtros de preview e player de áudio adicional.
- `TextEditorViewModel` mantém seleção e edição de overlays de texto.

### 5. Persistência

- Ao sair do editor ou quando a cena vai para `background`/`inactive`, `editorVM.updateProject()` salva o estado atual.
- Ao apagar um projeto, o app remove:
  - thumbnail `.jpg`
  - vídeo copiado em `Documents`
  - registro do Core Data

### 6. Exportação

- `VideoExporterBottomSheetView` escolhe qualidade e dispara `ExporterViewModel`.
- `ExporterViewModel` chama `VideoEditor.startRender(video:videoQuality:)`.
- O arquivo final pode ser salvo na biblioteca de fotos ou compartilhado.

---

## Ferramentas que existem hoje

### Corte

- Implementado por `ThumbnailsSliderView` + `RangedSliderView`.
- Atualiza `video.rangeDuration`.
- O preview para ao alcançar o fim do range.
- O export usa o mesmo `rangeDuration`.

### Velocidade

- Implementada por `VideoSpeedSlider`.
- Range de velocidade: `0.1x ... 8.0x`.
- `Video.updateRate(_:)` recalcula o range selecionado proporcionalmente.
- O player usa `AVPlayer.rate`.
- O export aplica `scaleTimeRange` nas tracks de vídeo e áudio.

### Crop / rotação / espelho

- O estado persistido e exportado hoje cobre:
  - rotação em passos de 90 graus
  - espelhamento horizontal
- Existe uma `CropView` com retângulo de crop visual e drag.
- Esse crop visual **não** é salvo no modelo e **não** participa do export atual.
- A aba `format` em `CropSheetView` está vazia.

### Áudio

- O app suporta um áudio adicional gravado no próprio editor.
- `AudioRecorderManager` grava para um arquivo `.m4a` temporário no cache.
- O fluxo de contagem regressiva e atualização de duração agora usa `Task` cancelável em vez de `Timer`.
- A gravação usa a duração máxima nativa de `AVAudioRecorder.record(forDuration:)`.
- O timeline mostra uma faixa de áudio quando existe áudio gravado.
- O usuário pode alternar entre faixa do vídeo e faixa gravada para ajustar volume.
- O export mistura:
  - áudio original do vídeo com `video.volume`
  - um único áudio adicional com `audio.volume`

### Texto

- `TextEditorView` cria e edita `TextBox`.
- Cada texto possui:
  - conteúdo
  - `fontSize`
  - cor de fundo
  - cor da fonte
  - `timeRange`
  - `offset`
- O preview permite:
  - selecionar
  - mover
  - aumentar/reduzir fonte com pinça
  - duplicar
  - remover
- `saveTapped()` remove textos vazios ou só com whitespace.
- O export desenha textos via `CATextLayer` com animações simples de entrada/saída.

### Filtros

- `FiltersViewModel` gera previews dos filtros a partir da primeira thumbnail.
- O preview usa `AVVideoComposition` com `CoreImage`.
- O export aplica filtros em uma segunda etapa após a composição base.

### Correções de cor

- Ajustes disponíveis:
  - brilho
  - contraste
  - saturação
- São convertidos em um `CIColorControls`.
- Preview e export usam a mesma combinação de filtros gerada em `Helpers.createFilters`.

### Moldura / frame

- `VideoFrames` guarda:
  - `scaleValue`
  - `frameColor`
- O preview aplica fundo colorido e escala do vídeo.
- O export recria esse efeito com `CALayer`.

### Câmera

- Existe implementação de câmera/gravação em `CameraManager` e `RecordVideoView`.
- O `AVCaptureMovieFileOutput` já usa `maxRecordedDuration` para o limite máximo da gravação.
- `MainEditorView` tem `showRecordView`, mas a UI atual não expõe um botão para abrir esse fluxo.
- Na prática, a câmera está presente no código, porém não integrada ao fluxo principal visível.

### Roadmap atual de modernização dos managers

- O plano incremental para `VideoPlayerManager`, `AudioRecorderManager` e `CameraManager` está documentado em `docs/managers-modernization-roadmap.md`.
- Fase 1 ja foi concluida com correcoes seguras de ciclo de vida, identidade de players e geracao de arquivo temporario por gravacao.
- Fase 2 ja foi concluida com `Task` cancelavel para countdown/progresso, `record(forDuration:)`, `maxRecordedDuration` e ajustes de isolamento/observation nos managers.
- Fase 3 segue como proxima etapa para seams de teste mais limpos e menor acoplamento com AVFoundation.

---

## Exportação atual

O pipeline real fica em `Utils/Helpers/VideoEditor.swift` e ocorre em duas etapas:

1. `resizeAndLayerOperation`
2. `applyFiltersOperations`

### Etapa 1: composição base

- cria `AVMutableComposition`
- recorta pelo `rangeDuration`
- aplica mudança de velocidade com `scaleTimeRange`
- aplica rotação/orientação
- aplica espelho
- define resolução final conforme `VideoQuality`
- adiciona fundo de moldura
- renderiza textos com `CATextLayer`

### Etapa 2: filtros

- abre o arquivo gerado na etapa 1
- aplica filtro principal + correção de cor com `AVVideoComposition`
- exporta novamente para um `temp_video.mp4`

### Qualidades disponíveis

- `low`: 854x480
- `medium`: 1280x720
- `high`: 1920x1080

O `VideoQuality` também expõe estimativa simples de tamanho por duração.

---

## Persistência atual

Persistência é feita via `CoreDataContainer.xcdatamodeld`.

### `ProjectEntity`

Salva:

- nome do arquivo de vídeo em `Documents`
- data de criação
- `lowerBound` / `upperBound`
- velocidade
- rotação
- espelho
- filtro
- brilho / contraste / saturação
- ferramentas aplicadas em CSV
- cor e escala da moldura
- relação com áudio
- relação com textos

### `TextBoxEntity`

Salva:

- texto
- cores em hexadecimal
- tamanho da fonte
- intervalo de tempo
- offset X/Y

### `AudioEntity`

Salva:

- URL do áudio gravado
- duração

### Thumbnail de projeto

- a capa do projeto é salva separadamente como `.jpg` em `Documents`

---

## Estado real de preview vs export

O projeto tenta manter coerência entre preview e export, mas **essa paridade ainda não é garantida por arquitetura centralizada**.

Situação atual:

- corte: parcialmente alinhado
- velocidade: alinhada entre player e export
- filtro/correção: mesma ideia de pipeline, mas preview e export usam caminhos diferentes
- moldura: alinhada conceitualmente
- texto: preview e export compartilham o mesmo modelo, mas a conversão de coordenadas é manual
- crop livre: preview visual existe, export não usa esse crop

Conclusão prática: **não assumir `Preview = Export` como verdade absoluta no estado atual**.

---

## Estado real de arquitetura e observação

O código atual já usa `@Observable` em boa parte do estado de UI:

- `RootViewModel`
- `EditorViewModel`
- `TextEditorViewModel`
- `FiltersViewModel`
- `ExporterViewModel`
- `VideoPlayerManager`
- `AudioRecorderManager`
- `CameraManager`

Ao mesmo tempo, ainda existem características de transição:

- lógica importante dentro de views e helpers
- uso de `GeometryReader`
- uso de `UIScreen.main.bounds` em extensão de `View`
- uso de `String(format:)`
- bridges UIKit relevantes para texto, player, câmera e share sheet

Ou seja: o projeto está mais próximo de um **app SwiftUI com MVVM + services** do que da arquitetura final orientada a engines puras descrita em `AGENTS.md`.

---

## Testes atuais

Existem apenas testes unitários.

A suíte usa **Swift Testing** como padrão:

- `import Testing`
- `@Suite` para agrupar cenários
- `@Test` para casos individuais
- `#expect` e `#require` para asserções

Cobertura atual:

- `EditorViewModelTests`
- `PlaybackTimeMappingTests`
- `TextEditorViewModelTests`
- `TimelineMetricsTests`
- `TimeIntervalFormattingTests`
- `VideoModelTests`

Os testes cobrem apenas partes pequenas do comportamento:

- trim de whitespace em texto
- remoção/cópia de `TextBox`
- formatação de tempo
- atualização de velocidade em `Video`
- rotação cíclica
- marcação de ferramentas aplicadas

Não há hoje testes unitários para:

- exportação
- player
- Core Data
- filtros
- correções
- áudio
- persistência completa de projeto

---

## Arquivos centrais para entender o projeto

- `VideoEditorKit/VideoEditorKitApp.swift`
- `VideoEditorKit/Views/RootView/RootView.swift`
- `VideoEditorKit/Views/EditorView/MainEditorView.swift`
- `VideoEditorKit/ViewModels/EditorViewModel.swift`
- `VideoEditorKit/Service/Player/VideoPlayerManager.swift`
- `VideoEditorKit/ViewModels/TextEditorViewModel.swift`
- `VideoEditorKit/Service/CoreData/ProjectEntity+Ext.swift`
- `VideoEditorKit/Utils/Helpers/VideoEditor.swift`

---

## Limitações importantes para futuras mudanças

1. Não tratar o projeto atual como SDK modular já pronto. Hoje ele é um app.
2. Não presumir que exista uma engine única de layout, tempo ou export. Essa centralização ainda não foi implementada.
3. Não presumir que crop livre funcione no export. Hoje não funciona.
4. Não presumir export concorrente bloqueado por regra explícita. O código atual não tem esse guarda.
5. Não presumir snapshot imutável de export. O export recebe o `Video` atual diretamente.
6. Não presumir múltiplas trilhas de áudio, multilayer de vídeo, presets sociais ou legenda por coordenadas normalizadas. Nada disso existe hoje.

---

## Diretriz para próximos agentes

Quando modificar este repositório, partir sempre do comportamento real descrito acima.

Se o projeto for migrado para a arquitetura alvo de `AGENTS.md`, este arquivo deve ser atualizado junto com:

- a estrutura de pastas
- o modelo de persistência
- a fonte de verdade de preview/export
- a estratégia de testes

---

## Padrão de estilo e manutenção

Para mudanças futuras neste repositório, usar o padrão abaixo como baseline:

- `.swift-format` na raiz é a fonte de verdade da formatação
- indentação com `4` espaços
- no máximo `1` linha em branco consecutiva
- preservar quebras de linha relevantes quando o formatter permitir
- remover código morto, helpers sem uso e vestígios visuais de debug antes de concluir a mudança
- evitar `force unwrap` quando `guard let` ou `if let` resolverem o fluxo com segurança equivalente
- corrigir typos e preferir nomes claros em inglês ao tocar em propriedades, métodos e tipos
- não espalhar `print` operacional pela base; preferir tratamento explícito e `assertionFailure` apenas para estados inesperados
- manter extensões utilitárias enxutas e alinhadas com uso real do projeto
- toda nova feature deve começar com testes cobrindo suas principais regras de negócio antes da implementação final ou, no mínimo, no mesmo ciclo da primeira alteração funcional
- ao tocar em código legado, primeiro criar um teste unitário de caracterização para preservar o comportamento atual e só depois aplicar refactors, correções ou melhorias
- todo `init` explícito deve usar `_` no primeiro parâmetro
- em `init` de views e componentes, parâmetros que alimentam `Binding` e `State` devem vir antes dos demais
- no corpo do `init`, atribuições de `Binding` e `State` devem ficar agrupadas e separadas visualmente das demais propriedades por uma linha em branco
- ao editar Swift, rodar formatação do projeto antes de finalizar
- novos testes e refactors de testes devem usar `Swift Testing`; não introduzir novos casos em `XCTestCase`
- em testes, preferir `@Suite` + `@Test` + `#expect`/`#require` e só usar `@MainActor` quando o cenário realmente tocar estado de UI ou tipos main-thread-bound

### Organização de arquivos Swift com `// MARK: -`

Todo código Swift do repositório deve seguir organização explícita por grupos com `// MARK: -`, usando nomes fixos e ordem previsível.

#### Regra geral

- aplicar esse padrão a `View`, `ViewModel`, `Manager`, `Model`, `Shape`, `ViewModifier` e `extension`
- omitir grupos que não se aplicam ao tipo, mas nunca trocar a ordem dos grupos usados
- preferir `fileprivate` para subviews auxiliares declaradas no mesmo arquivo
- callbacks devem começar como `private` e só serem expostos quando houver necessidade real de API
- actions inline em `Button`, `sheet`, `task`, `onChange` e similares são permitidas quando isso mantiver a leitura melhor do que extrair método

#### Ordem obrigatória para `View`

Quando aplicável, a ordem dos grupos em uma `View` deve ser:

1. `// MARK: - Environments`
2. `// MARK: - Bindables`
3. `// MARK: - Bindings`
4. `// MARK: - App Storage`
5. `// MARK: - Scene Storage`
6. `// MARK: - Focus State`
7. `// MARK: - Gesture State`
8. `// MARK: - Namespaces`
9. `// MARK: - States`
10. `// MARK: - Public Properties`
11. `// MARK: - Body`
12. `// MARK: - Private Properties`
13. `// MARK: - Initializer`
14. `// MARK: - Public Methods`
15. `// MARK: - Private Methods`

#### Regras de visibilidade

- propriedades expostas devem ficar em `Public Properties`
- propriedades internas de suporte e dependências não públicas devem ficar em `Private Properties`
- `@Environment`, `@Bindable`, `@Binding`, `@AppStorage`, `@SceneStorage`, `@FocusState`, `@GestureState`, `@Namespace` e `@State` devem ficar em grupos separados, sem misturar wrappers diferentes no mesmo bloco
- quando um grupo tiver apenas propriedades privadas, mantê-las com `private`
- quando uma propriedade ou método precisar ser público para composição externa, mover para o grupo público correspondente

#### Tipos sem `body`

Para tipos que não são `View`, usar o subconjunto compatível da mesma convenção, preservando nomes e ordem:

1. `// MARK: - Public Properties`
2. `// MARK: - Private Properties`
3. `// MARK: - Initializer`
4. `// MARK: - Public Methods`
5. `// MARK: - Private Methods`

#### Exemplo base para `View`

```swift
struct ExampleView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - Bindings

    @Binding private var value: String

    // MARK: - States

    @State private var isLoading = false

    // MARK: - Public Properties

    let title: String

    // MARK: - Body

    var body: some View {
        content
    }

    // MARK: - Private Properties

    private var content: some View {
        Text(title)
    }

    // MARK: - Initializer

    init(title: String, value: Binding<String>) {
        self.title = title
        _value = value
    }

    // MARK: - Public Methods

    func trackDisplay() {}

    // MARK: - Private Methods

    private func submit() {}
}
```
