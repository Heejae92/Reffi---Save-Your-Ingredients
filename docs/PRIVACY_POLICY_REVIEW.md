# Reffi privacy policy and publication

Updated 2026-09-07 for the account-free release. Operators: Jongmin Lee and Heejae Eo. Contact: lee1993ljm@gmail.com. General audiences in the US and South Korea. Homepage: https://reffi-site.vercel.app.

## Implemented notice

`PrivacyView` is available offline from the small settings footer. It includes an effective date, the supplied homepage, eight English/Korean sections, privacy contact and provider links. The old review-draft heading is removed. The notice follows actual behavior:

- Fridge, recipes, receipt recognition, preferences and allergy filtering stay on the device.
- New accounts, email login, password recovery and usage analytics are unavailable.
- Camera/photo selection and local notifications are optional. Manual entry remains available.
- Videos sends a current-language search to YouTube on user action; names entered by the user can appear in search terms. The website uses Vercel and privacy inquiries use Gmail.
- Earlier Supabase accounts and records can still exist. The primary database is in Seoul; this does not prove that every provider log or support operation stays there. Existing-account deletion, local erase and app deletion have different scopes.
- Local data stays accessible if a prior session expires. Server requests remain authenticated and use HTTPS.
- The notice states purpose-based inquiry retention, rights, children, safeguards and policy updates without inventing provider log-deletion deadlines or guaranteeing absolute security.

The privacy manifest matches the removal of analytics. Legacy Email/UserID functionality remains declared. App Store Connect privacy answers must be reviewed for this release.

## Public website

The public homepage was fetched successfully. Its existing Privacy link is `#`, so the offline notice alone does not complete publication. `website-release/privacy.html` contains the same eight bilingual sections. `website-release/index.html` preserves the current landing page, links Privacy to `/privacy.html`, and corrects the recipe count from 128 to 250.

This package is **not deployed**. The existing Vercel account was reached through GitHub sign-in; Vercel requires an authenticator code to finish login. The original homepage repository/path has also been requested. Publish in that existing project, verify the public URL without authentication, then enter it in App Store Connect. No replacement domain or speculative production project was created.

## Operating follow-through

Operators must follow the stated inquiry/deletion process. Do not equate dashboard log visibility with permanent deletion; provider security logs and recovery copies need provider confirmation for exact periods. `PRIVACY_PROVIDER_QUESTIONS.md` contains an unsent inquiry for earlier account records. No messages have been sent on the operators' behalf.

This is an implementation and factual consistency check, not a legal opinion or a guarantee of compliance in every jurisdiction.

## Sources

- [Apple review guidelines, privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Supabase privacy](https://supabase.com/privacy)
- [Google privacy](https://policies.google.com/privacy)
- [Vercel privacy notice](https://vercel.com/legal/privacy-notice)

Current test evidence and remaining distribution/device checks are recorded in `RELEASE_READINESS.md`.
