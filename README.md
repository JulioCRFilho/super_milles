# Super Milles - Flutter Game

Um jogo estilo Super Mario desenvolvido em Flutter, compilando para mobile, web e desktop.

## Arquitetura

O projeto utiliza **Clean Architecture** combinada com **Screaming Architecture**:

- **Domain Layer**: Entidades, interfaces de repositórios e casos de uso
- **Data Layer**: Implementações de repositórios, fontes de dados e modelos
- **Presentation Layer**: UI, providers (Riverpod) e componentes do jogo (Flame)

## Tecnologias

- **Flutter**: Framework principal
- **Flame**: Engine de jogos 2D
- **Riverpod**: Gerenciamento de estado
- **Flutter Hooks**: Hooks para componentes funcionais
- **Firebase**: Analytics, Crashlytics, Remote Config
- **Google Generative AI**: Geração de loot via Gemini

## Estrutura do Projeto

```
lib/
├── core/
│   ├── constants/      # Constantes do jogo
│   └── models/        # Modelos compartilhados
├── domain/
│   ├── entities/       # Entidades de domínio
│   ├── repositories/  # Interfaces de repositórios
│   └── use_cases/      # Casos de uso
├── data/
│   ├── data_sources/   # Fontes de dados (API, local)
│   └── repositories/  # Implementações de repositórios
└── presentation/
    ├── game/          # Componentes do jogo (Flame)
    ├── hud/           # Interface do usuário
    ├── loot/           # Modais de loot
    ├── menu/           # Telas de menu
    └── providers/      # Providers Riverpod
```

## Configuração

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Configurar Firebase

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com/)
2. Adicione os arquivos de configuração:
   - `android/app/google-services.json` (Android)
   - `ios/Runner/GoogleService-Info.plist` (iOS)
3. Execute `flutterfire configure`

### 3. Configurar API Key do Gemini (Opcional)

Para usar geração de loot via IA, configure a variável de ambiente:

```bash
export GEMINI_API_KEY=sua_chave_aqui
```

Ou adicione no arquivo de build:

```dart
--dart-define=GEMINI_API_KEY=sua_chave_aqui
```

## Executar

### Mobile
```bash
flutter run
```

### Web
```bash
flutter run -d chrome
```

### Desktop
```bash
flutter run -d windows  # ou macos, linux
```

## Build

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### Desktop
```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## CI/CD

O projeto inclui pipelines CI/CD configurados:

- **GitHub Actions**: Testes, builds e deploy automático
- **Firebase Hosting**: Deploy automático para web
- **GCP Cloud Run**: Deploy para Cloud Run (opcional)

### Configurar Secrets no GitHub

1. `FIREBASE_SERVICE_ACCOUNT`: JSON da service account do Firebase
2. `FIREBASE_PROJECT_ID`: ID do projeto Firebase
3. `GCP_SA_KEY`: Service account key do GCP
4. `GCP_PROJECT_ID`: ID do projeto GCP

## Performance

- Componentes constantes usando `const` widgets
- Riverpod para gerenciamento de estado eficiente
- Flame para renderização otimizada de jogos 2D
- Lazy loading de assets quando necessário

## Licença

Este projeto é privado e não deve ser publicado publicamente.
