# Mobile Application API Specification

> **Platform Version**: 1.0.0  
> **Target Audience**: Mobile App Engineers (Flutter / React Native / Android Kotlin / iOS Swift), QA, Backend Engineers  
> **Default Currency**: BDT (`৳`)  
> **Backend Base URL (Local)**: `http://localhost:8080/api/v1`
> **Dev Proxy Base URL**: `http://localhost:4200/api/v1`
> **Stage Base URL**: `https://api.avytor.com/api/v1`
> **Last Updated**: 2026-09-30 — campaign details now return the ad video + questions (§8.2), recommended campaign flow (§8.5), standalone quizzes are admin-managed (§10.1), standalone surveys added (§10.4), error codes corrected (§1.3)

---

## Table of Contents
1. [Global Standards & Conventions](#1-global-standards--conventions)
2. [Authentication & Session Management](#2-authentication--session-management)
3. [Mobile Home Feed & App Initialization](#3-mobile-home-feed--app-initialization)
4. [User Profile, Security & KYC](#4-user-profile-security--kyc)
5. [Wallet & Transaction History](#5-wallet--transaction-history)
6. [Deposits & Payment Gateways](#6-deposits--payment-gateways)
7. [Withdrawals & Payout Requests](#7-withdrawals--payout-requests)
8. [Campaigns, Media Ads & Interactive Viewing](#8-campaigns--video-ads)
9. [Micro Tasks & Social Tasks](#9-micro-tasks--social-tasks)
10. [Quizzes, Surveys & Interactive Assessments](#10-quizzes-surveys--interactive-assessments)
11. [Push Notifications & Device Tokens](#11-push-notifications--device-tokens)
12. [Geographic Master Data & Mobile Operators](#12-geographic-master-data--mobile-operators)
13. [Media Storage & File Uploads](#13-media-storage--file-uploads)
14. [E-Commerce Storefront (Catalog, Cart, Checkout)](#14-e-commerce-storefront-catalog-cart-checkout)
15. [Quick Reference Endpoint Matrix](#15-quick-reference-endpoint-matrix)

---

## 1. Global Standards & Conventions

### 1.1 HTTP Headers
- **JSON Requests**: `Content-Type: application/json`
- **Authenticated Endpoints**: `Authorization: Bearer <access_token>`
- **Guest E-Commerce Operations**: `X-Guest-Session-Id: <uuid>` (used before user logs in)
- **Order Checkout Idempotency**: `Idempotency-Key: <uuid>` (prevents duplicate orders/charges)

### 1.2 Unified Response Envelope (`ApiResponse<T>`)
Every JSON response adheres to this envelope:
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": { ... },
  "timestamp": "2026-09-12T18:00:00"
}
```

> [!NOTE]
> **Endpoints without the envelope**: these return the payload directly (a JSON array or object, no `success`/`data` wrapper):
> `GET /mobile/surveys`, `GET /mobile/surveys/{id}`, `POST /mobile/surveys/{id}/heartbeat|discard|submit`,
> `GET /mobile/quizzes`, `GET /mobile/quizzes/{id}`, `POST /mobile/quizzes/{id}/submit`,
> `GET /mobile/ads/feed`, `POST /mobile/ads/{id}/view`, `POST /quizzes/submit`, `POST /surveys/submit`.

### 1.3 Error Envelope
```json
{
  "success": false,
  "errorCode": "ALREADY_CLAIMED",
  "message": "You have already completed and claimed the reward for this ad",
  "timestamp": "2026-09-12T18:00:00"
}
```

| HTTP | `errorCode` | When |
|---|---|---|
| `400` | e.g. `VALIDATION_ERROR` | Invalid body, unknown ID, missing answers, invalid option ID |
| `401` | — | Missing or expired access token (call `/auth/refresh`) |
| `403` | — | Authenticated but not allowed |
| `409` | `ALREADY_CLAIMED` | Reward for this ad was already claimed |
| `500` | `ILLEGAL_STATE` | Business rule not met, e.g. quiz submitted before the ad was watched, quiz already completed, max attempts reached. Show `message` to the user. |

> Branch on the HTTP status and `errorCode`, and display `message`; do not parse the message text.

### 1.4 Test Accounts & OTP Configuration
- **Fixed OTP (Dev/Testing)**: `123456`
- **Default Password**: `Password@123`
- **Pre-seeded Accounts**:
  - `user@test.com` — Normal user (KYC incomplete, zero balance)
  - `kyc@test.com` — Verified user (starter balance). On stage this account currently has `kycCompleted=false`, so KYC-gated flows (withdrawals) are blocked; earning flows work.
  - `wallet@test.com` — High wallet balance user (KYC approved)

---

## 2. Authentication & Session Management

### 2.1 Register User
- **Method**: `POST`
- **URL**: `/api/v1/auth/register`
- **Auth**: None (Public)
- **Request Body**:
```json
{
  "fullName": "Tanvir Ahmed",
  "countryCode": "BD",
  "mobile": "01712345678",
  "email": "tanvir@example.com",
  "password": "Password@123",
  "referralCode": "REF98765"
}
```
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "success": true,
    "accessToken": "eyJhbGciOiJIUzI1NiIsIn...",
    "refreshToken": "48b6d859-f9c1-4ce8-8888-912f2cb261aa",
    "expiresIn": 900000,
    "user": {
      "id": "e3012ff1-1647-4934-8be0-bceadfc4e981",
      "fullName": "Tanvir Ahmed",
      "email": "tanvir@example.com",
      "profileImage": null,
      "role": "USER",
      "roles": ["USER"],
      "permissions": [],
      "mustChangePassword": false
    }
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.2 Mobile Login
- **Method**: `POST`
- **URL**: `/api/v1/auth/login`
- **Auth**: None (Public)
- **Request Body**:
```json
{
  "email": "01712345678",
  "password": "Password@123",
  "deviceId": "android-device-987123",
  "deviceName": "Samsung Galaxy S23",
  "platform": "ANDROID",
  "appVersion": "1.0.0",
  "pushToken": "fcm-push-token-value"
}
```
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "success": true,
    "accessToken": "eyJhbGciOiJIUzI1NiIsIn...",
    "refreshToken": "7092adce-06bb-49e0-8197-e85dfba90cc2",
    "expiresIn": 900000,
    "user": {
      "id": "e3012ff1-1647-4934-8be0-bceadfc4e981",
      "fullName": "Tanvir Ahmed",
      "email": "tanvir@example.com",
      "profileImage": "https://storage.uparjon.com/avatars/user.jpg",
      "role": "USER",
      "roles": ["USER"],
      "permissions": [],
      "mustChangePassword": false
    }
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.3 Refresh Access Token
- **Method**: `POST`
- **URL**: `/api/v1/auth/refresh`
- **Auth**: None
- **Request Body**:
```json
{
  "refreshToken": "7092adce-06bb-49e0-8197-e85dfba90cc2"
}
```
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Token refreshed",
  "data": {
    "success": true,
    "accessToken": "eyJhbGciOiJIUzI1NiIsIn...",
    "refreshToken": "82da2685-17a4-4f05-873b-b2fbcaae0955",
    "expiresIn": 900000,
    "mustChangePassword": false,
    "authStatus": null
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.4 Verify OTP
- **Method**: `POST`
- **URL**: `/api/v1/auth/verify-otp`
- **Auth**: None
- **Request Body**:
```json
{
  "emailOrPhone": "01712345678",
  "otp": "123456"
}
```
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "OTP verified successfully",
  "data": null,
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.5 Forgot Password
- **Method**: `POST`
- **URL**: `/api/v1/auth/forgot-password`
- **Auth**: None
- **Request Body**:
```json
{
  "emailOrPhone": "user@test.com"
}
```
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Password reset request accepted",
  "data": null,
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.6 Reset Password
- **Method**: `POST`
- **URL**: `/api/v1/auth/reset-password`
- **Auth**: None
- **Request Body**:
```json
{
  "token": "123456",
  "newPassword": "NewPassword@123"
}
```
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Password reset successful",
  "data": null,
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.7 Logout Current Device
- **Method**: `POST`
- **URL**: `/api/v1/auth/logout`
- **Auth**: None
- **Request Body**:
```json
{
  "refreshToken": "7092adce-06bb-49e0-8197-e85dfba90cc2"
}
```
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Logout successful",
  "data": null,
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.8 Logout All Devices
- **Method**: `POST`
- **URL**: `/api/v1/auth/logout-all`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Successfully logged out from all devices",
  "data": null,
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 2.9 Active Device Sessions
- **List Devices**: `GET /api/v1/auth/devices`
- **Terminate Device Session**: `DELETE /api/v1/auth/devices/{id}`
- **Auth**: `Bearer <Token>`

---

## 3. Mobile Home Feed & App Initialization

### 3.1 App Dynamic Config
- **Method**: `GET`
- **URL**: `/api/v1/mobile/app-config`
- **Headers**: `If-None-Match: "etag_value"` (Optional)
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "App config retrieved",
  "data": {
    "minAppVersion": "1.0.0",
    "latestAppVersion": "1.2.0",
    "forceUpdate": false,
    "maintenanceMode": false,
    "featureFlags": {
      "COMMERCE_ENABLED": true,
      "SURVEYS_ENABLED": true,
      "QUIZZES_ENABLED": true,
      "SOCIAL_TASKS_ENABLED": true
    },
    "currency": "BDT"
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 3.2 Promo Banners Carousel
- **Method**: `GET`
- **URL**: `/api/v1/mobile/banners`
- **Query Params**: `position` (optional, default: `HOME_PROMO`)
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Promo banners retrieved",
  "data": [
    {
      "id": "b1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
      "title": "Boost Your Earnings Today",
      "imageUrl": "https://storage.uparjon.com/banners/summer_boost.jpg",
      "targetUrl": "/mobile/campaigns",
      "actionType": "INTERNAL_NAVIGATION",
      "position": "HOME_PROMO",
      "displayOrder": 1
    }
  ],
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 3.3 Complete Home Feed Dashboard
- **Method**: `GET`
- **URL**: `/api/v1/mobile/home-feed`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Home feed retrieved",
  "data": {
    "wallet": {
      "balance": 14250.60,
      "currency": "BDT",
      "pendingAmount": 250.00
    },
    "featuredCampaigns": [
      {
        "id": "c1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
        "title": "Watch & Earn Tech Intro",
        "thumbnailUrl": "https://storage.uparjon.com/ads/thumb1.jpg",
        "type": "VIDEO",
        "rewardAmount": 75.00,
        "durationSeconds": 30,
        "status": "ACTIVE"
      }
    ],
    "recommendedCampaigns": [],
    "surveys": [
      {
        "id": "s1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
        "title": "E-Commerce Experience Survey",
        "rewardAmount": 10.00,
        "estimatedMinutes": 3
      }
    ],
    "quizzes": [
      {
        "id": "q1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
        "title": "Daily General Knowledge",
        "questionsCount": 5,
        "rewardAmount": 5.00
      }
    ],
    "categoryTiles": [
      {
        "code": "TASKS",
        "title": "Micro Tasks",
        "iconUrl": "https://storage.uparjon.com/icons/tasks.png",
        "route": "/mobile/tasks"
      }
    ],
    "unreadNotifications": 3,
    "stats": {
      "todayEarnings": 120.00,
      "completedTodayCount": 4
    }
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 3.4 Daily Tasks Checklist
- **Method**: `GET`
- **URL**: `/api/v1/mobile/tasks/daily`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Daily tasks retrieved",
  "data": [
    {
      "id": "task_watch_3_ads",
      "title": "Watch 3 Video Ads",
      "reward": 15.00,
      "progress": 2,
      "target": 3,
      "completed": false
    },
    {
      "id": "task_complete_quiz",
      "title": "Complete Daily Quiz",
      "reward": 5.00,
      "progress": 1,
      "target": 1,
      "completed": true
    }
  ],
  "timestamp": "2026-09-12T18:00:00"
}
```

---

## 4. User Profile, Security & KYC

### 4.1 Get Profile
- **Method**: `GET`
- **URL**: `/api/v1/mobile/profile`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Profile retrieved",
  "data": {
    "id": "e3012ff1-1647-4934-8be0-bceadfc4e981",
    "firstName": "Tanvir",
    "lastName": "Ahmed",
    "email": "tanvir@example.com",
    "phone": "01712345678",
    "mobileOperator": "GRAMEENPHONE",
    "avatarUrl": "https://storage.uparjon.com/avatars/user.jpg",
    "referralCode": "REF98765",
    "emailVerified": true,
    "emailVerifiedAt": "2026-01-15T10:00:00",
    "phoneVerified": true,
    "kycVerified": true,
    "joinedAt": "2026-01-01T12:00:00"
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 4.2 Update Profile
- **Method**: `PUT`
- **URL**: `/api/v1/mobile/profile`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "firstName": "Tanvir",
  "lastName": "Ahmed",
  "email": "tanvir.updated@example.com",
  "countryCode": "BD",
  "phone": "01712345678"
}
```

---

### 4.3 Upload Avatar Image
- **Method**: `POST`
- **URL**: `/api/v1/mobile/profile/avatar`
- **Headers**: `Content-Type: multipart/form-data`
- **Auth**: `Bearer <Token>`
- **Form Data**: `avatar` (File)
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Avatar uploaded",
  "data": {
    "avatarUrl": "https://storage.uparjon.com/avatars/user_123.jpg"
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 4.4 User Lifetime Stats
- **Method**: `GET`
- **URL**: `/api/v1/mobile/profile/stats`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "User stats retrieved",
  "data": {
    "campaignsCompleted": 18,
    "surveysCompleted": 6,
    "quizzesCompleted": 12,
    "lifetimeEarnings": 14250.60,
    "currentStreak": 5
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 4.5 Submit KYC Documents
- **Method**: `POST`
- **URL**: `/api/v1/mobile/kyc`
- **Headers**: `Content-Type: multipart/form-data`
- **Auth**: `Bearer <Token>`
- **Form Data**:
  - `fullName`: `Tanvir Ahmed`
  - `dateOfBirth`: `1995-06-15`
  - `nationalIdNumber`: `19951234567890123`
  - `frontDocument`: `<Front NID File>`
  - `backDocument`: `<Back NID File>`
  - `selfie`: `<User Selfie File>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "KYC submitted",
  "data": {
    "status": "PENDING",
    "rejectionReason": null
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 4.6 Check KYC Status
- **Method**: `GET`
- **URL**: `/api/v1/mobile/kyc`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "KYC status retrieved",
  "data": {
    "status": "APPROVED",
    "rejectionReason": null
  },
  "timestamp": "2026-09-12T18:00:00"
}
```
*(Values: `NOT_SUBMITTED`, `PENDING`, `APPROVED`, `REJECTED`)*

---

### 4.7 Change Password
- **Method**: `POST`
- **URL**: `/api/v1/mobile/security/change-password`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "currentPassword": "Password@123",
  "newPassword": "NewPassword@456",
  "confirmPassword": "NewPassword@456"
}
```
- **Response (`200 OK`)**: Returns new `TokenResponse`.

---

### 4.8 Referral Summary & History
- **Summary**: `GET /api/v1/mobile/referrals`
- **History List**: `GET /api/v1/mobile/referrals/history`
- **Share Link**: `GET /api/v1/mobile/referrals/share-link`
- **Auth**: `Bearer <Token>`

---

### 4.9 Account Deletion Request
- **Method**: `POST`
- **URL**: `/api/v1/mobile/account/delete-request`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "reason": "Account no longer needed"
}
```

---

## 5. Wallet & Transaction History

### 5.1 Mobile Wallet Overview
- **Method**: `GET`
- **URL**: `/api/v1/mobile/wallet/overview`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Wallet overview retrieved successfully",
  "data": {
    "availableBalance": 14250.60,
    "pendingBalance": 250.00,
    "lifetimeEarnings": 25000.00,
    "totalWithdrawn": 10500.00,
    "pendingRewards": 2,
    "completedRewards": 41
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 5.2 Transaction History (Paginated)
- **Method**: `GET`
- **URL**: `/api/v1/mobile/wallet/transactions`
- **Query Params**:
  - `page` (default: `0`)
  - `size` (default: `20`)
  - `type` (optional: `REWARD`, `WITHDRAWAL`, `ADMIN_ADJUSTMENT`, `BONUS`)
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Transaction history retrieved successfully",
  "data": {
    "content": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "type": "REWARD",
        "amount": 75.00,
        "status": "COMPLETED",
        "description": "Ad Reward: Summer Referral Drive",
        "createdAt": "2026-09-12T14:30:00"
      },
      {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "type": "WITHDRAWAL",
        "amount": -500.00,
        "status": "COMPLETED",
        "description": "Payout to bKash (017******78)",
        "createdAt": "2026-09-10T11:15:00"
      }
    ],
    "pageable": {
      "pageNumber": 0,
      "pageSize": 20
    },
    "totalElements": 2,
    "totalPages": 1,
    "last": true
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 5.3 Earnings Breakdown & Insights
- **Earnings Summary**: `GET /api/v1/mobile/wallet/earnings-summary`  
  *(Returns `today`, `thisWeek`, `thisMonth`, `lifetime`)*
- **Insights**: `GET /api/v1/mobile/wallet/insights`  
  *(Returns `highestEarningDay`, `highestEarningAmount`, `adsCompleted`, `averageDailyReward`)*

---

## 6. Deposits & Payment Gateways

### 6.1 Initiate Wallet Top-Up
- **Method**: `POST`
- **URL**: `/api/v1/payments/initiate`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "amount": 500.00,
  "gateway": "BKASH",
  "callbackUrl": "https://app.uparjon.com/payment/success",
  "cancelUrl": "https://app.uparjon.com/payment/cancel"
}
```
- **Response (`200 OK`)**:
```json
{
  "paymentUrl": "https://sandbox.payment.bkash.com/checkout/pay?token=xyz",
  "transactionReference": "TXN_BKASH_123456789"
}
```

---

### 6.2 Saved Cash-Out Methods
- **List Methods**: `GET /api/v1/mobile/payment-methods`
- **Register Method**: `POST /api/v1/mobile/payment-methods`
  - Body:
  ```json
  {
    "provider": "BKASH",
    "accountNumber": "01712345678",
    "gateway": "BKASH"
  }
  ```
- **Delete Method**: `DELETE /api/v1/mobile/payment-methods/{id}`

---

## 7. Withdrawals & Payout Requests

### 7.1 List Available Withdrawal Channels
- **Method**: `GET`
- **URL**: `/api/v1/withdrawal-methods`
- **Auth**: None (Public)
- **Response (`200 OK`)**:
```json
[
  {
    "id": "a1b2c3d4-0000-0000-0000-000000000001",
    "methodCode": "BKASH",
    "name": "bKash Personal",
    "methodType": "MOBILE_BANKING",
    "minimumAmount": 50.00,
    "maximumAmount": 25000.00,
    "processingFee": 5.00,
    "active": true
  },
  {
    "id": "a1b2c3d4-0000-0000-0000-000000000002",
    "methodCode": "NAGAD",
    "name": "Nagad Personal",
    "methodType": "MOBILE_BANKING",
    "minimumAmount": 50.00,
    "maximumAmount": 25000.00,
    "processingFee": 5.00,
    "active": true
  }
]
```

---

### 7.2 Link User Withdrawal Destination Account
- **Method**: `POST`
- **URL**: `/api/v1/withdrawal-accounts`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "userId": "e3012ff1-1647-4934-8be0-bceadfc4e981",
  "methodCode": "BKASH",
  "accountName": "Tanvir Ahmed",
  "accountNumber": "01712345678"
}
```

---

### 7.3 Submit Withdrawal Request
- **Method**: `POST`
- **URL**: `/api/v1/withdrawals`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "userId": "e3012ff1-1647-4934-8be0-bceadfc4e981",
  "withdrawalAccountId": "b1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
  "amount": 500.00
}
```
- **Response (`201 Created`)**:
```json
{
  "id": "w1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
  "userId": "e3012ff1-1647-4934-8be0-bceadfc4e981",
  "amount": 500.00,
  "fee": 5.00,
  "netAmount": 495.00,
  "status": "PENDING",
  "methodCode": "BKASH",
  "accountNumber": "01712345678",
  "createdAt": "2026-09-12T18:00:00"
}
```

---

### 7.4 Get User Withdrawal History
- **Method**: `GET`
- **URL**: `/api/v1/withdrawals/user/{userId}`
- **Auth**: `Bearer <Token>`

---

## 8. Campaigns & Video Ads

### 8.1 List Campaigns (Paginated)
- **Method**: `GET`
- **URL**: `/api/v1/mobile/campaigns`
- **Query Params**: `page` (default: `0`), `size` (default: `20`), `type` (optional)
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Campaigns retrieved successfully",
  "data": {
    "content": [
      {
        "id": "c1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
        "title": "Summer Referral Drive",
        "thumbnailUrl": "https://storage.uparjon.com/ads/thumb1.jpg",
        "type": "VIDEO",
        "rewardAmount": 75.00,
        "durationSeconds": 30,
        "status": "ACTIVE"
      },
      {
        "id": "c9e8d7c6-b5a4-3210-fedc-ba9876543210",
        "title": "Walton Smart Electronics",
        "thumbnailUrl": "https://storage.uparjon.com/ads/walton-thumb.jpg",
        "type": "VIDEO",
        "rewardAmount": 15.00,
        "durationSeconds": 30,
        "status": "COMPLETED"
      }
    ],
    "totalElements": 2,
    "totalPages": 1
  },
  "timestamp": "2026-09-12T18:00:00"
}
```
- **Campaign Status & UI Badging**:
  - `status`: Returns `"ACTIVE"` for available campaigns, or `"COMPLETED"` if the user has already participated and claimed the reward.
  - **Completed Campaigns Retention**: Completed campaigns remain visible in the feed so users can review their activity history instead of disappearing.
  - **Mobile UI**: Render a `[Completed]` badge on cards with `status == "COMPLETED"` and disable starting a new session.
- **Field aliases**: each card also carries `campaignType` (= `type`), `estimatedSeconds` (= `durationSeconds`) and `thumbnail` (= `thumbnailUrl`).
- **No video or questions on cards**: cards are for listing only. Open `GET /api/v1/mobile/campaigns/{id}` (§8.2.1) to get the video URL and quiz questions.
- **Visibility**: a campaign is listed when it is `ACTIVE`, has remaining budget, and the user matches its targeting rules (or has already completed it). Campaigns without targeting rules are visible to everyone.

---

### 8.2 Campaign Details (Video + Questions), Start & Complete Session

#### 8.2.1 Campaign Details
Returns everything needed to open a campaign: the ad video, thumbnail, minimum watch time, and quiz questions.

- **Method**: `GET`
- **URL**: `/api/v1/mobile/campaigns/{id}` (`{id}` = campaign ID from §8.1)
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Campaign details retrieved successfully",
  "data": {
    "id": "814c706b-5bbc-4250-880f-de815d2b2873",
    "title": "Arogga & Praava Digital Health Access Campaign - Quiz",
    "description": "Public wellness initiative incentivizing preventative health checks.",
    "image": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600",
    "instructions": "1. Watch the video ad completely.\n2. Complete the required tasks.\n3. Claim your reward.",
    "rewardAmount": 15.00,
    "estimatedDuration": 10,
    "eligible": true,
    "adId": "054266f2-5faa-4850-80d6-e4b67e552dc2",
    "adType": "QUIZ",
    "videoUrl": "https://api.avytor.com/api/v1/files/download/df448967-d136-4b27-84d5-5e5c2a6cc059.mp4",
    "thumbnailUrl": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600",
    "passingScore": 100,
    "maxAttempts": 3,
    "questions": [
      {
        "id": "9e073534-6943-4938-a08e-8f85b144bd6d",
        "questionText": "What energy savings percentage was demonstrated in the ad?",
        "questionType": "SINGLE_CHOICE",
        "isRequired": true,
        "orderIndex": 0,
        "options": [
          { "id": "0e093b03-97da-4e5b-9507-ab9026c97513", "optionText": "15%" },
          { "id": "b866ce57-81b3-48ac-96a4-b20b2fadbff3", "optionText": "5%" },
          { "id": "f66fbd6b-b1cf-461d-95f3-1e495f82466c", "optionText": "50%" }
        ]
      }
    ]
  },
  "timestamp": "2026-09-30T18:00:00"
}
```
- **Fields**:
  - `adId`: use it for `POST /mobile/ads/{adId}/view` and as `adId` in `POST /quizzes/submit`.
  - `adType`: `VIDEO` (watch and earn, `questions` is empty) or `QUIZ` (watch, then answer `questions`).
  - `videoUrl`: the media to play (supported formats in §8.4). `estimatedDuration` is the minimum watch time in seconds.
  - `questions[].options[]`: never include `correct`; grading happens on the server.
  - `eligible`: `false` if the user does not match targeting or has already completed the campaign — disable the Start button.
  - `adId`, `adType`, `videoUrl` are `null` and `questions` is empty when the campaign has no ad yet.

#### 8.2.2 Start & Complete Session (legacy campaign sessions)
- **Start Session**: `POST /api/v1/mobile/campaigns/{id}/start`
- **Complete & Claim**: `POST /api/v1/mobile/campaigns/{id}/complete`
- **Auth**: `Bearer <Token>`
- For video and quiz ads, use the ad flow in §8.5 instead; it records the view and handles rewards.

---

### 8.3 Watch Video Ads Feed & Track View

#### 8.3.1 Video Ads Feed
Retrieves the list of active video advertisements with per-user completion tags.

- **Method**: `GET`
- **URL**: `/api/v1/mobile/ads/feed`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
[
  {
    "id": "11111111-2222-3333-4444-555555555555",
    "adId": "11111111-2222-3333-4444-555555555555",
    "title": "Walton Primo Smartphone Promo",
    "mediaUrl": "https://storage.uparjon.com/ads/walton-promo.mp4",
    "videoUrl": "https://storage.uparjon.com/ads/walton-promo.mp4",
    "durationSeconds": 30,
    "duration": 30,
    "rewardAmount": 15.00,
    "reward": 15.00,
    "viewed": false,
    "status": "ACTIVE"
  },
  {
    "id": "22222222-3333-4444-5555-666666666666",
    "adId": "22222222-3333-4444-5555-666666666666",
    "title": "Apex Footwear September Collection",
    "mediaUrl": "https://storage.uparjon.com/ads/apex-collection.mp4",
    "videoUrl": "https://storage.uparjon.com/ads/apex-collection.mp4",
    "durationSeconds": 45,
    "duration": 45,
    "rewardAmount": 20.00,
    "reward": 20.00,
    "viewed": true,
    "status": "COMPLETED"
  }
]
```
- **New Fields & Flutter UI Handling**:
  - `viewed` (`boolean`): `true` if the current user has already watched and been rewarded for this ad; `false` otherwise.
  - `status` (`string`): `"ACTIVE"` or `"COMPLETED"`.
  - **Backward-Compatible Field Aliases**: Supports both naming conventions (`id` & `adId`, `mediaUrl` & `videoUrl`, `durationSeconds` & `duration`, `rewardAmount` & `reward`).
  - **Tagging & Badges**: Render a **"Viewed" / "Completed"** tag or badge on the video card when `item.viewed == true` or `item.status == 'COMPLETED'`. When tapped, completed ads should display a toast/modal informing the user that the reward was already claimed.
  - **Distinct Per-Ad Deduplication**: Duplicate tracking is strictly isolated per Ad ID (`ad.id`), **never by video URL**. Multiple campaigns or ads reusing the same media file will never trigger false duplicate claim errors.

#### 8.3.2 Track View Session
- **Method**: `POST`
- **URL**: `/api/v1/mobile/ads/{id}/view`
- **Auth**: `Bearer <Token>`
- **Identifier Flexibility**: `{id}` in the path can be either the **Ad ID (UUID)** or the **Campaign ID (UUID)**. The backend automatically resolves the campaign's active ad.
- **Request Body**:
```json
{
  "watchedDurationSeconds": 15,
  "deviceId": "android-device-987123"
}
```
- **Response Body (`200 OK`)**:
```json
{
  "id": "view-uuid-1111-2222-3333-4444",
  "adId": "11111111-2222-3333-4444-555555555555",
  "status": "COMPLETED",
  "watchedDurationSeconds": 15,
  "rewardEligible": true,
  "rewardEarned": 15.00,
  "startedAt": "2026-09-26T12:00:00",
  "completedAt": "2026-09-26T12:00:30"
}
```
- `status`: `REWARDED` once the reward is credited; `COMPLETED` for QUIZ/SURVEY ads that are still waiting for answers (`rewardEarned` is `0`).
- `409 ALREADY_CLAIMED` if the user was already rewarded for this ad.
- **Lifecycle & Reward Rules**:
  - **Standard Ads (`VIDEO`, `IMAGE`)**: Calling `/view` after watching the mandatory `durationSeconds` marks the session as `COMPLETED` and immediately credits the user's wallet with the reward.
  - **Interactive Ads (`QUIZ`, `SURVEY`)**: Calling `/view` marks the ad view session as `COMPLETED` fulfilling the prerequisite watch time, but **does not issue rewards yet**. The user proceeds to answer questions and submit via `/api/v1/quizzes/submit` or `/api/v1/surveys/submit`.
  - **Idempotency for Interactive Ads**: If the user re-triggers `/view` while taking an interactive quiz, the backend safely reuses the existing completed view session without throwing a duplicate claim error.

---

### 8.4 Get Ad Metadata & Interactive Questions
Used by the Flutter app to retrieve full ad configuration including media URL, duration timer, passing score, and all interactive questions.

- **Method**: `GET`
- **URL**: `/api/v1/ads/{id}`
- **Auth**: `Bearer <Token>`
- **Identifier Flexibility**: `{id}` in the path can be either the **Ad ID (UUID)** or the **Campaign ID (UUID)**. The backend resolves the active ad under the campaign automatically.
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Ad retrieved successfully",
  "data": {
    "id": "11111111-2222-3333-4444-555555555555",
    "title": "Aarong Dairy Promo",
    "adType": "QUIZ",
    "mediaUrl": "https://storage.uparjon.com/ads/aarong-promo.mp4",
    "durationSeconds": 15,
    "rewardAmount": 10.00,
    "passingScore": 100,
    "maxAttempts": 3,
    "questions": [
      {
        "id": "q-uuid-1111-aaaa-bbbb",
        "questionText": "What brand was featured in the advertisement?",
        "questionType": "SINGLE_CHOICE",
        "orderIndex": 1,
        "options": [
          {
            "id": "opt-uuid-1111-xxxx",
            "optionText": "Aarong Dairy"
          },
          {
            "id": "opt-uuid-1111-yyyy",
            "optionText": "Nestle Food"
          }
        ]
      },
      {
        "id": "q-uuid-2222-aaaa-bbbb",
        "questionText": "What percentage discount was offered in the ad?",
        "questionType": "SINGLE_CHOICE",
        "orderIndex": 2,
        "options": [
          {
            "id": "opt-uuid-2222-xxxx",
            "optionText": "20% Discount"
          },
          {
            "id": "opt-uuid-2222-yyyy",
            "optionText": "5% Discount"
          }
        ]
      }
    ]
  },
  "timestamp": "2026-09-22T18:00:00"
}
```

- Also returned: `description`, `status`, `thumbnailUrl`, `campaignId`, `completedViews`, `maxViews`.
- **Correct answers are never returned** to mobile users (`correct`, `hasCorrectAnswer` and `points` are omitted).
- The same video and questions are embedded in campaign details (§8.2.1), so you usually do not need this call.

- **Supported Media Formats**:
  - `mediaUrl` ending with `.mp4`, `.webm`, `.m3u8` $\rightarrow$ Render full-screen video player with playback controls disabled until timer expires.
  - `mediaUrl` ending with `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp` $\rightarrow$ Render high-resolution image/GIF banner with animated countdown circle.
- **Mandatory Timer Enforcement**:
  - `durationSeconds`: Minimum required seconds the user must view the media asset before the "Proceed to Questions" button unlocks.
  - Pausing video or backgrounding the Flutter app pauses the countdown timer.

---

### 8.5 Recommended Campaign Integration Flow

```
GET  /mobile/campaigns                 -> list cards (status ACTIVE / COMPLETED)
GET  /mobile/campaigns/{campaignId}    -> adId, adType, videoUrl, questions
     play videoUrl for at least estimatedDuration seconds
POST /mobile/ads/{adId}/view           -> {"watchedDurationSeconds": <seconds>, "deviceId": "<device>"}
     VIDEO ad: reward credited now, done
     QUIZ ad : status COMPLETED, reward pending
POST /quizzes/submit                   -> {"adId": "<adId>", "answers": [{"questionId": "...", "optionId": "..."}]}
     passed=true  -> reward credited, campaign card turns COMPLETED
     passed=false -> retry allowed until maxAttempts
GET  /mobile/wallet/overview           -> refresh balance
```

---

## 9. Micro Tasks & Social Tasks

### 9.1 List Social Tasks
- **Method**: `GET`
- **URL**: `/api/v1/mobile/social-tasks`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Available social tasks retrieved",
  "data": [
    {
      "id": "t1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
      "title": "Subscribe to Official YouTube Channel",
      "description": "Subscribe to our channel and upload a screenshot proof.",
      "platform": "YOUTUBE",
      "targetUrl": "https://youtube.com/@uparjonx",
      "rewardAmount": 20.00,
      "status": "available"
    }
  ],
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 9.2 Submit Task Proof
- **Method**: `POST`
- **URL**: `/api/v1/mobile/social-tasks/{id}/submit`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "socialHandle": "@tanvir_yt",
  "screenshotUrl": "https://storage.uparjon.com/proofs/proof_123.jpg"
}
```

---

## 10. Quizzes, Surveys & Interactive Assessments

### 10.1 Standalone General Quizzes
General knowledge, ICT, and e-commerce quizzes shown in the app's **Quiz** section and in `home-feed.quizzes`. These are separate from campaign quiz ads (§10.2).

> [!NOTE]
> Quizzes are created by admins via `POST /api/v1/admin/quizzes` (admin portal or seed automation). A quiz disappears from the user's list once they have submitted it.

> [!IMPORTANT]
> **UUID String Identification**: All IDs (`id`, `questionId`, `optionId`) in quizzes are standard UUID strings (e.g., `"c1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c"`). In Dart / TypeScript, declare them as `String` / `string`. Do NOT attempt to parse them into numeric integers.

#### 10.1.1 List Active Quizzes
- **Method**: `GET`
- **URL**: `/api/v1/mobile/quizzes`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
[
  {
    "id": "q1111111-2222-3333-4444-555555555555",
    "title": "Digital Bangladesh & Smart ICT Knowledge",
    "totalQuestions": 3,
    "questionCount": 3,
    "rewardAmount": 15.00
  },
  {
    "id": "q2222222-3333-4444-5555-666666666666",
    "title": "E-Commerce & Online Safety Essentials",
    "totalQuestions": 3,
    "rewardAmount": 12.00
  }
]
```

#### 10.1.2 Get Quiz Details & Questions
- **Method**: `GET`
- **URL**: `/api/v1/mobile/quizzes/{id}`
- **Auth**: `Bearer <Token>`
- **Response (`200 OK`)**:
```json
{
  "id": "q1111111-2222-3333-4444-555555555555",
  "title": "Digital Bangladesh & Smart ICT Knowledge",
  "description": "Test your knowledge on ICT developments and earn rewards.",
  "rewardAmount": 15.00,
  "questions": [
    {
      "id": "qu-1111-aaaa-bbbb-cccc",
      "questionText": "What does ICT stand for?",
      "options": [
        {
          "id": "op-1111-xxxx-yyyy-zzzz",
          "optionText": "Information and Communications Technology"
        },
        {
          "id": "op-2222-xxxx-yyyy-zzzz",
          "optionText": "Internal Computer Terminal"
        }
      ]
    }
  ]
}
```

#### 10.1.3 Submit Standalone Quiz Answers
- **Method**: `POST`
- **URL**: `/api/v1/mobile/quizzes/{id}/submit`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "answers": [
    {
      "questionId": "qu-1111-aaaa-bbbb-cccc",
      "optionId": "op-1111-xxxx-yyyy-zzzz"
    }
  ]
}
```
- **Response (`200 OK`)**:
```json
{
  "passed": true,
  "score": 3,
  "totalQuestions": 3,
  "rewardAmount": 15.00,
  "reward": 15.00,
  "message": "Congratulations! You passed the quiz."
}
```
- **Pass rule**: at least 60% correct. On pass, `rewardAmount` is credited to the wallet; on fail it is `0` and `message` is `"Quiz completed."`.
- **One attempt**: submitting again returns `500 ILLEGAL_STATE` ("You have already completed this quiz.").
- **All questions required**: fewer answers than questions returns `400`.

---

### 10.2 Campaign Interactive Video Ads Quiz
Evaluates the user's answers against configured correct options for interactive video ads, auto-grades the submission, and triggers wallet reward if the user meets or exceeds `passingScore`.

> [!IMPORTANT]
> **Watch Prerequisite Required**: The user must complete the mandatory media viewing timer (`POST /api/v1/mobile/ads/{id}/view`) prior to calling `/quizzes/submit`. Submitting without a completed view returns `500 ILLEGAL_STATE` (see below).
> **Dual ID Acceptance**: The `adId` property in the request body can be either the **Ad ID (UUID)** or the **Campaign ID (UUID)**.

- **Method**: `POST`
- **URL**: `/api/v1/quizzes/submit`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "adId": "11111111-2222-3333-4444-555555555555",
  "answers": [
    {
      "questionId": "q-uuid-1111-aaaa-bbbb",
      "optionId": "opt-uuid-1111-xxxx"
    },
    {
      "questionId": "q-uuid-2222-aaaa-bbbb",
      "optionId": "opt-uuid-2222-xxxx"
    }
  ]
}
```

- **Success Response — Passed (`200 OK`)**:
```json
{
  "passed": true,
  "score": 2,
  "totalQuestions": 2,
  "pointsEarned": 20,
  "rewardTriggered": true
}
```

- **Failure Response — Failed Passing Score (`200 OK`)**:
```json
{
  "passed": false,
  "score": 0,
  "totalQuestions": 2,
  "pointsEarned": 0,
  "rewardTriggered": false
}
```

- **Pass rule**: the percentage of correct answers must reach the ad's `passingScore` (default 100). Every question must be answered.

- **Prerequisite Error — Watch Timer Incomplete (`500`)**:
```json
{
  "success": false,
  "errorCode": "ILLEGAL_STATE",
  "message": "You must complete watching the ad before submitting answers",
  "timestamp": "2026-09-22T18:00:00"
}
```
- **Other errors**: `409 ALREADY_CLAIMED` (reward already claimed); `500 ILLEGAL_STATE` "You have reached the maximum number of attempts for this quiz".

---

### 10.3 Submit Survey Responses
Records user opinions/feedback for multi-vendor brand surveys and triggers the participation reward.

> [!IMPORTANT]
> **Watch Prerequisite Required**: The user must complete the media review period (`POST /api/v1/mobile/ads/{id}/view`) prior to submitting the survey.

- **Method**: `POST`
- **URL**: `/api/v1/surveys/submit`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "adId": "22222222-3333-4444-5555-666666666666",
  "answers": [
    {
      "questionId": "q-survey-1",
      "optionId": "opt-survey-1",
      "answerText": "Very Likely"
    }
  ]
}
```

- **Success Response (`200 OK`)**:
```json
{
  "passed": true,
  "totalQuestions": 1,
  "rewardTriggered": true
}
```

- **Prerequisite Error — Media Timer Incomplete (`400 Bad Request`)**:
```json
{
  "success": false,
  "message": "Ad view must be completed before taking the survey",
  "data": null,
  "timestamp": "2026-09-22T18:00:00"
}
```

---

### 10.4 Standalone Surveys
Surveys shown in the app's **Survey** section and in `home-feed.surveys`. Full guide: [`mobile-survey-api.md`](../src/main/resources/static/docs/mobile-survey-api.md).

| Step | Method & Path | Notes |
|---|---|---|
| List | `GET /api/v1/mobile/surveys` | Array of `{ id, title, questionCount, rewardAmount, estimatedSeconds }`; excludes surveys the user already submitted |
| Open | `GET /api/v1/mobile/surveys/{id}` | Returns `{ id, title, description, rewardAmount, estimatedSeconds, maxConcurrentSlots, questions[] }` and **reserves a slot** — call only when the user taps Start |
| Keep alive | `POST /api/v1/mobile/surveys/{id}/heartbeat` | Call periodically while answering to keep the slot |
| Cancel | `POST /api/v1/mobile/surveys/{id}/discard` | Releases the slot when the user leaves |
| Submit | `POST /api/v1/mobile/surveys/{id}/submit` | Body below; response includes `success` and `rewardAmount` |

Question types: `SINGLE_CHOICE`, `MULTIPLE_CHOICE`, `TEXT`, `RATING`, `BOOLEAN`.

```json
{
  "answers": [
    { "questionId": "<uuid>", "optionIds": ["<optionId>"] },
    { "questionId": "<uuid>", "optionIds": ["<optionId>", "<optionId>"] },
    { "questionId": "<uuid>", "optionIds": [], "answerText": "Free text answer" }
  ]
}
```

---

## 11. Push Notifications & Device Tokens

### 11.1 List & Unread Count
- **List Notifications**: `GET /api/v1/mobile/notifications?page=0&size=20`
- **Unread Count**: `GET /api/v1/mobile/notifications/unread-count`
- **Mark Single Read**: `PATCH /api/v1/mobile/notifications/{id}/read`
- **Mark All Read**: `PATCH /api/v1/mobile/notifications/read-all`
- **Auth**: `Bearer <Token>`

---

### 11.2 Register FCM / APNS Push Token
- **Method**: `POST`
- **URL**: `/api/v1/mobile/notifications/register-token`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "token": "fcm-registration-token-from-device-sdk",
  "deviceId": "android-device-987123",
  "platform": "ANDROID"
}
```

---

### 11.3 Notification Preferences
- **Get**: `GET /api/v1/mobile/notification-preferences`
- **Update**: `PUT /api/v1/mobile/notification-preferences`
- **Body**:
```json
{
  "rewardNotifications": true,
  "campaignNotifications": true,
  "surveyNotifications": true,
  "withdrawalNotifications": true,
  "marketingNotifications": false
}
```

---

## 12. Geographic Master Data & Mobile Operators

### 12.1 Cascading Dropdowns
- **Countries**: `GET /api/v1/geo/countries`
- **Divisions**: `GET /api/v1/geo/countries/{countryId}/divisions`
- **Districts**: `GET /api/v1/geo/divisions/{divisionId}/districts`
- **Thanas**: `GET /api/v1/geo/districts/{districtId}/thanas`
- **Auth**: None (Public)

---

### 12.2 Active Mobile Operators & Number Prefixes
- **Method**: `GET`
- **URL**: `/api/v1/geo/countries/by-code/BD/mobile-operators`
- **Auth**: None (Public)
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "Mobile operators retrieved",
  "data": {
    "countryCode": "BD",
    "callingCode": "+880",
    "nationalNumberLength": 10,
    "operators": [
      {
        "code": "GP",
        "name": "Grameenphone",
        "prefixes": ["017", "013"]
      },
      {
        "code": "BL",
        "name": "Banglalink",
        "prefixes": ["019", "014"]
      },
      {
        "code": "ROBI",
        "name": "Robi",
        "prefixes": ["018"]
      },
      {
        "code": "AIRTEL",
        "name": "Airtel",
        "prefixes": ["016"]
      },
      {
        "code": "TT",
        "name": "Teletalk",
        "prefixes": ["015"]
      }
    ]
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

## 13. Media Storage & File Uploads

### 13.1 Upload File (Screenshots, KYC, Avatars)
- **Method**: `POST`
- **URL**: `/api/v1/files/upload`
- **Headers**: `Content-Type: multipart/form-data`
- **Query Params**: `visibility` (`PUBLIC` or `PRIVATE`)
- **Auth**: `Bearer <Token>`
- **Form Data**: `file` (Binary)
- **Response (`200 OK`)**:
```json
{
  "success": true,
  "message": "File uploaded successfully",
  "data": {
    "fileId": "f1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
    "url": "http://localhost:8080/api/v1/files/public/f1a2b3c4-d5e6-proof.jpg"
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

## 14. E-Commerce Storefront (Catalog, Cart, Checkout)

### 14.1 Store Catalog
- **Categories Tree**: `GET /api/v1/commerce/store/categories`
- **List Products**: `GET /api/v1/commerce/store/products?page=0&size=24`
- **Product Detail**: `GET /api/v1/commerce/store/products/{slug}`
- **Search**: `GET /api/v1/commerce/store/search?q={query}`

### 14.2 Cart Operations
- **Get Cart**: `GET /api/v1/commerce/store/cart`
- **Add Line**: `POST /api/v1/commerce/store/cart/lines`
  ```json
  { "variantId": "uuid-here", "quantity": 1 }
  ```
- **Update Line**: `PATCH /api/v1/commerce/store/cart/lines/{lineId}`
  ```json
  { "quantity": 2 }
  ```
- **Remove Line**: `DELETE /api/v1/commerce/store/cart/lines/{lineId}`
- **Apply Coupon**: `POST /api/v1/commerce/store/cart/coupon`
  ```json
  { "couponCode": "DISCOUNT10" }
  ```

### 14.3 Checkout Orchestration
- **Start Checkout**: `POST /api/v1/commerce/store/checkout`
- **Shipping Address**: `PUT /api/v1/commerce/store/checkout/{sessionId}/shipping-address`
- **Shipping Method**: `PUT /api/v1/commerce/store/checkout/{sessionId}/shipping-method`
- **Payment Allocation (Wallet + Gateway)**: `PUT /api/v1/commerce/store/checkout/{sessionId}/payment-allocation`
- **Complete Order**: `POST /api/v1/commerce/store/checkout/{sessionId}/complete`
  - Required Header: `Idempotency-Key: <uuid>`

### 14.4 Orders & Tracking
- **My Orders**: `GET /api/v1/commerce/store/orders`
- **Order Details**: `GET /api/v1/commerce/store/orders/{orderId}`
- **Order Timeline & Tracking**: `GET /api/v1/commerce/store/orders/{orderId}/timeline`

---

## 15. Quick Reference Endpoint Matrix

| Domain | Method | Path | Auth |
|---|---|---|---|
| **Auth** | `POST` | `/api/v1/auth/register` | Public |
| **Auth** | `POST` | `/api/v1/auth/login` | Public |
| **Auth** | `POST` | `/api/v1/auth/refresh` | Refresh Token |
| **Auth** | `POST` | `/api/v1/auth/verify-otp` | Public |
| **Auth** | `POST` | `/api/v1/auth/forgot-password` | Public |
| **Auth** | `POST` | `/api/v1/auth/reset-password` | Public |
| **Auth** | `POST` | `/api/v1/auth/logout` | Public |
| **Auth** | `POST` | `/api/v1/auth/logout-all` | Bearer |
| **Home** | `GET` | `/api/v1/mobile/home-feed` | Bearer |
| **Home** | `GET` | `/api/v1/mobile/banners` | Bearer |
| **Home** | `GET` | `/api/v1/mobile/tasks/daily` | Bearer |
| **Home** | `GET` | `/api/v1/mobile/app-config` | Bearer |
| **Profile** | `GET` | `/api/v1/mobile/profile` | Bearer |
| **Profile** | `PUT` | `/api/v1/mobile/profile` | Bearer |
| **Profile** | `POST` | `/api/v1/mobile/profile/avatar` | Bearer (Multipart) |
| **Profile** | `GET` | `/api/v1/mobile/profile/stats` | Bearer |
| **Profile** | `GET` | `/api/v1/mobile/kyc` | Bearer |
| **Profile** | `POST` | `/api/v1/mobile/kyc` | Bearer (Multipart) |
| **Profile** | `POST` | `/api/v1/mobile/security/change-password` | Bearer |
| **Profile** | `GET` | `/api/v1/mobile/referrals` | Bearer |
| **Wallet** | `GET` | `/api/v1/mobile/wallet/overview` | Bearer |
| **Wallet** | `GET` | `/api/v1/mobile/wallet/transactions` | Bearer |
| **Wallet** | `GET` | `/api/v1/mobile/wallet/earnings-summary` | Bearer |
| **Wallet** | `GET` | `/api/v1/mobile/wallet/insights` | Bearer |
| **Deposit** | `POST` | `/api/v1/payments/initiate` | Bearer |
| **Withdrawal** | `GET` | `/api/v1/withdrawal-methods` | Public |
| **Withdrawal** | `POST` | `/api/v1/withdrawal-accounts` | Bearer |
| **Withdrawal** | `POST` | `/api/v1/withdrawals` | Bearer |
| **Campaigns** | `GET` | `/api/v1/mobile/campaigns` | Bearer |
| **Campaigns** | `GET` | `/api/v1/mobile/campaigns/{id}` | Bearer |
| **Campaigns** | `POST` | `/api/v1/mobile/campaigns/{id}/start` | Bearer |
| **Campaigns** | `POST` | `/api/v1/mobile/campaigns/{id}/complete` | Bearer |
| **Ads** | `GET` | `/api/v1/ads/{id}` | Bearer |
| **Ads** | `GET` | `/api/v1/mobile/ads/feed` | Bearer |
| **Ads** | `POST` | `/api/v1/mobile/ads/{id}/view` | Bearer |
| **Social Tasks** | `GET` | `/api/v1/mobile/social-tasks` | Bearer |
| **Social Tasks** | `POST` | `/api/v1/mobile/social-tasks/{id}/submit` | Bearer |
| **Quizzes** | `GET` | `/api/v1/mobile/quizzes` | Bearer |
| **Quizzes** | `GET` | `/api/v1/mobile/quizzes/{id}` | Bearer |
| **Quizzes** | `POST` | `/api/v1/mobile/quizzes/{id}/submit` | Bearer |
| **Quizzes** | `POST` | `/api/v1/quizzes/submit` (campaign quiz ads) | Bearer |
| **Surveys** | `GET` | `/api/v1/mobile/surveys` | Bearer |
| **Surveys** | `GET` | `/api/v1/mobile/surveys/{id}` | Bearer |
| **Surveys** | `POST` | `/api/v1/mobile/surveys/{id}/heartbeat` | Bearer |
| **Surveys** | `POST` | `/api/v1/mobile/surveys/{id}/discard` | Bearer |
| **Surveys** | `POST` | `/api/v1/mobile/surveys/{id}/submit` | Bearer |
| **Surveys** | `POST` | `/api/v1/surveys/submit` (campaign survey ads) | Bearer |
| **Notifications** | `GET` | `/api/v1/mobile/notifications` | Bearer |
| **Notifications** | `GET` | `/api/v1/mobile/notifications/unread-count` | Bearer |
| **Notifications** | `PATCH` | `/api/v1/mobile/notifications/{id}/read` | Bearer |
| **Notifications** | `PATCH` | `/api/v1/mobile/notifications/read-all` | Bearer |
| **Notifications** | `POST` | `/api/v1/mobile/notifications/register-token` | Bearer |
| **Geo** | `GET` | `/api/v1/geo/countries/by-code/{code}/mobile-operators` | Public |
| **Storage** | `POST` | `/api/v1/files/upload` | Bearer (Multipart) |
