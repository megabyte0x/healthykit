# App Review Remediation Design

HealthSync will remediate the three issues reported for version 1.0 (4): remove Apple Health from the App Store subtitle, use neutral wording on the pre-permission action, and make every permission and manual-sync attempt visibly acknowledge the user's tap.

The existing HealthKit request and sync services remain unchanged. `AppState` will expose a small typed feedback value that views render as an inline status banner. Permission success, empty sync results, successful uploads, and failures will each update visible state. Existing error logging remains intact.

The App Store subtitle will be changed in App Store Connect to `Private Health Data Sync`. New screenshots must not show the rejected `Connect Apple Health` button copy. A release checklist will record the metadata and clean-install physical-device verification required before resubmission.

Tests will cover neutral button wording and feedback messages. Verification requires the Swift test suite and a Release build for a generic iOS device; final HealthKit sheet behavior must also be checked on a physical iPhone because the simulator is not authoritative for HealthKit data access.
