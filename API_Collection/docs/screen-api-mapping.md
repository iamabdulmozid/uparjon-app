# Screen To API Mapping

| Flutter Screen | Primary API | Supporting APIs |
| --- | --- | --- |
| Splash / Startup | `GET /api/v1/mobile/app-config` | `GET /api/v1/mobile/config/static`, `GET /api/v1/mobile/bootstrap` |
| Login | `POST /api/v1/auth/login` | `POST /api/v1/auth/refresh` |
| Register | `POST /api/v1/auth/register` | `GET /api/v1/mobile/app-config` |
| Forgot Password | `POST /api/v1/auth/forgot-password` | `POST /api/v1/auth/reset-password` |
| Home Feed | `GET /api/v1/mobile/home-feed` | `GET /api/v1/mobile/tasks/daily`, `GET /api/v1/mobile/progress` |
| Campaign Feed | `GET /api/v1/mobile/campaigns` | `GET /api/v1/mobile/campaigns/featured`, `GET /api/v1/mobile/campaigns/trending` |
| Campaign Details | `GET /api/v1/mobile/campaigns/{id}` | `POST /api/v1/mobile/campaigns/{id}/start` |
| Campaign Completion | `POST /api/v1/mobile/campaigns/{id}/complete` | `GET /api/v1/mobile/rewards/history`, `GET /api/v1/mobile/wallet/overview` |
| Ads Feed | `GET /api/v1/mobile/ads/feed` | `POST /api/v1/mobile/ads/{id}/view` |
| Quizzes | `GET /api/v1/mobile/quizzes` | `GET /api/v1/mobile/quizzes/{id}`, `POST /api/v1/mobile/quizzes/{id}/submit` |
| Surveys | `GET /api/v1/mobile/surveys` | `GET /api/v1/mobile/surveys/{id}`, `POST /api/v1/mobile/surveys/{id}/submit` |
| Wallet | `GET /api/v1/mobile/wallet/overview` | `GET /api/v1/mobile/wallet/earnings-summary`, `GET /api/v1/mobile/wallet/insights` |
| Transactions | `GET /api/v1/mobile/wallet/transactions` | `GET /api/v1/mobile/rewards/history` |
| Withdrawals | `GET /api/v1/mobile/withdrawals` | `POST /api/v1/mobile/withdrawals`, `GET /api/v1/mobile/payment-methods` |
| Payment Methods | `GET /api/v1/mobile/payment-methods` | `POST /api/v1/mobile/payment-methods`, `DELETE /api/v1/mobile/payment-methods/{id}` |
| Notifications | `GET /api/v1/mobile/notifications` | `GET /api/v1/mobile/notifications/unread-count`, `PATCH /api/v1/mobile/notifications/{id}/read` |
| Notification Settings | `GET /api/v1/mobile/notification-preferences` | `PUT /api/v1/mobile/notification-preferences` |
| Profile | `GET /api/v1/mobile/profile` | `PUT /api/v1/mobile/profile`, `POST /api/v1/mobile/profile/avatar` |
| Profile Dashboard | `GET /api/v1/mobile/profile/dashboard` | `GET /api/v1/mobile/profile/stats` |
| KYC | `GET /api/v1/mobile/kyc` | `POST /api/v1/mobile/kyc` |
| Security | `GET /api/v1/mobile/security` | `POST /api/v1/mobile/security/change-password` |
| Device Sessions | `GET /api/v1/mobile/security/devices` | `DELETE /api/v1/mobile/security/devices/{id}`, `POST /api/v1/auth/logout-all` |
| Referrals | `GET /api/v1/mobile/referrals` | `GET /api/v1/mobile/referrals/history`, `GET /api/v1/mobile/referrals/share-link` |
| App Settings | `GET /api/v1/mobile/settings` | `GET /api/v1/mobile/support` |
| Account Deletion | `POST /api/v1/mobile/account/delete-request` | None |
| Offline Sync | `GET /api/v1/mobile/sync?since=<timestamp>` | Re-fetch changed screen APIs |
