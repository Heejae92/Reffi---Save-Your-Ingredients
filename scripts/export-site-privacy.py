#!/usr/bin/env python3
"""Export the app's English privacy review draft without changing its wording."""
import html
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
source = (root / "Reffi/Features/MyPage/PrivacyView.swift").read_text()
literal = r'"(?:[^"\\]|\\.)*"'
sections = re.findall(r"section\((" + literal + r"), (" + literal + r")\)", source)
intro = re.findall(r"Text\((" + literal + r")\)", source.split('section("Who operates Reffi"')[0])
links = re.findall(r"Link\((" + literal + r"), destination: URL\(string: (" + literal + r")", source)
def text(value):
    return html.escape(json.loads(value))

content = "\n".join("<p>" + text(value) + "</p>" for value in intro)
content += "\n" + "\n".join("<section><h2>" + text(title) + "</h2><p>" + text(body) + "</p></section>" for title, body in sections)
content += '<h2>Privacy resources</h2><ul>' + "".join('<li><a href="' + text(url) + '">' + text(title) + '</a></li>' for title, url in links) + '</ul>'
page = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Reffi app privacy policy | Review draft</title>
<style>
* { box-sizing: border-box; }
body { margin: 0; background: #f8f5ec; color: #25211b; font: 1rem/1.7 system-ui, sans-serif; }
main { max-width: 48rem; margin: auto; padding: 2rem 1.25rem 4rem; overflow-wrap: anywhere; }
h1 { font-size: 2rem; line-height: 1.2; } h2 { margin-top: 2rem; font-size: 1.25rem; line-height: 1.4; }
a { color: #176ab0; text-underline-offset: .2em; } nav a, li a, .contact { display: inline-block; padding: .65rem 0; }
a:focus-visible { outline: 3px solid #176ab0; outline-offset: 4px; }
</style>
</head>
<body><main>
<nav aria-label="Back"><a href="./">Back to Reffi</a></nav>
<h1>Reffi app privacy policy</h1>
""" + content + """
<p><a class="contact" href="mailto:lee1993ljm@gmail.com">Email the privacy contact</a></p>
</main></body>
</html>
"""
output = root / "site/privacy.html"
if "--check" in sys.argv:
    if not output.exists() or output.read_text() != page:
        sys.exit("Privacy export is stale. Run python3 scripts/export-site-privacy.py")
else:
    output.write_text(page)
print(f"Privacy draft: {len(sections)} sections exported from PrivacyView.swift")
