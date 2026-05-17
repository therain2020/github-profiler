"""_extract.py — Compact GitHub data: strip noise, keep signal."""
import json, sys, re

def compact_activity(data):
    """Trim timestamps to date-only, remove redundant merged bool, dedupe closed_at."""
    for section in ('pull_requests', 'issues'):
        obj = data.get('activity', {}).get(section, {})
        for item in obj.get('items', []):
            for field in ('created_at', 'merged_at', 'closed_at'):
                if item.get(field) and len(item[field]) > 10:
                    item[field] = item[field][:10]
            item.pop('merged', None)

def compact_contributions(data):
    """Drop color, drop zero-count days, flatten to active_days."""
    cal = data.get('contributions', {}).get('calendar', {})
    active_days = []
    for week in cal.get('weeks', []):
        for day in week.get('days', []):
            c = day.get('count', 0)
            if c > 0:
                active_days.append([day['date'], c])
    cal['active_days'] = active_days
    cal.pop('weeks', None)

def trim_readme(text):
    """For README > 3KB: keep title line, heading skeleton, first+last paragraphs."""
    if len(text or '') <= 3000:
        return text

    lines = text.split('\n')
    heading_re = re.compile(r'^#{1,4}\s')
    result = []
    intro_done = False

    for line in lines:
        if not intro_done:
            result.append(line)
            if len(''.join(result)) >= 100:
                intro_done = True
        if heading_re.match(line.strip()):
            result.append(line)

    tail = []
    for line in reversed(lines):
        if line.strip() == '':
            if tail:
                break
        else:
            tail.insert(0, line)
            if len(''.join(tail)) > 300:
                break

    result.append('')
    result.append('[...]')
    result.extend(tail)
    return '\n'.join(result)

def compact_readmes(data):
    """Trim READMEs > 3KB in deep_dive."""
    for repo in data.get('deep_dive', []):
        text = repo.get('readme', '')
        if text:
            repo['readme'] = trim_readme(text)

def compact_commits(data):
    """Keep only headline (first line) of commit messages."""
    for repo in data.get('deep_dive', []):
        for c in repo.get('commits', []):
            msg = c.get('message', '')
            if '\n' in msg:
                c['message'] = msg.split('\n')[0]

def compact_repositories(data):
    """Drop derivable fields: html_url, full_name, pushed_at."""
    for repo in data.get('repositories', []):
        repo.pop('html_url', None)
        repo.pop('full_name', None)
        repo.pop('pushed_at', None)

def main():
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    with open(input_path, encoding='utf-8') as f:
        data = json.load(f)
    compact_activity(data)
    compact_contributions(data)
    compact_readmes(data)
    compact_commits(data)
    compact_repositories(data)
    data['meta']['version'] = '2.2.1-extract'
    if output_path:
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    else:
        json.dump(data, sys.stdout, ensure_ascii=False, separators=(',', ':'))

if __name__ == '__main__':
    main()
