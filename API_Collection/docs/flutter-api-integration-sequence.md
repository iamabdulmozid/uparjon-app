# Flutter API Integration Sequence

This is the recommended order for Flutter integration. Build and test each block before moving to the next one.

## 1. App Startup And Configuration

Goal: decide whether the app can open, must update, or must show maintenance.

| Order | API | Purpose |
| --- | --- | --- |
| 1.1 | `GET /api/v1/mobile/app-config` | Check maintenance mode, force update, minimum app version, feature flags. |
| 1.2 | `GET /api/v1/mobile/config/static` | Load static app values such as supported options and constants. |
| 1.3 | `GET /api/v1/mobile/translations` | Load remote translation/config text if used by the app. |

Flow:

```text
Open App
  -> GET /mobile/app-config
  -> if maintenance: show maintenance screen
  -> if force update: show update screen
  -> else continue to auth check
```

## 2. Authentication

Goal: create and maintain a user session.

| Order | API | Purpose |
| --- | --- | --- |
| 2.1 | `POST /api/v1/auth/login` | Login and receive access token plus refresh token. |
| 2.2 | `POST /api/v1/auth/refresh` | Refresh expired access token. |
| 2.3 | `POST /api/v1/auth/logout` | Logout current device. |
| 2.4 | `POST /api/v1/auth/logout-all` | Logout all devices. |
| 2.5 | `GET /api/v1/auth/devices` | List active device sessions. |
| 2.6 | `DELETE /api/v1/auth/devices/{id}` | Revoke a device session. |

Flow:

```text
Login
  -> store accessToken and refreshToken
  -> use Authorization: Bearer <accessToken>
  -> on token expiry call refresh
  -> on logout clear tokens and cached private data
```

## 3. Bootstrap After Login

Goal: load the minimum data needed for the first authenticated screen.

| Order | API | Purpose |
| --- | --- | --- |
| 3.1 | `GET /api/v1/mobile/bootstrap` | Fetch startup bundle for profile, wallet, settings, and notification summary. |
| 3.2 | `GET /api/v1/mobile/sync?since=<timestamp>` | Reconcile cached data after reconnect or app resume. |

Flow:

```text
Auth success
  -> GET /mobile/bootstrap
  -> populate local cache/state
  -> navigate to Home
```

## 4. Home Feed

Goal: make the main user landing screen functional.

| Order | API | Purpose |
| --- | --- | --- |
| 4.1 | `GET /api/v1/mobile/home-feed` | Load campaign, quiz, survey, wallet, and task summary cards. |
| 4.2 | `GET /api/v1/mobile/tasks/daily` | Load daily tasks. |
| 4.3 | `GET /api/v1/mobile/progress` | Load user progress. |

Flow:

```text
Home Screen
  -> GET /mobile/home-feed
  -> GET /mobile/tasks/daily
  -> GET /mobile/progress
```

## 5. Profile And Settings

Goal: let the user view and manage account basics.

| Order | API | Purpose |
| --- | --- | --- |
| 5.1 | `GET /api/v1/mobile/profile` | Load profile. |
| 5.2 | `PUT /api/v1/mobile/profile` | Update profile. |
| 5.3 | `POST /api/v1/mobile/profile/avatar` | Upload avatar. |
| 5.4 | `GET /api/v1/mobile/profile/dashboard` | Load profile dashboard summary. |
| 5.5 | `GET /api/v1/mobile/profile/stats` | Load user stats. |
| 5.6 | `GET /api/v1/mobile/settings` | Load app/user settings. |
| 5.7 | `GET /api/v1/mobile/support` | Load support/help data. |

## 6. KYC

Goal: support locked features such as withdrawals.

| Order | API | Purpose |
| --- | --- | --- |
| 6.1 | `GET /api/v1/mobile/kyc` | Check KYC status. |
| 6.2 | `POST /api/v1/mobile/kyc` | Submit KYC multipart documents. |

Flow:

