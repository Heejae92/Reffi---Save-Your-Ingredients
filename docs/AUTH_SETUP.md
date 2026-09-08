# Reffi authentication

## Current release, 2026-09-07

New installations run locally without an account. Email registration, login, password reset and auth callbacks have been removed. Apple, Google and anonymous sign-in are unavailable. `AuthStore` only restores earlier sessions and supports existing-account deletion. It never requests a new session for local use.

The Supabase dashboard for project `bzzpmaeitfbbunsmjvmd` was updated and re-read on 2026-09-07: **Allow new users to sign up = off; Email provider = disabled; anonymous sign-in = off**. SMTP remains off and is no longer a dependency of the supported app flow. Old distributed builds still showing email forms will no longer be able to sign in or register.

## Existing installations

Saved fridge/profile storage remains scoped to its earlier local owner. Expiration of an Auth session must not switch the device to an empty guest file. There is no new login or logout button. Users with an existing usable session retain Delete account; users without it can request server-record deletion at lee1993ljm@gmail.com. No server accounts were deleted by this release change.

`delete_own_account()` deletes only the authenticated caller's account and application usage rows transactionally. It accepts no user ID. The client resets that account's local data only after server success. The Apple-identity guard remains, and Apple login is unavailable.

`Erase this device` clears all local fridge/profile copies and signs out. It does not delete a server account. Fridge contents have no server synchronization or sign-in recovery.

## Server evidence

Migrations `0003_account_deletion.sql` and `0004_remove_previous_project.sql` are applied. Five owner-approved previous-project tables were removed; Reffi account and usage counts were unchanged. Anonymous calls to the deletion RPC return 401 / `42501`. Local SQL tests cover caller isolation, deletion, rollback and deleted-JWT rejection. Actual-device account deletion still needs a disposable account with a usable existing session.

The unused legacy redirect configuration remains `reffi://auth-callback`; the app no longer consumes it. The project remains in Seoul.

## QA

`-skipAuth -skipOnboarding -analyticsOff` opens an isolated simulator. `-authView` is removed. Test the default onboarding path as well as the QA shortcuts. Test that expired legacy sessions preserve the current local fridge and that settings has no login or telemetry entry point.
