#!/usr/bin/env python3
"""render-report.py — Fill HTML template with JSON data, robust against special chars."""
import json, sys, os
from pathlib import Path
from datetime import datetime

data_file = sys.argv[1]
mode = sys.argv[2]  # scorer | distill
output = sys.argv[3] if len(sys.argv) > 3 else None

data = json.load(open(data_file, encoding='utf-8'))
project = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
template = (project / 'templates' / f'{mode}-report.html').read_text(encoding='utf-8')

profile = data.get('profile', {})
username = data.get('meta', {}).get('username') or profile.get('login', 'unknown')
avatar = profile.get('avatar_url', '')
ts = datetime.now().strftime('%Y%m%d-%H%M%S')
if not output:
    output = str(project / 'reports' / f'{username}-{mode}-{ts}.html')

cal = data.get('contributions', {}).get('calendar', {})
cal_data = []
for w in cal.get('weeks', []):
    for d in w.get('days', []):
        if d.get('count', 0) > 0:
            cal_data.append([d['date'], d['count']])
cal_max = max((c for _, c in cal_data), default=1)

lang_counts = {}
for r in data.get('repositories', []):
    l = r.get('language') or 'Unknown'
    lang_counts[l] = lang_counts.get(l, 0) + 1
lang_data = [{'name': k, 'value': v} for k, v in sorted(lang_counts.items(), key=lambda x: -x[1])]

repl = {
    '{{AVATAR_URL}}': avatar,
    '{{USERNAME}}': username,
    '{{CALENDAR_DATA}}': json.dumps(cal_data),
    '{{CALENDAR_MAX}}': str(cal_max),
    '{{CALENDAR_RANGE}}': '2025-05-17-2026-05-17',
    '{{LANGUAGE_DATA}}': json.dumps(lang_data),
}

if mode == 'scorer':
    tech = data.get('tech_score', 0)
    eng = data.get('engineering_score', 0)
    collab = data.get('collab_score', 0)
    influ = data.get('influence_score', 0)
    comp = data.get('composite_score', 0)
    tags_html = ' '.join(f'<span class="tag">{t}</span>' for t in data.get('profile_tags', []))
    summary = data.get('summary', '').replace('"', '\\"')

    if comp >= 4.5: grade, color, desc = '大师级', '#6366f1', '社区领袖级别'
    elif comp >= 4.0: grade, color, desc = '优秀', '#10b981', '深度参与开源，项目质量高'
    elif comp >= 3.0: grade, color, desc = '合格', '#f59e0b', '常规使用，有项目维护经验'
    elif comp >= 2.0: grade, color, desc = '初级', '#f97316', '偶尔提交，个人小项目为主'
    else: grade, color, desc = '入门', '#ef4444', '极少公开活动'

    quality_data = []
    for q in data.get('quality', []):
        quality_data.append({
            'name': q['repo'].split('/')[-1],
            'value': [
                q.get('community', {}).get('health_percentage', 0),
                100 if q.get('community', {}).get('has_readme') else 0,
                100 if q.get('ci', {}).get('has_status_checks') else 0,
                100 if q.get('workflows', {}).get('count', 0) > 0 else 0,
                100 if q.get('deployments', {}).get('count', 0) > 0 else 0,
            ]
        })

    repl.update({
        '{{COMPOSITE_SCORE}}': str(comp),
        '{{SCORE_COLOR}}': color,
        '{{GRADE_LABEL}}': grade,
        '{{GRADE_DESC}}': desc,
        '{{TAGS}}': tags_html,
        '{{TECH_SCORE}}': str(tech),
        '{{ENGINEERING_SCORE}}': str(eng),
        '{{COLLAB_SCORE}}': str(collab),
        '{{INFLUENCE_SCORE}}': str(influ),
        '{{TECH_PCT}}': str(int(tech * 20)),
        '{{ENG_PCT}}': str(int(eng * 20)),
        '{{COLLAB_PCT}}': str(int(collab * 20)),
        '{{INFLU_PCT}}': str(int(influ * 20)),
        '{{SUMMARY}}': summary,
        '{{QUALITY_DATA}}': json.dumps(quality_data),
    })

elif mode == 'distill':
    paradigm = data.get('dna', {}).get('paradigm', {})
    paradigm_vals = [paradigm.get(k, 0) for k in ['Builder', 'Learner', 'Collector', 'Hacker', 'Explainer']]
    dom = max(paradigm.items(), key=lambda x: x[1])[0] if paradigm else 'Builder'

    followers = profile.get('followers', 0)
    if followers > 200: soc_score, soc_label = 80, '温带·有来有往'
    elif followers > 50: soc_score, soc_label = 50, '微暖·开始连接'
    elif followers > 10: soc_score, soc_label = 25, '微温·偶有涟漪'
    else: soc_score, soc_label = 5, '冰点·尚未插上温度计'

    hidden_html = ''
    for item in data.get('hidden_self', []):
        parts = item.split('—', 1) if '—' in item else item.split('→', 1)
        signal = parts[0].strip() if len(parts) > 0 else item
        insight = parts[1].strip() if len(parts) > 1 else ''
        hidden_html += f'<div class="hidden-card"><div class="signal">{signal}</div><div class="insight">{insight}</div></div>'

    rpg = data.get('rpg', {})
    rpg_icons = {'机械师': '🔧', '枪匠': '🔧', '炼金术士': '⚗️', '游侠': '🏹', '法师': '🔮', '骑士': '⚔️'}
    rpg_icon = next((v for k, v in rpg_icons.items() if k in rpg.get('class', '')), '🛠️')

    repl.update({
        '{{DISTILLATE}}': data.get('distillate', ''),
        '{{NATIVE_LANGUAGE}}': data.get('dna', {}).get('native_language', ''),
        '{{DOMINANT_PARADIGM}}': dom,
        '{{SOCIAL_TEMPERATURE}}': data.get('dna', {}).get('social_temperature', ''),
        '{{PERSONA}}': data.get('persona', ''),
        '{{PARADIGM_VALUES}}': ','.join(str(v) for v in paradigm_vals),
        '{{SOCIAL_SCORE}}': str(soc_score),
        '{{SOCIAL_LABEL}}': soc_label,
        '{{HIDDEN_SELF_CARDS}}': hidden_html,
        '{{RPG_ICON}}': rpg_icon,
        '{{RPG_CLASS}}': rpg.get('class', ''),
        '{{RPG_LEVEL}}': rpg.get('level', ''),
        '{{SKILL_MAJOR}}': rpg.get('skill_tree', {}).get('major', ''),
        '{{SKILL_MINOR}}': rpg.get('skill_tree', {}).get('minor', ''),
        '{{SKILL_HIDDEN}}': rpg.get('skill_tree', {}).get('hidden', ''),
        '{{TREASURE}}': rpg.get('inventory', {}).get('treasure', ''),
        '{{HIDDEN_GEM}}': rpg.get('inventory', {}).get('hidden_gem', ''),
        '{{PARTY_STATUS}}': rpg.get('party_status', ''),
        '{{MAIN_QUEST}}': rpg.get('main_quest', ''),
    })

html = template
for k, v in repl.items():
    html = html.replace(k, v)

os.makedirs(os.path.dirname(output), exist_ok=True)
Path(output).write_text(html, encoding='utf-8')
print(f'OK {output} ({len(html)} bytes)')