```text
Wallet / Withdrawal / Restricted Feature
  -> if API returns KYC_REQUIRED
  -> GET /mobile/kyc
  -> show status or submit screen
  -> POST /mobile/kyc
```

## 7. Notifications And Push

Goal: support notification list, unread count, preferences, and FCM token.

| Order | API | Purpose |
| --- | --- | --- |
| 7.1 | `POST /api/v1/mobile/notifications/register-token` | Register FCM token after login/permission grant. |
| 7.2 | `GET /api/v1/mobile/notifications/unread-count` | Show badge count. |
| 7.3 | `GET /api/v1/mobile/notifications` | List notifications. |
| 7.4 | `GET /api/v1/mobile/notifications/dashboard` | Notification dashboard summary. |
| 7.5 | `GET /api/v1/mobile/notifications/{id}` | Notification details. |
| 7.6 | `PATCH /api/v1/mobile/notifications/{id}/read` | Mark one notification read. |
| 7.7 | `PATCH /api/v1/mobile/notifications/read-all` | Mark all read. |
| 7.8 | `DELETE /api/v1/mobile/notifications/{id}` | Delete one notification. |
| 7.9 | `DELETE /api/v1/mobile/notifications` | Bulk delete notifications. |
| 7.10 | `GET /api/v1/mobile/notification-preferences` | Load preferences. |
| 7.11 | `PUT /api/v1/mobile/notification-preferences` | Update preferences. |
| 7.12 | `DELETE /api/v1/mobile/notifications/token` | Remove FCM token on logout. |

## 8. Campaigns

Goal: support campaign browsing and reward-producing actions.

| Order | API | Purpose |
| --- | --- | --- |
| 8.1 | `GET /api/v1/mobile/campaigns` | Campaign list. |
| 8.2 | `GET /api/v1/mobile/campaigns/featured` | Featured campaigns. |
| 8.3 | `GET /api/v1/mobile/campaigns/trending` | Trending campaigns. |
| 8.4 | `GET /api/v1/mobile/campaigns/{id}` | Campaign details. |
| 8.5 | `POST /api/v1/mobile/campaigns/{id}/start` | Start campaign session. |
| 8.6 | `POST /api/v1/mobile/campaigns/{id}/complete` | Complete campaign and enter reward/fraud validation flow. |

Flow:

```text
Campaign Feed
  -> campaign details
  -> start
  -> complete
  -> show pending reward
  -> refresh rewards and wallet
```

## 9. Ads, Quizzes, And Surveys

Goal: integrate all earning content types.

| Order | API | Purpose |
| --- | --- | --- |
| 9.1 | `GET /api/v1/mobile/ads/feed` | Load mobile ads. |
| 9.2 | `POST /api/v1/mobile/ads/{id}/view` | Submit ad view. |
| 9.3 | `GET /api/v1/mobile/quizzes` | Quiz list. |
| 9.4 | `GET /api/v1/mobile/quizzes/{id}` | Quiz details. |
| 9.5 | `POST /api/v1/mobile/quizzes/{id}/submit` | Submit quiz answers. |
| 9.6 | `GET /api/v1/mobile/surveys` | Survey list. |
| 9.7 | `GET /api/v1/mobile/surveys/{id}` | Survey details. |
| 9.8 | `POST /api/v1/mobile/surveys/{id}/submit` | Submit survey answers. |

## 10. Wallet And Rewards

Goal: show balances, earnings, transactions, and rewards.

| Order | API | Purpose |
| --- | --- | --- |
| 10.1 | `GET /api/v1/mobile/wallet/overview` | Wallet balances. |
| 10.2 | `GET /api/v1/mobile/wallet/transactions` | Wallet transaction history. |
| 10.3 | `GET /api/v1/mobile/wallet/earnings-summary` | Earnings summary. |
| 10.4 | `GET /api/v1/mobile/wallet/insights` | Wallet insights. |
| 10.5 | `GET /api/v1/mobile/rewards/history` | Reward history and pending/approved reward state. |

Flow:

