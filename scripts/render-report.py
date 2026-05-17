#!/usr/bin/env python3
"""render-report.py v3 — Fill HTML templates with prompt v3 JSON output."""
import json, sys, os
from pathlib import Path
from datetime import datetime

data_file = sys.argv[1]
mode = sys.argv[2]  # scorer | distill | optimize
output = sys.argv[3] if len(sys.argv) > 3 else None

data = json.load(open(data_file, encoding='utf-8'))
project = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
template = (project / 'templates' / f'{mode}-report.html').read_text(encoding='utf-8')

# ── Shared data ──
username = data.get('username') or data.get('meta', {}).get('username', 'unknown')
ts = datetime.now().strftime('%Y%m%d-%H%M%S')
if not output:
    output = str(project / 'reports' / f'{username}-{mode}-{ts}.html')

cal_data = data.get('contributions', {}).get('calendar', {}).get('active_days', [])
cal_max = max((c for _, c in cal_data), default=1)

lang_counts = {}
for r in data.get('repositories', []):
    l = r.get('language') or 'Unknown'
    lang_counts[l] = lang_counts.get(l, 0) + 1
lang_data = [{'name': k, 'value': v} for k, v in sorted(lang_counts.items(), key=lambda x: -x[1])]

repl = {
    '{{USERNAME}}': username,
    '{{CALENDAR_DATA}}': json.dumps(cal_data),
    '{{CALENDAR_MAX}}': str(cal_max),
    '{{CALENDAR_RANGE}}': json.dumps(["2025-05-17", "2026-05-17"]),
    '{{LANGUAGE_DATA}}': json.dumps(lang_data),
}

