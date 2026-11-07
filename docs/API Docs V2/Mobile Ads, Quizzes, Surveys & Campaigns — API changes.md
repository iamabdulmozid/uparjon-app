# Mobile: Ads, Quizzes, Surveys & Campaigns — API changes

Oct 10, 2026 · @Takbir

## Summary

The four home buttons now come from five new GET endpoints. Everything shown is a campaign item, and items are viewed and submitted with the endpoints the app already uses.

- **Ads** lists media-only items (image, GIF, video) from every live campaign.
- **Quiz** lists graded-question items from every live campaign, plus active standalone quizzes.
- **Survey** lists ungraded-question items from every live campaign, plus active standalone surveys.
- **Campaign** lists live campaigns. Tapping one shows all of its ads, quizzes and surveys together, and the user can submit each from there.

**Rule change:** a user can now complete **each item** in a campaign once. Before, they could complete only one item per campaign. The campaign's participant target still counts people, not submissions.

All endpoints need the logged-in user's `Authorization: Bearer <accessToken>` header. They return the usual `{ success, message, data }` envelope.

## Screens and endpoints

Each button's list page uses one GET endpoint. Tapping an item opens the item detail; submitting uses the existing view and submit endpoints (see Submit flows).

| Screen | Endpoint | Returns | New? |
| --- | --- | --- | --- |
| Ads button | `GET /api/v1/mobile/content/ads?mediaType=&page=&size=` | Page of items, `kind = AD` | New |
| Quiz button | `GET /api/v1/mobile/content/quizzes?page=&size=` | Page of items, `kind = QUIZ` | New |
| Survey button | `GET /api/v1/mobile/content/surveys?page=&size=` | Page of items, `kind = SURVEY` | New |
| Campaign button | `GET /api/v1/mobile/campaigns?page=&size=` | Page of campaign cards | Existing, unchanged |
| Campaign screen (after tapping a campaign) | `GET /api/v1/mobile/campaigns/{campaignId}/items` | Campaign + `ads[]`, `quizzes[]`, `surveys[]` | New |
| Item detail / answer screen | `GET /api/v1/mobile/content/{itemId}` | Item + its questions (no correct answers) | New |
| View media (every item) | `POST /api/v1/mobile/ads/{itemId}/view` | View result | Existing |
| Submit a quiz | `POST /api/v1/quizzes/submit` | Score and reward | Existing |
| Submit a survey | `POST /api/v1/surveys/submit` | Reward | Existing |

`itemId` is the same id on every screen. The same quiz shows under the Quiz button and inside its campaign, and completing it in one place shows it completed in both.

## The item object

The Ads, Quiz and Survey lists and the campaign screen all return the same item object. Use `kind` to choose the card and the flow.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | UUID | Item id. Use it for detail, view and submit. |
| `kind` | `AD` \| `QUIZ` \| `SURVEY` | AD = media only, paid when viewed. QUIZ = graded questions. SURVEY = questions that are never graded. |
| `title`, `description` | string | Item text. |
| `mediaType` | `IMAGE` \| `GIF` \| `VIDEO` \| null | Type of `mediaUrl`. A quiz or survey may show media before its questions. |
| `mediaUrl` | string \| null | Media to show or play. |
| `thumbnailUrl` | string \| null | Card image. Falls back to the campaign banner. |
| `durationSeconds` | int | Media length. The view counts after 80% of it. |
| `reward` | decimal | Reward in BDT. When `paysPerQuestion` is true, this is the most a user can earn. |
| `paysPerQuestion` | bool | True when each question pays its own amount. |
| `questionCount` | int | Number of questions. 0 for AD. |
| `passingScore` | int \| null | QUIZ only: the % of correct answers needed to be paid. Null means 100. |
| `progress` | `NOT_STARTED` \| `ANSWERS_PENDING` \| `COMPLETED` | The user's progress. ANSWERS\_PENDING = media viewed, answers not sent yet. |
| `available` | bool | True when the user can do it now. |
| `unavailableCode`, `unavailableMessage` | string \| null | Why it is not available. The message is safe to show to users. |
| `campaignId`, `campaignTitle`, `campaignBannerUrl` |  | The campaign the item belongs to. |
| `campaignEndAt` | ISO local date-time \| null | When the campaign ends. Null means no end date. |
| source | CAMPAIGN \| STANDALONE | Which endpoints open and submit the item. STANDALONE = a quiz or survey that belongs to no campaign; its campaign fields are null and it has no media. |

