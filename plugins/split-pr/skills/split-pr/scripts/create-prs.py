#!/usr/bin/env python3
"""
Create GitHub PRs from a split plan and apply-split output.

Usage:
    python3 create-prs.py --plan /tmp/split-pr-plan.json \
                          --apply-output /tmp/split-pr-apply-output.json \
                          --repo fetch-rewards/fetch-marketplace \
                          [--jira-base-url https://fetchrewards.atlassian.net/browse]

Only creates PRs for splits with status "success" or "warning" in the apply
output. Creates PRs in topological order (parents before children), then does
a second pass to update every body with cross-references.

Output JSON (stdout):
{
  "prs": [
    {
      "index": 0,
      "branch": "feature/PAE-123/add-token-validator",
      "pr_number": 456,
      "pr_url": "https://github.com/org/repo/pull/456",
      "status": "created"
    }
  ],
  "skipped": [
    {
      "index": 1,
      "branch": "...",
      "reason": "..."
    }
  ]
}
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile


def run(cmd, check=True):
    result = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    if check and result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result


def topological_sort(splits):
    """Return splits ordered so parents always precede their dependents."""
    remaining = {s['index']: s for s in splits}
    ordered = []
    while remaining:
        ready = [s for s in remaining.values()
                 if s.get('depends_on') is None or s['depends_on'] not in remaining]
        if not ready:
            raise ValueError('Circular dependency in split plan')
        for s in sorted(ready, key=lambda x: x['index']):
            ordered.append(s)
            del remaining[s['index']]
    return ordered


def strip_origin(ref):
    """Convert 'origin/main' → 'main'. Leaves non-prefixed refs unchanged."""
    return ref[len('origin/'):] if ref.startswith('origin/') else ref


def extract_jira_key(title):
    m = re.search(r'\b([A-Z]+-\d+)\b', title or '')
    return m.group(1) if m else None


def build_body(split, part_n, total, pr_by_index, parallel_pr_numbers, jira_base_url):
    lines = []

    base_body = (split.get('body') or '').strip()
    if base_body:
        lines.append(base_body)
        lines.append('')

    lines.append(f'**Part {part_n} of {total}**')

    if split.get('depends_on') is not None:
        parent_pr = pr_by_index.get(split['depends_on'])
        if parent_pr:
            lines.append(f'Depends on: #{parent_pr}')

    if parallel_pr_numbers:
        lines.append('Parallel with: ' + ', '.join(f'#{n}' for n in parallel_pr_numbers))

    if jira_base_url:
        key = extract_jira_key(split.get('title', ''))
        if key:
            lines.append('')
            lines.append(f'[{key}]({jira_base_url.rstrip("/")}/{key})')

    return '\n'.join(lines)


def gh_pr_create(repo, base_branch, head_branch, title, body):
    """Create a PR via gh CLI using a temp file for the body."""
    fd, body_path = tempfile.mkstemp(suffix='.md', prefix='split-pr-body-')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(body)
        result = run([
            'gh', 'pr', 'create',
            '--repo', repo,
            '--base', base_branch,
            '--head', head_branch,
            '--title', title,
            '--body-file', body_path,
        ])
        return result.stdout.strip()
    finally:
        try:
            os.unlink(body_path)
        except OSError:
            pass


def gh_pr_edit_body(repo, pr_number, body):
    """Update a PR body via gh CLI using a temp file."""
    fd, body_path = tempfile.mkstemp(suffix='.md', prefix='split-pr-body-')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(body)
        run([
            'gh', 'pr', 'edit', str(pr_number),
            '--repo', repo,
            '--body-file', body_path,
        ])
    finally:
        try:
            os.unlink(body_path)
        except OSError:
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--plan', required=True)
    parser.add_argument('--apply-output', required=True)
    parser.add_argument('--repo', required=True, help='org/repo')
    parser.add_argument('--jira-base-url', default=None,
                        help='e.g. https://fetchrewards.atlassian.net/browse')
    args = parser.parse_args()

    with open(args.plan, encoding='utf-8') as f:
        plan = json.load(f)
    with open(args.apply_output, encoding='utf-8') as f:
        apply_output = json.load(f)

    apply_by_index = {s['index']: s for s in apply_output.get('splits', [])}
    plan_by_index = {s['index']: s for s in plan['splits']}
    base_ref = plan['base_ref']

    # Only create PRs for splits that applied successfully
    eligible = [
        s for s in plan['splits']
        if apply_by_index.get(s['index'], {}).get('status') in ('success', 'warning')
    ]

    ordered = topological_sort(eligible)

    # Phase 1: create all PRs with their base body (no cross-references yet)
    pr_by_index = {}   # split index → PR number
    pr_url_by_index = {}
    results = []
    skipped = []

    for split in ordered:
        idx = split['index']

        if split.get('depends_on') is not None and split['depends_on'] not in pr_by_index:
            skipped.append({
                'index': idx,
                'branch': split['branch'],
                'reason': f'parent split {split["depends_on"]} did not get a PR',
            })
            continue

        base_branch = (
            plan_by_index[split['depends_on']]['branch']
            if split.get('depends_on') is not None
            else strip_origin(base_ref)
        )

        try:
            pr_url = gh_pr_create(
                repo=args.repo,
                base_branch=base_branch,
                head_branch=split['branch'],
                title=split['title'],
                body=split.get('body') or '',
            )
            pr_number = int(pr_url.rstrip('/').split('/')[-1])
            pr_by_index[idx] = pr_number
            pr_url_by_index[idx] = pr_url
            results.append({
                'index': idx,
                'branch': split['branch'],
                'pr_number': pr_number,
                'pr_url': pr_url,
                'status': 'created',
            })
        except Exception as e:
            skipped.append({
                'index': idx,
                'branch': split['branch'],
                'reason': str(e),
            })

    # Phase 2: update every PR body with cross-references
    created_ordered = [s for s in ordered if s['index'] in pr_by_index]
    total = len(created_ordered)

    for part_n, split in enumerate(created_ordered, 1):
        idx = split['index']

        parallel_pr_numbers = [
            pr_by_index[s['index']]
            for s in created_ordered
            if s['index'] != idx
            and s.get('depends_on') == split.get('depends_on')
        ]

        body = build_body(
            split=split,
            part_n=part_n,
            total=total,
            pr_by_index=pr_by_index,
            parallel_pr_numbers=parallel_pr_numbers,
            jira_base_url=args.jira_base_url,
        )

        try:
            gh_pr_edit_body(args.repo, pr_by_index[idx], body)
        except Exception as e:
            for r in results:
                if r['index'] == idx:
                    r['body_update_warning'] = str(e)

    print(json.dumps({'prs': results, 'skipped': skipped}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(json.dumps({'prs': [], 'skipped': [], 'error': str(e)}))
        sys.exit(1)
