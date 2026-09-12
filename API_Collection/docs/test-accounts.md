# Fixed Test Accounts

All seeded staging accounts use password `Password@123`.

| Purpose | Email | Mobile | Role | Expected State |
| --- | --- | --- | --- | --- |
| Admin | `admin@test.com` | `01900000000` | `ROLE_ADMIN` | Active, KYC approved |
| Normal User | `user@test.com` | `01800000000` | `ROLE_USER` | Active, KYC incomplete, zero balance |
| KYC Approved User | `kyc@test.com` | `01800000001` | `ROLE_USER` | Active, KYC approved, starter balance |
| Fraud Test User | `fraud@test.com` | `01800000002` | `ROLE_USER` | Suspended, use for account restriction handling |
| High Balance User | `wallet@test.com` | `01800000003` | `ROLE_USER` | Active, KYC approved, high wallet balance |

Login body template:

```json
{
  "email": "user@test.com",
  "password": "Password@123",
  "deviceId": "flutter-dev-device-001",
  "deviceName": "Flutter Emulator",
  "platform": "ANDROID",
  "appVersion": "1.0.0",
  "pushToken": "optional-fcm-token"
}
```

Use `fraud@test.com` to verify suspended-account screens. It may fail login depending on current security policy, which is the intended test path for restricted account UX.
