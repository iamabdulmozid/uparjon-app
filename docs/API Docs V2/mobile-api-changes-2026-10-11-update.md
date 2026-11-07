# Mobile API changes: update (2026-10-11, afternoon)

This follows `mobile-api-changes-2026-10-11.md`. Two PRs were merged since then. **Neither requires an app change.** The second changes what happens on the server when a user answers some questions, so it is worth knowing about.

## PR #28: store check on cashback product links (no mobile impact)

The advertiser's campaign form now checks a cashback product link against the store while it is being typed, and shows the product title or why the link was refused. This is portal-only. The mobile cashback fields (`rewardMode`, `productUrl`, `productId`, `purchaseWindowDays`) and the cashback endpoints are unchanged.

## PR #29: answers can fill in the user's zone, area and interests

An advertiser can now link a choice question to part of the user's profile. Each option stands for one **zone** (division), **area** (district) or **interest**. When a user completes a campaign item, the options they picked update their profile:

- **Zone**: the latest answer replaces the user's zone. Their area is cleared if it lies in a different zone.
- **Area**: the latest answer replaces the user's area and sets its zone.
- **Interest**: the answer is added to the user's interests. Nothing is removed.

Campaign audience targeting reads these fields. A user who answers such a question can therefore start seeing campaigns aimed at that zone, area or interest, and stop seeing ones aimed elsewhere.

**What the app sees and sends:** nothing new.

- The new fields (`profileField` on the question, `profileValueId` on each option) are **hidden from mobile responses**. The app sees an ordinary choice question.
- Answer it as usual with `optionId` in `POST /api/v1/quizzes/submit` or `/api/v1/surveys/submit`. The submit response is unchanged.
- After such a submission, lists like `/mobile/campaigns`, `/mobile/content/...` and the home feed can change for that user. Refresh them after a submit rather than relying on a cached list.

This partly closes the earlier open question about targeting fields. The app still can't set zone, area or interests directly (`PUT /api/v1/mobile/profile` is unchanged), but users now get them by answering campaign questions.

The other two open questions in the earlier doc still stand: a too-early view completion returns 500 `ILLEGAL_STATE`, and images under `/api/...` probably need the bearer token.
