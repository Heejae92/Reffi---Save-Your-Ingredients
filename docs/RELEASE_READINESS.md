# Reffi release readiness

## Current P1/P2 fixes, 2026-09-07

| Review item | Current result |
|---|---|
| Blank quantity preserves an old value | Add/edit validate the entire text. Blank, zero, negative and malformed values cannot save. |
| Unmarked automatic use-by date | Auto dates show Estimated use-by and an explicit confirmation action. Saved stock keeps an approximate mark and accessibility description until confirmed. Legacy unverified dates default to estimated. |
| Production SMTP missing | Email registration, login, password recovery and callbacks removed. New-user signup and Email provider disabled in the live Supabase dashboard. No SMTP is required by this release. |
| Draft privacy notice | Rewritten in English/Korean for current data processing, with effective date and the supplied homepage. Offline screen and privacy manifest updated. Public website deployment and App Store Connect metadata remain open. |
| Silent disk-save failure | Atomic write success is checked before closing add/edit forms. A visible error with retry retains the unsaved snapshot. Receipt review and the app root also display recovery. |
| Inventory-first flow | Registered stock leads to View fridge, with registration feedback; Start cooking stays available as a secondary action. List/Cards control has a visible label. |
| Inaccurate fixed leftovers | Each selected leftover accepts an exact positive amount up to available stock. Units and undo are preserved. |

Existing work on manual first registration, 14 recipes with 100 bilingual ingredient amounts, safe matching, current-language YouTube search and artwork was preserved. See `RECIPE_CONTENT.md`. No new commit, archive, or TestFlight upload has been made for these fixes.

Removing sign-in also required preserving the current local owner after a legacy session expires, so saved stock does not become inaccessible. Existing-account deletion is retained; no existing accounts were deleted during this change. Production usage collection is disabled for all sessions, and old unsent queues are cleared. The local-only approach was communicated while the optional telemetry preference question awaited a reply.

### Verification in this change

- Full unit run: 648 passes, comprising 629 Swift Testing and 19 XCTest. Five focused reliability tests then passed, including one additional legacy-session/local-data regression test. Total distinct unit tests verified: 649.
- iPhone 17: English/Korean first registration, blank/zero quantity rejection, persisted stock, recipe amounts/checklist, no login/analytics entry point, English/Korean privacy opening/dismissal and Korean accessibility text passed.
- iPhone SE: first registration in both languages, recipe sheet, profile, exact leftover editing, persisted 800 ml stock and onboarding passed. Screenshots confirm the new home buttons, date approximation, editable remainder and visible list control fit the small screen.
- Initial leftover UI assertion failed because it searched a standalone text with a regular space. Stock is exposed as a combined button and uses a nonbreaking numeric-unit space. The corrected test finds the actual stock row and passes through relaunch. The original failing run is not counted as a successful suite.
- An injected filesystem write error was reproduced; retry preserved quantity and expiry provenance without duplicate IDs. This is an actual write failure test, not a claim that physical device storage was filled.
- The public-policy package renders locally in Korean at 375 px and English at desktop width. Its homepage Privacy link opens `/privacy.html`. It is not deployed to Vercel.

Evidence: `/tmp/reffi-p1p2-final-tests.log`, `/tmp/reffi-p1p2-small-tests.log`, `/tmp/reffi-p1p2-final-flow.log`. Final follow-up verification is appended below.

## Implemented

- Recipe matching filters actual inventory, including substitutions and concrete ingredients matched to a generic recipe line, against allergy/vegetarian restrictions. Expired stock cannot fill a recipe line. Unknown allergy names stop recommendations until corrected.
- Original and opened use-by dates both prevent expired food from becoming fresh through freezing. Previously saved invalid freezes retain the expired date.
- New installations use local storage without sign-in. Existing cached sessions are retained only for account maintenance and deletion.
- `0003_account_deletion.sql` provides a caller-only, transactional account deletion RPC. It deletes analytics, legacy AI usage and the auth user; auth-owned identities/sessions cascade. A foreign key and RLS stop deleted users from writing new events. Apple identities are explicitly blocked until token revocation is implemented; Apple login stays hidden.
- The privacy policy is available offline from settings. Usage sharing is disabled and its setting removed.
- Local fridge and profile data retain the existing storage scope. A missing or expired legacy session keeps the current saved local owner. Corrupt destination files abort a switch without clearing the current fridge.
- Cached authentication restores without blocking local access on network refresh. Production analytics cannot upload, including for cached sessions.
- The inactive, injectable analytics pipeline retains its regression tests and safe background-task cleanup.
- The app uses 48 selected Phosphor icons in all six weights as vector PDFs. The original shapes, Swift API and MIT license are preserved in `Vendor/PhosphorSwift`; app builds no longer compile the entire upstream SVG catalog.

## Build 26 verification on 2026-09-06

