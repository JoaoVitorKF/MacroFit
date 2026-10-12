# MacroFit — contexto para o Claude

App iOS pessoal (iPhone) de **recomposição corporal**: calcula a meta diária de calorias e macros a partir
do perfil e registra as refeições do dia. Uso pessoal, sem backend, sem login e sem dependências externas.

**Idioma:** responda, comente o código e escreva os textos da interface em **português do Brasil**.
Identificadores (tipos, funções, variáveis) ficam em inglês.

## Stack
- Swift 5 (language mode 5), SwiftUI, **SwiftData**, iOS 17+, só iPhone em retrato
- `@Observable` (Observation) nos ViewModels, sem `ObservableObject`
- Projeto gerado pelo **XcodeGen** a partir do `project.yml`. O `.xcodeproj` está no `.gitignore`
  - Instalado em `~/.local/bin/xcodegen` (binário oficial, sem Homebrew)
  - Rode `xcodegen generate` depois de adicionar ou remover arquivos `.swift`
- Testes:
  - `MacroFitTests` (XCTest, unitários): calculadora, validação e lógica de refeições. Rodam em menos de 1 s
  - `MacroFitUITests` (XCUITest): fluxos de onboarding, refeições e Hoje, sempre usando o modo demo. Levam cerca de 2 min
- Git: identidade local `JoãoV <314427355+JoaoVitorKF@users.noreply.github.com>`, a mesma do pin-upscaler

## Comandos
```sh
xcodegen generate
xcodebuild -project MacroFit.xcodeproj -scheme MacroFit -destination 'generic/platform=iOS Simulator' -derivedDataPath build build
xcodebuild test -project MacroFit.xcodeproj -scheme MacroFit -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build
# só os unitários (rápido):
xcodebuild test ... -only-testing:MacroFitTests
```
Antes do `xcodebuild test`, ligue o simulador e espere ele ficar pronto: `xcrun simctl bootstatus "iPhone 17" -b`.
Sem isso, a primeira execução costuma falhar com *"Application failed preflight checks (Busy)"*, sem rodar nenhum teste.

Checagem rápida de tipos sem gerar o projeto (expande as macros `@Model`/`#Predicate`):
```sh
xcrun --sdk iphonesimulator swiftc -typecheck -swift-version 5 -target arm64-apple-ios17.0-simulator $(find MacroFit -name '*.swift')
```

### Modo demo (só Debug)
`Services/DemoData.swift` usa um banco **em memória** e nunca toca nos dados reais. Serve para tirar prints e para
os testes de interface, porque não há como tocar no simulador pela linha de comando.
```sh
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/MacroFit.app
xcrun simctl launch booted com.joaovitor.macrofit -demo              # perfil 30a/80kg/180cm + refeições hoje e ontem
xcrun simctl launch booted com.joaovitor.macrofit -demo-onboarding   # banco vazio
xcrun simctl launch booted com.joaovitor.macrofit -demo-floor        # perfil que cai no piso de 1200 kcal
xcrun simctl launch booted com.joaovitor.macrofit -demo-over         # meta estourada (estados em laranja)
# extras: -demo-tab N (0 Hoje, 1 Refeições, 2 Perfil) · -demo-form (formulário de refeição)
#         -demo-weight (abre a evolução do peso) · -demo-select (gráfico com um dia já selecionado)
#         -skip-splash (pula a tela de carregamento; os testes de interface sempre usam)
xcrun simctl ui booted appearance dark && xcrun simctl io booted screenshot /caminho/print.png
```
Com `-demo`, a meta é 2.345 kcal, já foram consumidas 1.330 e faltam 1.015, com 115 de 160 g de proteína. Há
histórico de peso nos últimos 60 dias (82,5 → 80 kg) e refeições repetidas de 2 a 6 dias atrás (para os frequentes).
Os testes de interface contam com esses números: **não mude o demo de hoje e de ontem sem ajustar os testes.**

