# API Changelog

## v1.1.0 (Current Development)

Added:
- **Audience Targeting Builder API** (`/api/v1/campaigns/targeting/*` and `/api/v1/campaigns/{campaignId}/targeting-rules`): Allows advertisers to configure targeting criteria based on Gender, Age Range, Location, User Activity, Wallet Activity, and Campaign Participation.
- **Audience Estimation API** (`POST /api/v1/campaigns/targeting/estimate`): Estimates the reachable audience size for a set of targeting criteria prior to campaign launch.
- **Advertiser Analytics Dashboard APIs** (`/api/v1/analytics/advertiser/*`):
  - Overview metrics (Total campaigns, active campaigns, total views/completions, reward spend, remaining budget, conversion rate).
  - Campaign performance table/list (`GET /api/v1/analytics/advertiser/campaigns`).
  - View, completion, and spend trends charts data (`GET /api/v1/analytics/advertiser/trends`).
  - Demographic breakdowns (`GET /api/v1/analytics/advertiser/campaigns/{id}/audience`).
  - Quiz/Survey metrics, including pass rate and average scores (`GET /api/v1/analytics/advertiser/campaigns/{id}/quiz-survey`).
- **Campaign Creative Management** (`POST /api/v1/campaigns/{campaignId}/creatives`): Support for uploading campaign image/video assets.
- **Quiz Config and Survey Question Configs**: Added configurations for quiz/survey-based ads.

Changed:
- **Withdrawal Constraints Validation**: Updated client-facing withdrawal error codes and constraints verification (insufficient balance, minimum/maximum withdrawal amounts).

## v1.0.0

Added:
- Phase 10 Flutter handover package covering Swagger/OpenAPI URLs, Postman assets, staging details, fixed test accounts, error codes, screen-to-API mapping, Flutter architecture, push notifications, deep links, offline behavior, uploads, app config, payment flow, campaign flow, QA, release readiness, monitoring, and support playbooks.
- Authentication, refresh, logout, and device session APIs.
- Mobile feed, campaign, ads, survey, quiz, wallet, reward, withdrawal, notification, profile, KYC, settings, and optimization APIs.
- Admin APIs for campaigns, ads, withdrawals, rewards, notifications, users, analytics, fraud, payments, and platform configuration.
- JWT bearer authentication in Swagger UI.
- OpenAPI groups for Auth, Mobile, Admin, Profile, Notifications, and Mobile Optimization APIs.
- Durable idempotency key support for retry-safe state-changing requests.
- Mobile bootstrap, app config, sync, static config, analytics batch, and connection quality APIs.

Changed:
- Notification DTOs now include mobile fields such as deep links, image URLs, unread state, and dashboard aggregation.
- Profile APIs expose lightweight DTOs instead of the `User` entity.
- Cached mobile APIs use short TTLs suitable for low-bandwidth clients.

Deprecated:
- Legacy `/api/v1/notifications/device-token` remains supported. Prefer `/api/v1/mobile/notifications/register-token` for Flutter apps.

Removal policy:
- Deprecated v1 APIs should remain available for at least one published mobile release cycle.
- Breaking changes must be introduced under `/api/v2/`.
