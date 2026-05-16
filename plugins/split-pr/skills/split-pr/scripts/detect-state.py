#!/usr/bin/env python3
"""
Detect git working state for the split-pr skill.

Usage:
    python3 detect-state.py

Output JSON:
{
  "state": "uncommitted|committed_unpushed|mixed|clean",
  "base_ref": "origin/main",
  "diff_command": "git diff origin/main...HEAD > /tmp/split-pr-diff.patch",
  "org": "fetch-rewards",
  "repo": "fetch-marketplace",
  "upstream": "origin/main",
  "needs_base_confirmation": false,
  "untracked_files": [],
  "error": null
}

state values:
  uncommitted        — staged/unstaged changes, no commits ahead of remote
  committed_unpushed — commits ahead of remote, clean working tree
  mixed              — both commits ahead of remote and uncommitted changes
  clean              — nothing to split
"""
import json
import re
import subprocess
import sys


def run(cmd):
    return subprocess.run(
        cmd, shell=isinstance(cmd, str),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )


def parse_github_remote(url):
    """Extract (org, repo) from any common GitHub remote URL format."""
    m = re.search(r'github\.com[:/]([^/]+)/([^/\s]+?)(?:\.git)?$', url.strip())
    if m:
        return m.group(1), m.group(2)
    return None, None


def _closest_remote_branch():
    """Return the origin remote branch HEAD most recently diverged from.

    Counts commits in HEAD not reachable from each remote branch — the branch
    with the fewest such commits is the one we branched from most recently.
    Falls back to 'origin/main' if no remote branches exist.
    """
    refs = run("git for-each-ref '--format=%(refname:short)' refs/remotes/origin/")
    branches = [r for r in refs.stdout.splitlines() if r and not r.endswith('/HEAD')]
    if not branches:
        return 'origin/main'

    # Prefer well-known base branch names as a tiebreaker when distances are equal.
    _BASE_PRIORITY = {'development': 0, 'develop': 1, 'dev': 2, 'main': 3, 'master': 4}

    def _priority(ref):
        name = ref.split('/')[-1]
        return _BASE_PRIORITY.get(name, 99)

    best, best_count = None, None
    for ref in branches:
        result = run(f'git rev-list --count {ref}..HEAD')
        if result.returncode != 0:
            continue
        count = int(result.stdout.strip())
        if (best_count is None
                or count < best_count
                or (count == best_count and _priority(ref) < _priority(best))):
            best_count = count
            best = ref
    return best or 'origin/main'


def main():
    # Must be inside a git repo
    if run('git rev-parse --git-dir').returncode != 0:
        print(json.dumps({'error': 'Not inside a git repository.'}))
        sys.exit(1)

    # Extract org/repo from remote
    remote = run('git remote get-url origin')
    if remote.returncode != 0:
        print(json.dumps({'error': 'No remote named "origin" found.'}))
        sys.exit(1)

    org, repo = parse_github_remote(remote.stdout)

    # Determine upstream tracking branch
    upstream_result = run('git rev-parse --abbrev-ref @{u}')
    needs_base_confirmation = False

    if upstream_result.returncode == 0 and upstream_result.stdout.strip():
        upstream = upstream_result.stdout.strip()
    else:
        # No tracking branch — find the closest remote branch by commit distance.
        # This correctly identifies development/dev/main/master regardless of name.
        upstream = _closest_remote_branch()
        needs_base_confirmation = True

    # Classify working state
    status = run('git status --porcelain')
    status_lines = [l for l in status.stdout.splitlines() if l.strip()]
    has_uncommitted = bool(status_lines)
    untracked_files = [l[3:] for l in status_lines if l.startswith('??')]

    ahead = run(f'git log {upstream}..HEAD --oneline')
    has_commits_ahead = (
        ahead.returncode == 0 and bool(ahead.stdout.strip())
    )

    if not has_uncommitted and not has_commits_ahead:
        state = 'clean'
    elif has_uncommitted and not has_commits_ahead:
        state = 'uncommitted'
    elif not has_uncommitted and has_commits_ahead:
        state = 'committed_unpushed'
    else:
        state = 'mixed'

    # Build the diff command for this state
    if state == 'uncommitted':
        diff_command = 'git diff --find-renames HEAD > /tmp/split-pr-diff.patch'
    elif state == 'committed_unpushed':
        diff_command = f'git diff --find-renames {upstream}...HEAD > /tmp/split-pr-diff.patch'
    elif state == 'mixed':
        diff_command = f'git diff --find-renames {upstream} > /tmp/split-pr-diff.patch'
    else:
        diff_command = None

    print(json.dumps({
        'state': state,
        'base_ref': upstream,
        'diff_command': diff_command,
        'org': org,
        'repo': repo,
        'upstream': upstream,
        'needs_base_confirmation': needs_base_confirmation,
        'untracked_files': untracked_files,
        'error': None,
    }, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)