**How to show the state:**

- `COMPLETED`: show a done badge; disable the action.
- `ANSWERS_PENDING`: open straight to the questions; skip the media (the view is already counted).
- `NOT_STARTED` + `available: true`: show the normal action button.
- `available: false`: grey the card out and show `unavailableMessage`.

The Ads, Quiz and Survey lists include only items the user can do now, plus items they have already started or finished. The campaign screen shows every item in the campaign, including unavailable ones.

## Endpoint reference

The list endpoints are paged: `page` starts at 0, `size` defaults to 20 and is capped at 100. Items come newest first.

### GET /api/v1/mobile/content/ads

Optional `mediaType` = `IMAGE`, `GIF` or `VIDEO` filters the list for tabs inside the Ads screen. Leave it out, or send `ALL`, to get every type. Any other value returns 400.

```json
{
  "success": true,
  "message": "Ads retrieved",
  "data": {
    "content": [
      {
        "id": "9b1c…",
        "kind": "AD",
        "title": "New rice cooker",
        "description": null,
        "mediaType": "VIDEO",
        "mediaUrl": "https://cdn…/promo.mp4",
        "thumbnailUrl": "https://cdn…/thumb.png",
        "durationSeconds": 30,
        "reward": 2.00,
        "paysPerQuestion": false,
        "questionCount": 0,
        "passingScore": null,
        "progress": "NOT_STARTED",
        "available": true,
        "unavailableCode": null,
        "unavailableMessage": null,
        "campaignId": "4e7a…",
        "campaignTitle": "Kitchen week",
        "campaignBannerUrl": "https://cdn…/banner.png",
        "campaignEndAt": "2026-10-31T23:59:00"
      }
    ],
    "totalElements": 1,
    "totalPages": 1,
    "number": 0,
    "size": 20,
    "first": true,
    "last": true,
    "empty": false
  },
  "timestamp": "2026-10-10T12:00:00"
}
```

### GET /api/v1/mobile/content/quizzes and /content/surveys

Same page shape as Ads, with `kind` = `QUIZ` or `SURVEY`. No `mediaType` filter.

### GET /api/v1/mobile/campaigns (existing)

No change. It returns the campaign cards (`id`, `title`, `thumbnailUrl`, `bannerUrl`, `rewardAmount`, `status`, `startAt`, `endAt`, `contentType` …). Use a card's `id` to open the campaign screen.

### GET /api/v1/mobile/campaigns/{campaignId}/items

The campaign screen. It returns every active item in the campaign, grouped by kind, with the user's progress on each. It returns 404 when the campaign is not live, unless the user has already taken part in it.

```json
{
  "success": true,
  "message": "Campaign items retrieved",
  "data": {
    "id": "4e7a…",
    "title": "Kitchen week",
    "description": "…",
    "bannerUrl": "https://cdn…/banner.png",
    "bannerType": "IMAGE",
    "campaignType": "PRODUCT_LAUNCH",
    "campaignTypeLabel": "Product launch",
    "contentType": "QUIZ",
    "contentTypeLabel": "Quiz",
    "startAt": "2026-10-01T00:00:00",
    "endAt": "2026-10-31T23:59:00",
    "totalItems": 3,
    "completedItems": 1,
    "ads":     [ { "id": "9b1c…", "kind": "AD",     "progress": "NOT_STARTED", "available": true,  … } ],
    "quizzes": [ { "id": "a2d4…", "kind": "QUIZ",   "progress": "COMPLETED",   "available": false, "unavailableCode": "DUPLICATE_PARTICIPATION", … } ],
    "surveys": [ { "id": "c7f0…", "kind": "SURVEY", "progress": "NOT_STARTED", "available": true,  … } ]
  }
}
```

