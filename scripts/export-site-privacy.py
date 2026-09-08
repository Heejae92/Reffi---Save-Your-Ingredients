#!/usr/bin/env python3
"""Export bilingual policy sections from the app, preserving the static page layout."""
import html
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
source = (root / 'Reffi/Features/MyPage/PrivacyView.swift').read_text()
strings = json.loads((root / 'Reffi/Resources/Localizable.xcstrings').read_text())['strings']
literal = r'"(?:[^"\\]|\\.)*"'
sections = [(json.loads(a), json.loads(b)) for a, b in re.findall(r'section\((' + literal + r'), (' + literal + r')\)', source)]
assert len(sections) == 8

def localized(value, language):
    if language == 'en':
        return html.escape(value)
    return html.escape(strings[value]['localizations'][language]['stringUnit']['value'])

output = root / 'site/privacy.html'
page = output.read_text()
for language in ['ko', 'en']:
    content = ''.join('<h2>' + localized(title, language) + '</h2><p>' + localized(body, language) + '</p>' for title, body in sections)
    pattern = r'(<article id="' + language + r'"[^>]*>.*?)(<h2>.*?)(</article>)'
    page, count = re.subn(pattern, lambda match: match[1] + content + match[3], page, flags=re.S)
    assert count == 1
if '--check' in sys.argv:
    if page != output.read_text():
        sys.exit('Privacy export is stale. Run python3 scripts/export-site-privacy.py')
else:
    output.write_text(page)
print('Privacy policy: 8 sections in Korean and English match the app')