# ── Quality radar (mean across all deep_dive repos) ──
quality_raw = {'has_readme': [], 'commit_count': [], 'avg_commit_msg_len': [], 'issue_count': [], 'readme_bytes': []}
for q in data.get('deep_dive', []):
    qm = q.get('quality', {})
    quality_raw['has_readme'].append(qm.get('has_readme', 0))
    quality_raw['commit_count'].append(min(qm.get('commit_count', 0) * 100 // 30, 100))
    quality_raw['avg_commit_msg_len'].append(min(qm.get('avg_commit_msg_len', 0) * 100 // 60, 100))
    quality_raw['issue_count'].append(min(qm.get('issue_count', 0) * 100 // 10, 100))
    quality_raw['readme_bytes'].append(min(qm.get('readme_bytes', 0) * 100 // 5000, 100))
n_repos = max(len(quality_raw['has_readme']), 1)
quality_data = [{
    'name': '10仓库均值',
    'value': [
        sum(quality_raw['has_readme']) // n_repos,
        sum(quality_raw['commit_count']) // n_repos,
        sum(quality_raw['avg_commit_msg_len']) // n_repos,
        sum(quality_raw['issue_count']) // n_repos,
        sum(quality_raw['readme_bytes']) // n_repos,
    ]
}]
repl['{{QUALITY_DATA}}'] = json.dumps(quality_data)

# ════════════════════════════════════════════════════════════════════
# SCORER mode
# ════════════════════════════════════════════════════════════════════
if mode == 'scorer':
    dims = data.get('dimension_scores', {})
    overall = data.get('overall_score', 0) or round(data.get('composite_score', 0) * 20)  # legacy 1-5→0-100
    summary = data.get('summary', {})
    viz = data.get('visualization_data', {})
    # legacy fallback: construct dims from old individual scores
    if not dims:
        legacy = {k: round(data.get(f'{k}_score', 0) * 20) for k in ['tech','engineering','collab','influence']}
        if legacy['tech']: dims = legacy

    # Score ring offset (circumference 515)
    ring_off = round(515 * (1 - overall / 100), 1)

    # Grade
    if overall >= 90: grade, color, desc = 'S+', '#6366f1', '世界级'
    elif overall >= 75: grade, color, desc = 'A', '#10b981', '优秀'
    elif overall >= 60: grade, color, desc = 'B', '#f59e0b', '良好'
    elif overall >= 40: grade, color, desc = 'C', '#f97316', '中等'
    else: grade, color, desc = 'D', '#ef4444', '需要努力'

    # 6 dimension bars
    dim_labels = {
        'productivity': '代码生产力', 'influence': '社区影响力',
        'quality': '工程质量', 'collaboration': '协作贡献',
        'knowledge_sharing': '知识分享', 'growth_potential': '成长潜力'
    }
    dim_colors = ['#d4451a','#c27803','#2a7d4f','#2563eb','#8b5cf6','#ec4899']
    dim_bars = ''
    for i, (key, label) in enumerate(dim_labels.items()):
        v = dims.get(key, 0)
        dim_bars += f'<div class="dim-row"><span class="dim-name">{label}</span><div class="dim-bar-bg"><div class="dim-bar-fill" style="width:{v}%;background:{dim_colors[i]}"></div></div><span class="dim-val">{v}</span></div>'

    # Strengths / weaknesses (v3 dict or legacy string)
    if isinstance(summary, str):
        strengths_html = weaknesses_html = ''
        tagline = summary
    else:
        strengths_html = ''.join(f'<li>{s}</li>' for s in summary.get('strengths', []))
        weaknesses_html = ''.join(f'<li>{w}</li>' for w in summary.get('weaknesses', []))
        tagline = summary.get('tagline', '')

    # Activity breakdown chart data
    ab = viz.get('activity_breakdown', {})
    ab_keys = ['commits','pull_requests','issues','reviews','gists']
    ab_names = ['Commits','PRs','Issues','Reviews','Gists']
    activity_breakdown_data = json.dumps([
        {'name': n, 'value': ab.get(k, 0)} for k, n in zip(ab_keys, ab_names)
    ])

    # Top repos
    top_repos = viz.get('top_repos', [])
    top_repos_html = ''
    for r in top_repos[:5]:
        lang = r.get('language') or '—'
        top_repos_html += f'<div class="repo-card"><div class="repo-name">{r["name"]}</div><div class="repo-meta">{lang} &middot; {r["stars"]} stars &middot; {r["forks"]} forks</div></div>'

    # Commit frequency (monthly)
    cf = viz.get('commit_frequency_last_year', [])
    commit_freq_data = json.dumps([[item['month'], item['count']] for item in cf])

    repl.update({
        '{{DIM_BARS}}': dim_bars,
        '{{OVERALL_SCORE}}': str(overall),
        '{{SCORE_RING_OFFSET}}': str(ring_off),
        '{{GRADE}}': grade,
        '{{GRADE_COLOR}}': color,
        '{{GRADE_DESC}}': desc,
        '{{STRENGTHS}}': strengths_html,
        '{{WEAKNESSES}}': weaknesses_html,
        '{{TAGLINE}}': tagline,
        '{{ACTIVITY_BREAKDOWN_DATA}}': activity_breakdown_data,
        '{{TOP_REPOS}}': top_repos_html,
        '{{COMMIT_FREQ_DATA}}': commit_freq_data,
        '{{RADAR_LABELS}}': json.dumps(viz.get('radar', {}).get('labels', [])),
        '{{RADAR_VALUES}}': json.dumps(viz.get('radar', {}).get('values', [])),
    })

# ════════════════════════════════════════════════════════════════════
# DISTILL mode
# ════════════════════════════════════════════════════════════════════
elif mode == 'distill':
    ds = data.get('distilled_self', {})
    am = data.get('another_me', {})
    viz = data.get('visualization_data', {})

    # Radar
    radar = viz.get('radar', {})
    radar_dims = json.dumps(radar.get('dimensions', []))
    radar_self = json.dumps(radar.get('values', []))
    radar_other = json.dumps(radar.get('another_me_values', []))

    # Heatmap
    heatmap = viz.get('commit_heatmap', {})
    hourly = json.dumps(heatmap.get('hourly_distribution', [0]*24))
    weekday = json.dumps(heatmap.get('weekday_distribution', [0]*7))

    # Language cloud
    lang_cloud = viz.get('language_cloud', [])
    lang_cloud_data = json.dumps(lang_cloud)

    # Behavior summary
    bs = viz.get('behavior_summary', {})

    # Personality tags
    tags_html = ''.join(f'<span class="persona-tag">{t}</span>' for t in am.get('personality_tags', []))

    repl.update({
        '{{PRIMARY_LANGUAGE}}': ds.get('primary_language', ''),
        '{{TECH_ROLE}}': ds.get('tech_role', ''),
        '{{ACTIVITY_CRON}}': ds.get('activity_cron', ''),
        '{{COLLAB_STYLE}}': ds.get('collaboration_style', ''),
        '{{DOC_STYLE}}': ds.get('doc_style', ''),
        '{{EXPLORATION_SCORE}}': str(ds.get('exploration_score', 0)),
        '{{ALIAS}}': am.get('alias', ''),
        '{{REALM}}': am.get('realm', ''),
        '{{PERSONALITY_TAGS}}': tags_html,
        '{{QUOTE}}': am.get('quote', ''),
        '{{SIMILARITY}}': str(am.get('similarity', 0)),
        '{{RADAR_DIMENSIONS}}': radar_dims,
        '{{RADAR_SELF}}': radar_self,
        '{{RADAR_OTHER}}': radar_other,
        '{{HOURLY_DATA}}': hourly,
        '{{WEEKDAY_DATA}}': weekday,
        '{{LANG_CLOUD_DATA}}': lang_cloud_data,
        '{{TOTAL_COMMITS}}': str(bs.get('total_commits', 0)),
        '{{TOTAL_PRS}}': str(bs.get('total_prs', 0)),
        '{{MERGE_RATE}}': str(bs.get('merge_rate', 0)),
        '{{AVG_MSG_LEN}}': str(bs.get('avg_commit_msg_len', 0)),
        '{{REPO_COUNT}}': str(bs.get('repo_count_original', 0)),
    })

# ════════════════════════════════════════════════════════════════════
# OPTIMIZE mode
# ════════════════════════════════════════════════════════════════════
elif mode == 'optimize':
    health = data.get('overall_health_score', 0)
    viz = data.get('visualization_data', {})

    # Health ring
    ring_off = round(515 * (1 - health / 100), 1)

    # Top 3 suggestions
    top3 = data.get('top_3_priority_suggestions', [])
    difficulty_icons = {'低': '🟢', '中等': '🟡', '高': '🔴'}
    top3_html = ''
    for s in top3:
        steps = ''.join(f'<li>{step}</li>' for step in s.get('actionable_steps', []))
        diff = s.get('difficulty', '中等')
        top3_html += f'''
        <div class="suggestion-card">
          <div class="sug-header">
            <span class="sug-id">{s["id"]}</span>
            <span class="sug-category">{s["category"]}</span>
            <span class="sug-difficulty">{difficulty_icons.get(diff, '')} {diff}</span>
          </div>
          <div class="sug-title">{s["title"]}</div>
          <div class="sug-state"><strong>当前：</strong>{s["current_state"]}</div>
          <div class="sug-target"><strong>目标：</strong>{s["target_state"]}</div>
          <ol class="sug-steps">{steps}</ol>
          <div class="sug-impact">预期效果：{s["expected_impact"]}</div>
        </div>'''

    # Priority matrix
    pm = viz.get('priority_matrix', {})
    pm_data = json.dumps({
        'quick_wins': [{'name': i, 'value': [80, 20]} for i in pm.get('quick_wins', [])],
        'major_projects': [{'name': i, 'value': [80, 80]} for i in pm.get('major_projects', [])],
        'fill_ins': [{'name': i, 'value': [20, 20]} for i in pm.get('fill_ins', [])],
        'thankless_tasks': [{'name': i, 'value': [20, 80]} for i in pm.get('thankless_tasks', [])],
    })

    # Roadmap
    roadmap = viz.get('improvement_roadmap', [])
    roadmap_html = ''
    for i, phase in enumerate(roadmap):
        tasks = ''.join(f'<li>{t}</li>' for t in phase.get('tasks', []))
        roadmap_html += f'''
        <div class="roadmap-phase">
          <div class="phase-marker">{i+1}</div>
          <div class="phase-content">
            <div class="phase-title">{phase["phase"]}: {phase["focus"]}</div>
            <ul class="phase-tasks">{tasks}</ul>
          </div>
        </div>'''

    # Growth curve
    gc = viz.get('projected_growth_curve', [])
    growth_data = json.dumps([[item['month'], item['score']] for item in gc])

    # Current vs target scores
    curr_scores = viz.get('current_dimension_scores', {})
    tgt_scores = viz.get('target_dimension_scores', {})

    repl.update({
        '{{HEALTH_SCORE}}': str(health),
        '{{HEALTH_RING_OFFSET}}': str(ring_off),
        '{{TOP3_SUGGESTIONS}}': top3_html,
        '{{PRIORITY_MATRIX_DATA}}': pm_data,
        '{{ROADMAP}}': roadmap_html,
        '{{GROWTH_DATA}}': growth_data,
        '{{CURRENT_SCORES}}': json.dumps(list(curr_scores.values())),
        '{{TARGET_SCORES}}': json.dumps(list(tgt_scores.values())),
    })

# ── Fill template ──
html = template
for k, v in repl.items():
    html = html.replace(k, v)

os.makedirs(os.path.dirname(output), exist_ok=True)
Path(output).write_text(html, encoding='utf-8')
print(f'OK {output} ({len(html)} bytes)')