Prints de telas que só aparecem depois de um toque (aviso de Desfazer, comemoração, menu de porção) saem dos testes
de interface: `XCTAttachment(screenshot:)` com `lifetime = .keepAlways`, e depois
`xcrun xcresulttool export attachments --path <xcresult> --output-path <pasta>`. Use `build/tmp/` para arquivos
temporários; ela está no `.gitignore`.

## Fórmulas (fonte única: `Services/NutritionCalculator.swift`)
| Item | Regra |
|---|---|
| TMB (Mifflin-St Jeor) | Homem `10×kg + 6,25×cm − 5×idade + 5` · Mulher `… − 161` |
| TDEE | TMB × fator: sedentário 1,2 · leve 1,375 · moderado 1,55 · alto 1,725 · muito alto 1,9 |
| Meta kcal | Recomposição TDEE×0,85 · Emagrecer ×0,80 · Ganhar massa ×1,10 |
| Piso | Mínimo de 1500 kcal (homem) / 1200 kcal (mulher). Abaixo disso usa o mínimo e marca `minimumApplied` (a UI mostra aviso) |
| Déficit/superávit | `calorieDelta = meta final − TDEE` (com o piso aplicado, pode virar superávit) |
| Proteína | 2,0 g/kg (4 kcal/g) |
| Gordura | `max(0,9 g/kg, 20% das kcal ÷ 9)` (9 kcal/g) |
| Carboidrato | `max(0, (kcal − P×4 − G×9) ÷ 4)`. Se P+G passarem da meta, carbo = 0 e `macrosExceedCalories = true` (a UI mostra aviso) |

Qualquer mudança de regra: altere o `NutritionCalculator`, atualize esta tabela e os testes em
`MacroFitTests/NutritionCalculatorTests.swift`, que têm as contas à mão nos comentários.

## Arquitetura (MVVM simples)
- `Models/`: `UserProfile`, `Meal` e `WeightEntry` (`@Model`), `Enums.swift`, `Macros` (struct somável, `scaled(by:)`), `Portion`
  - **`MacroFitSchema.models`** lista todos os modelos. Use essa lista em todo `ModelContainer` (app, demo, previews e testes)
  - `WeightEntry`: um registro por dia. **O peso do perfil é sempre o do registro mais recente**, sincronizado pelo
    `WeightStore` (`Services/WeightLog.swift`), que devolve um `GoalChange` (metas antes e depois) para o aviso
  - Os enums são salvos como `String` (`sexRaw`, `typeRaw`…) e expostos por propriedades computadas tipadas
  - `Meal.day` guarda sempre o **início do dia** (00:00) e é o campo de filtro por dia. `createdAt` serve para ordenar
  - Há um único `UserProfile`; a `RootView` mostra o onboarding enquanto ele não existe
- `Services/`: `NutritionCalculator` (funções puras), `Validation.swift` (`NumericField` com as faixas, `NumberParser`
  que aceita vírgula ou ponto), `Formatting.swift` (`kcalText`, `gramsText`, `signedKcalText`), `WeightLog`/`WeightStore`
  (histórico de peso), **`DailyCoach`** (funções puras: `achievements(before:after:targets:)` decide a comemoração;
  `tip(...)` escolhe a dica, inclusive a sugestão do histórico com mais proteína por caloria que cabe no que falta)
- `ViewModels/`: `ProfileViewModel` e `MealFormViewModel` guardam os campos como **texto** e só convertem/validam na
  leitura. `DaySelection` é o dia selecionado, compartilhado via `.environment` entre Hoje e Refeições.
  `DayLogSummary` agrupa por tipo e soma (lógica pura). `MealHistory.frequent` (atalhos) e `uniqueRecent` (repetir).
  `MealQuickAdd` adiciona e desfaz a adição rápida
