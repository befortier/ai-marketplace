#!/usr/bin/env python3
"""
Commit binary files to their assigned split branches.

Binary files cannot be patched by git apply, so they are handled separately:
save each binary from the source, then for each split branch: checkout, apply
the saved files, commit, push, and return.

Usage:
    python3 commit-binaries.py \
        --assignments /tmp/split-pr-binary-assignments.json \
        --parsed-diff  /tmp/split-pr-parsed.json \
        --apply-output /tmp/split-pr-apply-output.json \
        --state-file   /tmp/split-pr-state.json \
        [--pr-head-ref origin/feature-branch]

Assignments JSON: {"path/to/file.png": <split_index>, ...}
  Keys are the new paths (as they appear in the parsed diff).

State file: output of detect-state.py. The `state` field determines how
  binaries are saved before checkout:
    uncommitted / mixed     — cp from the working tree (file is on disk)
    committed_unpushed      — git show HEAD:<path>
    existing_pr             — git show <pr-head-ref>:<path> (requires --pr-head-ref)

Output JSON (stdout):
{
  "commits": [
    {
      "split_index": 0,
      "branch": "feature/PAE-123/add-token-validator",
      "files": ["path/to/file.png"],
      "status": "success|failed",
      "error": null
    }
  ],
  "skipped": [
    {"path": "logo.png", "reason": "assigned split 2 did not complete"}
  ]
}
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import re
import tempfile
from collections import defaultdict


def bracket_prefix(title):
    """Extract leading [KEY] prefix from a title, e.g. '[PAE-123] Foo' → '[PAE-123]'."""
    m = re.match(r'(\[[^\]]+\])', title or '')
    return m.group(1) if m else None


def run(cmd, cwd=None, check=True, capture=False):
    stdout = subprocess.PIPE if capture else subprocess.DEVNULL
    result = subprocess.run(
        cmd, cwd=cwd,
        stdout=stdout, stderr=subprocess.PIPE, text=True,
    )
    if check and result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or ' '.join(cmd))
    return result


def run_binary_capture(cmd):
    """Run a command and return raw bytes on stdout (for binary files)."""
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors='replace').strip())
    return result.stdout


def save_binary(file_info, state, pr_head_ref, tmp_path):
    """
    Save a binary file to tmp_path before branch switching.
    Returns True if saved, False if no save is needed (deleted or uncommitted-added).
    """
    change_type = file_info['change_type']
    path = file_info['path']

    if change_type == 'deleted':
        return False

    # Uncommitted added: file is untracked on disk and survives git stash
    # (stash only stashes tracked changes by default). No explicit save needed.
    if change_type == 'added' and state in ('uncommitted', 'mixed'):
        return False

    if state in ('uncommitted', 'mixed'):
        # Binary is on disk in the working tree (possibly uncommitted).
        shutil.copy2(path, tmp_path)
    elif state == 'committed_unpushed':
        data = run_binary_capture(['git', 'show', f'HEAD:{path}'])
        with open(tmp_path, 'wb') as f:
            f.write(data)
    elif state == 'existing_pr':
        if not pr_head_ref:
            raise RuntimeError(
                '--pr-head-ref is required when state is existing_pr'
            )
        data = run_binary_capture(['git', 'show', f'{pr_head_ref}:{path}'])
        with open(tmp_path, 'wb') as f:
            f.write(data)
    else:
        raise RuntimeError(f'Unknown state: {state}')

    return True


def apply_binary(file_info, tmp_path, was_saved):
    """
    Apply a binary to the current worktree. Must be called after checkout.
    was_saved: whether save_binary wrote a file to tmp_path.
    """
    change_type = file_info['change_type']
    path = file_info['path']
    old_path = file_info.get('old_path')

    if change_type == 'deleted':
        run(['git', 'rm', path])

    elif change_type == 'renamed':
        # File exists at old_path on the split branch; replace with new content at new path.
        run(['git', 'rm', old_path])
        os.makedirs(os.path.dirname(path), exist_ok=True) if os.path.dirname(path) else None
        shutil.copy2(tmp_path, path)
        run(['git', 'add', path])

    else:  # added or modified
        if was_saved:
            os.makedirs(os.path.dirname(path), exist_ok=True) if os.path.dirname(path) else None
            shutil.copy2(tmp_path, path)
        # For uncommitted added (not saved): file is already on disk as untracked.
        run(['git', 'add', path])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assignments', required=True,
                        help='JSON file: {"path": split_index, ...}')
    parser.add_argument('--parsed-diff', required=True)
    parser.add_argument('--apply-output', required=True)
    parser.add_argument('--state-file', required=True)
    parser.add_argument('--plan', required=True)
    parser.add_argument('--pr-head-ref', default=None,
                        help='e.g. origin/feature-branch (required for existing_pr state)')
    args = parser.parse_args()

    with open(args.assignments, encoding='utf-8') as f:
        assignments = json.load(f)
    with open(args.parsed_diff, encoding='utf-8') as f:
        parsed_diff = json.load(f)
    with open(args.apply_output, encoding='utf-8') as f:
        apply_output = json.load(f)
    with open(args.state_file, encoding='utf-8') as f:
        state_data = json.load(f)
    with open(args.plan, encoding='utf-8') as f:
        plan = json.load(f)

    state = state_data['state']

    diff_by_path = {f['path']: f for f in parsed_diff['files']}
    plan_by_index = {s['index']: s for s in plan['splits']}
    apply_by_index = {s['index']: s for s in apply_output.get('splits', [])}
    eligible_indices = {
        s['index'] for s in apply_output.get('splits', [])
        if s['status'] in ('success', 'warning')
    }

    # Group file paths by split index, validating each entry
    splits_files = defaultdict(list)
    skipped = []

    for path, split_idx in assignments.items():
        if split_idx not in eligible_indices:
            skipped.append({
                'path': path,
                'reason': f'assigned split {split_idx} did not complete successfully',
            })
            continue
        if path not in diff_by_path:
            skipped.append({
                'path': path,
                'reason': f'path not found in parsed diff',
            })
            continue
        if not diff_by_path[path].get('binary'):
            skipped.append({
                'path': path,
                'reason': f'file is not marked binary in parsed diff',
            })
            continue
        splits_files[split_idx].append(path)

    if not splits_files:
        print(json.dumps({'commits': [], 'skipped': skipped}))
        return

    original_branch = run(
        ['git', 'rev-parse', '--abbrev-ref', 'HEAD'], capture=True
    ).stdout.strip()

    # Save all binaries before any branch switching
    tmp_files = {}  # path -> (tmp_path, was_saved)
    all_paths = {p for paths in splits_files.values() for p in paths}

    tmp_dir = tempfile.mkdtemp(prefix='split-pr-binaries-')
    try:
        for i, path in enumerate(all_paths):
            file_info = diff_by_path[path]
            tmp_path = os.path.join(tmp_dir, str(i))
            was_saved = save_binary(file_info, state, args.pr_head_ref, tmp_path)
            tmp_files[path] = (tmp_path, was_saved)

        # Stash local changes so checkout succeeds (uncommitted / mixed only)
        stashed = False
        if state in ('uncommitted', 'mixed'):
            run(['git', 'stash', 'push', '-m', 'pre-binary-commit stash'])
            stashed = True

        commits = []

        try:
            for split_idx, file_paths in splits_files.items():
                split_info = apply_by_index[split_idx]
                branch = split_info['branch']
                result_entry = {
                    'split_index': split_idx,
                    'branch': branch,
                    'files': file_paths,
                    'status': 'failed',
                    'error': None,
                }

                try:
                    run(['git', 'checkout', branch])

                    for path in file_paths:
                        file_info = diff_by_path[path]
                        tmp_path, was_saved = tmp_files[path]
                        apply_binary(file_info, tmp_path, was_saved)

                    title = plan_by_index[split_idx]['title']
                    prefix = bracket_prefix(title)
                    commit_msg = f'{prefix} Update binary assets' if prefix else 'Update binary assets'
                    run(['git', 'commit', '-m', commit_msg])
                    run(['git', 'push', 'origin', branch])

                    result_entry['status'] = 'success'

                except Exception as e:
                    result_entry['error'] = str(e)

                finally:
                    # Always return to original branch before next iteration.
                    run(['git', 'checkout', original_branch], check=False)

                commits.append(result_entry)

        finally:
            if stashed:
                run(['git', 'stash', 'pop'], check=False)

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

    print(json.dumps({'commits': commits, 'skipped': skipped}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(json.dumps({'commits': [], 'skipped': [], 'error': str(e)}))
        sys.exit(1)
