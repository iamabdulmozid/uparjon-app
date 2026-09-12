# Flutter Integration Guide

## Swagger And Client Generation

- Swagger UI: `https://api.avytor.com/swagger-ui.html`
- OpenAPI JSON: `https://api.avytor.com/v3/api-docs`
- Postman collection: `postman/RewardPlatform.postman_collection.json`
- Postman environments: `postman/Local.postman_environment.json`, `postman/Production.postman_environment.json`
- Recommended groups: `01 Auth`, `02 Mobile`, `10 Admin`
- Generate Dart clients from `/v3/api-docs/02%20Mobile` or the full `/v3/api-docs` spec.

## Authentication Flow

1. Call `POST /api/v1/auth/login` with email/mobile, password, device details, app version, and optional FCM token.
2. Store `accessToken` and `refreshToken` securely.
3. Send `Authorization: Bearer <accessToken>` on protected requests.
4. Call `POST /api/v1/auth/refresh` before access token expiry.
5. Call `POST /api/v1/auth/logout` for single-device logout or `/api/v1/auth/logout-all` for all devices.

Access tokens expire after 15 minutes. Refresh tokens expire after 30 days.

## Startup Flow

1. Call `GET /api/v1/mobile/app-config`.
2. If `maintenanceMode` is true, show the maintenance screen.
3. If `forceUpdate` is true, block the app and route to the store update flow.
4. Call `GET /api/v1/mobile/bootstrap` to fetch profile, wallet, settings, and notification count in one request.

## Offline And Retry

- Queue offline state-changing actions locally.
- Include `Idempotency-Key: <uuid>` on retryable `POST`, `PUT`, and `DELETE` requests.
- Use `GET /api/v1/mobile/sync?since=<timestamp>` after reconnecting to determine which screens need refresh.

## Push Notifications

- Register FCM token with `POST /api/v1/mobile/notifications/register-token`.
- Remove token on logout with `DELETE /api/v1/mobile/notifications/token`.
- Use `deepLink` from notification payloads to route inside Flutter.

## Error Handling

- Branch on `errorCode`, not the human message.
- Common codes include `INVALID_CREDENTIALS`, `BAD_CREDENTIALS`, `VALIDATION_ERROR`, `DUPLICATE_REQUEST`, `KYC_REQUIRED`, `CAMPAIGN_NOT_ELIGIBLE`, `ACCOUNT_SUSPENDED`, and `INSUFFICIENT_BALANCE`.

## Handover Docs

- Handover Docs: `docs/swagger-url.md`
- Test accounts: `docs/test-accounts.md`
- API integration sequence: `docs/flutter-api-integration-sequence.md`
- Error codes: `docs/error-codes.md`
- Screen mapping: `docs/screen-api-mapping.md`
- Flutter architecture: `docs/flutter-architecture.md`
- Client generation: `docs/api-client-generation.md`
- Push and deep links: `docs/push-notifications.md`, `docs/deep-links.md`
- Offline strategy: `docs/offline-strategy.md`
- Uploads, app config, payments, campaigns: `docs/file-upload.md`, `docs/app-config.md`, `docs/payment-flow.md`, `docs/campaign-flow.md`

## Pagination

- Page-based endpoints use `page`, `size`, and optional `sort`.
- New large-feed endpoints should prefer cursor pagination in future v1 additions or v2.

## Performance Targets

- Home feed: under 300 ms.
- Wallet overview: under 200 ms.
- Notifications: under 150 ms.
- Profile: under 150 ms.
