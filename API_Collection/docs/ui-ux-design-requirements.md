# UI/UX Design Requirements & Interface Blueprint

This document is specifically crafted for the UI/UX Design team. It outlines every screen, interaction, and data point that has been implemented in the backend and frontend code to date. This ensures the UI designs match 1-to-1 with the actual system capabilities.

## 1. Global App Components
Before designing individual screens, establish the following global components:
* **Bottom Navigation Bar**: Should contain links to Home, Campaigns/Ads, Wallet, and Profile.
* **Top App Bar**: Standard header containing page titles, a back button (when deep in a stack), and a notification bell icon (with unread badge).
* **Loading States**: Skeletons or spinners for asynchronous data fetching.
* **Alerts/Toasts**: Success and error message components (e.g., "Password Reset!", "Invalid Credentials").

---

## 2. Authentication & Onboarding
*Note: We have transitioned to a 6-digit OTP flow for password resets instead of email links.*

### 2.1 Login Screen
* **Inputs**: Email or Mobile Number, Password.
* **Actions**: "Sign In" button, "Forgot Password?" link, "Create Account" link.

### 2.2 Registration / Signup Screen
* **Inputs**: Full Name, Mobile Number, Email Address, Password, Confirm Password, Referral Code (Optional).
* **Actions**: "Create Account" button.

### 2.3 Forgot Password Flow (3-Step Dynamic Flow)
* **Step 1 (Request)**: Input field for Email Address. "Send OTP" button.
* **Step 2 (Verify & Reset)**: Input field for 6-digit OTP, Input field for New Password. "Reset Password" button.
* **Step 3 (Success)**: Success illustration/icon, "Password Reset!" text, "Back to Login" button.

---

## 3. Core Features & Feeds

### 3.1 Home Feed / Dashboard
* **Widgets/Components**: 
  - User greeting and quick stats (Available Balance).
  - Daily Tasks summary (e.g., "2/5 completed today").
  - Shortcuts to Quizzes, Surveys, and Featured Campaigns.

### 3.2 Campaigns Feed & Details
* **List View**: Cards showing Campaign Title, Reward amount, Banner Image, and Status. Tabs for "Featured", "Trending", "All".
* **Detail View**: Full description, requirements, start button, and progress tracker.

### 3.3 Ads Feed
* **List View**: A scrolling feed of video or banner ads.
* **Interactions**: Tapping an ad starts a viewing session. Requires a timer UI showing how long the user must watch to earn the reward.

### 3.4 Quizzes & Surveys
* **List View**: Available quizzes/surveys with estimated time and reward value.
* **Execution View**: Multiple-choice question interface, progress bar (e.g., Question 2 of 10), and a "Submit" button.

---

## 4. Wallet & Financials

### 4.1 Wallet Overview
* **Data Display**: Available Balance, Pending Balance, Lifetime Earnings.
* **Actions**: "Withdraw Funds" button, "View Transactions" button.
* **Charts (Optional)**: Earning insights over the last 7/30 days.

### 4.2 Transaction History
* **List View**: Chronological list of earnings and withdrawals. Each row should show Date, Amount (Green for positive, Red for negative), Type (Ad View, Quiz, Withdrawal), and Status.

### 4.3 Withdrawals & Payment Methods
* **Withdrawal Screen**: Input for amount, dropdown/selector for Payment Method (e.g., bKash, SSLCommerz).
* **Payment Methods Management**: List of saved accounts, button to "Add New Account".

---

## 5. Profile & Settings

### 5.1 Profile Dashboard
* **Header**: User Avatar, Full Name, Email/Mobile. Badges for "KYC Approved" or "Email Verified".
* **Stats Row**: Total Campaigns Completed, Total Quizzes Taken, Lifetime Earnings.
* **Menu List**: Links to Edit Profile, Security, KYC, Notifications, Referrals, App Settings.

### 5.2 Edit Profile & KYC
* **Edit Profile**: Avatar upload interface, editable fields for Name and Contact info.
* **KYC Screen**: Interface to upload ID documents (Front/Back) and input ID number. Status indicator (Pending, Approved, Rejected).

### 5.3 Security & Devices
* **Change Password**: Fields for Current Password, New Password, Confirm New Password.
* **Device Sessions**: List of currently logged-in devices (Device Name, Platform, Last Active Date). Action to "Logout" specific devices or "Logout All Devices".

### 5.4 Referrals
* **Share Screen**: Display user's unique referral code and a "Copy Link" / "Share" native button.
* **History**: List of users who joined using the referral code and the rewards earned from them.

---

## 6. Admin Portal (Web UI)
*For the internal administration team managing the platform.*

* **Admin Login**: Standard email/password login.
* **Dashboard Layout**: Left-side navigation sidebar, top header with admin profile.
* **Data Tables**: Standardized table designs with pagination, search, and filtering for managing Users, Campaigns, Transactions, and KYC Approvals.
