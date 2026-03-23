# VideoEditorKit — CLAUDE.md

## O que é este projeto

Biblioteca modular iOS (SwiftUI + Swift 6) para edição de vídeo no estilo do editor nativo da Apple. Detalhes completos em `PLAN.md`.

---

## Princípios obrigatórios

1. **Preview = Export** — toda decisão visual e temporal (aspect ratio, crop, fit/fill, duração, posição de legenda, safe area) deve ser idêntica entre preview e export.
2. **Edição não destrutiva** — o vídeo original nunca é modificado. Preset, range, crop, estilo e legendas são instruções; o export gera um arquivo novo.
3. **IA desacoplada** — a biblioteca não transcreve, não traduz e não conhece provider de IA. Apenas expõe callbacks async para o app host fornecer legendas.
4. **Coordenadas normalizadas** — posições de legenda usam `0...1` no frame final renderizado.
5. **Layout centralizado** — `LayoutEngine` é fonte única de verdade para rotação, escala, crop, frame final e render size.
6. **Tempo centralizado** — `PlayerEngine` é fonte de verdade do tempo. Timeline, scrub, overlays e export dependem dele.
7. **Preset controla tudo** — cada `ExportPreset` define resolução, aspect ratio, safe area, duração min/max, comportamento de scrub e validação de export.
8. **UI fina, lógica nas engines** — views devem ser leves. Regras de negócio e cálculos ficam em engines e modelos testáveis.

---

## Regras de código

### Swift & Observation
- Usar `@Observable` para todo estado mutável observado pela UI.
- Preferir classes `final` para objetos observáveis.
- **Nunca** usar `ObservableObject` ou `@Published` como padrão — apenas em caso excepcional documentado.
- Structs para modelos de valor que não precisam de observação direta.
- Separação clara: modelos de valor / estado observável / engines puras.

### Concorrência (Swift 6)
- UI e estado de edição no `@MainActor`.
- Callbacks que impactam UI devem retornar ao `@MainActor`.
- Export pode executar fora da main thread.
- Apenas um export por vez por instância.

### Engines
- Engines puras devem ter métodos `static` quando não mantêm estado.
- Toda engine deve ser testável isoladamente.

---

## Estrutura do projeto

```
VideoEditorKit/
  Core/       — PlayerEngine, TimeRangeEngine, LayoutEngine, CaptionEngine,
                CaptionMergeEngine, CaptionPositionResolver, CaptionSafeFrameResolver,
                SnapshotCoder, ProjectValidator, ExportEngine
  Models/     — VideoProject, EditorState, Caption, CaptionStyle, ExportPreset,
                ExportConfiguration, VideoEditorError, etc.
  Persistence/ — Snapshot structs (Codable, sem UIKit types)
  UI/         — VideoEditorView, PresetToolbarView, TimelineView,
                CaptionOverlayView, CaptionActionButtonView
```

---

## Regras de testes

- **Apenas testes unitários.** Nenhum teste de interface (UI tests, snapshot tests visuais).
- **TDD obrigatório** — cada fase começa escrevendo os testes, validando falha, implementando o mínimo, depois refatorando.
- Testes ficam em `VideoEditorKitTests/`.
- Engines são o núcleo de confiabilidade: `TimeRangeEngine`, `LayoutEngine`, `CaptionEngine`, `CaptionPositionResolver`, `ExportEngine`.

---

## Regras de legenda

- Legendas com texto vazio ou só espaços devem ser removidas.
- Legendas fora do `selectedTimeRange` devem ser removidas; parcialmente fora, truncadas.
- Se após truncamento `startTime >= endTime`, remover.
- Drag em legenda com preset converte automaticamente para `.freeform`.
- Centro da legenda deve permanecer dentro do safe frame.
- Posições preset (`top`, `middle`, `bottom`) são centralizadas horizontalmente na safe area.

---

## Regras de persistência

- Snapshots não dependem de `UIColor`, `UIFont`, `CGPoint` ou `URL`.
- Conversão snapshot <-> runtime sempre passa por validação.
- Snapshot inválido falha com `VideoEditorError.snapshotDecodingFailed`.

---

## Regras de export

- Export congela um snapshot do projeto no início (preset, gravity, selectedTimeRange, captions sanitizadas, config).
- Mudanças durante o export afetam apenas o próximo export.
- Export concorrente na mesma instância é bloqueado com `exportAlreadyInProgress`.
- Vídeo curto demais para o preset bloqueia export com `videoTooShortForPreset`.

---

## UX / Design

- Seguir o editor de vídeo nativo da Apple como referência visual.
- Dark mode como padrão.
- SF Symbols para ícones.
- Toolbar contém apenas os presets: Original, Instagram, YouTube, TikTok.
- Timeline horizontal inferior; trechos fora do range válido aparecem escurecidos.
- Trocar preset atualiza layout, safe area, duração, scrub, legendas e preview imediatamente.

---

## Fora do escopo (MVP)

Animações de legenda, filtros de vídeo, templates avançados, undo/redo completo, transcrição/tradução embutida, export concorrente, edição multilayer estilo CapCut.

---

## Skill obrigatória

Toda implementação deve usar a skill `ios-application-dev` do repositório `MiniMax-AI/skills` como referência para SwiftUI, UIKit, safe areas, acessibilidade, Dark Mode e padrões Apple HIG. Qualquer desvio relevante deve ser documentado.

---

## Roadmap (9 fases, TDD em cada)

1. Modelos + `TimeRangeEngine` + `ExportPreset`
2. `CaptionSafeFrameResolver` + `CaptionPositionResolver`
3. `CaptionEngine` + `CaptionMergeEngine`
4. `LayoutEngine`
5. `PlayerEngine`
6. Snapshots + `SnapshotCoder`
7. `ProjectValidator` + integração async de captions
8. `ExportEngine`
9. Views (UI fina, sem testes de interface)
