# Flutter Architecture Guide

Recommended structure:

```text
lib/
  core/
    api/
      generated/
      interceptors/
      api_client.dart
    auth/
      auth_repository.dart
      token_store.dart
      session_controller.dart
    config/
      app_config_repository.dart
    routing/
    storage/
      secure_storage.dart
      cache_store.dart
    errors/
      api_error.dart
      error_mapper.dart
  features/
    auth/
    home_feed/
    campaign/
    wallet/
    withdrawal/
    payment_method/
    notification/
    profile/
    kyc/
    referral/
    settings/
  shared/
    widgets/
    theme/
    utils/
```

Client recommendations:

- Keep generated OpenAPI DTOs in `lib/core/api/generated/`; do not edit generated files by hand.
- Wrap generated services with feature repositories so UI code does not depend directly on transport details.
- Store tokens in secure storage only.
- Cache read-only startup data, profile, wallet overview, notification counts, and static config in a local database.
- Use a single auth interceptor for `Authorization`, refresh coordination, correlation IDs, and idempotency keys.
- Map backend `errorCode` values to typed Dart failures in `core/errors`.

State management can be Riverpod, Bloc, or Provider. The backend contract does not require a specific Flutter state library.
