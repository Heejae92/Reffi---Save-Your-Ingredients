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
// Previous-project fixtures model the two live foreign keys without real user data.
await db.exec(`
  create table public.rejection_patterns(id uuid primary key);
  create table public.rejection_submissions(matched_pattern_id uuid references public.rejection_patterns(id));
  create table public.feedback(id uuid primary key);
  create table public.onboarding_responses(id uuid primary key);
  create table public.user_guide_progress(user_id uuid references auth.users(id) on delete cascade);
`);
const migration = (file) => readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8');
for (const file of ['0001_ai_recipe.sql','0002_analytics.sql','0003_account_deletion.sql','0004_remove_previous_project.sql']) {
  await db.exec(await migration(file));
}
for (const table of ['rejection_patterns','rejection_submissions','feedback','onboarding_responses','user_guide_progress']) {
  assert.equal((await db.query('select to_regclass($1) as relation', ['public.' + table])).rows[0].relation, null);
}
// Re-running the cleanup must be safe after its targets are gone.
await db.exec(await readFile(new URL('../supabase/migrations/0004_remove_previous_project.sql', import.meta.url), 'utf8'));
const probe='00000000-0000-0000-0000-0000000000ff';
// 0004 이전 상태 재현(2026-09-07 실서버 실측과 동일): anon 키만으로 캡 RPC 실행·AI 테이블 SELECT 가능.
// 관찰만 한다(단언 아님): 0001의 revoke를 나중에 고치면 여기가 false로 바뀌는 게 정상이다.
console.log('pre-0004 anon EXECUTE on ai_try_consume:',
  (await db.query("select has_function_privilege('anon','public.ai_try_consume(uuid,int)','EXECUTE') as ok")).rows[0].ok);
console.log('pre-0004 anon SELECT on ai_usage:',
  (await db.query("select has_table_privilege('anon','public.ai_usage','SELECT') as ok")).rows[0].ok);
await db.exec(await migration('0005_harden_client_grants.sql'));

// 일반 단언 — public/analytics 스키마에서 anon/authenticated가 가진 권한은 아래 허용 목록뿐이어야 한다.
// 이름을 박은 단언과 달리 앞으로 추가되는 객체가 0001처럼 기본 권한으로 열린 채 남는 것을 잡는다.
async function clientGrants() {
  const fns = (await db.query(`
    select n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' as obj, r.rolname as role
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      cross join (values ('anon'),('authenticated')) as r(rolname)
     where n.nspname in ('public','analytics')
       and has_function_privilege(r.rolname, p.oid, 'EXECUTE')`)).rows;
  const tables = (await db.query(`
    select n.nspname||'.'||c.relname as obj, r.rolname as role, priv
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      cross join (values ('anon'),('authenticated')) as r(rolname)
      cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) as p(priv)
     where n.nspname in ('public','analytics') and c.relkind in ('r','v','m','p')
       and (has_table_privilege(r.rolname, c.oid, priv)
            or (priv <> 'DELETE' and has_any_column_privilege(r.rolname, c.oid, priv)))`)).rows;
  return [...fns.map(x=>`${x.role} EXECUTE ${x.obj}`), ...tables.map(x=>`${x.role} ${x.priv} ${x.obj}`)].sort();
}
const allowedClientGrants = [
  'authenticated EXECUTE public.delete_own_account()',
  'authenticated EXECUTE public.has_active_account()',
  'authenticated INSERT public.analytics_events',
];
assert.deepEqual(await clientGrants(), allowedClientGrants, 'client roles hold only the allow-listed privileges');
for (const role of ['anon','authenticated']) {
  assert.equal((await db.query("select has_schema_privilege($1,'analytics','USAGE') as ok",[role])).rows[0].ok, false,
    `${role} must not reach the analytics schema`);
}
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

// 재실행 계약: 네 파일을 순서대로 다시 돌려도(0001이 search_path를 되돌린 뒤 0004가 다시 닫음) 같은 상태.
for (const file of ['0001_ai_recipe.sql','0002_analytics.sql','0003_account_deletion.sql','0005_harden_client_grants.sql']) {
  await db.exec(await migration(file));
}
assert.deepEqual(await clientGrants(), allowedClientGrants, 'grants unchanged after re-running all migrations');
assert.equal((await db.query(`select coalesce(array_to_string(proconfig, ','), '') as cfg
  from pg_proc where oid = 'public.ai_try_consume(uuid,int)'::regprocedure`)).rows[0].cfg, 'search_path=""', 'search_path stays empty after re-run');
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
console.log('PASS: account deletion, cleanup, client-role grant allow-list and migration retry');
