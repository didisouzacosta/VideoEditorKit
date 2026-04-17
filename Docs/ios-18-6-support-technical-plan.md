# Plano Tecnico de Suporte a iOS 18.6

## Objetivo

Adicionar suporte oficial a `iOS 18.6` no `VideoEditorKit` e no app de exemplo sem perder nenhuma feature existente.

Essa migracao deve preservar:

- importacao de video
- persistencia local
- trim
- velocidade
- presets e crop
- rotacao e espelho
- audio gravado e mix
- correcoes
- moldura
- exportacao
- transcricao com provider suportado

## Regras de negocio

1. Nenhuma feature pode deixar de funcionar para acomodar `iOS 18.6`.
2. Se alguma feature exigir uma versao superior do sistema para continuar existindo com qualidade de produto aceitavel, a orientacao oficial passa a ser subir novamente o deployment target para a versao compativel com essa feature.
3. O uso de glass nas views deve ficar encapsulado em uma API unica, `adaptativeGlass`, com fallback visual compativel para `iOS 18.6`.
4. A transcricao nativa via Apple Speech baseada em `SpeechAnalyzer` e `SpeechTranscriber` sai do roadmap. A feature de transcricao continua suportada via `OpenAI Whisper` e provider customizado.

## Estado atual relevante

- o package, o app e os testes do exemplo ja declaram `iOS 18.6`
- o vidro ja esta centralizado em `adaptativeGlass` e `AdaptativeGlassContainer`
- Apple Speech ja foi removido da API publica, implementacao e testes
- a validacao final ainda precisa confirmar paridade funcional em runtimes compativeis com `iOS 18.6` e `iOS 26`

## Escopo

### Em escopo

- reduzir o acoplamento direto a APIs exclusivas de `iOS 26`
- criar a camada de compatibilidade visual para glass
- baixar deployment targets para `iOS 18.6` quando o codigo estiver pronto
- remover a integracao Apple Speech da superficie publica e da implementacao
- validar o editor no simulador iOS em matriz de runtimes suportados

### Fora de escopo

- redesenhar a arquitetura do editor
- modularizar o app em engines puras
- alterar o comportamento de exportacao, crop ou persistencia alem do necessario para compatibilidade
- introduzir degradacao silenciosa de feature

## Fases

### Fase 1

Status atual: concluida.

Objetivo:

- preparar o codigo para a migracao sem ainda derrubar o deployment target de forma prematura

Escopo:

- criar este documento tecnico
- introduzir `adaptativeGlass` como ponto unico para glass e fallback visual
- introduzir um wrapper para `GlassEffectContainer`
- migrar os usos centrais do package e do app de exemplo para a nova abstracao
- registrar explicitamente que Apple Speech nao faz parte do rollout para `iOS 18.6`

Entregaveis esperados:

- helper visual unico para glass
- menos `#available(iOS 26, *)` espalhado pelas views
- caminho pronto para baixar o deployment target em fase posterior

### Fase 2

Status atual: concluida.

Objetivo:

- remover a dependencia funcional de Apple Speech e alinhar a API publica com a decisao de produto

Escopo:

- remover `appleSpeech` da configuracao publica
- remover implementacao e testes de Apple Speech
- manter transcricao por Whisper e provider customizado
- atualizar README, DocC e exemplos de integracao

Entregaveis esperados:

- superficie publica coerente com a estrategia de transcricao
- eliminacao de um dos principais riscos de disponibilidade para `iOS 18.6`

### Fase 3

Status atual: concluida.

Objetivo:

- baixar o deployment target para `iOS 18.6`

Escopo:

- atualizar `Package.swift`
- atualizar `Example/VideoEditor.xcodeproj`
- revisar scripts e documentacao de validacao
- corrigir qualquer chamada adicional a API indisponivel em `iOS 18.6`

Entregaveis esperados:

- package, app e testes compilando com `iOS 18.6`

### Fase 4

Objetivo:

- validar paridade funcional nos dois ambientes relevantes

Escopo:

- rodar testes do package com o scheme `VideoEditorKit-Package`
- rodar testes do app com o scheme `VideoEditor`
- executar smoke tests manuais para importacao, edicao, exportacao e transcricao
- validar tanto em runtime compativel com `iOS 18.6` quanto em runtime `iOS 26`

Entregaveis esperados:

- matriz de validacao fechada
- decisao final de manter `iOS 18.6` ou subir novamente o minimo se uma feature bloquear

## Riscos principais

1. `SpeechAnalyzer` e `SpeechTranscriber` impedem compatibilidade real se permanecerem como parte do produto.
2. Reduzir o deployment target antes de centralizar o glass pode espalhar erros de compilacao em SwiftUI.
3. A validacao visual do fallback pode mascarar diferencas de hierarquia ou hit testing se o container de glass nao for abstraido junto.
4. README, DocC e exemplos podem ficar incoerentes com a API publica durante a migracao se a documentacao nao andar junto.

## Criterios de aceite

- existe um modifier `adaptativeGlass` cobrindo os usos principais de surfaces com glass
- nao existe uso direto remanescente de `GlassEffectContainer` nas views migradas da fase 1
- a estrategia de transcricao deixa de depender de Apple Speech
- o repositorio consegue ser preparado para `iOS 18.6` sem regressao funcional conhecida
- a validacao oficial continua sendo feita por `xcodebuild test` em simulador iOS

## Progresso da Fase 1

Implementacao iniciada nesta entrega:

- criacao deste documento
- introducao da camada `adaptativeGlass`
- introducao do wrapper de container de glass
- migracao inicial dos helpers visuais para a nova abstracao

Implementacao concluida na fase seguinte:

- remocao da factory publica `appleSpeech`
- remocao dos componentes e testes baseados em Apple Speech
- alinhamento do README e da documentacao DocC para Whisper + provider customizado

Implementacao concluida nesta fase:

- reducao do deployment target para `iOS 18.6` no package, app e testes
- remocao do `NSSpeechRecognitionUsageDescription` do app de exemplo
- alinhamento das instrucoes do repositorio e do README com o novo minimo suportado
