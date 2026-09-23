# Submitted App Store 1.2 (34), September 23, 2026

Version 1.2 (34) was submitted for App Review at about 3:46 AM Pacific time. App Store Connect shows the version as `Waiting for Review`. Manual release after approval remains selected. Version 1.1 was already `Ready for Distribution` when 1.2 was created.

Build source: merge commit `4c996f8` on `main` (PR #35: widgets, Live Activity, Apple Watch app, next-morning use-by check), marketing version 1.2 and build 34. Validation before the archive: 665 unit tests and 35 UI tests passing, `549 keys / 365 literals / 0 missing`. The signed archive contains only `Products/Applications`, with `Reffi.app`, `PlugIns/ReffiWidgets.appex` and `Watch/ReffiWatch.app`, all at 1.2 (34) and signed by team `L3RY7X2WBC`. The app and widget carry the `group.com.reffi.app` App Group entitlement.

Signing setup done once for this release: the App Group `group.com.reffi.app` (Reffi App Group) was registered in Certificates, Identifiers & Profiles and assigned to the App IDs `com.reffi.app` and `com.reffi.app.widgets`. Automatic signing enabled the App Groups capability but could not create the group itself, so the first archive failed until the group existed and was assigned. `com.reffi.app.widgets` and `com.reffi.app.watchkitapp` were registered by automatic signing.

Archive: `/tmp/Reffi-1.2-build34.xcarchive`. Logs: `/tmp/reffi-1.2-build34-archive.log` and `/tmp/reffi-1.2-build34-upload.log`. The upload ended with `Upload succeeded` and `EXPORT SUCCEEDED`. Apple processing completed and the build showed as ready to submit, with an app icon and an Apple Watch asset.

Store changes for 1.2: localized What's New from `1.2-WHATS_NEW.md` (en-US and ko); two Apple Watch screenshots per locale (see the resubmission note below); one paragraph appended to the review notes describing the widget, the Live Activity (starts from Cook this on a recipe ticket), the watch app, and the next-morning reminder. Descriptions, keywords, iPhone screenshots, URLs and review contact were inherited from 1.1.

Resubmitted the same day at about 4:25 AM Pacific time to replace the Apple Watch screenshots with marketing versions. 1.2 was removed from review (`Developer Rejected`), the en-US watch screenshots were deleted and replaced, Korean got its own set instead of inheriting en-US, and the same build 34 went back to `Waiting for Review`. Files in `watch/`, uploaded in this order: `en-US-1-use-first.png`, `en-US-2-cooking.png`, `ko-1-use-first.png`, `ko-2-cooking.png`. Each is 416 x 496: a real Series 11 46 mm simulator capture (the watch app with `-glanceFixture`, fed the phone app's own `glance.json`; all four taken in the same minute) in an ink bezel under an OK DanDan headline, with paper-cut glyphs from `site/resources/` picked from that scene's data (tomato and pepper for Shakshuka, mushroom and broccoli for the fridge list). App Store Connect masks watch screenshots to a rounded watch shape, so the lower corners of the glyphs are clipped in its preview.

Open: phone-to-watch sync was confirmed in paired simulators (delivery was slow) but not yet on a real iPhone and Apple Watch.

---

# Submitted App Store 1.1 (33), September 20, 2026

Version 1.1 (33) was submitted for App Review at 7:52 PM Pacific time. App Store Connect confirmed both the review submission and app version as `WAITING_FOR_REVIEW`. Manual release after approval remains selected, so approval will not automatically publish the update.

Build source: commit `dc71a4b` on `main`, with marketing version 1.1 and build number 33. Release validation completed with 667 unit tests passing, `537 keys / 351 literals / 0 missing`, and a successful signed archive. Archive metadata verified `com.reffi.app`, `1.1 (33)`, iOS 18+, team `L3RY7X2WBC`, and the bundled receipt product data matched the source SHA-256.

Archive: `/tmp/Reffi-1.1-build33.xcarchive`. Logs: `/tmp/reffi-1.1-build33-archive.log` and `/tmp/reffi-1.1-build33-upload.log`. The upload ended with `Upload succeeded` and `EXPORT SUCCEEDED`. Apple processing completed with build `b35796d9-d6da-4e1e-ab16-545e442f101f` in `VALID` state.

The 1.1 version inherited both Korean and English descriptions, keywords, support and marketing URLs, three 6.9-inch screenshots per locale, review contact, and review notes. The localized What's New text is recorded in `1.1-WHATS_NEW.md`. App Store version ID: `a906039c-c1ac-41a4-8eac-1ccc0d6ced00`. Review submission ID: `af54412a-437d-40a8-9c24-d37df7d692a3`.

---

# Submitted for App Review, September 14, 2026

Version 1.0 (30) was submitted for App Review at 6:27 PM (App Store Connect local time). Status: Waiting for Review. Manual release after approval is unchanged.

Screenshots were replaced with the owner's marketing previews in `en-US/` and `ko/` (three per locale, 1320 x 2868, iPhone 6.9" slot, order: receipt, countdown, tickets). The old 6.5" real captures were deleted on the owner's instruction so every iPhone size falls back to the new 6.9" set. Local originals of the old captures remain in `output/app-store/screenshots/`.

Final check before submission: build 30 selected; en/ko promotional text, description and keywords match this folder; no em dashes in store copy; support and marketing URL https://reffi-site.vercel.app; privacy URL returns HTTP 200 with the September 13 effective date; homepage shows 250+; privacy details published; Food & Drink; public distribution in 2 countries; Mac and Vision Pro off; ITSAppUsesNonExemptEncryption false; review contact and notes filled, sign-in not required. Screenshot UI strings match `Localizable.xcstrings` in the build source.

Open, not blocking: the published privacy label still lists Analytics as a User ID purpose while the review notes say there is no usage analytics (over-disclosure, pending owner decision). The Korean keywords include 유통기한 as a search term only.

App Store Connect gotchas seen here: while the version sits in a draft review submission, its screenshots are read-only; removing the item from the draft (and re-running Add for Review) unlocks them. The 6.9" slot only appeared after the 6.5" set was emptied. Multi-file uploads landed out of order, so upload one file at a time.

---

# Build 30 update, September 14, 2026

Heejae's PR #30 (main c9a4bca) adds the dark-appearance white wordmark. Build source: a770e83. Version 1.0 (30) was signed, archived and uploaded successfully. Asset catalog inspection confirmed the normal and UIAppearanceDark wordmarks at all three scales and as vectors. Localization: 523 keys / 347 literals / 0 missing. No service logic changed.

Archive: /tmp/Reffi-build30.xcarchive. Logs: /tmp/reffi-build30-archive.log and /tmp/reffi-build30-upload.log. Apple processing completed (Ready to Submit). Build 30 replaced build 29 in the saved version 1.0 and the review draft; App Store Connect confirmed Item Ready to Submit, 1.0 (30). Submit for Review was not clicked. Existing manual release settings were preserved.

---

# Reffi App Store preparation, September 13, 2026

Candidate: 1.0 (29), com.reffi.app, iOS 18+, iPhone. App Store Connect app ID: 6795009532.

The signed Release archive and App Store Connect upload succeeded. Archive: /tmp/Reffi-build29.xcarchive. Logs: /tmp/reffi-build29-archive.log and /tmp/reffi-build29-upload.log. Apple processing completed (Ready to Submit), build 29 was selected and saved for version 1.0. The existing Reffi internal TestFlight group has access for three testers, and bilingual test notes were saved. Source commit: 6c72ff4.

Validation of the candidate source: 652 unit tests and seven distinct focused UI scenarios passed in the preceding integration runs. Localization reports 523 keys, 347 source literals, zero missing. Privacy export matches eight bilingual app sections. The owner confirmed on September 13 that receipt-camera registration and expiry notifications work on a real iPhone. That is owner-reported device validation, not an automated test of build 29.

Store setup saved (remaining items below):
- English and Korean descriptions and keywords saved; Korean name Reffi: 냉장고 재고관리 and localized subtitle saved.
- English screenshots: four real app captures at 1284 x 2778. Korean: three. Inventory comes first. Local captures: output/app-store/screenshots/.
- Review login not required; contact supplied directly in App Store Connect, not stored in this public repository.
- Manual release after approval.
- Food & Drink primary category; free price; United States and South Korea availability.
- Mac and Vision Pro availability disabled for this iPhone MVP.
- Age questionnaire: no social/UGC/web browsing, advertising, medical, sexual, violent or gambling features. Infrequent alcohol references reflect cooking wine/mirin recipes. Apple calculated 13+ globally, 12+ in Korea and on older operating systems.
- Privacy URL: https://reffi-site.vercel.app/privacy.html. Email and User ID retained for legacy account functionality; production analytics is disabled. Product Interaction declaration removed. User ID Analytics purpose update awaits explicit approval after automatic approval review held publication.

Website source includes 250+, the September 13 policy and a support mail link. Heejae must deploy site/ and verify the public URL before review submission. Assigned GitHub issue: https://github.com/LittleGD/Reffi---Save-Your-Ingredients/issues/29. The public policy still showed the previous date on the final HTTP check. See docs/WEBSITE_RELEASE_HANDOFF.md.

Apple accepted Add for Review and created a Draft Submission showing Item Ready to Submit, iOS 1.0 (29). The final Submit for Review button was left untouched. No App Review submission has been made. Do not interpret an uploaded build or completed metadata as an App Store release.
