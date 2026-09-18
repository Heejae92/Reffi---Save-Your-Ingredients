#!/usr/bin/env python3
"""Build the Korean landing page (site/ko/index.html) from the English page (site/index.html).

The English page is the source of truth for markup, styles and the inline hero script. This script
swaps every visible string through the table below, points relative asset paths at the site root,
and rewrites the SEO head (lang, canonical, og:locale/url, hreflang) for /ko/. Every source string
must be found exactly as often as expected, so a copy change on the English page fails loudly here
instead of silently shipping a half-translated page.

    python3 scripts/build-site-ko.py            # write site/ko/index.html
    python3 scripts/build-site-ko.py --check    # exit 1 if site/ko/index.html is stale
"""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "site" / "index.html"
DST = ROOT / "site" / "ko" / "index.html"
BASE = "https://reffi-site.vercel.app"

# Pretendard (OFL) — the app's body face. Pinned to the v1.3.9 commit; the dynamic-subset CSS only
# pulls the glyph ranges a page actually uses. Font files resolve relative to this same pinned path.
PRETENDARD_CSS = ("https://cdn.jsdelivr.net/gh/orioncactus/pretendard@5c41199ea0024a9e0b2cb31735265056e5472d76"
                  "/dist/web/static/pretendard-dynamic-subset.min.css")

