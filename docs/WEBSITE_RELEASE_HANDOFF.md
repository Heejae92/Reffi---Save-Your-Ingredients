# Website update handoff, 2026-09-13

Owner: Heejae Eo (GitHub Heejae92). Deploy the existing `site/` folder to the existing `reffi-site` Vercel project after these changes have been shared through Git. No new project or domain is needed.

Changes:
- Homepage count: `250+`; description: `over 250 recipes`. This is an intentionally stable lower-bound claim, not an exact catalog count.
- Privacy policy: September 13, 2026. Korean and English match the app, including local recovery copies and the existing jsDelivr font connection.
- Footer support link: mailto:lee1993ljm@gmail.com, used by the App Store support URL.
- Assets, hosting security headers and existing coming-soon CTAs remain intact.

Validation before deployment:
```sh
python3 scripts/export-site-privacy.py --check
```

Acceptance after deployment:
- Homepage displays 250+ and the footer opens privacy.html.
- https://reffi-site.vercel.app/privacy.html returns HTTP 200 without login.
- Both language sections show the September 13 effective date and recovery-copy disclosure.
- Verify the page on a narrow mobile screen and check homepage/contact links.
- Verify App Store Connect uses this public policy URL and that its privacy answers match the actual app.

This handoff describes prepared source changes. It does not assert that a new production deployment or App Store metadata change has occurred.
