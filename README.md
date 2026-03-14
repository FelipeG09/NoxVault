# NoxVault

Aplicativo de cofre seguro desenvolvido em Flutter para **Android e iOS**, que protege dados sensíveis (como notas privadas) usando **PIN** e, quando disponível, **biometria** (Face ID / Touch ID / impressão digital). As informações são armazenadas de forma segura utilizando `flutter_secure_storage`.

## Objetivo

Oferecer um cofre simples e funcional, com interface limpa e foco em privacidade, permitindo que o usuário:

- Defina um **PIN** de no mínimo 4 dígitos para acesso ao cofre.
- Use **autenticação biométrica** como atalho seguro para desbloquear o app.
- **Adicione e visualize notas** protegidas dentro do cofre.

## Tecnologias utilizadas

- **Flutter 3.x** com null safety.
- **Dart 3** como linguagem principal.
- **Provider** para gerenciamento de estado.
- **local_auth** para autenticação biométrica (Face ID / Touch ID / impressão digital).
- **flutter_secure_storage** para armazenamento seguro de PIN e notas.
- **Plataformas alvo**: Android e iOS.

## O que já foi implementado

- **Tela de login (`login_screen.dart`)**
  - Entrada de PIN com validação mínima de 4 dígitos (apenas números).
  - Primeiro acesso: criação e gravação segura do PIN.
  - Login com PIN já cadastrado.
  - Botão para autenticação biométrica via `local_auth` (quando disponível).
  - Mensagens de erro amigáveis em caso de PIN incorreto ou falha de biometria.

- **Tela principal (`home_screen.dart`)**
  - Exibição de lista de **notas do cofre** após autenticação.
  - Ação para **adicionar novas notas** (título e conteúdo) via bottom sheet.
  - Notas persistidas de forma segura usando `flutter_secure_storage`.
  - Animações sutis de entrada ao desbloquear o cofre.

- **Arquitetura e serviços**
  - Gerenciamento de estado com **Provider** (`AuthProvider` e `VaultProvider`).
  - Modelo de dados `Note` para representar cada nota.
  - Serviço `SecureStorageService` encapsulando o acesso ao armazenamento seguro.

## Como rodar

1. Instale as dependências:
   ```bash
   flutter pub get
   ```
2. Execute em um dispositivo ou emulador:
   ```bash
   flutter run
   ```

No primeiro uso será solicitado que você crie um PIN; depois disso, poderá entrar com o PIN ou usar biometria (se o dispositivo suportar).