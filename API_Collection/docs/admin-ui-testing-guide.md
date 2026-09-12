# Admin UI Testing Guide

This document provides a step-by-step guide for developers, QA, and administrators to test and verify the authentication and UI flows in the frontend application.

## Prerequisites

- The backend API (`uparjonx-api`) must be running locally on port 8080.
- The Angular frontend (`platform/frontend`) must be running locally (`npm run start` or `ng serve`) on port 4200.
- Ensure the database is seeded. The standard staging admin account is:
  - **Email:** `admin@test.com`
  - **Password:** `Password@123`

## Flow 1: Signup Flow Simulation

*Note: The frontend currently mocks the signup process and does not persist the user to the real backend database to prevent enumeration and clutter.*

1. Navigate to `http://localhost:4200/mobile/login`.
2. Click the **"Sign up"** link.
3. Fill in the required fields:
   - **Full Name:** E2E Tester
   - **Email Address:** `tester@e2e.com`
   - **Password:** `Password123`
   - **Confirm Password:** `Password123`
4. Click **"Create Account"**.
5. **Expected Result:** A loading spinner will appear for 1.5 seconds, and then the app will redirect you back to the `/mobile/login` page.

## Flow 2: Forgot Password (OTP) Flow

1. Navigate to `http://localhost:4200/mobile/login`.
2. Click the **"Forgot?"** link on the password field.
3. **Step 1 - Email Entry:**
   - Enter `admin@test.com` in the Email Address field.
   - Click **"Send Code"**.
   - **Expected Result:** The backend generates a 6-digit OTP, and the UI smoothly transitions to the OTP entry step.
4. **Step 2 - OTP & New Password Entry:**
   - Since email delivery is simulated locally, fetch the generated OTP from the test endpoint:
     - **Open a new tab:** `http://localhost:8080/api/v1/auth/test-otp?email=admin@test.com`
     - **Copy the `data` value** (e.g., `635104`).
   - Switch back to the UI and enter the 6-digit OTP.
   - Enter a new password (e.g., `NewPassword@123`).
   - Click **"Reset Password"**.
5. **Step 3 - Success Verification:**
   - **Expected Result:** A success screen appears with the message "Password Reset!".
   - Click **"Go to Sign In"** to return to the login page.

## Flow 3: Login Verification

1. Navigate to `http://localhost:4200/mobile/login`.
2. Enter the email address: `admin@test.com`.
3. Enter the newly created password (or the seeded `Password@123` if you skipped the reset flow).
4. Click **"Sign In"**.
5. **Expected Result:** The application should authenticate successfully and redirect to the dashboard or home view.

## Automated Testing

To automatically verify these flows, execute the Playwright End-to-End test suite:

```bash
cd frontend
npx playwright test tests/mobile-auth-flows.spec.ts
```

**Expected Console Output:**
```text
Running 2 tests using 1 worker

  ok 1 [Mobile Chrome] › tests\mobile-auth-flows.spec.ts:5:7 › Mobile Auth Flows › Signup Flow (2.6s)
  ok 2 [Mobile Chrome] › tests\mobile-auth-flows.spec.ts:26:7 › Mobile Auth Flows › Forgot Password Flow (3.1s)

  2 passed (6.2s)
```
