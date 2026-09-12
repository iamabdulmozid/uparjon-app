# Deep Link Guide

Notification payloads may include a `deepLink` value. Flutter should parse it and route to the target screen after authentication.

Examples:

| Deep Link | Target |
| --- | --- |
| `campaign://123` | Campaign details for campaign `123` |
| `reward://456` | Reward history/details entry `456` |
| `withdrawal://789` | Withdrawal details/status for withdrawal `789` |
| `notification://42` | Notification details `42` |
| `wallet://overview` | Wallet overview |
| `kyc://status` | KYC status screen |

Routing flow:

```text
Notification tap
  -> parse deepLink
  -> ensure auth session
  -> refresh target resource
  -> navigate target screen
```

Rules:

- If logged out, store the pending link, complete login, then route.
- If the target API returns `NOT_FOUND`, show a removed/expired state.
- If the target API returns `KYC_REQUIRED`, route to KYC.
- Do not trust deep link data as complete screen data; always fetch the resource by API.