Show `completedItems` / `totalItems` as campaign progress (for example "1 of 3 done"). An empty group is `[]`, never null.

### GET /api/v1/mobile/content/{itemId}

The answer screen. It returns `item` (the same item object) plus `questions`. Correct answers are never sent.

```json
{
  "success": true,
  "message": "Item retrieved",
  "data": {
    "item": { "id": "a2d4…", "kind": "QUIZ", "mediaType": "IMAGE", "mediaUrl": "…", "questionCount": 2, … },
    "questions": [
      {
        "id": "q1…",
        "questionText": "What colour is the logo?",
        "questionType": "SINGLE_CHOICE",
        "isRequired": true,
        "orderIndex": 0,
        "options": [ { "id": "o1…", "optionText": "Red" }, { "id": "o2…", "optionText": "Blue" } ],
        "rewardAmount": 4.00,
        "mediaUrl": null
      }
    ]
  }
}
```

`questionType` is `SINGLE_CHOICE`, `MULTIPLE_CHOICE`, `TEXT`, `RATING` (use `minVal`/`maxVal`) or `BOOLEAN`. A question can have its own `mediaUrl` and `mediaType`. Null fields are left out of the question object.

## Submit flows

Every item starts with a view. A plain AD pays when the view is recorded. A QUIZ or SURVEY pays only after its answers are submitted. The flow is the same from the Ads/Quiz/Survey buttons and from the campaign screen.

&#91;embedded content: submit flow · one view, then answers for quizzes and surveys\]

### Step 1 — record the view (all kinds)

`POST /api/v1/mobile/ads/{itemId}/view`

```json
{ "watchedDurationSeconds": 30, "deviceId": "<stable device id>" }
```

- `watchedDurationSeconds` must be at least 80% of the item's `durationSeconds`, or the call fails. For an image, keep it on screen for that long before calling.
- If the item has no media, send its `durationSeconds` once the user opens it.
- **This response is not wrapped** in `{success, data}`; it is the view object itself:

```json
{ "id": "view-id", "adId": "9b1c…", "status": "REWARDED", "rewardEarned": 2.00, "questionMode": null, "awaitingAnswers": false, … }
```

- **AD:** `status` = `REWARDED` and the flow ends here. Refresh the wallet.
- **QUIZ / SURVEY:** `status` = `COMPLETED` and `awaitingAnswers` = true. Go to step 2. If the item is `ANSWERS_PENDING`, calling view again is safe: it returns the existing view.

### Step 2 — submit answers (QUIZ and SURVEY)

`POST /api/v1/quizzes/submit` for a quiz, `POST /api/v1/surveys/submit` for a survey. The body is the same for both:

```json
{
  "adId": "a2d4…",
  "answers": [
    { "questionId": "q1…", "optionId": "o2…" },
    { "questionId": "q2…", "answerText": "Very easy to use" }
  ]
}
```

- `adId` is the item `id`.
- Every question must be answered, once each. Choice questions send `optionId`; TEXT and RATING send `answerText` (for a rating, the number as text).
- **This response is not wrapped either:**

```json
{
  "passed": true,
  "score": 2,
  "wrongAnswers": 0,
  "totalQuestions": 2,
  "rewardTriggered": true,
  "rewardEarned": 4.00,
  "cashbackPromised": 0,
  "participationReference": "CP-…",
  "questionMode": "QUIZ",
  "paysPerQuestion": false
}
```

- When `paysPerQuestion` is true, `results[]` lists each question's `correct`, `rewardEarned` and `cashbackPromised`.
- When `cashbackPromised` is above 0, `cashback[]` lists the purchase cashback the user can still earn, with `purchaseDeadline`.
- **One submission per item.** A failed quiz still counts as done: it moves to `COMPLETED` with no reward and cannot be retried. The user can still do the campaign's other items.

### After a submit

Re-fetch the list or campaign screen the user came from so `progress` and `available` update, then refresh the wallet.

### Standalone quizzes and surveys (`source = STANDALONE`)

These have no media and no view step. They use the older endpoints:

