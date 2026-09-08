# 개인정보처리방침 확정을 위한 확인 요청

2026-09-07. 아래 내용은 발송하지 않은 문의 초안이다. 공급업체 전체 목록만으로 Reffi 이용자의 실제 처리 국가와 보관기간을 추정하지 않는다.

## Supabase에 보낼 초안

수신처: Supabase 개인정보/계약 담당 창구. [공식 개인정보처리방침](https://supabase.com/privacy)에서 최신 연락처를 확인한 뒤 보낸다.

Subject: End-user data locations and retention for a Seoul-region Auth project

We operate Reffi, a local-first iOS fridge inventory app for users in South Korea and the United States. Our Supabase project is bzzpmaeitfbbunsmjvmd, on the Free plan in ap-northeast-2 (Seoul).

New registration, login and usage collection are disabled. We retain earlier accounts for session restoration and deletion. Fridge contents, receipt images, allergy entries and user-created recipes stay on the device. Before publishing our privacy notice, could you confirm:

1. Which countries and subprocessors handle our end users' Auth data, request/security logs and support access? Please distinguish end-user data from our developer/organization account data. The June 1, 2026 subprocessor list identifies purposes but does not identify processing countries.
2. What are the retention and deletion periods for Auth/network/security logs and any infrastructure recovery copies on this plan? We have no scheduled project database backups. Does the one-day log access window indicate actual deletion, or only dashboard availability?
3. After deleting an Auth user and their application rows, which copies remain, for how long, and under which deletion or legal-retention conditions?
4. Which current DPA and transfer provisions cover these operations, and which contact should users in South Korea use for processor-related inquiries?

No authentication email is sent by this release. Please do not send any end-user records in your response.

## 운영자가 정할 항목

- 이메일 인증을 제거했으므로 SMTP 선정은 현재 출시 요건에서 제외한다. 기존 계정의 삭제 요청 절차는 유지한다.
- 방침의 문의 보관 원칙을 실제로 이행한다. 요청과 후속 대응에 더 이상 필요하지 않으면 삭제하고, 법적 보존이 필요하면 근거와 종료일을 별도로 기록한다. 확정하지 않은 90일 같은 숫자를 고지하지 않는다.
- 시행일은 2026-09-07. 홈페이지의 실제 프로젝트에 로그인 없이 읽을 수 있는 공개 개인정보처리방침 URL을 배포한다. 앱 내 전문은 오프라인에서 읽을 수 있으나 App Store Connect의 웹 URL을 대신하지 않는다.

## 근거

- [Supabase subprocessor list, June 1, 2026](https://supabase.com/legal/subprocessor-list/June-1-2026.pdf)
- [Supabase GDPR and data residency documentation](https://supabase.com/docs/guides/security/gdpr-compliance)
- [Supabase custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Apple review guidelines, privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
