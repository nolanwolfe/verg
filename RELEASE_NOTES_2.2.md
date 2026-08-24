# Verg 2.2 — Release Notes

App Store listing copy — promotional text, description, What's New,
keywords — lives in `APP_STORE.md`. This file is the QA pass.

## QA before submission

### Covered by `VergUITests` — run `xcodebuild test -only-testing:VergUITests`

Twenty tests drive the real app and attach a screenshot of every state, so
these no longer need a person:

- Every tab renders its own content, in Light and in Dark
- Onboarding: all six screens in order, and Skip going straight into the app
- Appearance picker selects and persists; History switches the Archive
  between heatmap and month grid
- A script can be written, saved, and then edited
- The Oracle sheet and the duration picker open
- The Sound pill on Write and the Sound row in Settings are one switch
- The journal grid draws pages; the fullscreen viewer opens on the tapped one
- Book detail opens, and the rename/colour sheet reaches its 21 swatches
- Tapping a locked page opens the paywall *and* names the page
- The paywall opens from The Golden Age
- The timer screen renders and counts down, in both themes
- The achievements ladder renders below the fold

### Still needs a physical device

Everything below touches hardware, money, or real time — none of it can be
exercised in a simulator.

- [ ] **Camera.** Close-up focus on a page: the app now asks for the virtual
      multi-camera device so iOS can drop to the ultra-wide for macro. Check a
      page fills the frame *and* comes sharp. Tap-to-focus ring appears. The
      1x/2x selector switches lenses. The torch lights and goes out when the
      screen closes. `CameraView` compiles out to a photo-picker stub in the
      simulator, so none of this has ever run outside a device.
- [ ] **Page format.** Pages are landscape 3:2 now, and the viewfinder is
      masked to it. Find the angle and distance that frames a spread — an
      upright phone crops to the middle band, which is a real change from 2.1.
- [ ] **Prices and the trial.** The paywall reads RevenueCat at runtime. See
      the two open items below before testing this.
- [ ] **Purchase, restore, and the access code**, against a sandbox account.
- [ ] **Ambient sound** on speaker and headphones; silent switch stops it;
      it does not interrupt music already playing.
- [ ] **Upgrade from 2.1** with a real journal: pages load, legacy images
      migrate in the background, nothing re-runs onboarding.
- [ ] **Relight**, which needs a premium account and moving the device clock.
- [ ] **Notifications** actually fire at the set time.
- [ ] **Reduce Motion**: the paywall flame holds still; the gold sheen on the
      trial badge holds still.

### Two things that are not code

Both were confirmed from the running app tonight and neither can be fixed
here:

1. **Monthly is priced $4.99, not $7.99.** The paywall shows real RevenueCat
   data, and Monthly reads $4.99/mo — identical to Yearly's per-month figure,
   which leaves the yearly plan with no advantage at all. The local
   `VergProducts.storekit` says $7.99 but that file is test-only. Fix in App
   Store Connect.
2. **There is no free trial on the real product.** The app logs
   `[Trial] offer=nil eligible=false storeKitTrial=nil productFound=true` —
   StoreKit found `Verg_Yearly` and reports no introductory offer on it. The
   trial exists only in the local test file. Configure it in App Store
   Connect, or the trial badge will never appear.

