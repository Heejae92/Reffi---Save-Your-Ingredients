# Reffi authentication, build 26

Supabase project: `bzzpmaeitfbbunsmjvmd`, Seoul. Dashboard: https://supabase.com/dashboard/project/bzzpmaeitfbbunsmjvmd

## Launch methods

Email signup/login and local guest mode are the supported launch methods. Apple and Google are hidden until provider setup, device login and account deletion are verified. Keeping native implementations in source does not make those providers release-ready.

`AuthStore.refreshAvailability()` reads `/auth/v1/settings`. Anonymous sign-in is attempted only when enabled there; otherwise guest mode remains local. Usage events cannot upload without a server session. Analytics is optional and off by default.

## Email verification and password recovery

Add `reffi://auth-callback` to Authentication > URL Configuration > Redirect URLs, exactly and without wildcards. Signup, anonymous email upgrade and password recovery explicitly request this URL. Reffi handles the callback at the app root so the authentication sheet need not be open; it accepts only that scheme and host. A failed code exchange is logged under the `auth` category and shown to the user: inside the sign-in sheet when it is open, otherwise as a dialog at the app root. A network failure asks the user to tap the link again; any other failure asks for a new link. Tapping an already-used confirmation link while signed in shows nothing.

Password recovery with PKCE signs the user in but does not emit a recovery event (supabase-swift 2.51 emits `.passwordRecovery` only in the implicit flow), so the app remembers the last reset request on this device (24 hours) and opens the new-password sheet after the link signs in. A recovery link opened on a different device only signs the user in. A dedicated recovery redirect URL would remove that limitation and needs a new allowlist entry.

The client pins `flowType: .pkce`. `reffi://` is a custom scheme any app can register, so the PKCE verifier kept in Reffi's own Keychain is what prevents an intercepted link from becoming a session. Do not switch to the implicit flow. A Universal Link (`https://<domain>/auth/callback`) should replace the custom scheme once the privacy-policy domain exists.

Verify email confirmation and recovery on a physical iPhone, including a cold launch from the email link. Production email sending/SMTP and rate limits also need verification before release.

## Server deployment (owner action required)

Verified against the live project on 2026-09-07 with the publishable key only: email sign-in responds correctly, but `rpc/delete_own_account` returns 404 (migration 0003 is not applied) and `rpc/ai_try_consume` is executable by the anonymous role (migration 0001's `revoke ... from public` does not remove the explicit grants Supabase gives `anon`/`authenticated` through default privileges). Both are fixed by applying two migrations in order, as the database owner, from Dashboard > SQL Editor:

1. `supabase/migrations/0003_account_deletion.sql` (account deletion RPC, deleted-JWT insert guard, analytics FK).
2. `supabase/migrations/0004_harden_client_grants.sql` (revokes `anon`/`authenticated` from `ai_try_consume`, `ai_usage`, `ai_config` and `analytics.local_day`; pins the RPC's `search_path`).

Both files are idempotent. Then confirm in the SQL Editor:

```sql
select p.proname, p.proacl from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('ai_try_consume','delete_own_account','has_active_account');
select grantee, table_name, privilege_type from information_schema.role_table_grants
 where table_schema = 'public' and table_name in ('ai_usage','ai_config','analytics_events')
   and grantee in ('anon','authenticated');
```

Expected: `ai_try_consume` lists no `anon=`/`authenticated=` entry; `delete_own_account` and `has_active_account` list `authenticated=X`; the grant query returns only the `analytics_events` / `authenticated` / `INSERT` row. From outside, `POST /rest/v1/rpc/ai_try_consume` with the publishable key must now answer 403 with `"code":"42501"` (or 404 from the schema cache) instead of 200. Also delete the probe row left by the 2026-09-07 check: `delete from public.ai_usage where user_id = '00000000-0000-0000-0000-000000000000';`.

Locally, `scripts/test-account-deletion.mjs` reproduces the pre-0004 exposure and verifies the fix (see `docs/RELEASE_READINESS.md` for the command).

## Account deletion

Apply `supabase/migrations/0003_account_deletion.sql` after `0002_analytics.sql`. The client calls `public.delete_own_account()` using the current session. It accepts no account ID. The database deletes the caller's analytics, legacy AI usage and auth account in one transaction. The client clears local data only after server success. A failed call logs the server error under the `auth` category so a missing RPC is distinguishable from a network failure.

The RPC rejects Apple identities until server-side Apple token revocation is implemented. Apple/Google login remain hidden. Do not enable them by only changing a UI flag.

## Password policy

The client requires at least 8 characters (`AuthView.PasswordRule.min`) on signup and password reset. Sign-in only requires a non-empty password so accounts created under the old 6-character minimum can still log in; the server decides. Set the same minimum in Authentication > Policies (Supabase defaults to 6) and require letters and digits; enable leaked-password protection if the plan allows it. Keep the client constant and the dashboard value in the same change.

## Dashboard checklist before public release

- Rate limits: sign-in/sign-up per IP 30 per hour or lower; password recovery 5 to 10 per hour per IP; verify by bursting failed logins from a test IP and seeing a 429.
- Email: a production SMTP provider with SPF, DKIM and DMARC; the built-in service is not for production. Link/OTP expiry 3600 seconds or less.
- Attack protection: CAPTCHA on signup, sign-in and recovery. The client must pass `captchaToken` first; enabling the toggle alone breaks all three flows.
- Providers: Email on with confirmation; anonymous sign-in off; Apple/Google off until revocation and QA are done.
- Auth audit logging on; scheduled backups or a rehearsed `pg_dump` restore.
- Shared project check: `public.rejection_patterns`, `public.rejection_submissions` and `public.feedback` are RLS-disabled and not Reffi-owned. The app ships this project's publishable key, so those tables are readable by anyone until their owner enables RLS or moves them.

## Local data ownership

Fridge files and profile snapshots are kept per account on this device. First account registration transfers guest data; later logins restore that account's local data. Signing out opens separate guest storage. A damaged destination file blocks the switch and leaves the current data intact. There is no cloud fridge synchronization.

`Erase this device` removes all local account archives and signs out. `Delete account` removes the server account and the active account's local data. These are separate actions with separate confirmations.

## QA

`-authView` opens authentication directly. `-skipAuth -skipOnboarding -analyticsOff` opens an isolated simulator without authentication or telemetry. See `docs/RELEASE_READINESS.md` for validation commands and outstanding release requirements.
