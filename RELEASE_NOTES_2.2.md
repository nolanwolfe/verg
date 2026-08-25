# Verg 2.2 — Release Notes

App Store listing copy — promotional text, description, What's New,
keywords — lives in `APP_STORE.md`. This file is the QA pass.

## QA before submission

### Covered by `VergUITests` — run `xcodebuild test -only-testing:VergUITests`

Thirty-four tests drive the real app and attach a screenshot of every state,
so these no longer need a person. A further 117 unit tests cover pure logic:

- Every tab renders its own content, in Light and in Dark
- Onboarding: all six screens in order, and Skip going straight into the app
- Theme picker selects and persists; History switches the Archive
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
- Onboarding is dark and the paywall is light, measured by screen brightness
  rather than assumed — the two theme pins that structural assertions cannot
  see
- The app lock engages on backgrounding, opens with the code, refuses a wrong
  one, and hides the content behind it from the accessibility tree
- Drawing a question and cancelling does not change the session; Select
  Guidance is what commits it
- Choosing one of your own questions selects it rather than opening the editor
- Swiping in the fullscreen viewer cannot walk past a locked page

### Still needs a physical device

Everything below touches hardware, money, or real time — none of it can be
exercised in a simulator.

- [ ] **Camera.** Close-up focus on a page: the app now asks for the virtual
      multi-camera device so iOS can drop to the ultra-wide for macro. Check a
      page fills the frame *and* comes sharp. Tap-to-focus ring appears. The
      1x/2x selector switches lenses. The torch lights and goes out when the
      screen closes. `CameraView` compiles out to a photo-picker stub in the
      simulator, so none of this has ever run outside a device.
- [ ] **Page format.** Pages are portrait **3:4** now, matching a single
      notebook page (Letter 0.77, A5 0.70, Moleskine 0.62). The camera's
      `.photo` preset on a portrait-locked phone already produces 3:4, so a
      capture is stored untouched — check that what the viewfinder frames is
      exactly what lands in the journal. This replaced a landscape 3:2 that
      had been chosen for an open spread; single pages were hard to
      photograph through it, which is the thing to confirm is gone.
- [ ] **Photos are stored whole now.** Nothing is cropped on save; the frame
      is applied on display. Import a wide photo from the library and confirm
      the journal shows it page-shaped without the file itself being
      destroyed.
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

### Two things that were not code — both now resolved

Both were found by reading the running app, and both were fixed in App Store
Connect rather than here. Kept on the record because the paywall reads
RevenueCat at runtime, so a change there can silently undo either of them.

1. ~~**Monthly is priced $4.99, not $7.99.**~~ **Fixed.** Monthly now reads
   **$7.99/mo** against Yearly's **$59.99/yr** — which is **$4.99/mo**
   equivalent, so the yearly plan finally has the advantage its layout
   implies. Confirmed on the paywall.
2. ~~**There is no free trial on the real product.**~~ **Fixed.** The
   introductory offer is configured and the app reports it: the Yearly row
   shows *"3 days free"* with *"then $59.99/year, cancel anytime"* beneath
   it, and the button reads *"Enter The Golden Age — 3 Days Free"*. The
   duration comes from StoreKit at runtime and is never hardcoded, so
   changing the offer in App Store Connect changes the copy automatically.

**Prices as shipped (2.2)**

| Plan | Price | Shown as | Trial |
|---|---|---|---|
| Yearly | $59.99 / year | $4.99 /mo | 3 days free |
| Monthly | $7.99 / month | $7.99 /mo | — |

`VergProducts.storekit` matches these, but it is test-only: the live figures
come from App Store Connect and the app never hardcodes them.

