-- Owner confirmed on 2026-09-07 that this project is dedicated to Reffi and
-- authorized deletion of all previous-project remnants. Reffi source does not
-- reference these five tables. No CASCADE: unexpected dependencies abort the
-- transaction instead of silently deleting objects outside this list.
begin;
drop table if exists public.rejection_submissions;
drop table if exists public.rejection_patterns;
drop table if exists public.feedback;
drop table if exists public.onboarding_responses;
drop table if exists public.user_guide_progress;
commit;