- OKDandan Display and Heading use -2% tracking and no extra SwiftUI line spacing; web specimens use 115% line height. Korean and English use the same font. The font is embedded in the app, but excluded from the public Git repository; `scripts/prepare-font.py` verifies the download and converted TTF hashes before XcodeGen runs.
- 645 tests passed: 627 unit tests (608 Swift Testing and 19 XCTest) and 18 UI tests. Zero failures. UI coverage includes cooking, fridge tabs/history/sorting, onboarding, shopping, authentication, privacy, accessibility and language switching.
- Localization: 455 keys, 361 source literals, zero missing keys. Seven local account-deletion SQL checks passed.
- A clean font preparation run without a pre-existing font succeeded and produced the expected SHA-256.
- Signed Release archive and App Store distribution export succeeded for version 1.0 (26), bundle ID `com.reffi.app`, team `L3RY7X2WBC`, using Cloud Managed Apple Distribution.
- Changes were committed as `ce76f59` and merged into `main` as `17c7977`; both branches were pushed. App Store Connect accepted the version 1.0 (26) upload at 22:10 PDT on 2026-09-06. The upload appeared in TestFlight and entered Apple processing.
- This is a TestFlight QA candidate. The server deployment and privacy publication items below remain required before public release.

## Earlier build 25 verification on 2026-09-06

- Build 25 passed 632 tests on an isolated iPhone 17 simulator running iOS 26.5: 627 unit tests (608 Swift Testing and 19 XCTest) and 5 UI tests. Zero failures or skipped tests.
- UI coverage includes firing a cooking ticket, retaining checked cooking steps, the supported authentication entry points, opening authentication from the profile, and scrolling the Korean privacy policy at accessibility text size AX5. The new authentication and privacy screens were also visually inspected in light and dark appearance during this session.
- Localization check: 419 keys, 355 source literals, zero missing keys.
- All 250 recipes and 279 ingredient entries have valid canonical references, including alternative and safety references.
- All seven local account-deletion SQL checks passed.
- A signed Release archive and a local App Store distribution export both succeeded. The exported IPA uses `Apple Distribution: Jongmin Lee (L3RY7X2WBC)` and bundle ID `com.reffi.app`.
- No TestFlight/App Store upload, production database migration, commit or push was performed.

The exported build is a verification artifact. The server and privacy items below still block public release; a successful export does not prove App Store validation or actual-device behavior.

## Live server state, 2026-09-07

The owner confirmed that project `bzzpmaeitfbbunsmjvmd` is dedicated to Reffi and authorized deletion of previous-project remnants. Its dashboard display name is now Reffi. Project ID, API URL and region are unchanged.

Applied `0003_account_deletion.sql` and `0004_remove_previous_project.sql` in one transaction through the authenticated SQL editor. The exact pasted SQL was verified before execution. Cleanup used explicit DROP TABLE statements without CASCADE and removed `rejection_submissions`, `rejection_patterns`, `feedback`, `onboarding_responses` and `user_guide_progress`. No other application tables or Auth accounts were deleted. There were no Storage buckets or custom Auth-user triggers; the only Edge Function was Reffi's legacy `recipe-generate`.

After deployment, the five old tables were absent. Reffi account/analytics/legacy AI-usage counts remained 1/0/1, matching the counts before cleanup. The deletion RPC is executable by authenticated users, not anon; the analytics policy requires an active account. An anonymous HTTP call returned 401 / PostgreSQL `42501`, confirming that the API resolves and rejects the RPC. Caller isolation, transaction rollback, retry and deleted-account writes were tested in local PostgreSQL. Deletion of a disposable account through the actual iPhone app is still required; no real account was deleted for validation.

Site URL and the sole redirect allow-list entry are now `reffi://auth-callback`. The previous Site URL was `http://localhost:3000`, with no allowed redirect URL. These callbacks are no longer consumed by the app.

Custom SMTP remains disabled. New-user signup and the Email provider were disabled on 2026-09-07 and their saved states were re-read. SMTP is no longer a launch dependency. No test emails or provider inquiries were sent. The project remains on the Free plan with a Seoul primary database. The previous 2026-09-06 inspection found no scheduled project backups and disabled database auth-audit logging; these are separate from provider security logs and infrastructure recovery copies.

## Privacy publication required

The operators are Jongmin Lee and Heejae Eo; the privacy contact is lee1993ljm@gmail.com. General audiences in the US and South Korea, not children. The offline policy has an effective date and links to https://reffi-site.vercel.app. It describes local processing, existing accounts, optional external searches, Vercel/Google Fonts website requests and Gmail inquiries, retention/deletion and user rights.

The canonical website source is `site/`, integrated from Heejae's remote commits and updated with the bilingual policy. Heejae92 owns Vercel publication, tracked in GitHub issue #26. App Store Connect requires authenticated access for store metadata. Publication and store metadata have not been verified. Do not use a source file or localhost preview as evidence of public publication. See `PRIVACY_POLICY_REVIEW.md` and the unsent provider questions for remaining operating details.

## Validation commands

