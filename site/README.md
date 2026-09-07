# Reffi 소개 사이트 (정적)

Google Labs Pomelli로 만든 앱 소개 페이지의 정적 내보내기입니다. `index.html` 한 장과 `resources/` 이미지 14장으로 구성되며, 외부 의존은 Google Fonts(Story Script, Noto Sans KR)만 있습니다. 스크립트는 히어로 낙하 애니메이션용 인라인 코드 하나뿐이고, 추적·분석 코드는 없습니다.

- 원본 편집: Pomelli 웹사이트 에디터(버전 V15 기준). Pomelli에서 수정하면 이 폴더를 다시 내보내야 합니다.
- 이미지: `resources/<id>.png`는 앱에서 캡처한 재료 글리프, 워드마크, 화면 스프라이트 시트(4×3, 12프레임)입니다. 시트는 `.app-motion` CSS가 프레임 단위로 재생합니다.
- 배포: 정적 호스팅 어디서나 동작합니다. Vercel 프로젝트 `reffi-site`(heejae92)에서 https://reffi-site.vercel.app 으로 서빙 중이며, `vercel deploy --target preview`(미리보기) 또는 `--prod`(공개)로 올립니다.
- 미정: "Join the iPhone beta" 버튼은 아직 링크가 없습니다(`href="#"`). TestFlight 공개 링크가 정해지면 연결합니다.
