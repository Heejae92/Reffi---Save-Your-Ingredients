# Reffi 소개 사이트 (정적)

Google Labs Pomelli로 만든 앱 소개 페이지의 정적 내보내기입니다. `index.html` 한 장과 `resources/` 이미지 14장으로 구성되며, 외부 의존은 Google Fonts(Story Script, Google Sans Flex)만 있습니다. 스크립트는 히어로 낙하 애니메이션용 인라인 코드 하나뿐이고, 추적·분석 코드는 없습니다.

- 원본 편집: Pomelli 웹사이트 에디터(버전 V15 기준). Pomelli에서 수정하면 이 폴더를 다시 내보내야 합니다.
- 이미지: `resources/<id>.png`는 앱에서 캡처한 재료 글리프, 워드마크, 화면 스프라이트 시트(4×3, 12프레임)입니다. 시트는 `.app-motion` CSS가 프레임 단위로 재생합니다.
- 배포: 정적 호스팅 어디서나 동작합니다. Vercel 프로젝트 `reffi-site`(heejae92)에서 https://reffi-site.vercel.app 으로 서빙 중이며, `vercel deploy --target preview`(미리보기) 또는 `--prod`(공개)로 올립니다.
- 베타: 공개 TestFlight 링크가 확인되기 전에는 참여 버튼 대신 "See how Reffi works" 소개 링크와 준비 중 안내를 표시합니다. 공개 링크가 정해지면 두 CTA와 안내 문구를 함께 갱신합니다.
- 개인정보: `privacy.html`은 앱의 한국어와 영어 방침을 내보낸 페이지입니다. `python3 scripts/export-site-privacy.py --check`로 정본과 일치를 확인합니다. Vercel 배포는 Heejae92가 담당합니다.
- 재내보내기 시 위의 베타 안내와 Privacy 링크를 보존하고, 인라인 스크립트가 바뀌면 `vercel.json`의 CSP 해시도 다시 계산합니다.
