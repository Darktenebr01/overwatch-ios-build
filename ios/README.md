# Overwatch Suite for iOS

This is a native SwiftUI companion to the Android apps. It uses the same
Overwatch server and the same `overwatch` team code.

## What is included

- Workday: name, server setup, setup QR scanning, local Work Day records,
  monthly totals, live location, home region monitoring, and auto Work Day
  distance/hours.
- Overwatch Admin: admin key, team totals, MapKit map with school/home/auto-work
  circles, geofence editing from the map center, recent arrival/departure
  events, and a Workday setup QR.

## Build

The repository includes a GitHub Actions workflow that produces an **unsigned**
IPA on a macOS runner. It does not need an Apple Developer account:

1. Push the repository.
2. Open **Actions → Build unsigned iOS IPA → Run workflow**.
3. Download the `OverwatchSuite-unsigned-ipa` artifact.

An unsigned IPA cannot be installed directly. Sign it with your own Apple ID
using AltStore or SideStore on Windows, or build it in Xcode with a development
team.

## Install with AltStore / SideStore

1. Install AltServer or SideStore on the Windows PC and pair the iPhone.
2. Download `OverwatchSuite-unsigned.ipa` from the Actions artifact.
3. Open the IPA with AltStore/SideStore and sign it with your Apple ID.
4. Trust the developer certificate on the iPhone if prompted.

Free Apple IDs normally expire after seven days and must be refreshed. A paid
Apple Developer account can use TestFlight or longer-lived provisioning.

## iOS limitations

- iOS requires **Always** location permission for home region monitoring and
  background sharing. The blue location indicator remains visible.
- Region monitoring can be delayed by iOS and is suspended if the user
  force-quits the app.
- Auto Work Day measures straight-line distance from the home center.
- This app is not App Store-ready: it has no App Store metadata, icon set, or
  privacy review package.
- The unsigned workflow is for personal sideloading only.
