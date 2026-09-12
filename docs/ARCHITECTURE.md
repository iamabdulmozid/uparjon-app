# Uparjon — Technical Architecture

Companion to [PRD.md](PRD.md). This is the source of truth for stack choices,
folder structure, and conventions. Update it when a decision changes.

## 1. Stack decisions

Guiding principle (from product owner): **prefer official / first-party
packages, keep the dependency list small, and wrap every third-party package
behind our own abstraction** so it can be replaced without touching features.

| Concern | Choice | Why / notes |
|---|---|---|
| Framework | Flutter (latest stable), Material 3 | |
| State management & DI | **flutter_riverpod** (no codegen) | Compile-safe, testable, doubles as dependency injection (no `get_it` needed). Features only see `Notifier`/`Provider` — idiomatic Flutter. |
| Navigation | **go_router** | Maintained by the Flutter team (official). Declarative, deep-link ready, guarded redirects for auth. |
| Networking | **dio**, wrapped in our `ApiClient` | Interceptors (auth, logging, error mapping), timeouts, multipart/progress — needed for ad/photo flows. Features never import dio; they call `ApiClient`/repositories, so dio is swappable. |
| Key-value storage | **shared_preferences** | Flutter-team maintained. Wrapped in `LocalStore`. |
| Secure storage | **flutter_secure_storage** | Tokens only (Keystore/Keychain). Wrapped in `SecureStore`. |
| SVG rendering | **flutter_svg** | Logo/icons are SVG exports. |
| Localization | Flutter's own `gen_l10n` (ARB files) | Official, no dependency. bn + en. |
| Lints | **flutter_lints** | Official. |
| UI components | **Custom internal UI kit** (`core/ui`) | shadcn-*inspired* (variant-driven API, design tokens), but shadcn itself is a React library and its Flutter ports are third-party and would fight the Figma design language. We own buttons/cards/inputs, themed from Figma tokens. |

Deliberately **not** used (for now): bloc (Riverpod covers it), get_it/injectable
(Riverpod covers DI), freezed/json_serializable & build_runner (hand-written
models with `fromJson` — revisit if models multiply), retrofit, hive/drift
(no offline DB need yet — add drift later if task caching is required).

## 2. Folder structure (feature-first)

```
lib/
├── main.dart                  # entry: bootstrap + runApp
├── app/                       # app-level wiring (composition root)
│   ├── app.dart               # root MaterialApp.router + global keys
│   ├── router/
│   │   ├── app_router.dart    # GoRouter config + auth redirects
│   │   └── routes.dart        # route names/paths as constants
│   └── theme/
│       ├── app_colors.dart    # Figma color tokens
│       ├── app_spacing.dart   # spacing/radius scale
│       └── app_theme.dart     # ThemeData (Material 3) built from tokens
├── core/                      # shared, feature-agnostic code
│   ├── config/                # AppEnv (dev/stage/prod via --dart-define)
│   ├── constants/             # asset paths, durations, misc constants
│   ├── error/                 # Failure types + exception→Failure mapping
│   ├── network/               # ApiClient (dio wrapper), interceptors
│   ├── storage/               # LocalStore, SecureStore wrappers
│   ├── utils/                 # extensions, formatters, validators
│   ├── services/              # SnackbarService, connectivity, etc.
│   └── ui/                    # ★ custom UI kit: AppButton, AppCard, ...
└── features/                  # one folder per product module
    ├── splash/
    │   └── presentation/      # screens + widgets + controllers
    ├── onboarding/            # welcome + 3-slide carousel
    ├── auth/
    │   ├── data/              # models, repository (API + fake impls)
    │   └── presentation/      # login, sign up, OTP + AuthController
    ├── home/                  # dashboard
    ├── earn/                  # ads + surveys (Phase 1 core) — placeholder
    ├── wallet/                # balance + withdrawals — placeholder
    ├── menu/                  # profile/settings — placeholder
    ├── freelance/             # Phase 2 (not created yet)
    └── ecommerce/             # Phase 3 (not created yet)
```

The four bottom-nav tabs (Home, Uparjon/earn, Wallet, Menu) are composed by
`app/shell/app_shell.dart` using an `IndexedStack`, so each tab keeps its
state across switches. Unbuilt tabs render `core/ui/placeholder_page.dart`.

Rules:
- A feature may import `core/` and `app/theme`, **never another feature's
  internals**. Cross-feature needs go through core or a shared provider.
- `data` → talks to `ApiClient`/storage, returns models or throws `AppException`.
- `presentation` → Riverpod `Notifier`s hold screen state; widgets stay dumb.
- Simple features (splash) may skip `data/domain` — don't create empty layers.

## 3. Error handling & feedback (global)

```
dio error ──► ErrorInterceptor ──► AppException(kind, message, statusCode)
                                        │  caught in repository/Notifier
                                        ▼
                                   Failure (sealed)
                                        │  AsyncValue.error in controller
                                        ▼
                       ui: ErrorView / SnackbarService.showError
```

- `Failure` is a sealed class: `NetworkFailure`, `ServerFailure`,
  `AuthFailure`, `ValidationFailure`, `UnknownFailure` — each with a
  user-facing (localizable) message.
- **SnackbarService** owns a global `scaffoldMessengerKey` (registered on
  `MaterialApp`), so any layer can show success/error/info snackbars without
  a `BuildContext`.
- HTTP 401 → attempt token refresh once → on failure, clear session and
  redirect to login (router listens to auth state).

## 4. Environments

- `AppEnv` reads `--dart-define=APP_ENV=dev|stage|prod` (+ `API_BASE_URL`).
- No secrets committed; per-env launch configs live in `.vscode/launch.json`.

## 5. Assets

- `assets/logo/`, `assets/icons/`, selected `assets/images/` files are bundled.
- `assets/svg/` holds **full-screen Figma mockup exports — design reference
  only, never bundled** (each is ~2 MB). pubspec lists only what the app uses.
- `pubspec.yaml` bundles `assets/icons/` **wholesale**, so build-time-only
  images must not live there — launcher icon sources sit in `tool/launcher_icon/`
  and are regenerated with `dart run flutter_launcher_icons`.
- Vector art can be lifted straight out of the Figma SVG exports (copy the
  `<g>` plus the defs it references) — `assets/icons/lock.svg` and
  `assets/images/money_bag.svg` were produced that way.
- Large raster art (e.g. `bg_2_1.png`) must be compressed before release.

## 6. Conventions

- Dart style + `flutter_lints`; `dart format` clean; no `print` (use `log`).
- Files: `snake_case.dart`; one public widget/class per file where sensible.
- Providers live beside their feature: `features/x/presentation/x_providers.dart`.
- Route names centralized in `app/router/routes.dart`; navigate by name.
- Every PR: `flutter analyze` and `flutter test` pass.

## 7. Testing (grows with the app)

- Unit tests: repositories (mock ApiClient), Notifiers.
- Widget tests: UI kit components + critical flows (auth, task completion).
- Golden tests for the UI kit once tokens stabilize.

## 8. Future-proofing notes

- Phase 2/3 arrive as `features/freelance`, `features/ecommerce` + new routes
  and home tabs — zero restructuring.
- If the app grows to multiple teams/packages, features can graduate to melos
  workspace packages; the layering above already matches that split.
- Bangla font (Hind Siliguri or Noto Sans Bengali) to be bundled under
  `assets/fonts/` and wired in `app_theme.dart` — pending Figma confirmation.
