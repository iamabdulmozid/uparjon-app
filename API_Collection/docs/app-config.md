# App Config Guide

Startup endpoint:

```text
GET /api/v1/mobile/app-config
```

Flutter should call this before loading authenticated screens.

Expected behavior:

| Field | Flutter Behavior |
| --- | --- |
| `maintenanceMode` | Show maintenance screen and block normal navigation. |
| `forceUpdate` | Show mandatory update screen and link to app store. |
| `minimumSupportedVersion` | Compare with installed app version. |
| `latestVersion` | Show optional update prompt when newer. |
| `featureFlags` | Enable/disable feature entry points. |
| `supportUrl` / support fields | Use on error, disabled account, and help screens. |

Recommended startup order:

```text
GET /mobile/app-config
  -> block if maintenance
  -> block if force update
  -> restore token
  -> refresh if needed
  -> GET /mobile/bootstrap
  -> route to app
```

Cache the last successful app config so the app can show a graceful offline startup state.
