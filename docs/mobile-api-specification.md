# Mobile Application API Specification

> **Platform Version**: 1.0.0  
> **Target Audience**: Mobile App Engineers (Flutter / React Native / Android Kotlin / iOS Swift), QA, Backend Engineers  
> **Default Currency**: BDT (`৳`)  
> **Backend Base URL (Local)**: `http://localhost:8080/api/v1`  
> **Dev Proxy Base URL**: `http://localhost:4200/api/v1`  

---

## Table of Contents
1. [Global Standards & Conventions](#1-global-standards--conventions)
2. [Authentication & Session Management](#2-authentication--session-management)
3. [Mobile Home Feed & App Initialization](#3-mobile-home-feed--app-initialization)
4. [User Profile, Security & KYC](#4-user-profile-security--kyc)
5. [Wallet & Transaction History](#5-wallet--transaction-history)
6. [Deposits & Payment Gateways](#6-deposits--payment-gateways)
7. [Withdrawals & Payout Requests](#7-withdrawals--payout-requests)
8. [Campaigns & Video Ads](#8-campaigns--video-ads)
9. [Micro Tasks & Social Tasks](#9-micro-tasks--social-tasks)
10. [Quizzes & Daily Assessments](#10-quizzes--daily-assessments)
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

### 1.3 Error Envelope
```json
{
  "success": false,
  "message": "Invalid credentials or validation error",
  "data": null,
  "timestamp": "2026-09-12T18:00:00"
}
```

### 1.4 Test Accounts & OTP Configuration
- **Fixed OTP (Dev/Testing)**: `123456`
- **Default Password**: `Password@123`
- **Pre-seeded Accounts**:
  - `user@test.com` — Normal user (KYC incomplete, zero balance)
  - `kyc@test.com` — Verified user (KYC approved, starter balance)
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
- **Query Params**: `page` (default: `0`), `size` (default: `20`)
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
      }
    ],
    "totalElements": 1,
    "totalPages": 1
  },
  "timestamp": "2026-09-12T18:00:00"
}
```

---

### 8.2 Campaign Details, Start & Complete Session
- **Details**: `GET /api/v1/mobile/campaigns/{id}`
- **Start Session**: `POST /api/v1/mobile/campaigns/{id}/start`
- **Complete & Claim**: `POST /api/v1/mobile/campaigns/{id}/complete`
- **Auth**: `Bearer <Token>`

---

### 8.3 Watch Video Ads Feed & Track View
- **Feed**: `GET /api/v1/mobile/ads/feed`
- **Track View**: `POST /api/v1/mobile/ads/{id}/view`
- **Request Body**:
```json
{
  "watchedDurationSeconds": 30,
  "deviceId": "android-device-987123"
}
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

## 10. Quizzes & Daily Assessments

### 10.1 List & Details
- **List Quizzes**: `GET /api/v1/mobile/quizzes`
- **Quiz Details & Questions**: `GET /api/v1/mobile/quizzes/{id}`
- **Auth**: `Bearer <Token>`

---

### 10.2 Submit Quiz & Auto-Grade
- **Method**: `POST`
- **URL**: `/api/v1/mobile/quizzes/{id}/submit`
- **Auth**: `Bearer <Token>`
- **Request Body**:
```json
{
  "answers": [
    {
      "questionId": "qst-1111-2222-3333-444444444441",
      "optionId": "opt-2"
    }
  ]
}
```
- **Response (`200 OK`)**:
```json
{
  "score": 5,
  "totalQuestions": 5,
  "passed": true,
  "rewardAmount": 10.00
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
| **Ads** | `GET` | `/api/v1/mobile/ads/feed` | Bearer |
| **Ads** | `POST` | `/api/v1/mobile/ads/{id}/view` | Bearer |
| **Social Tasks** | `GET` | `/api/v1/mobile/social-tasks` | Bearer |
| **Social Tasks** | `POST` | `/api/v1/mobile/social-tasks/{id}/submit` | Bearer |
| **Quizzes** | `GET` | `/api/v1/mobile/quizzes` | Bearer |
| **Quizzes** | `GET` | `/api/v1/mobile/quizzes/{id}` | Bearer |
| **Quizzes** | `POST` | `/api/v1/mobile/quizzes/{id}/submit` | Bearer |
| **Notifications** | `GET` | `/api/v1/mobile/notifications` | Bearer |
| **Notifications** | `GET` | `/api/v1/mobile/notifications/unread-count` | Bearer |
| **Notifications** | `PATCH` | `/api/v1/mobile/notifications/{id}/read` | Bearer |
| **Notifications** | `PATCH` | `/api/v1/mobile/notifications/read-all` | Bearer |
| **Notifications** | `POST` | `/api/v1/mobile/notifications/register-token` | Bearer |
| **Geo** | `GET` | `/api/v1/geo/countries/by-code/{code}/mobile-operators` | Public |
| **Storage** | `POST` | `/api/v1/files/upload` | Bearer (Multipart) |
