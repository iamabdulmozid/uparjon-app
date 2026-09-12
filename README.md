# Uparjon (উপার্জন)

Earn money from home — micro-tasks, freelancing, and cashback for Bangladesh.

> উপার্জন হবে ঘরে ঘরে…

## Documentation

- [Product requirements (PRD)](docs/PRD.md)
- [Technical architecture & conventions](docs/ARCHITECTURE.md)

## Getting started

```sh
flutter pub get
flutter run --dart-define=APP_ENV=dev
```

VS Code launch configs for dev/stage/prod are in `.vscode/launch.json`.

## Project layout

```
lib/
├── app/        # composition root: app widget, router, theme
├── core/       # shared: config, network, storage, error, services, UI kit
└── features/   # one folder per product module (splash, auth, earn, ...)
assets/         # bundled assets — see pubspec.yaml; assets/svg/ holds
                # full-screen Figma exports (design reference only, not bundled)
docs/           # PRD + architecture docs
```

## Quality gates

```sh
flutter analyze
flutter test
```

Both must pass before merging.
