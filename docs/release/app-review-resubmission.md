# App Review Resubmission Checklist

Review submission: `afac4317-5834-4191-97a6-b29bcfde6214`
Rejected build: `1.0 (6)`
Replacement build: `1.0 (7)`

## App Store Connect metadata

- Subtitle: `Private Health Data Sync`
- Replacement onboarding screenshot: `screenshots/appstore/01-onboarding.png`
- Select build `1.0 (7)` for the existing app version before resubmitting.
- Paste the App Review notes below into **App Review Information**.
- Do not send the App Review reply until every physical-iPhone check is complete.

## Root cause and fix

The rejected clean-install build defaulted to **My own backend** without a backend URL or token. The dashboard still exposed **Sync Last 24 Hours**, so tapping the app's primary action necessarily produced a missing-configuration error even though the review device had Health access and an active internet connection.

Build 7 fixes the first-run contract:

- New installations explicitly disclose and default to private hosted HealthSync storage.
- Tapping **Continue** provisions the private hosted workspace before requesting Health read access.
- Hosted storage is automatically repaired before a manual 24-hour sync if its local credentials are missing.
- Users can still switch to **My own backend** in Settings.
- Sync reports an explicit success or no-data result instead of a configuration error on the default path.

## Clean-install release verification

Run these checks using the archived Release build on a physical iPhone:

- [ ] Delete HealthSync and install build `1.0 (7)` from TestFlight.
- [ ] Confirm onboarding says that Continue creates private hosted storage.
- [ ] Tap **Continue** on an active internet connection and confirm the native Health permission sheet appears after setup.
- [ ] Grant read access and confirm the dashboard shows **Storage Destination: Hosted**.
- [ ] Tap **Sync Last 24 Hours** and confirm the action ends with either:
   - `The last 24 hours were synced successfully.`, or
   - `No health samples were found for the last 24 hours.`
- [ ] Confirm no missing-backend or missing-token error appears.
- [ ] Repeat after deleting the app and declining Health access; confirm the app does not claim that access was granted.
- [ ] In Settings, switch to **My own backend** and confirm the existing custom URL/token workflow remains available.
- [ ] Verify the archived Release build on every enabled device family. The app currently enables iPhone only (`TARGETED_DEVICE_FAMILY = 1`).

## Verification record

Completed locally on July 15, 2026:

- [x] Build number is `1.0 (7)` in Debug and Release configurations.
- [x] HealthKit authorization is read-only: the app requests an empty share set, includes `NSHealthShareUsageDescription`, and omits the write-only `NSHealthUpdateUsageDescription` key.
- [x] Clean-install Release launch shows the private hosted storage disclosure and neutral **Continue** action.
- [x] Tapping **Continue** on a clean simulator provisions hosted storage before presenting the native Health permission sheet.
- [x] Swift test suite: 65 passed, 0 failed.
- [x] Generic iPhone Release build using the iOS 26.5 SDK passed store bundle validation.
- [x] Backend test suite: 19 passed, 0 failed.
- [x] Supabase function bundle and website production build passed.
- [x] `Info.plist`, entitlements, and patch whitespace validation passed.

Still requires a connected physical iPhone and the processed TestFlight build:

- [ ] Complete every item in **Clean-install release verification** above.
- [ ] Record the device model, iOS version, TestFlight build, tester, date, and both permission-path outcomes here.

## App Review notes

Use this text in App Review Information:

> HealthSync now creates a private hosted storage destination during first-run setup. On a clean installation, tap Continue, review the Health read permissions, then tap Sync Last 24 Hours. No backend URL or token needs to be entered by the reviewer. If the device has no matching Health samples, the app displays a no-data result rather than an error.

## App Review reply

Send the following only after completing the physical-iPhone checks above:

Hello App Review Team,

Thank you for the report. We reproduced the issue from a clean installation. The cause was that build 1.0 (6) opened the dashboard with the app set to a custom backend, but no backend URL or token existed yet. Tapping Sync Last 24 Hours therefore displayed a configuration error.

In build 1.0 (7), first-run setup now explicitly creates a private hosted storage destination before Health access is requested. After setup, Sync Last 24 Hours works without reviewer-supplied credentials and displays either a successful-sync result or a no-data result when the device has no matching samples. The custom-backend option remains available in Settings.

We tested the replacement build from a clean installation on an iPhone using an active internet connection and verified the first-run, permission, no-data, and successful-sync paths.

Thank you for reviewing the updated submission.
