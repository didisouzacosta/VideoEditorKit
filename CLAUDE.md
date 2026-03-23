# VideoEditorKit — CLAUDE.md

## O que é este projeto

`VideoEditorKit` é um SDK iOS para edição de vídeo.

O app host fornece um vídeo de entrada, o SDK aplica instruções de edição não destrutivas e retorna um novo vídeo editado. O arquivo original nunca é alterado.

O objetivo é oferecer uma base modular, previsível e testável para um editor de vídeo no estilo do editor nativo da Apple, com consistência total entre preview e export.

---

## Escopo funcional do SDK

O SDK deve suportar as seguintes operações de edição:

1. **Cortar** — definir intervalo inicial e final do vídeo.
2. **Alterar velocidade** — acelerar ou desacelerar trechos suportados pelo produto.
3. **Crop** — recortar a área visível do vídeo.
4. **Ajustar áudio** — controlar volume, mix e comportamento do áudio associado ao projeto.
5. **Adicionar texto** — sobrepor textos posicionados sobre o frame final.
6. **Adicionar filtros** — aplicar filtros visuais ao vídeo.
7. **Correções de cor** — brilho, contraste, saturação e ajustes equivalentes.
8. **Ajustar frame** — controlar aspect ratio, fit/fill, render size e composição final.

---

## Princípios obrigatórios

1. **Preview = Export** — toda decisão visual e temporal deve ser idêntica entre preview e export.
2. **Edição não destrutiva** — corte, velocidade, crop, áudio, texto, filtros, correção de cor e frame são instruções. O export gera um novo arquivo.
3. **SDK desacoplado do app host** — o SDK não depende de regras específicas de produto do app hospedeiro. Integrações externas entram por interfaces claras.
4. **Layout centralizado** — `LayoutEngine` é a fonte única de verdade para frame final, aspect ratio, fit/fill, crop e render size.
5. **Tempo centralizado** — `PlayerEngine` é a fonte de verdade para tempo corrente, scrub, range selecionado, duração efetiva e sincronização entre preview e export.
6. **Estado de edição explícito** — todo ajuste aplicado ao vídeo deve existir como modelo de domínio ou estado observável, nunca como regra implícita espalhada na UI.
7. **Export por snapshot** — o export sempre congela um snapshot imutável do projeto no início da operação.
8. **UI fina, lógica nas engines** — cálculos, validações e regras de edição pertencem às engines e modelos testáveis.

---

## Regras de código

### Swift & Observation
- Usar `@Observable` para todo estado mutável observado pela UI.
- Preferir classes `final` para objetos observáveis.
- **Nunca** usar `ObservableObject` ou `@Published` como padrão, exceto quando houver justificativa técnica clara.
- Structs para modelos de valor que não precisam de observação direta.
- Separação explícita entre modelos de domínio, estado observável e engines puras.
- Toda view SwiftUI criada ou alterada deve incluir um `#Preview` funcional quando o ambiente suportar previews de forma estável.

### Concorrência (Swift 6)
- UI e estado de edição observado devem ficar no `@MainActor`.
- Operações pesadas de render, composição e export podem executar fora da main thread.
- Callbacks que atualizam UI devem retornar explicitamente ao `@MainActor`.
- Apenas um export por instância do editor pode estar ativo ao mesmo tempo.
- Tasks de preview, geração de thumbnails, filtros e export devem ser canceláveis sempre que possível.

### Engines
- Engines puras devem preferir métodos `static` quando não mantêm estado.
- Toda engine deve ser testável isoladamente.
- Engines não podem depender diretamente de views SwiftUI.

---

## Estrutura do projeto

```text
VideoEditorKit/
  Core/
    PlayerEngine              — tempo, scrub, reprodução e sincronização
    TimeRangeEngine           — corte e validação de ranges
    LayoutEngine              — crop, fit/fill, aspect ratio, frame final
    SpeedEngine               — regras de velocidade e duração efetiva
    AudioEngine               — volume, mix, mute e ajustes de áudio
    TextEngine                — overlays de texto, posicionamento e timing
    FilterEngine              — aplicação de filtros visuais
    ColorCorrectionEngine     — brilho, contraste, saturação e ajustes afins
    SnapshotCoder             — snapshot codável do projeto
    ProjectValidator          — validação do estado editável
    ExportEngine              — composição e export final

  Models/
    VideoProject
    EditorState
    TimeRange
    CropConfiguration
    FrameConfiguration
    AudioConfiguration
    TextOverlay
    FilterConfiguration
    ColorCorrection
    ExportConfiguration
    VideoEditorError

  Persistence/
    Snapshot structs Codable sem tipos de UIKit/SwiftUI/AVFoundation não codáveis

  UI/
    VideoEditorView
    PlayerView
    TimelineView
    CropEditorView
    SpeedEditorView
    AudioEditorView
    TextEditorView
    FilterEditorView
    ColorCorrectionView
    ExportView
```

