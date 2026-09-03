# Pushlog store readiness

Last reviewed: 3 September 2026

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
| Local Flutter build / Android version code | `26` |
| Latest valid Xcode Cloud build | `48` |
| Privacy policy | <https://pushlog.iamngoni.dev/privacy/> |
| Terms | <https://pushlog.iamngoni.dev/terms/> |
| Account deletion | <https://pushlog.iamngoni.dev/delete-account/> |
| Marketing / support site | <https://pushlog.iamngoni.dev/> |
| Support email | `info@codecraftsolutions.co.za` |

All mobile flavours currently use the canonical Pushlog Worker at
`https://pushlog-api-staging.imngonii.workers.dev`. The hostname is retained
for compatibility, but this is the production data source; do not switch the
production flavour to the empty legacy Worker.

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
| Health | Latest heart-rate and active-calorie summaries saved with a live session |
| Fitness | Workout counts, sessions, duration, plan and progress |
| Device ID | Push messaging token registered to the account |
| Other User Content | A safety report submitted about another profile |

Data not linked to the user, used only for **App Functionality**:

| App Store category | Pushlog use |
|---|---|
| Crash Data | Sentry crash reports used for app functionality |
| Performance Data | Limited Sentry performance traces used for app functionality |

Do not declare camera images or videos: no frame leaves the device or is saved.
Declare the saved latest heart-rate and active-calorie session summaries as
developer-collected Health data. The underlying sensor sample stream remains
on-device and is not uploaded. Sentry is configured without default PII and no
Pushlog account identity is attached to diagnostic events.

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
  (workout activity plus saved latest heart-rate and active-calorie session
  summaries), app info and performance (crash logs, diagnostics, and limited
  performance traces), user-generated content (safety reports), and device or
  other IDs (push token).
- Data shared: **No**, when completing the form under Google's service-provider
  exception. Firebase, Cloudflare, and Sentry process data to provide Pushlog
  and are not used for advertising.
- Purposes: app functionality, account management, fraud prevention / security,
  and developer communications only when the user contacts support.
- Data is encrypted in transit: **Yes**.
- Users can request deletion: **Yes** — use the public deletion URL above.
- Data collection is required for account identity, cloud sync, and production
  diagnostics. Friends, notifications, camera counting and health export are
  optional.
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

- [x] Set App Store Connect Privacy Policy URL and Support URL to the live URLs.
- [ ] Complete App Privacy using the mapping above and verify the generated
      privacy report from the archived build.
- [ ] Complete the Google Play Data safety and Health apps declarations using
      the mapping above.
- [ ] Set Google Play's account-deletion web URL to the live deletion page.
- [x] Confirm the Android phone artifact targets API 36 or later and the Wear OS
      artifact targets API 35 or later.
- [x] Confirm the signed Android phone and Wear OS AABs report version `1.1.0`
      with version codes `26` and `360110026`, respectively.
- [x] Confirm the local iOS production build embeds the watch app and reports
      version `1.1.0 (26)`, and Xcode Cloud build `48` is valid in App Store
      Connect.
- [x] Prepare App Store version `1.1.0`, attach build `48`, set the Health &
      Fitness category, copyright, content rights, age rating, description,
      keywords, support URL, marketing URL, subtitle, and privacy-policy URL.
- [x] Add TestFlight build `48` to Internal and External Testers, add test
      notes, and submit it for beta review.
- [x] Publish the Google Play title, descriptions, store icon, feature graphic,
      and four real phone screenshots as listing metadata. Version code `25`
      remains completed on the internal track; production remains empty.
- [ ] Add at least one real 1:1 Wear OS screenshot before opting into Wear OS
      distribution. Do not use a generated or device-framed watch image.
- [x] Set App Review contact first name, last name, email, and phone number.
- [ ] Choose App Store availability territories. Do not infer a global or
      country-limited launch without an owner decision.
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