| Step | Quiz | Survey |
| --- | --- | --- |
| Open (questions) | `GET /api/v1/mobile/quizzes/{id}` | `GET /api/v1/mobile/surveys/{id}` (holds a slot for the user) |
| Keep the slot | — | `POST /api/v1/mobile/surveys/{id}/heartbeat` while the screen is open |
| Leave without submitting | — | `POST /api/v1/mobile/surveys/{id}/discard` |
| Submit | `POST /api/v1/mobile/quizzes/{id}/submit` with `{ "answers": [{ "questionId", "optionId" }] }` | `POST /api/v1/mobile/surveys/{id}/submit` |

A standalone quiz pays when at least 60% of answers are correct, and each can be submitted once. These responses are not wrapped in `{success, data}`.

## Errors

Errors come back as `{ "success": false, "errorCode": "…", "message": "…", "timestamp": "…" }`. Branch on `errorCode`. The message is safe to show to users. The same codes appear in `unavailableCode` on items.

| errorCode | HTTP | When | App action |
| --- | --- | --- | --- |
| `DUPLICATE_PARTICIPATION` | 409 | The user already completed this item | Mark the item done; re-fetch |
| `ALREADY_CLAIMED` | 409 | The ad already paid this user | Mark the item done; re-fetch |
| `PARTICIPANT_TARGET_REACHED` | 409 | The campaign is full (users already in it can still finish their items) | Show the message; disable the item |
| `CAMPAIGN_BUDGET_EXHAUSTED` | 409 | The campaign's budget ran out | Show the message; disable the item |
| `CAMPAIGN_ENDED`, `CAMPAIGN_NOT_STARTED`, `CAMPAIGN_INACTIVE` | 409 | The campaign is not running now | Show the message; re-fetch the list |
| `NOT_IN_TARGET_AUDIENCE` | 403 | The user's profile is outside the campaign's audience | Hide or disable the item |
| `PRODUCT_INELIGIBLE` | 409 | The cashback product is no longer available | Show the message |
| `INVALID_ANSWER` | 400 | A question is missing, repeated, or has an invalid option or rating | Highlight the question; let the user fix it |
| `VALIDATION_ERROR` | 400 | Bad request body (for example, no answers) | Fix the request |
| `INVALID_ARGUMENT` | 400 | Unknown item id on submit, or a bad `mediaType` | Fix the request |
| `ILLEGAL_STATE` | 500 | Watched too little of the media, submitted before viewing, or hit the daily limit of 100 views | Show the message; let the user watch again |
| `NOT_FOUND` | 404 | The campaign or item is not live and the user never took part | Remove it from the list |
| SURVEY\_FULL | — | Only in unavailableCode: a standalone survey has no free slot right now | Disable the item; re-fetch later |

`ILLEGAL_STATE` is returned as 500 today even though it is a user error. Don't treat it as a server crash: show the message.

## Notes and edge cases

- **Old endpoints.** `GET /api/v1/mobile/ads/feed`, `/mobile/quizzes` and `/mobile/surveys` still work. Note that `/mobile/quizzes` and `/mobile/surveys` serve the older standalone quizzes and surveys, which do not belong to campaigns. The Quiz and Survey lists now include them (`source = STANDALONE`), so the app needs no separate screen. The four buttons should use the new `/mobile/content/*` endpoints.
- **One item, many places.** A quiz appears under the Quiz button and inside its campaign. Both use the same `id`, so cache by item `id`.
- **Media with questions.** A quiz or survey can have `mediaType`/`mediaUrl`. Show the media first, record the view, then show the questions.
- **Campaign fills up.** If the campaign reaches its participant target, it closes for new users. Users who already completed one item can still do the rest while the campaign stays live. When the last slot is taken, the campaign may complete and close its remaining items. Those items return `available: false` with a code.
- **Refresh.** These lists are not cached on the server. Re-fetch on pull-to-refresh, after every submit, and when the user returns to a screen.
- **Testing.** Log in as `user@test.com` / `01700000001` on the dev server. An admin must create a campaign with at least one plain ad, one quiz and one survey, and take it live.
- **Ids in this doc** (`9b1c…`, `a2d4…`) are placeholders. Real ids are full UUIDs.