# (english, korean, expected occurrences). Order matters where one string contains another.
STRINGS: list[tuple[str, str, int]] = [
    # head + shared taglines
    ("Reffi | Eat it today, waste nothing.", "Reffi | 오늘 먹고, 버리지 않아요.", 3),
    ("Reffi turns your grocery receipt into a fridge that counts down. Eat it today, waste nothing.",
     "Reffi는 장본 영수증을 소비기한이 카운트다운되는 냉장고로 바꿔요. 오늘 먹고, 버리지 않아요.", 4),
    ('<meta property="og:locale" content="en_US">', '<meta property="og:locale" content="ko_KR">', 1),
    ("Reffi: a fridge list that counts down to each use-by date", "Reffi: 소비기한까지 남은 날을 세어 주는 냉장고 목록", 1),
    # header
    ('aria-label="Reffi Home"', 'aria-label="Reffi 홈"', 1),
    ('alt="Reffi logo"', 'alt="Reffi 로고"', 2),
    (">How it works<", ">이렇게 써요<", 1),
    (">Features<", ">기능<", 1),
    (">FAQ<", ">자주 묻는 질문<", 2),
    ('<a href="/ko/" class="tab lang-switch" hreflang="ko" lang="ko">한국어</a>',
     '<a href="/" class="tab lang-switch" hreflang="en" lang="en">English</a>', 1),
    # hero
    (">IPHONE APP FOR YOUR FRIDGE<", ">냉장고를 위한 아이폰 앱<", 1),
    ("Eat it today,<br>waste nothing.", "오늘 먹고,<br>버리지 않아요.", 1),
    (">Free on the App Store for iPhone.<", ">App Store에서 무료로 만나요.<", 1),
    ("Reffi turns your grocery receipt into a fridge that counts down. When something is about to turn, it hands you recipe tickets that use it first.",
     "Reffi는 장본 영수증을 소비기한이 카운트다운되는 냉장고로 바꿔요. 재료가 상하기 직전이면, 그 재료를 먼저 쓰는 레시피 티켓을 건네요.", 1),
    (">Download on the App Store</a>", ">App Store에서 다운로드</a>", 2),
    ('alt="Tomato"', 'alt="토마토"', 1), ('alt="Mushroom"', 'alt="버섯"', 1), ('alt="Broccoli"', 'alt="브로콜리"', 1),
    ('alt="Avocado"', 'alt="아보카도"', 1), ('alt="Meat"', 'alt="고기"', 1), ('alt="Apple"', 'alt="사과"', 1),
    ('alt="Pepper"', 'alt="파프리카"', 1), ('alt="Eggplant"', 'alt="가지"', 1),
    # stats
    ('aria-label="Reffi Statistics"', 'aria-label="Reffi 숫자"', 1),
    (">built-in recipes<", ">기본 레시피<", 1),
    (">cuisines<", ">나라의 요리<", 1),
    (">ingredients in the dictionary<", ">사전에 등록된 재료<", 1),
    # sound familiar
    (">Sound familiar?<", ">이런 적 있죠?<", 1),
    (">Groceries you forgot are money in the trash.<", ">잊어버린 식재료는 그대로 버려지는 돈이에요.<", 1),
    (">Living alone<", ">1인 가구<", 1),
    (">I buy for the week and cook twice.<", ">일주일치 장을 보고 요리는 두 번 해요.<", 1),
    (">Busy couples<", ">바쁜 맞벌이<", 1),
    (">Nobody knows what is in the back of the fridge.<", ">냉장고 안쪽에 뭐가 있는지 아무도 몰라요.<", 1),
    (">Students<", ">학생<", 1),
    (">Typing every item into an app never lasts a week.<", ">앱에 하나하나 입력하는 건 일주일도 못 가요.<", 1),
    (">Stop guessing. Reffi logs, ranks and reminds, in one place.<", ">이제 짐작은 그만. Reffi가 기록하고, 순서를 매기고, 알려 드려요.<", 1),
    # features
    (">Log it like a receipt<", ">영수증처럼 기록해요<", 1),
    (">Receipt scan<", ">영수증 스캔<", 1), (">Photo<", ">사진<", 1), (">By hand<", ">직접 입력<", 1),
    ("Snap the receipt. Groceries land in your fridge with use-by dates filled in. Receipt text is read on this device. Receipt images are not uploaded.",
     "영수증을 찍으면 재료가 소비기한과 함께 냉장고에 들어와요. 영수증 글자는 기기 안에서 읽고, 영수증 이미지는 업로드하지 않아요.", 1),
    ('alt="Scan a receipt sheet"', 'alt="영수증 스캔 시트"', 1),
    (">A countdown you can see<", ">한눈에 보이는 카운트다운<", 1),
    (">Fresh<", ">신선<", 1), (">Soon<", ">임박<", 1), (">Urgent<", ">오늘까지<", 1),
    ("Sage means fresh, amber means soon, terracotta means today. Every color comes with a day count.",
     "초록은 신선, 노랑은 임박, 빨강은 오늘까지. 모든 색에는 남은 날수가 함께 붙어요.", 1),
    ('alt="Fridge In stock list"', 'alt="냉장고 재고 목록"', 1),
    (">Tickets for what expires first<", ">임박한 재료로 티켓을 뽑아요<", 1),
    (">Ticket deck<", ">티켓 덱<", 1), (">Cooking ticket<", ">조리 티켓<", 1), (">How to cook<", ">조리법<", 1),
    ("Tap Start cooking and a deck of kitchen tickets appears, ranked by what spoils first. Flick right to cook, left to pass.",
     "요리 시작을 누르면 임박한 순서로 정렬된 주방 티켓이 펼쳐져요. 오른쪽으로 넘기면 요리하고, 왼쪽으로 넘기면 건너뛰어요.", 1),
    ('alt="The ticket deck"', 'alt="티켓 덱"', 1),
    (">Your weekly tally<", ">이번 주 정산<", 1),
    (">Daily chips<", ">하루 한 칩<", 1), (">Waste rate<", ">낭비율<", 1), (">Streak<", ">연속 기록<", 1),
    ("A chip a day. Green is what you ate. See your eaten rate against last week and what you toss most.",
     "하루에 칩 하나. 초록은 먹은 것이에요. 지난주와 비교한 소비율과 가장 많이 버리는 재료를 확인해요.", 1),
    ('alt="Kitchen ledger history screen"', 'alt="주방 장부 기록 화면"', 1),
    (">One quiet alert a day<", ">하루 한 번, 조용한 알림<", 1),
    (">Morning alert<", ">아침 알림<", 1), (">Tomorrow<", ">내일<", 1), (">Freezer<", ">냉동실<", 1),
    ("Once a day, only when something is expiring. Default 9 AM, yours to change.",
     "하루 한 번, 상할 재료가 있을 때만. 기본은 아침 9시, 원하는 시간으로 바꿀 수 있어요.", 1),
    ('alt="Home screen with the Morning alerts card"', 'alt="아침 알림 카드가 있는 홈 화면"', 1),
    # core values
    (">Core values<", ">우리가 지키는 것<", 1),
    (">Waste nothing<", ">버리지 않기<", 1),
    (">Food you already bought is the first ingredient.<", ">이미 산 식재료가 첫 번째 재료예요.<", 1),
    (">Act today<", ">오늘 하기<", 1),
    (">One clear thing to do now beats a long list for later.<", ">나중에 할 긴 목록보다 지금 할 한 가지가 나아요.<", 1),
    (">Clarity and honesty<", ">분명하고 정직하게<", 1),
    (">Color means freshness, and every color comes with a label.<", ">색은 신선도를 뜻하고, 모든 색에는 글자 라벨이 함께 붙어요.<", 1),
    (">Your fridge stays on your phone<", ">냉장고는 내 폰 안에<", 1),
    ("Receipt images stay on your phone. Signing in and optional usage sharing involve separate server processing.",
     "영수증 이미지는 폰에만 남아요. 로그인과 선택적 사용 데이터 공유는 별도의 서버 처리를 거쳐요.", 1),
    # faq
    (">Which phones?<", ">어떤 기기에서 쓸 수 있나요?<", 1),
    (">iPhone with iOS 18 or later.<", ">iOS 18 이상 아이폰이에요.<", 1),
    (">Is it free?<", ">무료인가요?<", 1),
    (">Yes. Reffi is free on the App Store, and there is nothing to sign up for.<",
     ">네. Reffi는 App Store에서 무료이고, 가입할 것도 없어요.<", 1),
    (">Do I need an account?<", ">계정이 필요한가요?<", 1),
    (">No. Reffi works without an account, and your fridge stays on your phone.<",
     ">아니요. 계정 없이 쓸 수 있고, 냉장고 정보는 폰에만 남아요.<", 1),
    (">Where do the recipes come from?<", ">레시피는 어디서 오나요?<", 1),
    ("A curated library of over 250 recipes from 12 cuisines plus your own, ranked by what spoils first. Reffi does not generate recipes with AI.",
     "12개 나라 요리 250여 개를 골라 담은 레시피와 직접 등록한 레시피를 임박한 재료 기준으로 정렬해요. AI로 레시피를 만들어 내지 않아요.", 1),
    # final cta + footer
    (">Start with the fridge you already have.<", ">지금 있는 냉장고로 시작하세요.<", 1),
    (">Download Reffi and cook what is about to turn, first.<", ">Reffi를 내려받고 임박한 재료부터 요리하세요.<", 1),
    (">Eat it today, waste nothing.<", ">오늘 먹고, 버리지 않아요.<", 1),
    ('<a href="/privacy.html">Privacy Policy</a>', '<a href="/privacy.html#ko">개인정보 처리방침</a>', 1),
]

