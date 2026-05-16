#!/usr/bin/env python3
"""
Apply a split plan to create git branches with partial changesets.

Uses git worktrees and `git apply` to create each branch in isolation
without touching the working directory. The original working state is
never modified.

Usage:
    python3 apply-split.py --plan /tmp/split-pr-plan.json \
                           --parsed-diff /tmp/split-pr-parsed.json

Plan JSON format:
{
  "base_ref": "origin/main",
  "splits": [
    {
      "index": 0,
      "branch": "refactor/PAE-123/refactor-networking-layer",
      "title": "[PAE-123] Refactor networking layer",
      "body": "Extracts APIClient into a dedicated networking module.",
      "depends_on": null,
      "file_hunks": {
        "path/to/File.swift": "all",
        "path/to/Shared.swift": ["0", "2"]
      }
    }
  ]
}

Branch naming: {feature|bugfix|refactor}/{JIRA-KEY}/{kebab-description}

file_hunks values:
  "all"        — apply every hunk for that file
  ["0", "1"]   — apply only the hunks with those IDs from the parsed diff

Output JSON (stdout):
{
  "splits": [
    {
      "index": 0,
      "branch": "refactor/PAE-123/refactor-networking-layer",
      "status": "success|warning|conflict|failed",
      "warnings": [],
      "error": null
    }
  ]
}
"""
import argparse
import json
import os
import shutil
import subprocess
import tempfile


