# AutoTelemetry for iOS

SwiftUI (iOS 17+) port of the Android app: map-first home, search with recent drives, garage (add a car by VIN),
route planning against your maps-engine, a drive HUD, and streaming uploads through the router.

## Build

```sh
brew install xcodegen          # once
cd ios && xcodegen generate    # the .xcodeproj is generated, not committed
open AutoTelemetry.xcodeproj   # or: xcodebuild -scheme AutoTelemetry -destination 'platform=iOS Simulator,name=<device>' test
```

Router address and Clerk publishable key live in `project.yml` (same values as the Android build).

## Sign-in

Uses the same Clerk instance as the Android app (the publishable key in `project.yml`), so the Native API is already on.
Starting Google sign-in works without registering this app as a Clerk native application (tested in the simulator:
Clerk answered and iOS opened the Google sign-in prompt). Finishing a login and returning to the app is untested.
If it fails on return, register an iOS app under Clerk -> Native applications (Team ID + `org.nighthawklabs.telemetry`)
and allowlist `org.nighthawklabs.telemetry://callback`, as Mission Control does.

## Differences from Android

- **OBD adapters must be Bluetooth Low Energy** (Veepeak BLE+, vLinker BLE, OBDLink CX...). iOS gives apps no
  access to classic-Bluetooth (SPP) adapters without Apple's MFi program, so the classic VEEPEAK won't connect.
  A demo drive (simulated readings) is built in.
- Only combustion PIDs are read from real adapters; EV battery PIDs are manufacturer-specific.
- Map is Apple MapKit (no API key). Navigate hands off to Google Maps (or the browser).
- Uploads run while the app is open or driving (background location keeps it alive); there is no background
  upload task yet, and request bodies are not gzipped (the server accepts both).

## CarPlay

A "Driving Task" companion. Navigation needs the app's own turn-by-turn; EV Charging may only show chargers and Fueling
only fuel stations, so neither can show a plan with either kind of stop; Driving Task covers "driving or road status and
information" and "tasks at the start and end of a drive", for any drivetrain. Apple asks that the task "actually help with
the drive", so pitch it as the trip's status and stops plus start/stop, not a dashboard. Data on screen refreshes at most
once every 10 seconds, per Apple's guideline.

In the car: **Plan** (the trip planned on the phone: time, arrival charge or fuel, cost, and its stops; tap a stop for
directions in Apple Maps, if CarPlay allows that for this category, which is confirmed once the entitlement is granted),
**Drive** (status and Start/Stop) and **Drives** (recent). Destination search is not available to this kind of app, so
plans are made on the phone, as are adapter pairing and the garage; turn-by-turn is Google Maps' job.

- Code: `AutoTelemetry/CarPlay/` (`CarPlayContent` is pure and unit-tested; `CarPlayController` builds the templates).
- **Apple must grant the entitlement** before it can ship or run on a device: request "Driving Task" at
  https://developer.apple.com/contact/carplay/. Until then it is applied to simulator builds only
  (`CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]` in `project.yml`); the device build is unchanged.
- Once granted: remove the `[sdk=iphonesimulator*]` condition in `project.yml`, enable CarPlay for the App ID in
  Apple Developer, and regenerate the provisioning profile.
- Try it in the simulator: run the app, then Simulator -> I/O -> External Displays -> CarPlay.
- Starting a drive from the car uses the car's remembered adapter; a first drive asks you to pick one on the phone.

## Tests

`AutoTelemetryTests` covers the parsers and mappers. `AutoTelemetryUITests/FlowTests` walks the guest flow in the
simulator; set `TEST_RUNNER_SHOTS_DIR=/some/dir` to also save a screenshot per step.
