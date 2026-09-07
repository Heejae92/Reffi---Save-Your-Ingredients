// Local PostgreSQL validation only. See docs/RELEASE_READINESS.md for the command.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth;
  create table auth.users(id uuid primary key);
  create table auth.identities(user_id uuid references auth.users(id) on delete cascade, provider text);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create function auth.role() returns text language sql stable as
    $$ select current_setting('request.jwt.claim.role', true) $$;
  grant usage on schema auth to authenticated, anon;
  grant usage on schema public to anon, authenticated, service_role;
  -- Supabase 프로젝트 기본값 재현: public 스키마의 새 테이블·함수에 anon/authenticated/service_role 명시 GRANT.
  -- 이 한 줄이 없으면 0001의 \`revoke ... from public\`만으로 닫힌 것처럼 보여 실서버와 어긋난다.
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;
`);
const migration = (file) => readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8');
for (const file of ['0001_ai_recipe.sql','0002_analytics.sql','0003_account_deletion.sql']) {
  await db.exec(await migration(file));
}
const probe='00000000-0000-0000-0000-0000000000ff';
// 0004 이전 상태 재현(2026-09-07 실서버 실측과 동일): anon 키만으로 캡 RPC 실행·AI 테이블 SELECT 가능.
// 관찰만 한다(단언 아님): 0001의 revoke를 나중에 고치면 여기가 false로 바뀌는 게 정상이다.
await db.exec('set role anon');
console.log('pre-0004 anon executes ai_try_consume:',
  (await db.query('select public.ai_try_consume($1, 5) as ok',[probe])).rows[0].ok);
console.log('pre-0004 anon selects ai_usage rows:', (await db.query('select * from public.ai_usage')).rows.length);
await db.exec('reset role');
await db.query('delete from public.ai_usage where user_id=$1',[probe]);
await db.exec(await migration('0004_harden_client_grants.sql'));
for (const role of ['anon','authenticated']) {
  await db.exec(`set role ${role}`);
  await assert.rejects(db.query('select public.ai_try_consume($1, 5)',[probe]),{code:'42501'},`${role} must not execute ai_try_consume`);
  await assert.rejects(db.query('select * from public.ai_usage'),{code:'42501'},`${role} must not read ai_usage`);
  await assert.rejects(db.query('select * from public.ai_config'),{code:'42501'},`${role} must not read ai_config`);
  await db.exec('reset role');
}
await db.exec('set role service_role');
assert.equal((await db.query('select public.ai_try_consume($1, 5) as ok',[probe])).rows[0].ok, true, 'service_role still consumes the cap');
// 0004가 바꾼 건 ON CONFLICT 분기(search_path '')다 — 캡까지 증가하고 캡에서 false, 카운트는 캡을 넘지 않는다.
for (let i=2;i<=5;i++) {
  assert.equal((await db.query('select public.ai_try_consume($1, 5) as ok',[probe])).rows[0].ok, true, `call ${i} within cap`);
}
assert.equal((await db.query('select public.ai_try_consume($1, 5) as ok',[probe])).rows[0].ok, false, 'cap exceeded returns false');
assert.equal((await db.query('select count from public.ai_usage where user_id=$1',[probe])).rows[0].count, 5, 'rejected call does not increment');
await db.exec('reset role');
await db.query('delete from public.ai_usage where user_id=$1',[probe]);
const a='00000000-0000-0000-0000-000000000001';
const b='00000000-0000-0000-0000-000000000002';
const c='00000000-0000-0000-0000-000000000003';
for (const id of [a,b,c]) {
  await db.query('insert into auth.users values ($1)',[id]);
  await db.query("insert into auth.identities values ($1, 'email')",[id]);
  await db.query('insert into public.ai_usage values ($1, current_date, 1)',[id]);
  await db.query(`insert into public.analytics_events
    (user_id,install_id,session_id,seq,name,occurred_at)
    values ($1,$1,$1,1,'screen_view',now())`,[id]);
}
await db.exec('set role anon');
await assert.rejects(db.query('select public.delete_own_account()'),{code:'42501'});
await db.exec('reset role');
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[a]);
await db.query("select set_config('request.jwt.claim.role','authenticated',false)");
await db.exec('set role authenticated');
await assert.rejects(db.query('select public.delete_own_account($1)',[b]),{code:'42883'});
await db.query('select public.delete_own_account()');
await db.query('select public.delete_own_account()'); // lost-response retry
await assert.rejects(db.query(`insert into public.analytics_events
  (install_id,session_id,seq,name,occurred_at) values ($1,$1,2,'screen_view',now())`,[a]));
await db.exec('reset role');
for (const table of ['auth.users','auth.identities','public.analytics_events','public.ai_usage']) {
  const rows=(await db.query(`select count(*)::int as n from ${table}`)).rows;
  assert.equal(rows[0].n,2,table+' must retain the other two users');
}
// Force a failure after analytics deletion and ensure the entire RPC rolls back.
await db.exec(`create function auth.fail_delete() returns trigger language plpgsql as $$
  begin raise exception 'injected failure'; end; $$;
  create trigger fail_delete before delete on auth.users for each row execute function auth.fail_delete();`);
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[b]);
await db.exec('set role authenticated');
await assert.rejects(db.query('select public.delete_own_account()'));
await db.exec('reset role');
assert.equal((await db.query('select count(*)::int as n from public.analytics_events')).rows[0].n,2);
assert.equal((await db.query('select count(*)::int as n from public.ai_usage')).rows[0].n,2);
await db.exec('drop trigger fail_delete on auth.users');
await db.query("update auth.identities set provider='apple' where user_id=$1",[c]);
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[c]);
await db.exec('set role authenticated');
await assert.rejects(db.query('select public.delete_own_account()'));
await db.exec('reset role');
assert.equal((await db.query('select count(*)::int as n from auth.users')).rows[0].n,2);
await db.close();
console.log('PASS: anonymous denial, caller isolation, own data deletion, retry, deleted-JWT rejection, transaction rollback, Apple revocation guard, 0004 client-role grant revocation');
