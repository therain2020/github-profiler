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

def _compress_inline(line):
    """Strip inline markdown formatting: HTML, images, links, bold, italic, code."""
    line = re.sub(r'<[^>]+>', '', line)
    # Discard all images: [![alt](img-url)](link-url) and ![alt](url)
    line = re.sub(r'\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\)', '', line)
    line = re.sub(r'!\[[^\]]*\]\([^)]*\)', '', line)
    # Links: keep text, discard URL
    line = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', line)
    line = re.sub(r'\*\*(.+?)\*\*|__(.+?)__', r'\1\2', line)
    line = re.sub(r'\*(.+?)\*|_(.+?)_', r'\1\2', line)
    line = re.sub(r'`([^`]+)`', r'\1', line)
    return line.strip()

def _first_sentence(text):
    """Keep up to first sentence terminator (. 。! ！), or first 120 chars if no terminator."""
    m = re.search(r'[^。.!！\n]+[。.!！]', text)
    if m:
        s = m.group(0).rstrip()
        if len(s) < len(text.strip()):
            return s
    # No sentence terminator found — cap at 120 chars
    t = text.strip()
    if len(t) > 120:
        return t[:120] + '...'
    return t

def _compress_code_block(lines):
    """Keep all lines if <=8, else keep first 4 + last 2."""
    n = len(lines)
    if n <= 8:
        return [f'  | {l}' for l in lines]
    head = [f'  | {l}' for l in lines[:4]]
    tail = [f'  | {l}' for l in lines[-2:]]
    return head + [f'  | [... {n - 6} lines ...]'] + tail

def smart_compress_readme(text):
    """Compress README > 3KB: keep emphasized content (headings, lists, code, tables),
    heavily compress plain paragraphs to first sentence. Output as plaintext."""
    if len(text or '') <= 3000:
        return text

    lines = text.split('\n')
    out = []
    state = 'NORMAL'       # NORMAL | CODE_BLOCK | TABLE
    code_buf = []           # accumulate code block lines
    table_header = None     # first table row (header)
    table_rows = 0          # body row count
    pending_blank = False

    heading_re = re.compile(r'^#{1,6}\s')
    list_re = re.compile(r'^(\s*)[-*+]\s+')
    num_list_re = re.compile(r'^(\s*)\d+\.\s+')
    fence_re = re.compile(r'^\s*```')
    table_re = re.compile(r'^\|.*\|$')
    hr_re = re.compile(r'^[-*_]{3,}\s*$')
    bq_re = re.compile(r'^\s*>\s?')

    for line in lines:
        stripped = line.strip()

        # ── CODE_BLOCK state ──
        if state == 'CODE_BLOCK':
            if fence_re.match(stripped):
                out.append('[CODE]')
                out.extend(_compress_code_block(code_buf))
                out.append('')
                state = 'NORMAL'
                code_buf = []
            else:
                code_buf.append(line)
            continue

        # ── TABLE state ──
        if state == 'TABLE':
            if table_re.match(stripped):
                table_rows += 1
            else:
                out.append(f'  {_compress_inline(table_header)}')
                out.append(f'  [TABLE: {table_rows} rows]')
                out.append('')
                state = 'NORMAL'
                table_header = None
                table_rows = 0
            if state == 'TABLE':
                continue

        # ── NORMAL state ──

        # Fence start → enter CODE_BLOCK
        if fence_re.match(stripped):
            state = 'CODE_BLOCK'
            code_buf = []
            continue

        # Table row → enter TABLE
        if table_re.match(stripped):
            state = 'TABLE'
            table_header = stripped
            table_rows = 0
            continue

        # Heading
        if heading_re.match(stripped):
            if pending_blank:
                out.append('')
                pending_blank = False
            out.append(_compress_inline(re.sub(r'^#{1,6}\s+', '', stripped)))
            out.append('')
            continue

        # List item
        lm = list_re.match(line) or num_list_re.match(line)
        if lm:
            indent = '  ' * (len(lm.group(1)) // 2 + 1)
            content = _compress_inline(line[lm.end():])
            out.append(f'{indent}{content}')
            pending_blank = False
            continue

        # Blockquote
        if bq_re.match(stripped):
            content = _compress_inline(bq_re.sub('', stripped))
            out.append(f'"{content}"')
            pending_blank = False
            continue

        # Horizontal rule
        if hr_re.match(stripped):
            continue

        # Blank line
        if stripped == '':
            pending_blank = True
            continue

        # Paragraph — first sentence only
        if pending_blank:
            out.append('')
            pending_blank = False
        compressed = _compress_inline(stripped)
        if compressed:
            s = _first_sentence(compressed)
            out.append(s)

    # Drain pending TABLE
    if state == 'TABLE' and table_header:
        out.append(f'  {_compress_inline(table_header)}')
        out.append(f'  [TABLE: {table_rows} rows]')
    # Drain pending CODE_BLOCK (unclosed fence — keep as plain)
    if state == 'CODE_BLOCK' and code_buf:
        out.append('[CODE]')
        out.extend(_compress_code_block(code_buf))

    return '\n'.join(out).strip()

def compact_readmes(data):
    """Smart-compress READMEs > 3KB in deep_dive: keep emphasized, compress paragraphs."""
    for repo in data.get('deep_dive', []):
        if not repo:
            continue
        text = repo.get('readme', '') or ''
        if text:
            compressed = smart_compress_readme(text)
            repo['readme'] = compressed
            if compressed != text:
                repo.setdefault('quality', {})['_compressed'] = True

def compact_commits(data):
    """Keep only headline (first line) of commit messages."""
    for repo in data.get('deep_dive', []):
        if not repo:
            continue
        for c in repo.get('commits', []):
            msg = c.get('message', '')
            if '\n' in msg:
                c['message'] = msg.split('\n')[0]

def compact_repositories(data):
    """Drop derivable fields: html_url, full_name, pushed_at."""
    for repo in data.get('repositories', []):
        if not repo:
            continue
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
