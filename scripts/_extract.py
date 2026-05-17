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

# ── Smart README compression: module-level compiled patterns ──
_RE_HTML = re.compile(r'<[^>]+>')
_RE_LINKED_IMG = re.compile(r'\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\)')
_RE_IMG = re.compile(r'!\[[^\]]*\]\([^)]*\)')
_RE_LINK = re.compile(r'\[([^\]]+)\]\([^)]+\)')
_RE_BOLD = re.compile(r'\*\*(.+?)\*\*|__(.+?)__')
_RE_ITALIC = re.compile(r'\*(.+?)\*|_(.+?)_')
_RE_INLINE_CODE = re.compile(r'`([^`]+)`')
_RE_SENTENCE = re.compile(r'[^。.!！\n]+[。.!！]')
_RE_HEADING = re.compile(r'^#{1,6}\s')
_RE_HEADING_STRIP = re.compile(r'^#{1,6}\s+')
_RE_LIST = re.compile(r'^(\s*)[-*+]\s+')
_RE_NUM_LIST = re.compile(r'^(\s*)\d+\.\s+')
_RE_FENCE = re.compile(r'^\s*```')
_RE_TABLE = re.compile(r'^\|.*\|$')
_RE_HR = re.compile(r'^[-*_]{3,}\s*$')
_RE_BQ = re.compile(r'^\s*>\s?')

_README_THRESHOLD = 3000
_CODE_MAX_LINES = 8
_CODE_HEAD = 4
_CODE_TAIL = 2
_SENTENCE_MAX_CHARS = 120

def _compress_inline(line):
    """Strip inline markdown formatting: HTML, images, links, bold, italic, code."""
    line = _RE_HTML.sub('', line)
    line = _RE_LINKED_IMG.sub('', line)
    line = _RE_IMG.sub('', line)
    line = _RE_LINK.sub(r'\1', line)
    line = _RE_BOLD.sub(r'\1\2', line)
    line = _RE_ITALIC.sub(r'\1\2', line)
    line = _RE_INLINE_CODE.sub(r'\1', line)
    return line.strip()

def _first_sentence(text):
    """Keep up to first sentence terminator, or cap at max chars if no terminator."""
    m = _RE_SENTENCE.search(text)
    if m:
        s = m.group(0).rstrip()
        if len(s) < len(text.strip()):
            return s
    t = text.strip()
    if len(t) > _SENTENCE_MAX_CHARS:
        return t[:_SENTENCE_MAX_CHARS] + '...'
    return t

def _compress_code_block(lines):
    """Keep all lines if short, else keep head + tail."""
    n = len(lines)
    if n <= _CODE_MAX_LINES:
        return [f'  | {l}' for l in lines]
    head = [f'  | {l}' for l in lines[:_CODE_HEAD]]
    tail = [f'  | {l}' for l in lines[-_CODE_TAIL:]]
    return head + [f'  | [... {n - _CODE_HEAD - _CODE_TAIL} lines ...]'] + tail

def smart_compress_readme(text):
    """Compress README > 3KB: keep emphasized content, compress paragraphs to first sentence."""
    if len(text or '') <= _README_THRESHOLD:
        return text

    lines = text.split('\n')
    out = []
    state = 'NORMAL'
    code_buf = []
    table_header = None
    table_rows = 0
    pending_blank = False

    for line in lines:
        if state == 'CODE_BLOCK':
            if _RE_FENCE.match(line.strip()):
                out.append('[CODE]')
                out.extend(_compress_code_block(code_buf))
                out.append('')
                state = 'NORMAL'
                code_buf = []
            else:
                code_buf.append(line)
            continue

        if state == 'TABLE':
            if _RE_TABLE.match(line.strip()):
                table_rows += 1
                continue
            out.append(f'  {_compress_inline(table_header)}')
            out.append(f'  [TABLE: {table_rows} rows]')
            out.append('')
            state = 'NORMAL'
            table_header = None
            table_rows = 0
            # fall through to process this line in NORMAL state

        stripped = line.strip()

        if _RE_FENCE.match(stripped):
            state = 'CODE_BLOCK'
            code_buf = []
            continue

        if _RE_TABLE.match(stripped):
            state = 'TABLE'
            table_header = stripped
            table_rows = 0
            continue

        if _RE_HEADING.match(stripped):
            if pending_blank:
                out.append('')
                pending_blank = False
            out.append(_compress_inline(_RE_HEADING_STRIP.sub('', stripped)))
            out.append('')
            continue

        lm = _RE_LIST.match(line) or _RE_NUM_LIST.match(line)
        if lm:
            indent = '  ' * (len(lm.group(1)) // 2 + 1)
            content = _compress_inline(line[lm.end():])
            out.append(f'{indent}{content}')
            pending_blank = False
            continue

        if _RE_BQ.match(stripped):
            content = _compress_inline(_RE_BQ.sub('', stripped))
            out.append(f'"{content}"')
            pending_blank = False
            continue

        if _RE_HR.match(stripped):
            continue

        if stripped == '':
            pending_blank = True
            continue

        if pending_blank:
            out.append('')
            pending_blank = False
        compressed = _compress_inline(stripped)
        if compressed:
            out.append(_first_sentence(compressed))

    if state == 'TABLE' and table_header:
        out.append(f'  {_compress_inline(table_header)}')
        out.append(f'  [TABLE: {table_rows} rows]')
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
