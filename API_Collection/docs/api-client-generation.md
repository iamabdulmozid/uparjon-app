# Dart API Client Generation

Generate the Flutter client from OpenAPI into:

```text
lib/core/api/generated/
```

Recommended generator:

```bash
openapi-generator-cli generate \
  -i https://api.avytor.com/v3/api-docs/02%20Mobile \
  -g dart-dio \
  -o lib/core/api/generated \
  --additional-properties=pubName=uparjonx_api,serializationLibrary=json_serializable,nullableFields=true
```

For full coverage including auth and shared non-mobile endpoints:

```bash
openapi-generator-cli generate \
  -i https://api.avytor.com/v3/api-docs \
  -g dart-dio \
  -o lib/core/api/generated \
  --additional-properties=pubName=uparjonx_api,serializationLibrary=json_serializable,nullableFields=true
```

After generation:

```bash
flutter pub add dio json_annotation
flutter pub add --dev build_runner json_serializable
dart run build_runner build --delete-conflicting-outputs
```

Regeneration rules:

- Regenerate after backend OpenAPI changes.
- Commit generated files only if the Flutter team wants reproducible diffs.
- Keep custom interceptors, repositories, and mappers outside `generated/`.
- Run smoke login, app config, home feed, wallet, and notifications calls after every regeneration.
