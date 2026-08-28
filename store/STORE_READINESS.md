# Pushlog store readiness

Last reviewed: 28 August 2026

This file is the source of truth for App Store Connect and Google Play Console
answers. Keep the public policy and the shipped app behaviour aligned with it.

## Release identity

| Field | Value |
|---|---|
| App name | Pushlog |
| Category | Health & Fitness |
| iOS bundle ID | `za.co.codecraftsolutions.pushlog` |
| Android application ID | `za.co.codecraftsolutions.pushlog` |
| Current version | `1.1.0` |
| Current build / version code | `22` |
| Privacy policy | <https://pushlog.iamngoni.dev/privacy/> |
| Terms | <https://pushlog.iamngoni.dev/terms/> |
| Account deletion | <https://pushlog.iamngoni.dev/delete-account/> |
| Marketing / support site | <https://pushlog.iamngoni.dev/> |
| Support email | `info@codecraftsolutions.co.za` |

The production mobile flavour uses `https://pushlog-api.imngonii.workers.dev`.
Development and staging flavours use the isolated staging Worker.

## Implemented review requirements

- Privacy policy is available before sign-in and from **You → Legal & support**.
- Terms and account-deletion help are available in the same two locations.
- Account deletion is available in-app at **You → Account → Delete account**.
- The public deletion page provides a request route that does not require the
  app to be installed.
- Deletion cascades through the Pushlog D1 profile, workout, friend, device,
  and notification records before the Firebase sign-in account is deleted.
- Camera frames are processed on-device, never saved or uploaded, and this is
  disclosed before the camera permission is requested.
- Apple Health and Health Connect are optional, requested in context, and used
  only to write a workout the user chose to save.
- Friends are accepted explicitly. A user can report and immediately block an
  accepted friend; blocking removes the connection and prevents rediscovery or
  a new request in either direction.
- Notification tokens are not written to production logs.
- iOS and watchOS targets contain privacy manifests. The watch manifest declares
  App Group `UserDefaults` access with required reason `1C8F.1`.
- Store-safe iPhone and Android screenshot sets are in `store/*/screenshots`.
- Android production release signing is configured and the local keystore is
  present. Never ship a debug-signed artifact.

## Apple App Privacy answers

Select **Data Not Used to Track You**. Pushlog has no advertising SDK and does
not perform cross-app tracking.

Data linked to the user, used only for **App Functionality**:

| App Store category | Pushlog use |
|---|---|
| Name | Sign-in display name, when supplied by Apple or Google |
| Email Address | Authentication and account support |
| User ID | Firebase UID and Pushlog username |
| Fitness | Workout counts, sessions, duration, plan and progress |
| Device ID | Push messaging token registered to the account |
| Other User Content | A safety report submitted about another profile |

Do not declare camera images or videos: no frame leaves the device or is saved.
Do not declare Health data as developer-collected: heart-rate and active-energy
samples are used during the local workout / health export and are not uploaded
to the Pushlog cloud service. The fitness workout record itself is declared.

App Review notes:

> Pushlog requires sign-in to provide cross-device workout sync, account
> deletion, optional friends and notifications. Reviewers can create an account
> with Sign in with Apple; no paid feature or external hardware is required.
> Camera counting is optional and has a complete manual alternative. Health and
> watch features are optional. Account deletion is under You → Account. Privacy,
> terms and deletion help are available before sign-in from About and after
> sign-in under You → Legal & support.

## Google Play Data safety answers

- Data collected: personal info (name, email, user IDs), health and fitness
  (workout activity), user-generated content (safety reports), and device or
  other IDs (push token).
- Data shared: **No**, when completing the form under Google's service-provider
  exception. Firebase and Cloudflare process data to provide Pushlog and are not
  used for advertising.
- Purposes: app functionality, account management, fraud prevention / security,
  and developer communications only when the user contacts support.
- Data is encrypted in transit: **Yes**.
- Users can request deletion: **Yes** — use the public deletion URL above.
- Data collection is required for account identity and cloud sync. Friends,
  notifications, camera counting and health export are optional.
- Ads declaration: **No ads**.

Health apps declaration:

- App category: **Activity and fitness**.
- Features: push-up workout logging, training plans, fitness progress, optional
  live heart-rate display from Wear OS / Apple Watch, and optional workout
  export to Health Connect / Apple Health.
- Health Connect types: write Exercise Session, Heart Rate, and Total Calories
  Burned. No Health Connect read access is requested by the phone app.
- Wear OS sensor access: heart rate and activity recognition are used only
  during a user-started foreground workout.

## Console checklist before submission

- [ ] Set App Store Connect Privacy Policy URL and Support URL to the live URLs.
- [ ] Complete App Privacy using the mapping above and verify the generated
      privacy report from the archived build.
- [ ] Complete the Google Play Data safety and Health apps declarations using
      the mapping above.
- [ ] Set Google Play's account-deletion web URL to the live deletion page.
- [x] Confirm the Android phone artifact targets API 36 or later and the Wear OS
      artifact targets API 35 or later.
- [x] Confirm the release AAB and iOS archive both report version `1.1.0 (22)`
      and are signed with distribution credentials.
- [ ] Verify Sign in with Apple and Google sign-in on store-distributed builds.
- [ ] Verify camera permission, notification permission, HealthKit / Health
      Connect permission, account deletion, report-and-block, and legal links on
      real release devices.
- [ ] Publish and verify iOS/TestFlight and Android internal testing separately;
      one platform is not evidence for the other.

## Copy boundaries

Do not make medical, guaranteed strength, calorie-loss, or body-transformation
claims. Use “training plan”, “workout record”, “progress”, and “optional health
export”. Keep the safety statement: Pushlog is not medical advice, and users
should stop exercising if they experience concerning symptoms.