- `Views/`: `Onboarding/`, `Today/`, `Meals/`, `Profile/`, `Components/`
  - `DayMealsReader` encapsula o `@Query` filtrado por dia
  - `MealSheet` (`.new(day:type:)` / `.edit(meal)` / `.fromTemplate(meal, day:, portion:)`) controla a folha de refeição
  - `SplashView`/`LaunchContainerView`: tela de carregamento por cima da `RootView`, que já carrega por baixo
  - Comemoração (`Components/Celebration.swift`): o `CelebrationWatcher` observa o total de **hoje** na `MainTabView`
    e chama o `CelebrationCenter`, então funciona para qualquer forma de registrar. Ele ignora os primeiros 0,8 s
    (carregamento) e só comemora quando a meta é **cruzada**. O confete é desenhado com `Canvas` e some com Reduzir Movimento
  - `Weight/`: `WeightCard` (Perfil), `WeightHistoryView`, `WeightChart` (Swift Charts com `chartXSelection`), `WeightEntrySheet`
  - `Theme.swift`: cores e ícones de cada nutriente (`Nutrient`) e o modificador `.card()`

## Convenções
- Faixas válidas: idade 14–100 (inteiro), peso 30–300 kg, altura 120–230 cm; por refeição 0–5000 kcal e 0–500 g
  por macro; nome da refeição 1–60 caracteres. O botão Salvar fica desabilitado enquanto houver campo inválido
- Os erros só aparecem depois que o usuário digitou algo no campo
- Teclados: `.numberPad` (idade) e `.decimalPad` (o resto), sempre com `.keyboardDoneButton()` no formulário
- Cores do sistema e `Color(.secondarySystemGroupedBackground)` nos cards, para o modo escuro funcionar sem esforço
- Cores dos nutrientes: calorias = accent, proteína = rosa, carbo = teal, gordura = laranja
- **Destaque (AccentColor): roxo `rgb(112,64,196)` no modo claro e amarelo `rgb(255,204,0)` no escuro**, pedido do usuário.
  Texto ou ícone *sobre* o destaque (botões `.borderedProminent`) usa `Color.accentForeground`: branco no claro e
  **preto no escuro**, porque branco sobre amarelo fica ilegível. Contraste de 6,5:1 e 13,9:1. Botão desabilitado volta ao `.secondary`
- Passar da meta de calorias deixa o anel **vermelho**. Laranja se confundia com o amarelo do modo escuro
- O botão "+ Adicionar refeição" da tela Hoje fica **no fluxo**, logo abaixo do anel. Flutuante, ele cobria as barras de macros
- Passar da meta de proteína mostra "Meta atingida (+X g)" sem cor de alerta; nos outros macros e nas calorias, o aviso é laranja
- **Botões dentro de linha de `List`/`Form`:** se houver mais de um na mesma linha, cada um precisa de
  `.buttonStyle(.borderless/.plain)`. Com o estilo padrão, um toque dispara todos (o `DaySelector` teve esse bug, e
  `testDayNavigationDoesNotTriggerOtherButtons` o cobre)
- Testes de interface localizam elementos pelos `accessibilityIdentifier`: campos (`campo-age`, `campo-weight`,
  `campo-calories`, `campo-nome`…), atalhos (`atalho-<nome da refeição>`), `dica-adicionar`, `comemoracao` e
  `seletor-porcao`. Linhas de refeição são localizadas por `label BEGINSWITH "<nome>"`. **Não localize por rótulo que
  outro botão possa repetir:** o botão da dica ("Adicionar Iogurte…") já fez um teste segurar o botão errado
- Para substituir o valor de um campo num teste de interface, use `doubleTap()` (seleciona) e depois `typeText`.
  Tocar e apagar falha quando o cursor cai no começo do texto
- Avisos de resultado aparecem **perto de onde o usuário tocou**. Exemplo: "Metas atualizadas" fica na seção Peso,
  porque no topo da lista ficava fora da tela
- Toda lógica testável fica fora das Views. Cada função nova no calculador ou na validação ganha teste
- Git: um commit por etapa/feature, mensagens em português
