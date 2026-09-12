# Push Notification Guide

Backend supports Firebase Cloud Messaging token registration and notification payload deep links.

Firebase setup:

1. Create Firebase apps for Android and iOS.
2. Add `google-services.json` and `GoogleService-Info.plist` to the Flutter project.
3. Enable FCM permissions and APNs configuration for iOS.
4. Initialize Firebase before app startup routing.

Token registration:

| Action | API |
| --- | --- |
| Register token | `POST /api/v1/mobile/notifications/register-token` |
| Remove token on logout | `DELETE /api/v1/mobile/notifications/token` |
| Update notification preferences | `PUT /api/v1/mobile/notification-preferences` |

Registration payload includes the FCM token, platform, device ID, app version, and device model when available.

Foreground handling:

- Show in-app banner or update notification badge.
- If payload includes `deepLink`, route only after explicit user tap.
- Refresh `GET /api/v1/mobile/notifications/unread-count`.

Background handling:

- Let FCM display the notification.
- On tap, parse `deepLink`.
- Mark the notification read with `PATCH /api/v1/mobile/notifications/{id}/read` when an ID is present.

Logout handling:

1. Call `DELETE /api/v1/mobile/notifications/token`.
2. Call `POST /api/v1/auth/logout`.
3. Clear local tokens and cached private data.