def run(cmd, cwd=None, check=True, capture=False):
    stdout = subprocess.PIPE if capture else subprocess.DEVNULL
    if isinstance(cmd, str):
        result = subprocess.run(cmd, shell=True, cwd=cwd,
                                stdout=stdout, stderr=subprocess.PIPE, text=True)
    else:
        result = subprocess.run(cmd, cwd=cwd,
                                stdout=stdout, stderr=subprocess.PIPE, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\n{result.stderr.strip()}")
    return result


def topological_sort(splits):
    """Return splits ordered so parents always precede their dependents."""
    remaining = {s['index']: s for s in splits}
    ordered = []
    while remaining:
        ready = [s for s in remaining.values()
                 if s.get('depends_on') is None or s['depends_on'] not in remaining]
        if not ready:
            raise ValueError('Circular dependency detected in split plan')
        for s in sorted(ready, key=lambda x: x['index']):
            ordered.append(s)
            del remaining[s['index']]
    return ordered


def _hunk_range(start, count):
    """Format one side of a @@ header range. Omits ,count when count == 1."""
    if count == 1:
        return str(start)
    return f'{start},{count}'


def _format_hunk(hunk):
    old_range = _hunk_range(hunk['old_start'], hunk['old_count'])
    new_range = _hunk_range(hunk['new_start'], hunk['new_count'])
    header_ctx = f" {hunk['header']}" if hunk.get('header') else ''
    lines = [f'@@ -{old_range} +{new_range} @@{header_ctx}\n']
    for entry in hunk['lines']:
        prefix = ' ' if entry['type'] == 'context' else (
                 '+' if entry['type'] == 'add' else '-')
        content = entry['content']
        if not content.endswith('\n'):
            content += '\n'
        lines.append(f'{prefix}{content}')
        if entry.get('no_newline'):
            lines.append('\\ No newline at end of file\n')
    return ''.join(lines)


def build_patch(file_info, hunks_to_apply):
    """
    Reconstruct a minimal unified diff patch for the given file and hunks.

    Returns the patch string, or None if there is nothing to apply
    (non-renamed file with no hunks).
    """
    change_type = file_info['change_type']
    path = file_info['path']
    old_path = file_info.get('old_path', path)

    # Rename-only: emit the rename header with no hunk content.
    if change_type == 'renamed' and not hunks_to_apply:
        return (
            f'diff --git a/{old_path} b/{path}\n'
            f'similarity index 100%\n'
            f'rename from {old_path}\n'
            f'rename to {path}\n'
        )

    if not hunks_to_apply:
        return None

    parts = [f'diff --git a/{old_path} b/{path}\n']

    if change_type == 'added':
        mode = file_info.get('mode', '100644')
        parts += [f'new file mode {mode}\n', '--- /dev/null\n', f'+++ b/{path}\n']
    elif change_type == 'deleted':
        mode = file_info.get('mode', '100644')
        parts += [f'deleted file mode {mode}\n', f'--- a/{path}\n', '+++ /dev/null\n']
    elif change_type == 'renamed':
        parts += [
            'similarity index 75%\n',
            f'rename from {old_path}\n',
            f'rename to {path}\n',
            f'--- a/{old_path}\n',
            f'+++ b/{path}\n',
        ]
    else:  # modified
        parts += [f'--- a/{path}\n', f'+++ b/{path}\n']

    for hunk in sorted(hunks_to_apply, key=lambda h: h['old_start']):
        parts.append(_format_hunk(hunk))

    return ''.join(parts)


def apply_patch_to_worktree(patch_text, worktree_path):
    """Write patch_text to a temp file and apply it to the worktree index."""
    fd, patch_path = tempfile.mkstemp(suffix='.patch', prefix='split-pr-')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(patch_text)
        result = run(['git', 'apply', '--index', patch_path],
                     cwd=worktree_path, check=False)
        if result.returncode != 0:
            raise RuntimeError(f'git apply failed: {result.stderr.strip()}')
    finally:
        try:
            os.unlink(patch_path)
        except OSError:
            pass


def build_commit_message(title, body):
    if body and body.strip():
        return f'{title}\n\n{body}'
    return title


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--plan', required=True)
    parser.add_argument('--parsed-diff', required=True)
    parser.add_argument('--force', action='store_true',
                        help='Overwrite existing local and remote branches')
    args = parser.parse_args()

    with open(args.plan, encoding='utf-8') as f:
        plan = json.load(f)
    with open(args.parsed_diff, encoding='utf-8') as f:
        parsed_diff = json.load(f)

    # Build lookup: file path → {hunk_id → hunk}
    diff_by_file = {}
    for file_info in parsed_diff['files']:
        diff_by_file[file_info['path']] = {
            'info': file_info,
            'hunks': {h['id']: h for h in file_info['hunks']},
        }

    base_ref = plan['base_ref']
    splits = plan['splits']

    # Fetch so base_ref and any parent branches are up to date
    run('git fetch origin', capture=True)

    branch_by_index = {}
    worktrees = []
    results = []

    try:
        for split in topological_sort(splits):
            idx = split['index']
            branch = split['branch']
            title = split['title']
            body = split.get('body', '')
            depends_on = split.get('depends_on')
            file_hunk_plan = split.get('file_hunks', {})

            if depends_on is not None:
                if depends_on not in branch_by_index:
                    results.append({
                        'index': idx, 'branch': branch, 'status': 'failed',
                        'warnings': [],
                        'error': f'Parent split {depends_on} did not complete successfully',
                    })
                    continue
                start_ref = branch_by_index[depends_on]
            else:
                start_ref = base_ref

            # Check for existing local or remote branches before proceeding.
            remote_exists = bool(run(
                ['git', 'ls-remote', '--heads', 'origin', branch],
                capture=True, check=False,
            ).stdout.strip())
            local_exists = bool(run(
                ['git', 'branch', '--list', branch],
                capture=True, check=False,
            ).stdout.strip())

            if remote_exists or local_exists:
                if not args.force:
                    locations = ' and '.join(filter(None, [
                        'local' if local_exists else '',
                        'remote' if remote_exists else '',
                    ]))
                    results.append({
                        'index': idx, 'branch': branch, 'status': 'conflict',
                        'warnings': [],
                        'error': (
                            f'Branch "{branch}" already exists ({locations}). '
                            f'Re-run with --force to overwrite.'
                        ),
                    })
                    continue

            worktree_path = tempfile.mkdtemp(prefix=f'split-pr-{idx}-')
            worktrees.append(worktree_path)

            try:
                # Delete local branch so -b can recreate it; force-push the
                # remote instead of deleting it — deletion closes open PRs.
                if local_exists:
                    run(['git', 'branch', '-D', branch], capture=True)
                run(['git', 'worktree', 'add', worktree_path, '-b', branch, start_ref])
                push_flags = ['--force'] if remote_exists else []

                warnings = []
                patch_parts = []

                for file_path, hunk_spec in file_hunk_plan.items():
                    if file_path not in diff_by_file:
                        warnings.append(f'File not in diff: {file_path}')
                        continue

                    file_entry = diff_by_file[file_path]
                    file_info = file_entry['info']
                    all_hunks = file_entry['hunks']

                    if hunk_spec == 'all':
                        hunks_to_apply = list(all_hunks.values())
                    else:
                        hunks_to_apply = [all_hunks[hid] for hid in hunk_spec
                                          if hid in all_hunks]
                        missing = [hid for hid in hunk_spec if hid not in all_hunks]
                        if missing:
                            warnings.append(
                                f'Hunk IDs not found in {file_path}: {missing}'
                            )

                    patch_text = build_patch(file_info, hunks_to_apply)
                    if patch_text is None:
                        warnings.append(f'No valid hunks for {file_path}')
                        continue

                    patch_parts.append(patch_text)

                if not patch_parts:
                    warnings.append('No changes to commit — split may be empty')
                    run(['git', 'push', 'origin', branch] + push_flags, cwd=worktree_path)
                    results.append({
                        'index': idx, 'branch': branch,
                        'status': 'warning', 'warnings': warnings, 'error': None,
                    })
                    branch_by_index[idx] = branch
                    continue

                apply_patch_to_worktree('\n'.join(patch_parts), worktree_path)

                status = run('git status --porcelain', cwd=worktree_path, capture=True)
                if not status.stdout.strip():
                    warnings.append('No changes to commit — split may be empty')
                    run(['git', 'push', 'origin', branch] + push_flags, cwd=worktree_path)
                    results.append({
                        'index': idx, 'branch': branch,
                        'status': 'warning', 'warnings': warnings, 'error': None,
                    })
                    branch_by_index[idx] = branch
                    continue

                commit_msg = build_commit_message(title, body)
                run(['git', 'commit', '-m', commit_msg], cwd=worktree_path)
                run(['git', 'push', 'origin', branch] + push_flags, cwd=worktree_path)

                branch_by_index[idx] = branch
                status_str = 'warning' if warnings else 'success'
                results.append({
                    'index': idx, 'branch': branch,
                    'status': status_str, 'warnings': warnings, 'error': None,
                })

            except Exception as e:
                results.append({
                    'index': idx, 'branch': branch,
                    'status': 'failed', 'warnings': [], 'error': str(e),
                })

    finally:
        for wt in worktrees:
            run(['git', 'worktree', 'remove', wt, '--force'],
                capture=True, check=False)
            shutil.rmtree(wt, ignore_errors=True)

    print(json.dumps({'splits': results}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(json.dumps({'splits': [], 'error': str(e)}, indent=2))
        raise SystemExit(1)