# Structural rewrites (paths and SEO head), applied after the string table.
REWRITES: list[tuple[str, str, int]] = [
    ('<html lang="en">', '<html lang="ko">', 1),
    # Korean storefront for the two CTA buttons and the JSON-LD download/install URLs
    ("https://apps.apple.com/us/app/reffi-save-your-ingredients/id6795009532", "https://apps.apple.com/kr/app/id6795009532", 4),
    ('src="resources/', 'src="/resources/', -1),            # -1 = at least one
    (f'<link rel="canonical" href="{BASE}/">', f'<link rel="canonical" href="{BASE}/ko/">', 1),
    (f'<meta property="og:url" content="{BASE}/">', f'<meta property="og:url" content="{BASE}/ko/">', 1),
    (f'<meta property="og:image" content="{BASE}/og-image.png">', f'<meta property="og:image" content="{BASE}/og-image-ko.png">', 1),
    (f'<meta name="twitter:image" content="{BASE}/og-image.png">', f'<meta name="twitter:image" content="{BASE}/og-image-ko.png">', 1),
    (f'"url": "{BASE}/",\n      "description"', f'"url": "{BASE}/ko/",\n      "description"', 1),
    (f'"image": "{BASE}/og-image.png"', f'"image": "{BASE}/og-image-ko.png"', 1),
    # Korean body face: Pretendard first; numerals keep Google Sans Flex (Latin digits) with Pretendard behind it.
    ("--font-body: 'Google Sans Flex', 'Pretendard Variable', Pretendard, -apple-system, 'Apple SD Gothic Neo', system-ui, sans-serif;",
     "--font-body: 'Pretendard', -apple-system, 'Apple SD Gothic Neo', system-ui, sans-serif;", 1),
    ("--font-num: 'Google Sans Flex', 'Pretendard Variable', Pretendard, system-ui, sans-serif;",
     "--font-num: 'Google Sans Flex', 'Pretendard', system-ui, sans-serif;", 1),
    ('<link href="https://fonts.googleapis.com/css2?family=Google+Sans+Flex:wght@400;500;600;700&display=swap" rel="stylesheet">',
     '<link href="https://fonts.googleapis.com/css2?family=Google+Sans+Flex:wght@400;500;600;700&display=swap" rel="stylesheet">\n'
     f'    <link href="{PRETENDARD_CSS}" rel="stylesheet">', 1),
    ("        html {\n            scroll-behavior: smooth;",
     "        /* Korean copy: keep words whole at line ends */\n        body { word-break: keep-all; }\n\n        html {\n            scroll-behavior: smooth;", 1),
]


def build(src_html: str) -> str:
    html = src_html
    for en, ko, count in STRINGS:
        found = html.count(en)
        if found != count:
            sys.exit(f"[build-site-ko] expected {count}x but found {found}x: {en[:70]!r}")
        html = html.replace(en, ko)
    for before, after, count in REWRITES:
        found = html.count(before)
        if (count == -1 and found < 1) or (count != -1 and found != count):
            sys.exit(f"[build-site-ko] expected {count}x but found {found}x: {before[:70]!r}")
        html = html.replace(before, after)
    return html


def main() -> None:
    out = build(SRC.read_text(encoding="utf-8"))
    if "--check" in sys.argv:
        if not DST.exists() or DST.read_text(encoding="utf-8") != out:
            sys.exit("[build-site-ko] site/ko/index.html is stale — run scripts/build-site-ko.py")
        print("site/ko/index.html is up to date")
        return
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(out, encoding="utf-8")
    print(f"wrote {DST.relative_to(ROOT)} ({len(out)} bytes)")


if __name__ == "__main__":
    main()
