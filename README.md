# MacroFit

App iOS pessoal para **recomposição corporal**: calcula sua meta diária de calorias e de proteína,
carboidrato e gordura, e deixa você registrar as refeições do dia para ver quanto ainda falta.

- SwiftUI + SwiftData, iOS 17+, só iPhone
- Tudo fica salvo no aparelho: sem login, sem servidor, sem bibliotecas externas

> As metas são estimativas por fórmulas populacionais e **não substituem um nutricionista**.

## Telas

| Aba | O que tem |
|---|---|
| **Hoje** | Anel de calorias (consumido / meta / quanto falta), botão grande **+ Adicionar refeição**, barras de proteína, carbo e gordura e resumo por tipo de refeição (toque em "Jantar" para adicionar um jantar) |
| **Refeições** | Refeições do dia agrupadas por tipo. Deslize para a esquerda para **editar** ou **apagar**; toque para editar |
| **Perfil** | TMB, gasto total, meta, déficit/superávit e macros; seus dados com botão **Editar** |

Use as setas ‹ › no topo de Hoje ou Refeições para trocar de dia, ou toque na data para abrir o calendário.
O dia escolhido vale para as duas abas. Ao adicionar uma refeição, toque em **Repetir refeição anterior**
para reaproveitar algo que você já registrou.

## Pré-requisitos

1. **Xcode 16 ou mais novo** (testado no Xcode 26.6), instalado pela App Store.
2. **Plataforma iOS do Xcode**, que inclui o simulador. Se o Xcode reclamar que "iOS xx is not installed":
   ```sh
   xcodebuild -downloadPlatform iOS
   ```
   Ou pelo Xcode: **Settings › Components**.
3. **XcodeGen**, que gera o `MacroFit.xcodeproj` a partir do `project.yml`:
   ```sh
   brew install xcodegen            # se você usa Homebrew
   ```
   Sem Homebrew, baixe o `xcodegen.zip` em <https://github.com/yonaskolb/XcodeGen/releases>,
   descompacte e rode `./install.sh ~/.local`. O binário vai para `~/.local/bin`, que precisa estar no seu `PATH`.

## Abrir no Xcode

```sh
cd ~/MacroFit
xcodegen generate        # cria o MacroFit.xcodeproj (ele não fica no git)
open MacroFit.xcodeproj
```

Rode `xcodegen generate` de novo sempre que **adicionar ou remover arquivos** ou mudar o `project.yml`.

### No simulador

No topo do Xcode, escolha um simulador de iPhone (ex.: *iPhone 17*) e aperte **⌘R**.

### Testes

São 49 testes: 39 unitários (calculadora, validação e lógica das refeições) e 10 de interface, que tocam na tela
do simulador (onboarding, adicionar, repetir, editar e apagar refeição, trocar de dia, tela Hoje).

**⌘U** no Xcode, ou pelo terminal:

```sh
xcrun simctl bootstatus "iPhone 17" -b      # liga o simulador e espera ficar pronto
xcodebuild test -project MacroFit.xcodeproj -scheme MacroFit \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Para rodar só os unitários (menos de 1 segundo), acrescente `-only-testing:MacroFitTests`.
Troque o nome do simulador por um dos que aparecem em `xcrun simctl list devices available`.

> Se o primeiro `xcodebuild test` falhar com *"Application failed preflight checks"*, foi porque o simulador
> ainda estava ligando. É só rodar de novo (ou rodar o `bootstatus` acima antes).

## Rodar no seu iPhone com Apple ID gratuito

Não precisa pagar o Apple Developer Program (US$ 99/ano). Com uma conta gratuita o app funciona
normalmente, só que a assinatura **vale por 7 dias**. Depois disso o app para de abrir e basta
rodar de novo pelo Xcode; os dados salvos continuam no iPhone.

### 1. Adicione seu Apple ID ao Xcode (só uma vez)
**Xcode › Settings… › Accounts › +** › *Apple ID* e faça login.
Vai aparecer um time chamado **"Seu Nome (Personal Team)"**.

### 2. Configure o Signing
1. No Xcode, clique no projeto **MacroFit** (ícone azul no topo da barra lateral).
2. Selecione o target **MacroFit**, aba **Signing & Capabilities**.
3. Deixe **Automatically manage signing** marcado.
4. Em **Team**, escolha o seu *Personal Team*.
5. Se aparecer um erro de que o **Bundle Identifier** já está em uso, troque
   `com.joaovitor.macrofit` por algo único, como `com.seunome.macrofit`.

> **Atenção:** o `xcodegen generate` recria o projeto e apaga o Team que você escolheu na interface.
> Para não precisar escolher de novo, copie o seu Team ID (Xcode › Settings › Accounts › seu time;
> ou em *Signing & Capabilities* depois de escolher) e coloque em `project.yml`:
> ```yaml
> DEVELOPMENT_TEAM: "ABCDE12345"
> ```
> Se trocou o bundle id, troque também o `PRODUCT_BUNDLE_IDENTIFIER` no `project.yml`.

### 3. Prepare o iPhone (só uma vez)
1. Conecte o iPhone no Mac por cabo e toque em **Confiar** no aviso do iPhone.
2. Ative o **Modo de Desenvolvedor**: **Ajustes › Privacidade e Segurança › Modo de Desenvolvedor**,
   ligue e reinicie o iPhone. A opção só aparece depois que o iPhone foi conectado ao Xcode uma vez.

### 4. Rode
1. No topo do Xcode, escolha o seu iPhone como destino.
2. Aperte **⌘R**.
3. Na primeira vez, o iPhone vai bloquear o app como "desenvolvedor não confiável". Para liberar:
   **Ajustes › Geral › VPN e Gerenciamento de Dispositivos** › seu Apple ID › **Confiar**.
4. Abra o MacroFit no iPhone.

Depois da primeira vez, dá para rodar sem cabo: no Xcode, **Window › Devices and Simulators**,
selecione o iPhone e marque **Connect via network**. O iPhone e o Mac precisam estar na mesma rede Wi-Fi.

## Estrutura

```
MacroFit/
├── MacroFitApp.swift      # entrada do app e container do SwiftData
├── Models/                # UserProfile e Meal (@Model), enums, Macros
├── Services/              # NutritionCalculator (fórmulas), validação, formatação
├── ViewModels/            # estado dos formulários, dia selecionado, resumo do dia
└── Views/                 # Onboarding, Today, Meals, Profile, Components
MacroFitTests/             # XCTest: calculadora, validação, refeições
MacroFitUITests/           # XCUITest: fluxos na tela (usam dados de demonstração em memória)
```

As fórmulas estão documentadas no `CLAUDE.md` e em `Services/NutritionCalculator.swift`.
