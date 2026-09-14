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
