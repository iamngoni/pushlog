# Pushlog store screenshots

These assets are built from real Pushlog Flutter views rendered with fictional
demo data. The app surface is captured as a whole and stays unchanged inside
the marketing canvas.

## Sets

- `ios/screenshots/raw`: physical iPhone 17 Pro captures at 1206×2622. The
  inconsistent real-device status bars are cropped as a whole in the designed
  outputs.
- `ios/screenshots/mockups/store-safe-exact`: App Store upload candidates at
  1320×2868.
- `android/screenshots/raw`: clean Pixel 9 Pro XL emulator captures at
  1344×2992 with Android's fixed 9:41 demo status bar.
- `android/screenshots/mockups/store-safe-exact`: Google Play upload candidates
  at 1080×1920.

The iOS set includes the iPhone camera-counted session screen. The Android set
uses training-plan onboarding in that slot because camera counting remains an
iPhone-only capability. Wear OS requires a separate real 1:1 watch screenshot;
do not repurpose, frame, or generate one from the phone captures.

## Google Play graphics

- `android/graphics/icon-512.png`: exact 512×512 store icon derived from the
  shipped Pushlog master icon.
- `android/graphics/feature-graphic-1024x500.png`: 1024×500 signal-lime and
  black feature graphic used by the en-GB listing.

The local iOS 27 simulator cannot currently build Pushlog because Google ML
Kit's transitive pods do not provide the required arm64 simulator slice. These
captures therefore used the separate development bundle on a physical iPhone;
the normal development target setting was restored afterwards. Android was
captured on the dedicated `Pushlog_Store_Pixel_9` AVD.

Regenerate the designed outputs after raw captures change:

```sh
./tool/store_screenshots/build_mockups.sh
```
