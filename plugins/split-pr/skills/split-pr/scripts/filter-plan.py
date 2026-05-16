#!/usr/bin/env python3
"""
Filter a split plan for a --force re-run after conflict resolution.

Keeps only:
  - The splits chosen for overwrite
  - Their ancestors (required so dependency resolution works correctly)
  - Their transitive descendants (must be recreated since their base will change)

Everything else (skipped splits, failed splits, parallel splits that already
succeeded) is removed — those branches already exist and don't need recreation.

Usage:
    python3 filter-plan.py --plan /tmp/split-pr-plan.json \
                           --overwrite-indices 0,2 \
                           --output /tmp/split-pr-plan.json

Output JSON (stdout):
{
  "kept": [0, 1, 2],
  "removed": [3, 4]
}
"""
import argparse
import json
import sys


def get_ancestors(index, plan_by_index):
    """All ancestor indices for a given split via the depends_on chain."""
    result = set()
    current = plan_by_index.get(index)
    while current:
        parent = current.get('depends_on')
        if parent is None or parent in result:
            break
        result.add(parent)
        current = plan_by_index.get(parent)
    return result


def get_descendants(seed_indices, plan_by_index):
    """All splits that transitively depend on any index in seed_indices."""
    children_of = {}
    for s in plan_by_index.values():
        parent = s.get('depends_on')
        if parent is not None:
            children_of.setdefault(parent, []).append(s['index'])

    result = set()
    queue = list(seed_indices)
    while queue:
        current = queue.pop()
        for child in children_of.get(current, []):
            if child not in result:
                result.add(child)
                queue.append(child)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--plan', required=True)
    parser.add_argument('--overwrite-indices', required=True,
                        help='Comma-separated split indices to overwrite, e.g. "0,2"')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    with open(args.plan, encoding='utf-8') as f:
        plan = json.load(f)

    try:
        overwrite = {int(i.strip()) for i in args.overwrite_indices.split(',')}
    except ValueError:
        print(json.dumps({'error': f'Invalid --overwrite-indices: {args.overwrite_indices}'}))
        sys.exit(1)

    plan_by_index = {s['index']: s for s in plan['splits']}

    for idx in overwrite:
        if idx not in plan_by_index:
            print(json.dumps({'error': f'Index {idx} not found in plan'}))
            sys.exit(1)

    keep = set()
    keep |= overwrite
    for idx in overwrite:
        keep |= get_ancestors(idx, plan_by_index)
    keep |= get_descendants(overwrite, plan_by_index)

    kept_splits = [s for s in plan['splits'] if s['index'] in keep]
    removed_splits = [s for s in plan['splits'] if s['index'] not in keep]

    output_plan = {**plan, 'splits': kept_splits}
    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(output_plan, f, indent=2)

    print(json.dumps({
        'kept': [s['index'] for s in kept_splits],
        'removed': [s['index'] for s in removed_splits],
    }))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)
