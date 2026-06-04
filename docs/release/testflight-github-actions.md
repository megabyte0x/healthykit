# TestFlight upload through GitHub Actions

Use this when local Xcode cannot complete the App Store Connect archive/upload path, or when you want the release to run from a clean hosted macOS 26 runner.

## Required repository secrets

Create an App Store Connect API key, then add these repository secrets in GitHub:

- `APP_STORE_CONNECT_API_KEY_ID`: the key ID.
- `APP_STORE_CONNECT_API_ISSUER_ID`: the issuer ID.
- `APP_STORE_CONNECT_API_PRIVATE_KEY`: the full `.p8` private key contents.

The private key secret can be pasted as the raw multiline `.p8` file. The workflow also accepts keys where newlines are escaped as `\n`.

## Upload

1. Confirm the App Store Connect app exists for `com.megabyte0x.HealthSync`.
2. Open GitHub Actions and run `TestFlight Upload`.
3. Keep `version` at `1.0` for the first public TestFlight build unless App Store Connect already has that version.
4. Leave `build_number` blank to use the GitHub run number.

The workflow runs on `macos-26`, verifies the runner has an iOS 26 SDK, archives `HealthSync`, and uploads the export directly to App Store Connect/TestFlight using automatic signing for team `9UR77TD484`.
