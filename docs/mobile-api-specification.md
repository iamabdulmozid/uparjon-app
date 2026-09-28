# Mobile Application API Specification

> **Platform Version**: 1.0.0  
> **Target Audience**: Mobile App Engineers (Flutter / React Native / Android Kotlin / iOS Swift), QA, Backend Engineers  
> **Default Currency**: BDT (`৳`)  
> **Backend Base URL (Local)**: `http://localhost:8080/api/v1`  
> **Dev Proxy Base URL**: `http://localhost:4200/api/v1`  
> **Staging Base URL**: `https://api.avytor.com/api/v1` (Swagger UI: `https://api.avytor.com/swagger-ui.html`)  
> **Production Base URL**: `https://api.uparjonx.com/api/v1` (planned — not live as of 2026-09-28)  
> **Last Updated**: 2026-09-28 — merged the *Media Watch & Interactive Questions* Flutter integration guide (see §8.5 and Appendix A); this is now the single reference for all mobile app APIs.  

---

## Table of Contents
1. [Global Standards & Conventions](#1-global-standards--conventions)
2. [Authentication & Session Management](#2-authentication--session-management)
3. [Mobile Home Feed & App Initialization](#3-mobile-home-feed--app-initialization)
4. [User Profile, Security & KYC](#4-user-profile-security--kyc)
5. [Wallet & Transaction History](#5-wallet--transaction-history)
6. [Deposits & Payment Gateways](#6-deposits--payment-gateways)
7. [Withdrawals & Payout Requests](#7-withdrawals--payout-requests)
8. [Campaigns, Media Ads & Interactive Viewing](#8-campaigns-media-ads--interactive-viewing)
   - [8.5 Media Watch & Interactive Questions Flow](#85-media-watch--interactive-questions-flow)
9. [Micro Tasks & Social Tasks](#9-micro-tasks--social-tasks)
10. [Quizzes, Surveys & Interactive Assessments](#10-quizzes-surveys--interactive-assessments)
11. [Push Notifications & Device Tokens](#11-push-notifications--device-tokens)
12. [Geographic Master Data & Mobile Operators](#12-geographic-master-data--mobile-operators)
13. [Media Storage & File Uploads](#13-media-storage--file-uploads)
14. [E-Commerce Storefront (Catalog, Cart, Checkout)](#14-e-commerce-storefront-catalog-cart-checkout)
15. [Quick Reference Endpoint Matrix](#15-quick-reference-endpoint-matrix)
16. [Appendix A: Flutter Reference Implementation — Media Watch & Questions](#appendix-a-flutter-reference-implementation--media-watch--questions)

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

### 1.3 Error Envelope
```json
{
  "success": false,
  "errorCode": "INVALID_ARGUMENT",
  "message": "Invalid credentials or validation error",
  "data": null,
  "timestamp": "2026-09-12T18:00:00"
}
```
- `errorCode` is the stable, machine-readable reason (e.g. `INVALID_ARGUMENT`, `ALREADY_CLAIMED`, `UNAUTHORIZED`). Clients should branch on `errorCode`, never on `message`.

### 1.4 Test Accounts & OTP Configuration
- **Fixed OTP (Dev/Testing)**: `123456`
- **Default Password**: `Password@123`
- **Pre-seeded Accounts**:
  - `user@test.com` — Normal user (KYC incomplete, zero balance)
  - `kyc@test.com` — Verified user (KYC approved, starter balance)
  - `wallet@test.com` — High wallet balance user (KYC approved)
  - `admin@test.com` — Admin; can create & publish campaigns from the web dashboard
- The fixed OTP `123456` is accepted for all phone verification flows, so integration tests can run without a live SMS gateway.

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

## 8. Campaigns, Media Ads & Interactive Viewing

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

---

### 8.2 Campaign Details, Start & Complete Session
- **Details**: `GET /api/v1/mobile/campaigns/{id}`
- **Start Session**: `POST /api/v1/mobile/campaigns/{id}/start`
- **Complete & Claim**: `POST /api/v1/mobile/campaigns/{id}/complete`
- **Auth**: `Bearer <Token>`

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
  - **Tagging & Badges**: Render a **"Viewed" / "Completed"** tag or badge on the video card when `item.viewed == true` or `item.status == 'COMPLETED'`. When tapped, completed ads should display a toast/modal informing the user that the reward was already claimed: *"You have already claimed your reward for this ad."*
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
  "rewardEarned": 15.00,
  "startedAt": "2026-09-26T12:00:00Z",
  "completedAt": "2026-09-26T12:00:30Z"
}
```
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

- **Supported Media Formats**:
  - `mediaUrl` ending with `.mp4`, `.webm`, `.m3u8` $\rightarrow$ Render full-screen video player with playback controls disabled until timer expires.
  - `mediaUrl` ending with `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp` $\rightarrow$ Render high-resolution image/GIF banner with animated countdown circle.
- **Mandatory Timer Enforcement**:
  - `durationSeconds`: Minimum required seconds the user must view the media asset before the "Proceed to Questions" button unlocks.
  - Pausing video or backgrounding the Flutter app pauses the countdown timer.

> [!NOTE]
> **Anti-Cheat & Answer Protection**: The `GET /api/v1/ads/{id}` response strictly omits grading keys (`correct`, `correctOptionIndex`, `hasCorrectAnswer`, `points`) for earners and non-admin clients. Answers are validated and graded exclusively server-side during `POST /quizzes/submit`.
> **Ad Type Recognition**: All interactive quiz ads carry `adType: "QUIZ"`. If an ad returned by the feed contains questions and is not a survey, client applications should treat it as a quiz and dispatch answers to `/quizzes/submit`.

---

### 8.5 Media Watch & Interactive Questions Flow

The **Media Watch & Interactive Questions** module empowers advertisers to sponsor multimedia creatives (Video, Image, or animated GIF) accompanied by a mandatory viewing duration (`durationSeconds`). Upon fulfilling this viewing timer, earners are prompted to complete an interactive assessment (either a multi-question Quiz or Survey) to qualify for a wallet reward.

**Key Capabilities for Flutter:**
1. **Multi-Format Creatives**: Video streaming (`.mp4`, `.m3u8`), high-resolution static images (`.jpg`, `.png`), or animated GIFs.
2. **Mandatory Timed Viewing**: Strict client-side timer enforced by server-side session checks. The user cannot skip or rush the view.
3. **Dynamic Multi-Question Answering**: Questions and options carry unique UUIDs generated by the backend. The Flutter app iterates through questions with progress indicators (`Question 1 of N`).
4. **Prerequisite Gating**: Calling quiz or survey submission before recording view completion results in HTTP `400 Bad Request`.
5. **Real-Time Auto-Grading & Reward Settlement**: Server grades quiz responses against passing criteria (`passingScore`) and atomically awards wallet balance upon passing.

The endpoints involved: §8.3.1 (feed), §8.4 (ad metadata & questions), §8.3.2 (record the watch), then §10.2 (quiz) or §10.3 (survey). A reference Flutter implementation is in [Appendix A](#appendix-a-flutter-reference-implementation--media-watch--questions).

#### 8.5.1 End-to-End User Journey & State Machine

```mermaid
sequenceDiagram
    autonumber
    actor User as Earner (Flutter App)
    participant Flutter as Flutter UI / Controller
    participant API as Backend REST API (/api/v1)
    participant DB as PostgreSQL & Redis
    participant Wallet as Wallet Service

    User->>Flutter: Taps Ad from Feed or Campaigns (/watch-ad/{id})
    Flutter->>API: GET /api/v1/ads/{id}
    API-->>Flutter: Return Ad metadata, durationSeconds, mediaUrl, & questions[]
    
    Flutter->>Flutter: Initialize Media (VideoPlayer / CachedNetworkImage)
    Flutter->>Flutter: Start Countdown Timer (durationSeconds -> 0)
    Note over Flutter,User: Controls disabled; Seek disabled; Timer pauses on backgrounding
    
    User->>Flutter: Watches media until timer reaches 0s
    Flutter->>Flutter: Enable "Proceed to Questions" CTA
    
    User->>Flutter: Taps "Proceed to Questions"
    Flutter->>API: POST /api/v1/mobile/ads/{id}/view { watchedDurationSeconds: N }
    API->>DB: Mark AdView as COMPLETED (Prerequisite fulfilled, no reward yet)
    API-->>Flutter: HTTP 200 { success: true }
    
    Flutter->>Flutter: Render Question 1 of N (Dynamic Radio Options)
    loop For Each Question
        User->>Flutter: Selects Option -> Taps "Next Question"
        Flutter->>Flutter: Advance Stepper to next question
    end
    
    User->>Flutter: Answers final question -> Taps "Submit"
    Flutter->>Flutter: Show Fullscreen / Modal Loading Indicator
    
    alt Ad Type is QUIZ
        Flutter->>API: POST /api/v1/quizzes/submit { adId, answers: [{ questionId, optionId }] }
        API->>DB: Verify AdView is COMPLETED
        API->>DB: Grade answers against correct options & passingScore
        
        alt Score >= Passing Score
            API->>DB: Transition AdView to REWARDED
            API->>Wallet: Create Pending/Approved Wallet Reward (+৳10.00)
            API-->>Flutter: HTTP 200 { passed: true, score: N, pointsEarned: 10, rewardTriggered: true }
            Flutter->>User: Display "Congratulation!" Success Modal -> Redirect to /campaigns
        else Score < Passing Score
            API-->>Flutter: HTTP 200 { passed: false, score: 0, rewardTriggered: false }
            Flutter->>User: Display "Wrong Answer!" Modal -> Show retry options or exit
        end
        
    else Ad Type is SURVEY
        Flutter->>API: POST /api/v1/surveys/submit { adId, answers: [{ questionId, optionId, answerText }] }
        API->>DB: Verify AdView is COMPLETED & persist feedback responses
        API->>DB: Transition AdView to REWARDED
        API->>Wallet: Create Wallet Reward (+৳10.00)
        API-->>Flutter: HTTP 200 { passed: true, totalQuestions: N, rewardTriggered: true }
        Flutter->>User: Display "Feedback Submitted!" Success Modal -> Redirect to /campaigns
    end
```

#### 8.5.2 Anti-Fraud & Business Rules

| Rule | Implementation Requirement | Server Reaction |
|---|---|---|
| **Anti-Skip Protection** | Disable video scrubbing / seeking controls until `durationSeconds` reaches 0. | Submitting before watch completion returns HTTP 400. |
| **Prerequisite Gating** | Flutter app MUST execute `POST /api/v1/mobile/ads/{id}/view` before calling `/quizzes/submit` or `/surveys/submit`. | Backend checks `adView.completed == true`. Rejects premature submission with HTTP 400. |
| **App Backgrounding** | Observe `AppLifecycleState`. If the app enters background, pause video and countdown timer. | Prevents earners from letting ads run unseen while using other applications. |
| **Passing Score Gate** | Grade calculation is computed on the backend (`score >= passingScore`). | If below threshold, response returns `passed: false` and `rewardTriggered: false`. |
| **Single Reward Guarantee** | A user can only complete and claim rewards once per active campaign session. | Duplicate completion attempts return HTTP 409 or mark status as ALREADY_CLAIMED. |

#### 8.5.3 Edge Cases & Error Handling Checklist

- [ ] **Network Loss during playback**: Store elapsed seconds locally. Allow resuming without restarting countdown from zero if under 5 minutes elapsed.
- [ ] **Video Buffer / Stalling**: Countdown timer should pause if video playback state is `isBuffering == true`.
- [ ] **Token Expiry (HTTP 401)**: The Dio Auth Interceptor should catch 401, trigger `/api/v1/auth/refresh`, and retry the pending submission payload transparently.
- [ ] **Ad Creative 404 / Broken URL**: Display fallback branded placeholder image and gracefully permit the user to exit without crashing.
- [ ] **Empty Questions Array**: If `questions.isEmpty` on a `QUIZ` ad, treat viewing completion as full reward trigger or inform user.

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
General knowledge, ICT, and e-commerce quizzes available directly on the mobile app feed.

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
  "message": "Congratulations! You passed the quiz."
}
```

---

### 10.2 Campaign Interactive Video Ads Quiz
Evaluates the user's answers against configured correct options for interactive video ads, auto-grades the submission, and triggers wallet reward if the user meets or exceeds `passingScore`.

> [!IMPORTANT]
> **Watch Prerequisite Required**: The user must complete the mandatory media viewing timer (`POST /api/v1/mobile/ads/{id}/view`) prior to calling `/quizzes/submit`. Attempting to submit without completed watch status triggers HTTP 400.
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

- **Prerequisite Error — Watch Timer Incomplete (`400 Bad Request`)**:
```json
{
  "success": false,
  "errorCode": "INVALID_ARGUMENT",
  "message": "You must complete watching the ad before submitting answers",
  "data": null,
  "timestamp": "2026-09-22T18:00:00"
}
```

- **Duplicate Claim Error — Already Rewarded (`409 Conflict`)**:
```json
{
  "success": false,
  "errorCode": "ALREADY_CLAIMED",
  "message": "You have already completed and claimed the reward for this ad",
  "data": null,
  "timestamp": "2026-09-25T18:00:00"
}
```

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
| **Quizzes** | `POST` | `/api/v1/quizzes/submit` | Bearer |
| **Surveys** | `POST` | `/api/v1/surveys/submit` | Bearer |
| **Notifications** | `GET` | `/api/v1/mobile/notifications` | Bearer |
| **Notifications** | `GET` | `/api/v1/mobile/notifications/unread-count` | Bearer |
| **Notifications** | `PATCH` | `/api/v1/mobile/notifications/{id}/read` | Bearer |
| **Notifications** | `PATCH` | `/api/v1/mobile/notifications/read-all` | Bearer |
| **Notifications** | `POST` | `/api/v1/mobile/notifications/register-token` | Bearer |
| **Geo** | `GET` | `/api/v1/geo/countries/by-code/{code}/mobile-operators` | Public |
| **Storage** | `POST` | `/api/v1/files/upload` | Bearer (Multipart) |

---

## Appendix A: Flutter Reference Implementation — Media Watch & Questions

Reference Dart code for the flow in §8.5, carried over from the former *Flutter Developer Integration Guide: Media Watch & Interactive Questions* (v1.0.0, 2026-09-22). It is a self-contained sample; file paths such as `lib/models/ad_models.dart` are suggestions, not requirements.

### A.1 Data Models (Dart Classes)

Save these models under `lib/models/ad_models.dart`.

#### A.1.1 Video Ads Feed Item Model

```dart
class VideoAdFeedItemModel {
  final String id;
  final String title;
  final String mediaUrl;
  final int durationSeconds;
  final double rewardAmount;
  final bool viewed;
  final String status;

  VideoAdFeedItemModel({
    required this.id,
    required this.title,
    required this.mediaUrl,
    required this.durationSeconds,
    required this.rewardAmount,
    required this.viewed,
    required this.status,
  });

  bool get isCompleted => viewed || status.toUpperCase() == 'COMPLETED';

  factory VideoAdFeedItemModel.fromJson(Map<String, dynamic> json) {
    return VideoAdFeedItemModel(
      id: (json['id'] ?? json['adId']) as String? ?? '',
      title: json['title'] as String? ?? 'Video Ad',
      mediaUrl: (json['mediaUrl'] ?? json['videoUrl']) as String? ?? '',
      durationSeconds: ((json['durationSeconds'] ?? json['duration']) as num?)?.toInt() ?? 30,
      rewardAmount: ((json['rewardAmount'] ?? json['reward']) as num?)?.toDouble() ?? 10.0,
      viewed: json['viewed'] as bool? ?? false,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}
```

#### A.1.2 Ad Metadata & Questions Model

```dart
enum AdType { VIDEO, IMAGE, GIF, QUIZ, SURVEY }

class AdDetailModel {
  final String id;
  final String title;
  final AdType adType;
  final String? mediaUrl;
  final int durationSeconds;
  final double rewardAmount;
  final int? passingScore;
  final int? maxAttempts;
  final List<QuestionModel> questions;

  AdDetailModel({
    required this.id,
    required this.title,
    required this.adType,
    this.mediaUrl,
    required this.durationSeconds,
    required this.rewardAmount,
    this.passingScore,
    this.maxAttempts,
    required this.questions,
  });

  bool get isVideo =>
      mediaUrl != null &&
      (mediaUrl!.endsWith('.mp4') ||
          mediaUrl!.endsWith('.webm') ||
          mediaUrl!.endsWith('.m3u8'));

  factory AdDetailModel.fromJson(Map<String, dynamic> json) {
    return AdDetailModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Advertisement',
      adType: _parseAdType(json['adType'] as String?),
      mediaUrl: json['mediaUrl'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 10,
      rewardAmount: (json['rewardAmount'] as num?)?.toDouble() ?? 10.0,
      passingScore: (json['passingScore'] as num?)?.toInt(),
      maxAttempts: (json['maxAttempts'] as num?)?.toInt(),
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static AdType _parseAdType(String? type) {
    switch (type?.toUpperCase()) {
      case 'QUIZ':
        return AdType.QUIZ;
      case 'SURVEY':
        return AdType.SURVEY;
      case 'IMAGE':
        return AdType.IMAGE;
      default:
        return AdType.VIDEO;
    }
  }
}

class QuestionModel {
  final String id;
  final String questionText;
  final String questionType;
  final int orderIndex;
  final List<OptionModel> options;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.orderIndex,
    required this.options,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String,
      questionText: json['questionText'] as String? ?? '',
      questionType: json['questionType'] as String? ?? 'SINGLE_CHOICE',
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 1,
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => OptionModel.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class OptionModel {
  final String id;
  final String optionText;

  OptionModel({
    required this.id,
    required this.optionText,
  });

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      id: json['id'] as String,
      optionText: json['optionText'] as String? ?? '',
    );
  }
}
```

---

#### A.1.3 Quiz & Survey Submission Models

```dart
class QuizAnswerItem {
  final String questionId;
  final String optionId;
  final String? answerText;

  QuizAnswerItem({
    required this.questionId,
    required this.optionId,
    this.answerText,
  });

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'optionId': optionId,
      if (answerText != null) 'answerText': answerText,
    };
  }
}

class QuizSubmissionRequest {
  final String adId;
  final List<QuizAnswerItem> answers;

  QuizSubmissionRequest({
    required this.adId,
    required this.answers,
  });

  Map<String, dynamic> toJson() => {
        'adId': adId,
        'answers': answers.map((a) => a.toJson()).toList(),
      };
}

class QuizSubmissionResult {
  final bool passed;
  final int score;
  final int totalQuestions;
  final int pointsEarned;
  final bool rewardTriggered;

  QuizSubmissionResult({
    required this.passed,
    required this.score,
    required this.totalQuestions,
    required this.pointsEarned,
    required this.rewardTriggered,
  });

  factory QuizSubmissionResult.fromJson(Map<String, dynamic> json) {
    return QuizSubmissionResult(
      passed: json['passed'] as bool? ?? false,
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      rewardTriggered: json['rewardTriggered'] as bool? ?? false,
    );
  }
}
```

---

### A.2 Flutter Service Implementation (Dio)

Save under `lib/services/ad_api_service.dart`.

#### A.2.1 API Client with Auth Interceptor

```dart
import 'package:dio/dio.dart';
import '../models/ad_models.dart';

class ApiService {
  late final Dio _dio;

  ApiService({required String baseUrl, required Future<String?> Function() tokenProvider}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Centralized error normalization
          return handler.next(error);
        },
      ),
    );
  }

  Dio get client => _dio;
}
```

---

#### A.2.2 Ad & Assessment Service

```dart
class AdApiService {
  final ApiService _api;

  AdApiService(this._api);

  /// 1. Fetch Ad metadata and dynamic questions
  Future<AdDetailModel> getAdDetails(String adId) async {
    final response = await _api.client.get('/ads/$adId');
    if (response.data['success'] == true) {
      return AdDetailModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to load ad details');
  }

  /// 2. Track media watch completion (Prerequisite for submitting answers)
  Future<bool> recordWatchCompletion(String adId, {required int watchedSeconds, required String deviceId}) async {
    final response = await _api.client.post(
      '/mobile/ads/$adId/view',
      data: {
        'watchedDurationSeconds': watchedSeconds,
        'deviceId': deviceId,
      },
    );
    return response.statusCode == 200;
  }

  /// 3. Submit quiz answers for grading & wallet reward
  Future<QuizSubmissionResult> submitQuiz(QuizSubmissionRequest request) async {
    final response = await _api.client.post(
      '/quizzes/submit',
      data: request.toJson(),
    );
    return QuizSubmissionResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// 4. Submit survey feedback
  Future<bool> submitSurvey(QuizSubmissionRequest request) async {
    final response = await _api.client.post(
      '/surveys/submit',
      data: request.toJson(),
    );
    return response.data['passed'] == true;
  }
}
```

---

### A.3 UI & Controller Implementation Patterns

#### A.3.1 Media Player with Non-Skippable Countdown

Implement this inside `lib/screens/watch_ad_screen.dart`.

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/ad_models.dart';
import '../services/ad_api_service.dart';

class WatchAdScreen extends StatefulWidget {
  final String adId;
  final AdApiService adService;

  const WatchAdScreen({Key? key, required this.adId, required this.adService}) : super(key: key);

  @override
  State<WatchAdScreen> createState() => _WatchAdScreenState();
}

class _WatchAdScreenState extends State<WatchAdScreen> with WidgetsBindingObserver {
  AdDetailModel? _ad;
  VideoPlayerController? _videoController;
  Timer? _countdownTimer;

  int _remainingSeconds = 0;
  bool _canProceed = false;
  bool _isLoading = true;
  bool _isQuestionStage = false;

  // Question navigation state
  int _currentQuestionIndex = 0;
  final Map<String, String> _selectedAnswers = {}; // questionId -> optionId

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Anti-fraud: pause video and timer when user leaves app
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _videoController?.pause();
      _countdownTimer?.cancel();
    } else if (state == AppLifecycleState.resumed && !_canProceed) {
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController!.play();
      }
      _startTimer();
    }
  }

  Future<void> _loadAd() async {
    try {
      final ad = await widget.adService.getAdDetails(widget.adId);
      setState(() {
        _ad = ad;
        _remainingSeconds = ad.durationSeconds;
        _isLoading = false;
      });

      if (ad.isVideo && ad.mediaUrl != null) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(ad.mediaUrl!))
          ..initialize().then((_) {
            setState(() {});
            _videoController!.play();
          });
      }
      _startTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ad: $e')),
      );
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _canProceed = true;
        });
      }
    });
  }

  Future<void> _onProceedToQuestions() async {
    setState(() => _isLoading = true);
    try {
      // 1. Mark ad view complete
      await widget.adService.recordWatchCompletion(
        widget.adId,
        watchedSeconds: _ad!.durationSeconds,
        deviceId: 'flutter-client-device',
      );

      setState(() {
        _isLoading = false;
        _isQuestionStage = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE5A93C))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(_isQuestionStage ? 'Assessment' : 'Watch Ad'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: _isQuestionStage ? _buildQuestionsView() : _buildMediaWatchView(),
    );
  }

  Widget _buildMediaWatchView() {
    return Column(
      children: [
        // Media Container
        Expanded(
          child: Center(
            child: _ad!.isVideo && _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : Image.network(
                    _ad!.mediaUrl ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                  ),
          ),
        ),

        // Countdown Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Text(
                _canProceed ? 'Media review completed!' : 'Reward unlocks in: ${_remainingSeconds}s',
                style: TextStyle(
                  color: _canProceed ? Colors.greenAccent : const Color(0xFFE5A93C),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _canProceed ? _onProceedToQuestions : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    disabledBackgroundColor: Colors.grey.shade800,
                  ),
                  child: const Text('Proceed to Questions', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
```

---

#### A.3.2 Question Stepper & Selection Wizard

Add this method to `_WatchAdScreenState`:

```dart
  Widget _buildQuestionsView() {
    final questions = _ad!.questions;
    final currentQ = questions[_currentQuestionIndex];
    final selectedOptionId = _selectedAnswers[currentQ.id];
    final isLastQuestion = _currentQuestionIndex == questions.length - 1;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Text(
            'Question ${_currentQuestionIndex + 1} of ${questions.length}',
            style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / questions.length,
            backgroundColor: Colors.grey.shade800,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE5A93C)),
          ),
          const SizedBox(height: 24),

          // Question Title
          Text(
            currentQ.questionText,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Options List
          Expanded(
            child: ListView.separated(
              itemCount: currentQ.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final opt = currentQ.options[index];
                final isSelected = selectedOptionId == opt.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAnswers[currentQ.id] = opt.id;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0x33E5A93C) : const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE5A93C) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? const Color(0xFFE5A93C) : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.optionText,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Action Button (Next or Submit)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: selectedOptionId != null ? _onNextOrSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A93C),
                disabledBackgroundColor: Colors.grey.shade800,
              ),
              child: Text(
                isLastQuestion ? 'Submit Assessment' : 'Next Question',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onNextOrSubmit() async {
    final questions = _ad!.questions;
    if (_currentQuestionIndex < questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      // Final submission
      _submitAssessment();
    }
  }

  Future<void> _submitAssessment() async {
    setState(() => _isLoading = true);

    final answers = _selectedAnswers.entries
        .map((e) => QuizAnswerItem(questionId: e.key, optionId: e.value))
        .toList();

    final req = QuizSubmissionRequest(adId: widget.adId, answers: answers);

    try {
      if (_ad!.adType == AdType.QUIZ || (_ad!.questions.isNotEmpty && _ad!.adType != AdType.SURVEY)) {
        final result = await widget.adService.submitQuiz(req);
        setState(() => _isLoading = false);
        if (result.passed) {
          _showCongratulationModal(result.pointsEarned);
        } else {
          _showWrongAnswerModal();
        }
      } else {
        await widget.adService.submitSurvey(req);
        setState(() => _isLoading = false);
        _showCongratulationModal(_ad!.rewardAmount.toInt());
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
```

---

#### A.3.3 Success & Failure Modal Dialogs

```dart
  void _showCongratulationModal(int points) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Congratulation! 🎉', style: TextStyle(color: Colors.greenAccent)),
        content: Text(
          'Your answers are correct!\n৳$points.00 has been added to your pending wallet.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5A93C)),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Return to feed/campaigns
            },
            child: const Text('Continue', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showWrongAnswerModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Wrong Answer!', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Your answers did not meet the passing score for this campaign. You may re-attempt if attempts remain.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Exit', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5A93C)),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _currentQuestionIndex = 0;
                _selectedAnswers.clear();
              });
            },
            child: const Text('Try Again', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
```
