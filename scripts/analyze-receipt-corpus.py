#!/usr/bin/env python3
"""Score manually annotated ingredient groups and generate a local visual review."""
import argparse
import html
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('corpus', type=Path)
args = parser.parse_args()
root = args.corpus.resolve()
manifest = json.loads((root / 'manifest.json').read_text())
run = json.loads((root / 'results.json').read_text())
results = {r['id']: r for r in run['results']}
rows = []
cards = []
escape = html.escape
for record in manifest:
    result = results[record['id']]
    groups = {tuple(sorted(i['acceptableCanonicalIDs'])) for i in record['items'] if i['acceptableCanonicalIDs']}
    expected = set().union(*map(set, groups)) if groups else set()
    candidates = result['candidates']
    found = {c['canonicalID'] for c in candidates}
    oracle = {c['canonicalID'] for c in result['oracleCandidates']}
    row = dict(id=record['id'], country=record['country'], scored=record['scored'],
               targets=len(groups), recovered=sum(bool(set(g) & found) for g in groups),
               correctCandidates=sum(c['canonicalID'] in expected for c in candidates),
               emitted=len(candidates), oracleRecovered=sum(bool(set(g) & oracle) for g in groups))
    automatic = [c for c in candidates if c.get('automatic', False)]
    row['automatic'] = len(automatic)
    row['correctAutomatic'] = sum(c['canonicalID'] in expected for c in automatic)
    quantity_truth = list(record.get('verifiedQuantities', []))
    row['automaticQuantitiesChecked'] = len(automatic) if 'verifiedQuantities' in record else 0
    row['correctAutomaticQuantities'] = 0
    for candidate in automatic:
        match = next((i for i, item in enumerate(quantity_truth)
                      if item['canonicalID'] == candidate['canonicalID'] and item['unit'] == candidate['unit']
                      and abs(item['quantity'] - candidate['quantity']) < 0.0001), None)
        if match is not None:
            row['correctAutomaticQuantities'] += 1
            quantity_truth.pop(match)
    rows.append(row)
    predicted = ''.join(f'<li class="{"ok" if c["canonicalID"] in expected else "bad"}">{escape(c["canonicalID"])} · {'자동 선택' if c.get('automatic') else '확인 필요'} · {c["quantity"]} {escape(c["unit"])}<small>{escape(c["rawLine"])}</small></li>' for c in candidates)
    manual = ''.join(f'<li>{escape(i["text"])}<small>{escape(", ".join(i["acceptableCanonicalIDs"]) or "점수 대상 밖: 미지원·불명확 항목")}</small></li>' for i in record['items'])
    cards.append(f'''<article id="{record['id']}"><h2>{record['id']} · {escape(record['description'])}</h2>
<p>{record['width']} × {record['height']} · {'정량 평가' if row['scored'] else '스트레스 사례, 집계 제외'} · 복원 {row['recovered']}/{row['targets']} · 올바른 후보 {row['correctCandidates']}/{row['emitted']}</p>
<a href="{escape(record['source_page'], quote=True)}">원본 출처</a><div class="grid"><a href="{record['path']}"><img loading="lazy" src="{record['path']}" alt="{record['id']} 영수증 원본"></a><div><h3>수작업 상품명 전사</h3><ul>{manual}</ul><h3>실제 앱 후보</h3><ul>{predicted or '<li>후보 없음</li>'}</ul><details><summary>OCR 전체 텍스트</summary><pre>{escape(chr(10).join(result['lines']))}</pre></details></div></div></article>''')
summary = {}
for country in ['ALL', 'KR', 'US']:
    selected = [r for r in rows if r['scored'] and (country == 'ALL' or r['country'] == country)]
    totals = {k: sum(r[k] for r in selected) for k in ['targets','recovered','correctCandidates','emitted','oracleRecovered','automatic','correctAutomatic','automaticQuantitiesChecked','correctAutomaticQuantities']}
    totals['images'] = len(selected)
    totals['precision'] = totals['correctCandidates'] / totals['emitted'] if totals['emitted'] else None
    totals['recall'] = totals['recovered'] / totals['targets'] if totals['targets'] else None
    summary[country] = totals
(root / 'assessment.json').write_text(json.dumps({'summary':summary,'images':rows},ensure_ascii=False,indent=2)+'\n')
all_scores = summary['ALL']
page = f'''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Reffi 영수증 실사진 평가</title><style>body{{font-family:system-ui;margin:40px auto;max-width:1100px;padding:0 24px;background:#f7f5ed;color:#243126}}h1{{font-size:36px}}article{{background:white;padding:24px;margin:28px 0;border-radius:16px}}.grid{{display:grid;grid-template-columns:1fr 1fr;gap:30px;margin-top:20px}}img{{max-width:100%;max-height:850px;object-fit:contain}}li{{margin:10px 0}}small{{display:block;color:#646a64}}.bad{{color:#a12f24}}.ok{{color:#246a42}}pre{{white-space:pre-wrap;font-size:12px}}a{{color:#165887}}@media(max-width:700px){{.grid{{grid-template-columns:1fr}}}}</style><h1>Reffi 영수증 실사진 평가</h1><p>미국 {sum(r['country'] == 'US' for r in manifest)}장 + 한국 {sum(r['country'] == 'KR' for r in manifest)}장 · 실행 {escape(run['generatedAt'])} · {escape(run['os'])}</p><p>정량 표본 {all_scores['images']}장: 후보 정밀도 {all_scores['correctCandidates']}/{all_scores['emitted']} ({(all_scores['precision'] or 0):.1%}), 재료 종류 재현율 {all_scores['recovered']}/{all_scores['targets']} ({(all_scores['recall'] or 0):.1%}).</p><p>사진 안에서 판독하고 사전에 대응시킬 수 있는 재료 종류만 점수화했습니다. 전체 식품 상품행·수량 정확도가 아닙니다. 미지원 식품과 세금·광고·결제 정보는 분모에서 제외합니다. 복합상품을 원재료로 바꾸면 오답입니다. 녹색은 재료 ID가 허용 집합에 있다는 뜻이며 수량이 정확하다는 뜻은 아닙니다. 스트레스 사례의 색상과 숫자는 거래 문맥 정답을 보장하지 않습니다.</p><p>자동 선택 후보: {all_scores['automatic']}개. 자동 선택하지 않은 항목은 이름과 수량을 확인해야 합니다. 공개 사진은 로컬 평가용으로 보관했습니다. 원본 재배포 라이선스를 일괄 확보한 데이터셋이 아닙니다.</p>{''.join(cards)}</html>'''
(root / 'index.html').write_text(page)
print(json.dumps(summary,ensure_ascii=False,indent=2))
for row in rows:
    print(row)