---

## Regras por feature

### Corte
- O usuário define um intervalo válido dentro da duração do vídeo de origem.
- Intervalos inválidos devem ser corrigidos ou rejeitados pela engine, nunca pela view de forma isolada.
- O preview e o export devem respeitar exatamente o mesmo `selectedTimeRange`.

### Velocidade
- A velocidade altera a duração efetiva reproduzida e exportada.
- Mudanças de velocidade devem refletir imediatamente no preview.
- Regras de velocidade devem ser determinísticas e independentes da UI.

### Crop e frame
- Crop, aspect ratio, fit/fill e render size devem ser resolvidos exclusivamente pela `LayoutEngine`.
- O frame final exportado deve corresponder exatamente ao frame exibido no preview.
- Coordenadas espaciais devem usar um sistema consistente e previsível.

### Áudio
- Ajustes de áudio nunca modificam o arquivo original.
- Volume, mute e mix devem fazer parte explícita do estado do projeto.
- O comportamento de áudio no preview deve refletir o export final sempre que tecnicamente possível.

### Texto
- Texto é overlay de edição, não parte destrutiva do vídeo de origem.
- Posição, estilo e tempo de exibição devem ser modelados explicitamente.
- Overlays vazios ou inválidos devem ser removidos ou bloqueados por validação.

### Filtros e correção de cor
- Filtros e ajustes de cor são transformações configuráveis do projeto.
- O preview deve aplicar a mesma ordem lógica usada no export.
- A engine deve evitar estados ambíguos ou duplicados de processamento.

### Export
- O export congela um snapshot completo do projeto no início.
- Mudanças feitas durante o export só afetam exports futuros.
- Export concorrente na mesma instância deve falhar de forma previsível.
- Falhas de validação devem ocorrer antes do pipeline pesado de renderização.

---

## Regras de persistência

- Snapshots não devem depender de `UIColor`, `UIFont`, `CGPoint`, `URL` bruto de sandbox temporário ou tipos não codáveis.
- Conversão entre snapshot e runtime deve sempre passar por validação.
- Snapshot inválido deve falhar com erro de domínio explícito, nunca com comportamento silencioso.

---

## Regras de testes

- **Apenas testes unitários.** Não criar UI tests nem snapshot tests visuais.
- **TDD obrigatório** — escrever o teste primeiro, validar falha, implementar o mínimo e refatorar.
- Testes ficam em `VideoEditorKitTests/`.
- Engines críticas para cobertura:
  - `TimeRangeEngine`
  - `LayoutEngine`
  - `SpeedEngine`
  - `AudioEngine`
  - `TextEngine`
  - `FilterEngine`
  - `ColorCorrectionEngine`
  - `ExportEngine`
  - `ProjectValidator`

---

## UX / Design

- A referência visual deve seguir o editor de vídeo nativo da Apple.
- Dark mode é o padrão.
- SF Symbols são a base para iconografia.
- A UI do SDK deve ser leve e consistente, mas o núcleo do produto é a engine de edição.
- Regras de app específico, presets comerciais ou branding do host não devem contaminar o domínio central do SDK.

---

## Fora do escopo (MVP)

- Transcrição e tradução embutidas
- Integrações de IA acopladas ao SDK
- Edição multilayer avançada estilo CapCut
- Undo/redo completo
- Templates avançados
- Export concorrente por instância
- Motion graphics complexos

---

## Skills obrigatórias

Toda implementação deve usar as skills `swiftui-pro` e `swiftui-expert-skill` como referência para SwiftUI, safe areas, acessibilidade, Dark Mode e padrões Apple HIG. Qualquer desvio relevante deve ser documentado.

---

## Roadmap sugerido

1. Modelos base + `EditorState` + `TimeRangeEngine`
2. `LayoutEngine` para crop, fit/fill, aspect ratio e frame final
3. `SpeedEngine`
4. `AudioEngine`
5. `TextEngine`
6. `FilterEngine` + `ColorCorrectionEngine`
7. `PlayerEngine`
8. Snapshots + `SnapshotCoder`
9. `ProjectValidator`
10. `ExportEngine`
11. Views SwiftUI finas para edição e preview