```text
Wallet Screen
  -> overview
  -> transactions
  -> earnings summary
  -> rewards history
```

## 11. Withdrawals And Payment Methods

Goal: allow users to cash out.

| Order | API | Purpose |
| --- | --- | --- |
| 11.1 | `GET /api/v1/mobile/payment-methods` | List saved payout methods. |
| 11.2 | `POST /api/v1/mobile/payment-methods` | Add payout method. |
| 11.3 | `DELETE /api/v1/mobile/payment-methods/{id}` | Delete payout method. |
| 11.4 | `GET /api/v1/mobile/withdrawals` | Withdrawal history. |
| 11.5 | `POST /api/v1/mobile/withdrawals` | Request withdrawal. |
| 11.6 | `GET /api/v1/mobile/wallet/overview` | Refresh wallet after withdrawal request. |

Flow:

```text
Withdrawal Screen
  -> GET payment methods
  -> GET wallet overview
  -> POST withdrawal
  -> show Pending
  -> refresh withdrawal history and wallet
```

## 12. Referrals

Goal: integrate referral sharing and referral history.

| Order | API | Purpose |
| --- | --- | --- |
| 12.1 | `GET /api/v1/mobile/referrals` | Referral summary. |
| 12.2 | `GET /api/v1/mobile/referrals/history` | Referral history. |
| 12.3 | `GET /api/v1/mobile/referrals/share-link` | Shareable referral link. |

## 13. Security And Account Management

Goal: complete user account controls.

| Order | API | Purpose |
| --- | --- | --- |
| 13.1 | `GET /api/v1/mobile/security` | Security settings summary. |
| 13.2 | `POST /api/v1/mobile/security/change-password` | Change password. |
| 13.3 | `GET /api/v1/mobile/security/devices` | List devices. |
| 13.4 | `DELETE /api/v1/mobile/security/devices/{id}` | Revoke device. |
| 13.5 | `POST /api/v1/mobile/account/delete-request` | Request account deletion. |

## 14. Offline, Analytics, And Quality Signals

Goal: add production-grade app behavior after core flows work.

| Order | API | Purpose |
| --- | --- | --- |
| 14.1 | `GET /api/v1/mobile/sync?since=<timestamp>` | Sync after reconnect/app resume. |
| 14.2 | `POST /api/v1/mobile/analytics/session` | Send session analytics. |
| 14.3 | `POST /api/v1/mobile/analytics/batch` | Send batched events. |
| 14.4 | `POST /api/v1/mobile/connection-quality` | Report network/device quality. |

## 15. Final End-To-End Test Order

Use this exact order for QA smoke testing:

1. `GET /api/v1/mobile/app-config`
2. `POST /api/v1/auth/login`
3. `GET /api/v1/mobile/bootstrap`
4. `GET /api/v1/mobile/home-feed`
5. `GET /api/v1/mobile/profile`
6. `GET /api/v1/mobile/kyc`
7. `POST /api/v1/mobile/notifications/register-token`
8. `GET /api/v1/mobile/notifications`
9. `GET /api/v1/mobile/campaigns`
10. `GET /api/v1/mobile/campaigns/{id}`
11. `POST /api/v1/mobile/campaigns/{id}/start`
12. `POST /api/v1/mobile/campaigns/{id}/complete`
13. `GET /api/v1/mobile/rewards/history`
14. `GET /api/v1/mobile/wallet/overview`
15. `GET /api/v1/mobile/wallet/transactions`
16. `GET /api/v1/mobile/payment-methods`
17. `POST /api/v1/mobile/withdrawals`
18. `GET /api/v1/mobile/withdrawals`
19. `POST /api/v1/auth/logout`

Important implementation rules:

- Always branch on `errorCode`, never `message`.
- Use `Idempotency-Key` for retryable `POST`, `PUT`, `PATCH`, and `DELETE` calls.
- Do not allow campaign completion, quiz submit, survey submit, KYC upload, or withdrawal request while offline.
- Refresh wallet and reward history after campaign completion and withdrawal submission.
