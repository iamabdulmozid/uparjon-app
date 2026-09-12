# QA Checklist

Authentication:

- Login succeeds for `user@test.com`.
- Login succeeds for `admin@test.com` only where admin access is expected.
- Suspended account path works with `fraud@test.com`.
- Refresh token renews session.
- Logout clears local tokens.
- Logout all invalidates other device sessions.

Core mobile:

- App config handles normal, maintenance, and force-update states.
- Bootstrap loads profile, wallet, settings, and notification summary.
- Home feed loads and paginates where applicable.
- Offline cached profile/wallet/feed render with stale indicators.

Wallet and payments:

- Wallet overview loads for normal and high-balance users.
- Transaction list filters and paginates.
- Payment method add/delete works.
- Withdrawal request succeeds for eligible high-balance user.
- Insufficient balance and KYC-required errors map to correct screens.

Campaigns, quizzes, surveys, targeting, analytics:

- Campaign feed, featured, trending, and details load.
- Campaign start and complete flow returns expected reward state.
- Quiz list, details, and submit work.
- Survey list, details, and submit work.
- Ineligible campaign error removes or disables action.
- Target audience reach estimation updates dynamically during campaign creation.
- Campaign targeting exclusions prevent targeted users (e.g. demographic filters) from seeing the campaign in mobile feeds.
- Advertiser analytics overview, campaigns, and trend charts load correct statistics.
- CSV export downloads valid formatted report matching active date picker range.

Notifications:

- Notification list and dashboard load.
- Read single, read all, delete single, bulk delete work.
- FCM token registration and deregistration work.
- Deep links route to target screens.

Profile and KYC:

- Profile view/update works.
- Avatar upload works with supported image formats.
- KYC status loads.
- KYC multipart submit works.
- Security device list and device revoke work.

Regression:

- Run Postman smoke collection against staging.
- Run full Postman regression before release candidate.
- Verify no Flutter code branches on human error messages.
