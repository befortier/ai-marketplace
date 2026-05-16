#!/usr/bin/env python3
"""
Parse a unified diff into structured JSON for the split-pr skill.

Usage:
    python3 parse-diff.py <diff_file>

Output JSON:
{
  "files": [
    {
      "path": "path/to/file.swift",
      "old_path": "path/to/old.swift",    // only present if renamed
      "change_type": "modified|added|deleted|renamed",
      "binary": true,                     // only present for binary files
      "additions": N,
      "deletions": N,
      "hunks": [
        {
          "id": "0",
          "old_start": N,
          "old_count": N,
          "new_start": N,
          "new_count": N,
          "header": "optional function context",
          "lines": [
            {"type": "context|add|remove", "content": "line content",
             "no_newline": true}  // optional; present and true when the line has no trailing newline
          ]
        }
      ]
    }
  ],
  "total_additions": N,
  "total_deletions": N
}
"""
import json
import re
import sys


def parse_hunk_header(line):
    m = re.match(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)', line)
    if not m:
        return None
    return {
        'old_start': int(m.group(1)),
        'old_count': int(m.group(2)) if m.group(2) is not None else 1,
        'new_start': int(m.group(3)),
        'new_count': int(m.group(4)) if m.group(4) is not None else 1,
        'header': m.group(5).strip(),
    }


def parse_diff(content):
    files = []
    current_file = None
    current_hunk = None
    hunk_index = 0

    for line in content.splitlines():
        if line.startswith('diff --git '):
            if current_hunk is not None:
                current_file['hunks'].append(current_hunk)
                current_hunk = None
            if current_file is not None:
                files.append(current_file)

            current_file = {
                'path': None,
                'old_path': None,
                'change_type': 'modified',
                'additions': 0,
                'deletions': 0,
                'hunks': [],
                '_raw_header': line,
            }
            hunk_index = 0

            m = re.match(r'^diff --git a/(.*) b/(.*)$', line)
            if m:
                current_file['old_path'] = m.group(1)
                current_file['path'] = m.group(2)

        elif line.startswith('new file mode') and current_file is not None:
            current_file['change_type'] = 'added'
            current_file['mode'] = line.split()[-1]

        elif line.startswith('deleted file mode') and current_file is not None:
            current_file['change_type'] = 'deleted'
            current_file['mode'] = line.split()[-1]

        elif line.startswith('rename from ') and current_file is not None:
            current_file['change_type'] = 'renamed'
            current_file['old_path'] = line[len('rename from '):]

        elif line.startswith('rename to ') and current_file is not None:
            current_file['path'] = line[len('rename to '):]

        elif line.startswith('Binary files ') and current_file is not None:
            current_file['binary'] = True

        elif line.startswith('--- ') and current_file is not None:
            # For deleted files +++ is /dev/null, so --- a/path is the canonical path.
            if line.startswith('--- a/') and current_file['change_type'] == 'deleted':
                current_file['path'] = line[6:]

        elif line.startswith('+++ ') and current_file is not None:
            # +++ b/path is the authoritative new path for all non-deleted files,
            # overriding the potentially ambiguous 'diff --git a/... b/...' header
            # (which breaks when the path itself contains ' b/').
            if line.startswith('+++ b/'):
                current_file['path'] = line[6:]

        elif line.startswith('@@') and current_file is not None:
            if current_hunk is not None:
                current_file['hunks'].append(current_hunk)

            meta = parse_hunk_header(line)
            if meta:
                current_hunk = {
                    'id': str(hunk_index),
                    'old_start': meta['old_start'],
                    'old_count': meta['old_count'],
                    'new_start': meta['new_start'],
                    'new_count': meta['new_count'],
                    'header': meta['header'],
                    'lines': [],
                }
                hunk_index += 1

        elif current_hunk is not None:
            if line.startswith('+'):
                current_hunk['lines'].append({'type': 'add', 'content': line[1:]})
                current_file['additions'] += 1
            elif line.startswith('-'):
                current_hunk['lines'].append({'type': 'remove', 'content': line[1:]})
                current_file['deletions'] += 1
            elif line.startswith(' '):
                current_hunk['lines'].append({'type': 'context', 'content': line[1:]})
            elif line.startswith('\\ ') and current_hunk['lines']:
                current_hunk['lines'][-1]['no_newline'] = True

    if current_hunk is not None and current_file is not None:
        current_file['hunks'].append(current_hunk)
    if current_file is not None:
        files.append(current_file)

    # Drop entries where path was never resolved (malformed diff header).
    for f in files:
        if f['path'] is None:
            print(f"warning: could not parse path for diff entry — skipping: {f['_raw_header']}", file=sys.stderr)
    files = [f for f in files if f['path'] is not None]

    # Strip internal fields and old_path when it's not a rename (redundant with path)
    for f in files:
        del f['_raw_header']
        if f['change_type'] != 'renamed':
            del f['old_path']

    return {
        'files': files,
        'total_additions': sum(f['additions'] for f in files),
        'total_deletions': sum(f['deletions'] for f in files),
    }


def main():
    if len(sys.argv) < 2:
        print('Usage: parse-diff.py <diff_file>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], encoding='utf-8') as f:
        content = f.read()

    print(json.dumps(parse_diff(content), indent=2))


if __name__ == '__main__':
    main()
