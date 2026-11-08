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
3. Use `version` `1.0.1` for the maintenance release.
4. Leave `build_number` blank to use the GitHub run number, or set it to `11` for the maintenance candidate. Build 10 was an earlier export-only candidate.
5. Enable `export_only` to prepare a signed IPA artifact without uploading to TestFlight. Leave it disabled for the existing direct upload behavior.

The workflow first validates the App Store Connect secrets on Linux, then runs the archive/upload job on `macos-26`. The macOS job verifies the runner has an iOS 26 SDK, runs the complete iOS XCTest suite, and archives `HealthSync` using automatic signing for team `9UR77TD484`. With `export_only` enabled it exports a signed IPA into the `testflight-diagnostics` artifact. Otherwise it uploads directly to App Store Connect/TestFlight. Test results and distribution diagnostics are included in the artifact.


## Prepare the maintenance candidate

Run the workflow on the maintenance branch after reviewing the changes:

```bash
gh workflow run testflight.yml --repo megabyte0x/healthykit \
  --ref codex/maintenance-sync-workouts \
  -f version=1.0.1 -f build_number=11 -f export_only=true
```

Download the `testflight-diagnostics` artifact from the successful run. Its `HealthSync-export` folder contains the signed IPA. Keep the artifact private when distributing it for review. For a later TestFlight upload, use the same validated commit and set `export_only=false`.

## Check processing without another upload

Enable `status_only` to read recent App Store versions and build processing states using the existing API secrets. This mode skips the macOS build/upload job and makes only read requests to Apple's API. It also works after an upload performed locally with an existing signing identity:

```bash
gh workflow run testflight.yml --repo megabyte0x/healthysync \
  --ref BRANCH -f version=1.0.3 -f status_only=true
```

An uploaded or processed build is not a public release. Verify its processing result, select it for the intended App Store version, complete App Review and release it before expecting public users to receive the update.
