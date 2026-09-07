-- 0004_harden_client_grants.sql — AI 캡 RPC·AI 테이블에서 클라이언트 롤(anon/authenticated)의 잔여 권한 회수.
-- 0003_account_deletion.sql 다음에 데이터베이스 소유자(postgres)로 적용한다. 재실행 안전(idempotent).
--
-- 배경(2026-09-07 실서버 실측): 0001의 `revoke all on function public.ai_try_consume from public`은
-- PUBLIC 의사 롤의 권한만 지운다. Supabase는 public 스키마에 ALTER DEFAULT PRIVILEGES로
-- anon/authenticated/service_role에 **명시적** EXECUTE를 자동 부여하므로 그 권한이 그대로 남아,
-- publishable(anon) 키만으로 `rpc/ai_try_consume`이 200/true를 돌려줬다 — 누구나 임의 user_id의
-- 일일 캡을 소진시키고 ai_usage에 행을 무한정 넣을 수 있는 상태였다(security definer라 RLS 우회).
-- ai_usage/ai_config도 같은 이유로 테이블 GRANT가 남아 있었다(RLS 정책 0개라 행은 안 보이지만
-- 권한 거부가 아니라 빈 배열 200이 돌아온다 — RLS 한 겹만 남은 상태).
-- 0002(analytics_events)·0003(delete_own_account)은 처음부터 `from public, anon, authenticated` 꼴로
-- 올바르게 회수했고, 0001만 불완전했다. CREATE OR REPLACE는 기존 ACL을 보존하므로 0001 재실행으로는
-- 고쳐지지 않는다 — 명시적 revoke가 필요하다.

begin;

-- 1. AI 캡 RPC — Edge Function(service_role)만 호출한다.
--    본문은 0001과 같되 search_path를 비우고 참조를 스키마 한정한다(0002/0003과 같은 관례).
create or replace function public.ai_try_consume(p_user uuid, p_cap int)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  if p_cap <= 0 then
    return false;
  end if;
  insert into public.ai_usage (user_id, day, count)
  values (p_user, current_date, 1)
  on conflict (user_id, day)
  do update set count = ai_usage.count + 1
    where ai_usage.count < p_cap
  returning count into v_count;
  return v_count is not null;
end;
$$;

revoke all on function public.ai_try_consume(uuid, int) from public, anon, authenticated;
grant execute on function public.ai_try_consume(uuid, int) to service_role;

-- 2. AI 테이블 — 클라이언트 접근 없음. RLS는 켜 둔 채 GRANT까지 회수한다(방어 심층:
--    정책 하나가 잘못 추가되거나 RLS가 꺼져도 anon/authenticated는 여전히 권한 거부).
revoke all on table public.ai_config from anon, authenticated;
revoke all on table public.ai_usage  from anon, authenticated;

commit;

-- 검증(대시보드 SQL Editor, 적용 직후):
--   select p.proname, p.proacl from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname in ('ai_try_consume','delete_own_account','has_active_account');
--   select grantee, table_name, privilege_type from information_schema.role_table_grants
--    where table_schema = 'public' and table_name in ('ai_usage','ai_config','analytics_events')
--      and grantee in ('anon','authenticated');
-- 기대: ai_try_consume의 proacl에 anon=/authenticated= 항목 없음, 두 번째 쿼리는 analytics_events의
-- authenticated INSERT 한 줄만(0002) 남고 ai_usage/ai_config 행은 0건.
--
-- 참고: 기본 권한(ALTER DEFAULT PRIVILEGES) 자체는 건드리지 않는다 — 이 프로젝트에 Reffi 소유가 아닌
-- 테이블(rejection_patterns·feedback 등, docs/RELEASE_READINESS.md)이 있어 다른 서비스의 새 객체까지
-- 닫힐 수 있다. 앞으로 public에 함수를 추가할 때는 0002/0003처럼 `from public, anon, authenticated`로
-- 명시 회수한다.
