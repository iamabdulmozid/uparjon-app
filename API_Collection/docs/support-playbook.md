# Support Playbook

## User Cannot Login

1. Confirm user used email/mobile and correct password.
2. Check account status in admin users screen.
3. If `BAD_CREDENTIALS`, do not disclose whether the account exists.
4. If `ACCOUNT_DISABLED` or `ACCOUNT_SUSPENDED`, route to account review process.
5. If repeated failures occur, check rate limiting and auth logs with correlation ID.

## Refresh Token Fails

1. Ask user to log in again.
2. Check whether logout all or device revoke was triggered.
3. Verify device time is reasonably accurate.
4. Confirm app is sending the latest refresh token after token rotation.

## Withdrawal Pending

1. Check withdrawal status in admin withdrawals.
2. Confirm user KYC is approved.
3. Confirm wallet approved balance was locked/deducted correctly.
4. Check payment gateway transaction status.
5. If approved but unpaid, inspect queue and payment provider logs.

## Push Notifications Not Working

1. Confirm notification permission is granted on device.
2. Confirm FCM token registered via `POST /api/v1/mobile/notifications/register-token`.
3. Check notification preferences.
4. Send a test notification from admin.
5. Inspect Firebase response and invalid-token cleanup logs.

## KYC Rejected

1. Review rejection reason in admin KYC/moderation records.
2. Confirm uploaded document quality and supported file type.
3. Ask user to resubmit only through `POST /api/v1/mobile/kyc`.
4. If rejection reason is unclear, escalate to operations with user ID and correlation ID.

## Campaign Reward Missing

1. Confirm campaign completion API returned success.
2. Check reward history for pending reward.
3. Check fraud validation result.
4. Inspect reward queue/dead-letter status.
5. Refresh wallet only after reward is approved.