```sh
xcodegen generate
python3 scripts/check-strings.py
xcodebuild -project Reffi.xcodeproj -scheme Reffi \
  -destination 'platform=iOS Simulator,id=<isolated-device-id>' \
  -derivedDataPath /tmp/reffi-release-fixed-dd \
  -only-testing:ReffiTests \
  -only-testing:ReffiUITests/ReffiFlowUITests \
  -only-testing:ReffiUITests/CookTicketFlickUITests/testTicketDeck_RightFlick_FiresTheFrontTicket \
  -only-testing:ReffiUITests/CookTicketFlickUITests/testKitchenCopySheet_ChecksPersistAcrossOpenClose test
```

The SQL test uses an in-memory PostgreSQL build with a minimal Supabase Auth schema. It executes all four real migrations, checks previous-project cleanup and its safe re-run, and checks anonymous denial, caller isolation, account/data deletion, retry, deleted-JWT rejection, transaction rollback and the Apple revocation guard. This does not prove live server deployment or GoTrue integration.

```sh
npm install --prefix /tmp/reffi-sql-validation --no-audit --no-fund @electric-sql/pglite@0.5.8
PGLITE_MODULE=/tmp/reffi-sql-validation/node_modules/@electric-sql/pglite/dist/index.js \
  node scripts/test-account-deletion.mjs
```

## Remaining release verification

- Installation and launch of the distribution build on an actual iPhone through TestFlight.
- Actual receipt camera scan and notification delivery on an iPhone.
- Existing-account deletion with a disposable legacy session, public privacy-policy publication, and App Store Connect privacy URL/answers.
- The remaining 236 seed recipes have no ingredient amounts. Recommendations do not promise sufficient quantities. The 14 enriched recipes still need cooking trials before they can be described as kitchen-tested.

## Dependency reproducibility

The generated Xcode project remains ignored, except for `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. This retains the versions used to validate build 25, including Supabase Swift 2.51.0.

## Display font update

Display and Heading now use OKDandan in Korean and English. The published OKTICON license permits commercial use and embedding; the former Jeju Stone Wall font and its pending permission requirement have been removed. Separate redistribution of the font file is restricted. See `Reffi/Resources/Fonts/OKDANDAN-NOTICE.md`.

## Final verification, account-free candidate

Final focused tests passed after the local-owner lifecycle changes: session expiration preserves the current fridge, while an explicit erase/delete flow leaves the previous owner. Default onboarding uses no authentication bypass flag. Profile and privacy checks also pass. Nine distinct UI scenarios were validated during this change, with repeated runs on iPhone 17 and iPhone SE. Test selector failures described above were corrected and rerun.

The final device-targeted **Release build succeeded** with `CODE_SIGNING_ALLOWED=NO`. It verifies production compilation for iOS arm64; it is not a signed archive, exported IPA, installation or TestFlight upload. Log: `/tmp/reffi-p1p2-release-final.log`. The existing non-mutated variable warning in `PaperSilhouette.swift` and the App Intents metadata notice remain.

Final localization gate: 501 keys / 342 literals / 0 missing. Privacy manifest validation and `git diff --check` passed. Eight Korean/English policy sections match between the app and website package. Those checks preceded the build 27 integration recorded below. Vercel publication is assigned to Heejae92 in issue #26; public publication and App Store Connect privacy metadata remain unverified.

Evidence is retained under `output/release-p1p2-2026-09-07/`, including test/build logs, selected screenshots and source hashes. The current TestFlight build predates these edits. Its old email screens cannot sign in now that the live provider has been disabled.

## Build 27 integration (2026-09-07)

- Integrated remote main through d0a2b55, retaining site assets and client-role grant hardening. Email authentication UI and its obsolete tests are removed for the account-free release.
- Local cleanup already occupies migration 0004; client grant hardening is numbered 0005 to avoid duplicate migration versions. The combined SQL harness passes.
- Website source is `site/`; Heejae92 owns Vercel publication. The bilingual policy matches the app.
- Build 27 signed archive and strict signature validation passed. The archive contains version 1.0 (27), bundle com.reffi.app and the OKDandan font. Full unit suite passed: 630 Swift Testing + 19 XCTest = 649. Localization: 510 keys / 342 literals / 0 missing. Earlier source manifest matched all 750 files before integration; only the merged string catalog differs within app sources.
- App source commit: `2dcd49a`. Build 1.0 (27) upload accepted by App Store Connect at 2026-09-07 19:33 PDT. Xcode reported `Uploaded package is processing`, `Upload succeeded`, and `EXPORT SUCCEEDED`. Apple processing completion and tester availability are not yet verified.
- Local evidence: `/tmp/reffi-build27-archive.log`, `/tmp/reffi-build27-tests.log`, `/tmp/reffi-build27-upload.log`. Website publication is assigned to [Heejae92 in issue #26](https://github.com/LittleGD/Reffi---Save-Your-Ingredients/issues/26).
