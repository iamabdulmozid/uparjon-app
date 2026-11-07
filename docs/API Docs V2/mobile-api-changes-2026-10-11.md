# Mobile API changes: handoff (2026-10-11)

What the mobile app needs to know from the backend changes merged on 9–10 October 2026: PR #26 (content types, live-only data), PR #27 (question rewards, purchase cashback, targeting, lifecycle) and the commits that followed on `master` (campaign content tabs, standalone quizzes/surveys in those tabs, the earn-to-withdraw flow, support tickets).

Auth is unchanged: `Authorization: Bearer <accessToken>`. Most endpoints wrap data in `{ success, message, data }`; errors come back as `{ success: false, errorCode, message, timestamp }`. **Branch on `errorCode`, not on `message`.** The message is safe to show to the user.

---

## 1. Must change (behaviour that breaks the current app)

| # | What changed | What the app must do |
|---|---|---|
| 1 | **`POST /api/v1/mobile/ads/{id}/view` is now two calls.** The first call only *starts* the view and returns it with `status: "STARTED"` (nothing is paid). A second call after the ad has been watched completes it and pays (or sets `awaitingAnswers: true` for ads with questions). | Call it once when the media starts, then again with `watchedDurationSeconds` when it ends. Do not treat the first response as a reward. |
| 2 | **Real elapsed time is checked.** The server requires 80% of the ad's `durationSeconds` (minus a 2 s grace) to have actually passed between the two calls, and the reported `watchedDurationSeconds` must also reach 80%. | Don't send the completion early. If it is too early the server answers **HTTP 500, `errorCode: "ILLEGAL_STATE"`**, message `Insufficient watch duration...`; the view stays started (inferred from the transaction rolling back), so wait and call again. |
| 3 | **Every question must be answered.** `POST /api/v1/quizzes/submit` and `/api/v1/surveys/submit` refuse a submission that misses a question, answers one twice, or includes a question not in the ad: **HTTP 400 `INVALID_ANSWER`**. | Send exactly one answer per question. Don't offer "skip". |
| 4 | **Answers are validated by format.** `TEXT` needs non-empty text (max 2000 chars); `RATING` needs an option or a number between `minVal` and `maxVal` (default 1–5) in `textAnswer`; choice questions need an `optionId` from that question. Otherwise **400 `INVALID_ANSWER`**. | Validate the same way client-side before submitting. |
| 5 | **Only live campaigns reach the app** (from #26). A campaign shows up only after admin approval, payment and final approval. `GET /mobile/campaigns/{id}` returns **404** for one that is not live, unless the user already took part. | Treat 404 on a campaign as "no longer available". |
| 6 | **Feeds and lists are now filtered per user** by campaign rules (audience, participant target, budget, cashback product, already taken part). Items the user already completed stay listed. | Don't assume a campaign seen yesterday is still listed; handle it disappearing. |

---

## 2. New endpoints

### Campaign content tabs (Ads / Quizzes / Surveys)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/mobile/content/ads?mediaType=IMAGE\|GIF\|VIDEO&page&size` | Plain media ads (no questions) from all live campaigns, newest first |
| GET | `/api/v1/mobile/content/quizzes?page&size` | Quizzes (graded). Also includes **standalone** quizzes that belong to no campaign |
| GET | `/api/v1/mobile/content/surveys?page&size` | Surveys (never graded). Also includes **standalone** surveys |
| GET | `/api/v1/mobile/content/{id}` | One campaign item with its media and questions (never the correct answers) |
| GET | `/api/v1/mobile/campaigns/{id}/items` | A live campaign with all its ads, quizzes and surveys, each with the user's progress |

Lists are pages (`content`, `totalElements`, ...), `size` max 100. Items the user can't do and hasn't started are hidden.

**Item (`MobileContentItemDto`)**

| Field | Notes |
|---|---|
| `id` | For `source: CAMPAIGN` this is the **ad id**: view it with `POST /mobile/ads/{id}/view`, answer with `/quizzes/submit` or `/surveys/submit` |
| `source` | `CAMPAIGN` or `STANDALONE`. Standalone items open and submit through the existing `/api/v1/mobile/quizzes/{id}` and `/api/v1/mobile/surveys/{id}`; their campaign fields are null |
| `kind` | `AD` (media only, paid on view), `QUIZ`, `SURVEY` |
| `title`, `description`, `mediaType`, `mediaUrl`, `thumbnailUrl` | `mediaType` is `IMAGE`, `GIF`, `VIDEO` or null |
| `durationSeconds` | Media must be shown for 80% of this before the view counts |
| `reward`, `paysPerQuestion` | When `paysPerQuestion` is true, `reward` is the most one user can earn |
| `questionCount`, `passingScore` | `passingScore` null means 100 |
| `progress` | `NOT_STARTED`, `ANSWERS_PENDING` (viewed, answers not sent), `COMPLETED` |
| `available`, `unavailableCode`, `unavailableMessage` | Why not, e.g. `DUPLICATE_PARTICIPATION`, `CAMPAIGN_BUDGET_EXHAUSTED`; standalone surveys can return `SURVEY_FULL` |
| `campaignId`, `campaignTitle`, `campaignBannerUrl`, `campaignEndAt` | Null for standalone |

`/campaigns/{id}/items` returns the campaign header (`title`, `description`, `bannerUrl`, `bannerType`, `campaignType(+Label)`, `contentType(+Label)`, `startAt`, `endAt`), `totalItems`, `completedItems`, and `ads`, `quizzes`, `surveys` lists of the item above.

A user can complete **each item** of a campaign once (it used to be once per campaign). The participant target still counts people, not items.

### Participation and purchase cashback

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/mobile/campaigns/{id}/availability` | Can the user take part right now? `{ campaignId, available, code, message }` |
| GET | `/api/v1/mobile/campaigns/participations?page&size` | The user's participations, newest first |
| GET | `/api/v1/mobile/campaigns/cashback?filter=pending\|settled\|all&page&size` | The user's purchase cashback |
| POST | `/api/v1/mobile/campaigns/cashback/check` | Re-check the user's open cashback against their store orders now; returns how many were checked (it also runs automatically every few minutes) |

**Participation**: `id`, `reference`, `campaignId`, `campaignTitle`, `adId`, `status` (`ACCEPTED`, `REWARDED`, `NOT_REWARDED`), `submittedAt`, `answerRewardTotal`, `cashbackPromisedTotal`.

**Cashback**: `id`, `campaignId`, `campaignTitle`, `questionId`, `productId`, `productUrl`, `amount`, `status`, `eligibleFrom`, `purchaseDeadline`, `orderNumber`, `purchasedAt`, `deliveredObservedAt`, `settledAt`, `releasedAt`, `reason`, plus internal fields (`attempts`, `lastError`, `lastCheckedAt`, `stuck`) the app can ignore.

Cashback `status` values:

| Status | Show the user |
|---|---|
| `AWAITING_PURCHASE` | Buy the product from the store before `purchaseDeadline` |
| `PURCHASE_PENDING` | Order found; paid after delivery and the return window |
| `SETTLED` | Paid to your wallet |
| `EXPIRED` | No purchase before the deadline |
| `CANCELED` | Order cancelled or refunded, or cancelled by support |
| `REVERSED` | Order refunded after payment; cashback taken back |
| `REVERSAL_PENDING` | Same as reversed, waiting for support (balance too low) |

### Withdrawals (earn to cash out)

| Method | Path | Body / notes |
|---|---|---|
| GET | `/api/v1/withdrawal-methods` | Available methods: `BKASH`, `NAGAD`, `ROCKET` (min 50, max 25,000 BDT) and `BANK` (min 500, max 50,000 BDT); no fee at seed |
| GET | `/api/v1/mobile/withdrawals/accounts` | The user's payout accounts: `id`, `methodCode`, `accountName`, `accountNumber`, `verified`, `defaultAccount`, `createdAt` |
| POST | `/api/v1/mobile/withdrawals/accounts` | `{ methodCode, accountNumber, accountName? }`. Returns 201. The first account becomes the default |
| GET | `/api/v1/mobile/withdrawals?page&size` | The user's withdrawals, newest first |
| POST | `/api/v1/mobile/withdrawals` | `{ amount, accountId? }`; without `accountId` the default account is used. Returns 201. The amount is locked in the balance |
| POST | `/api/v1/mobile/withdrawals/{id}/cancel` | Only while `PENDING_APPROVAL`; the amount goes back to the balance |

Withdrawal `status`: `PENDING_APPROVAL`, `APPROVED`, `PROCESSING`, `COMPLETED`, `REJECTED`, `CANCELLED`, `FAILED` (on reject, cancel and fail the amount returns to the balance). New response fields: `methodCode`, `accountNumber`, `accountVerified`, `adminRemarks` (rejection reason), `payoutReference` (transfer ref once paid), `reviewedAt`.

Rules the app should mirror (errors come back as **400 `BUSINESS_ERROR`** with a readable message): bKash/Nagad/Rocket numbers must be valid mobile numbers; bank numbers 6–34 letters, digits, spaces or dashes; at most 5 payout accounts; no duplicates; an account with a withdrawal in flight (or past withdrawals) can't be removed; amount has at most 2 decimals and must be within the method's min/max, the daily and monthly limits, and the available balance (`Insufficient balance: you can withdraw up to X`). With no payout account and no `accountId`: `Add a payout account first`.

Withdrawals now draw from the **earnings wallet the user is paid into** (before this, every withdrawal failed against an empty wallet).

### Support tickets

Users can now use their own tickets (these endpoints return the object directly, without the `{ success, data }` wrapper):

| Method | Path | Notes |
|---|---|---|
| POST | `/api/v1/support/tickets?userId&subject&message` | `userId` must be the signed-in user's own id, otherwise 403 |
| GET | `/api/v1/support/tickets/mine` | The user's tickets |
| GET | `/api/v1/support/tickets/{ref}/messages` | Only the ticket's owner |
| POST | `/api/v1/support/tickets/{ref}/messages?senderUserId&message&attachmentFileId?` | `senderUserId` must be the user's own id |

---

## 3. Changed responses (additive)

### Campaign details and question fields

`GET /api/v1/mobile/campaigns/{id}` (`questions[]`) and `GET /api/v1/mobile/content/{id}` (`questions[]`) carry these new question fields:

| Field | Meaning |
|---|---|
| `questionKind` | `SURVEY`, `QUIZ` or `MEDIA`: what the question is. `questionType` is still the answer format (`SINGLE_CHOICE`, `MULTIPLE_CHOICE`, `TEXT`, `RATING`, `BOOLEAN`) |
| `rewardMode` | `ANSWER_REWARD` (paid when answered) or `PURCHASE_CASHBACK` (paid after the user buys a product) |
| `rewardAmount` | BDT for this question |
| `rewardOnIncorrectAnswer` | Graded questions pay even for a wrong answer (replaces the old `wrongAnswerReward`) |
| `productUrl`, `productId`, `purchaseWindowDays` | Cashback questions only: the store product to buy, and how many days after answering the purchase must be placed |

For a `PURCHASE_CASHBACK` question, show the product link and "buy within N days to get X BDT cashback". Old questions without these fields keep working as before. All questions are now mandatory (`isRequired` is effectively always true).

`endAt` on campaigns can now be **null** (no end date).

### Quiz / survey submit response

`POST /api/v1/quizzes/submit` and `/api/v1/surveys/submit` add:

| Field | Meaning |
|---|---|
| `cashbackPromised` | Total cashback promised by this submission (paid later, not now) |
| `participationId`, `participationReference` | The participation created (campaign ads only) |
| `cashback[]` | `{ cashbackId, questionId, productId, amount, status, purchaseDeadline }` per promised cashback |
| `results[].questionType`, `results[].rewardType`, `results[].cashbackPromised` | Per-question breakdown (when `paysPerQuestion`) |

`rewardEarned` is only what was paid to the wallet now. A submission that earns only cashback still returns `passed: true` with `rewardEarned: 0` and a positive `cashbackPromised`. Say "X BDT cashback after you buy", not "you earned X".

### Earlier in #26 (already in `docs/mobile-api-changes-2026-10-09.md` in the repo)

- New `GET /api/v1/mobile/campaigns/categories`: every content type with a live count, always all five (`SURVEY`, `QUIZ`, `VIDEO`, `IMAGE`, `OTHER`).
- `contentType` and `contentTypeLabel` on `/mobile/campaigns` items, `/featured`, `/trending`, `/{id}`, home-feed campaign cards and `/mobile/ads/feed`; `GET /mobile/campaigns?contentType=SURVEY` filters by it.
- `GET /mobile/home-feed` adds `contentCategories`.

### Wallet transaction types

Wallet history can now show `CAMPAIGN_CASHBACK` (cashback paid) and `CAMPAIGN_CASHBACK_REVERSAL` (taken back after a refund). Give them labels. (`CAMPAIGN_FUNDING` and `CAMPAIGN_REFUND` are advertiser-side.)

---

## 4. Eligibility and error codes

When the user can't take part, start a view or submit answers, the server returns one of these `errorCode`s (also returned as `code` by `/availability` and `unavailableCode` on items):

| errorCode | HTTP | Meaning |
|---|---|---|
| `CAMPAIGN_NOT_STARTED` | 409 | Scheduled, start time not reached |
| `CAMPAIGN_ENDED` | 409 | End date passed |
| `CAMPAIGN_INACTIVE` | 409 | Paused, cancelled or otherwise not live |
| `CAMPAIGN_BUDGET_EXHAUSTED` | 409 | No budget left for a full reward |
| `PARTICIPANT_TARGET_REACHED` | 409 | All participant slots taken |
| `PRODUCT_INELIGIBLE` | 409 | Cashback product no longer sold |
| `NOT_IN_TARGET_AUDIENCE` | 403 | User's area or interests don't match |
| `DUPLICATE_PARTICIPATION` | 409 | Already took part in this item |
| `INVALID_ANSWER` | 400 | See section 1 |
| `ALREADY_CLAIMED` | unchanged | User already rewarded for this ad (still returned first, as before) |

Campaign states the app may meet: `SCHEDULED` (approved and paid, waiting for its start time), `ACTIVE`, `PAUSED`, `COMPLETED`. Only `ACTIVE` campaigns are listed.

**Audience targeting** matches the user's profile `division`, `district` and `interests`. A user without those values does not match a campaign that targets them. `PUT /api/v1/mobile/profile` currently accepts only `firstName`, `lastName`, `email`, `countryCode`, `phone`, so the app can't set them yet (see open questions).

---

## 5. Payout behaviour summary

- **Plain media ad**: paid on the second `/view` call, once per user per ad, recorded under a campaign lock so parallel taps can't pay twice.
- **Ad with questions**: the view completes with `awaitingAnswers: true`; payment comes from the submit call.
- **Answer reward**: paid to the wallet immediately on submit, computed on the server only from the stored question. Client-sent amounts are ignored.
- **Purchase cashback**: reserved on submit. The user must buy that product **from the platform store with the same account** within `purchaseWindowDays`. It is paid after delivery plus the store's return window, and taken back if the order is later refunded.
- **Campaign session** (`/mobile/campaigns/{id}/start` + `/complete`): no longer pays a campaign whose ad has questions unless the answers were submitted.

---

## 6. Open questions for the backend (not yet handled)

1. **Profile targeting fields**: there is no mobile endpoint to set `division`, `district` or `interests`. *Update: since PR #29, users get these by answering campaign questions linked to the profile; see `mobile-api-changes-2026-10-11-update.md`.*
2. **"Too early" view completion returns 500** (`ILLEGAL_STATE`) instead of a 4xx business code. The app has to special-case it for now.
3. **Images under `/api/...`**: the admin portal had to start sending the bearer token to load campaign banners. If a `bannerUrl`, `mediaUrl` or `thumbnailUrl` is a relative `/api/...` path, load it with the `Authorization` header (inferred from the portal fix; not checked against the mobile file endpoint).
