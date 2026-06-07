# 🔐 NoxVault

**Cofre de senhas local para Android com autenticação biométrica e análise de segurança por IA.**

NoxVault armazena suas credenciais inteiramente no dispositivo, protegidas por criptografia AES-256-GCM e autenticadas via PIN (PBKDF2-SHA256) ou biometria nativa do Android (face/digital). Uma camada de inteligência artificial analisa a qualidade das suas senhas sem jamais transmiti-las em texto puro.

---

## ✨ Features

### 🔑 Autenticação
| Feature | Descrição |
|---|---|
| **Criação de PIN** | PIN de 4–6 dígitos criado no primeiro acesso; hash PBKDF2-SHA256 com salt aleatório de 32 bytes e 200 000 iterações |
| **Desbloqueio por Biometria** | Facial ou digital via API nativa Android; a chave AES é recuperada do Keystore após autenticação bem-sucedida |
| **Desbloqueio por PIN** | Fallback automático após 2 falhas biométricas |
| **Bloqueio progressivo** | 3 tentativas incorretas de PIN → bloqueio de 1 minuto |
| **Recuperação de PIN** | Redefinição via biometria (sessão válida por 3 minutos); notas antigas são limpas para garantir integridade |
| **Alteração de PIN** | Dentro do cofre, com re-cifragem automática de todas as notas com a nova chave |

### 🗃️ Cofre de Senhas
| Feature | Descrição |
|---|---|
| **Criar / Editar / Excluir entradas** | Cada entrada contém título, usuário, senha e anotações |
| **Criptografia AES-256-GCM** | Cada nota é cifrada individualmente com IV aleatório de 16 bytes |
| **Reveal de senha protegido** | Exibe senha apenas após reautenticação biométrica |
| **Copiar para área de transferência** | Copia automaticamente; limpa o clipboard após 30 segundos |
| **Indicador de força de senha** | Visual em tempo real (Muito Fraca → Muito Forte) |
| **Gerador de senhas** | Senha aleatória segura com comprimento e tipos de caractere configuráveis |
| **Busca** | Filtragem por título ou usuário em tempo real |
| **Logout seguro** | Apaga a chave AES da memória imediatamente |

### 🤖 Análise de Segurança com IA (GROQ)
| Feature | Descrição |
|---|---|
| **Score geral (0–100)** | Pontuação de segurança calculada pelo modelo LLaMA via GROQ API |
| **Nível de risco** | Crítico / Fraco / Médio / Bom / Excelente |
| **Detecção de reutilização** | Identifica senhas idênticas usadas em múltiplos sites |
| **Detecção de senhas fracas** | Comprimento < 8, sem variedade de caracteres, padrões comuns |
| **Detecção de senhas antigas** | Entradas não atualizadas há mais de 180 dias |
| **Alertas, sugestões e destaques** | Até 5 alertas, 5 sugestões e 3 pontos positivos |
| **Privacidade garantida** | Apenas metadados são enviados; nenhuma senha em texto puro trafega pela rede |
| **Chave API criptografada** | Chave GROQ armazenada no Keystore do Android via flutter_secure_storage |

---

## 🏗️ Arquitetura

```
lib/
├── main.dart
├── providers/
│   ├── auth_provider.dart       # Autenticação: PIN + biometria + lockout
│   └── vault_provider.dart      # CRUD de notas + re-cifragem
├── services/
│   ├── ai_security_service.dart # Integração GROQ API (LLaMA)
│   ├── crypto_service.dart      # AES-256-GCM + PBKDF2-SHA256
│   └── secure_storage_service.dart # Wrapper do Android Keystore
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── security_analysis_screen.dart
│   └── change_master_pin_screen.dart
├── models/
│   ├── note.dart
│   └── security_analysis.dart
├── widgets/
│   ├── note_form_sheet.dart
│   ├── password_hint_row.dart
│   └── forgot_pin_dialog.dart
└── utils/
    └── password_security.dart
```

---

## 🔒 Segurança

- **Chave AES nunca persistida em texto puro** — derivada do PIN via PBKDF2 e salva no Keystore do Android (base64, protegida pelo sistema)
- **Biometria não deriva a chave diretamente** — serve como portão para liberar a chave já armazenada com segurança
- **Zero dados em servidores externos** — o cofre vive inteiramente no dispositivo
- **Análise de IA usa apenas metadados** — tamanho, diversidade de caracteres, reutilização, idade; nenhuma senha é transmitida
- **Clipboard auto-limpo** em 30 segundos após cópia de senha

---

## 🛠️ Tecnologias

| Pacote | Uso |
|---|---|
| `flutter` + `provider` | Framework + gerenciamento de estado |
| `local_auth ^3.0.1` | Biometria nativa Android (face/digital) via FlutterFragmentActivity |
| `flutter_secure_storage ^10.0.0` | Keystore/Keychain do SO |
| `encrypt ^5.0.3` | AES-256-GCM |
| `pointycastle ^3.9.1` | PBKDF2-SHA256 |
| `crypto ^3.0.3` | SHA-256 |
| `http ^1.2.2` | Chamadas REST à API GROQ |
| `connectivity_plus ^7.1.1` | Verificação de conectividade |

---

## 🚀 Como executar

### Pré-requisitos
- Flutter SDK >= 3.4.0
- Android SDK (minSdk 21+)
- Dispositivo ou emulador Android com biometria cadastrada

### Passos

```bash
# 1. Clone o repositório
git clone https://github.com/seu-usuario/noxvault.git
cd noxvault

# 2. Instale as dependências
flutter pub get

# 3. Execute (dispositivo/emulador conectado)
flutter run
```

### Usando a Análise de IA
1. Acesse **Análise de Segurança** no menu
2. Na primeira vez, o app pedirá sua chave da GROQ API (https://console.groq.com)
3. Insira a chave (formato `gsk_...`) — ela será salva criptografada no dispositivo

---

## 📋 Permissões Android

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

## 📄 Licença

MIT License
