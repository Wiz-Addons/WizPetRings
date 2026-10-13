"""Prepare metadata updates and review PRs; never certify in-game compatibility."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
BASELINE = '.github/forever-baseline.json'
SOURCE = 'Gethe/wow-ui-source'
PLAN = ROOT / 'dist' / 'forever-plan.json'


def version_interface(version):
    match = re.fullmatch(r'1\.(\d+)\.(\d+)\.(\d+)', version)
    if not match or int(match[1]) < 60:
        raise ValueError('Expected a WoW Forever 1.60+ client version.')
    minor, patch, _ = map(int, match.groups())
    if minor > 99 or patch > 99:
        raise ValueError('Client version cannot be represented as a TOC interface.')
    return 10000 + minor * 100 + patch


def update_toc(text, interface):
    replacement, count = re.subn(r'^## Interface: [0-9]+[ \t]*$',
                                 f'## Interface: {interface}', text, flags=re.MULTILINE)
    if count != 1:
        raise ValueError('Expected exactly one numeric Interface field.')
    return replacement


def relevant_file(path):
    value = path.lower()
    return any(part in value for part in ('secure', 'restrictedaddon', 'petaction',
        'petstable', 'spellbook', 'spellapi', 'spellbookapi', 'petinfo', 'bindings'))


def api(path, data=None, method=None):
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'WizPetRings-Forever-watch',
               'X-GitHub-Api-Version': '2022-11-28'}
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    body = json.dumps(data).encode() if data is not None else None
    request = urllib.request.Request('https://api.github.com/' + path, body,
                                     headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f'GitHub request failed ({error.code}) for {path}.') from None


def raw_version(commit):
    # Fetch public source text without sending the repository token to another host.
    url = f'https://raw.githubusercontent.com/{SOURCE}/{commit}/version.txt'
    request = urllib.request.Request(url, headers={'User-Agent': 'WizPetRings-Forever-watch'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode('utf-8').strip()


def prepare():
    old = json.loads((ROOT / BASELINE).read_text())
    if old['repository'] != SOURCE or old['branch'] != 'forever':
        raise ValueError('Unexpected patch source; refusing to monitor a different client.')
    head = api(f'repos/{SOURCE}/branches/forever')['commit']['sha']
    if not re.fullmatch('[0-9a-f]{40}', head):
        raise ValueError('Invalid source commit.')
    PLAN.parent.mkdir(exist_ok=True)
    if head == old['commit']:
        PLAN.write_text(json.dumps({'changed': False}) + '\n')
        print('No new Forever source update.')
        return
    version = raw_version(head)
    interface = version_interface(version)
    comparison = api(f"repos/{SOURCE}/compare/{old['commit']}...{head}")
    if comparison.get('status') not in ('ahead', 'identical'):
        raise ValueError('Upstream history changed unexpectedly; inspect it manually.')
    files = comparison.get('files', [])
    new = dict(repository=SOURCE, branch='forever', commit=head, version=version, interface=interface)
    changes = {BASELINE: json.dumps(new, indent=2) + '\n'}
    for name in ('WizPetRings.toc', 'WizPetRings_Camelot.toc'):
        before = (ROOT / name).read_text()
        after = update_toc(before, interface)
        if after != before:
            changes[name] = after
    for name, content in changes.items():
        (ROOT / name).write_text(content)
    plan = dict(changed=True, old=old, new=new, changes=changes,
                relevant=[file['filename'] for file in files if relevant_file(file['filename'])],
                truncated=len(files) >= 300)
    PLAN.write_text(json.dumps(plan, indent=2) + '\n')
    print(f'Prepared review for Forever {version}; interface {interface}.')


def publish():
    plan = json.loads(PLAN.read_text())
    if not plan['changed']:
        return
    repo = os.environ['GITHUB_REPOSITORY']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo):
        raise ValueError('Invalid target repository.')
    if not os.environ.get('GITHUB_TOKEN'):
        raise ValueError('Publishing requires the workflow repository token.')
    owner = repo.split('/')[0]
    new = plan['new']
    branch = f"automation/forever-{new['version']}-{new['commit'][:8]}"
    query = urllib.parse.urlencode({'state': 'all', 'head': f'{owner}:{branch}', 'per_page': 100})
    existing = api(f'repos/{repo}/pulls?{query}')
    if existing:
        print('This source update already has a review; no duplicate created.')
        return
    refs = api(f'repos/{repo}/git/matching-refs/heads/{branch}')
    if not any(ref['ref'] == 'refs/heads/' + branch for ref in refs):
        parent = api(f'repos/{repo}/git/ref/heads/main')['object']['sha']
        checked_head = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
        if parent != checked_head:
            raise ValueError('Main advanced during checks; rerun on its latest commit.')
        base = api(f'repos/{repo}/git/commits/{parent}')['tree']['sha']
        tree = []
        for name, content in plan['changes'].items():
            blob = api(f'repos/{repo}/git/blobs', {'content': content, 'encoding': 'utf-8'})
            tree.append(dict(path=name, mode='100644', type='blob', sha=blob['sha']))
        tree_sha = api(f'repos/{repo}/git/trees', {'base_tree': base, 'tree': tree})['sha']
        commit = api(f'repos/{repo}/git/commits', {
            'message': f"Review Forever {new['version']} compatibility", 'tree': tree_sha,
            'parents': [parent]})['sha']
        api(f'repos/{repo}/git/refs', {'ref': 'refs/heads/' + branch, 'sha': commit})
    relevant = '\n'.join('- `' + name + '`' for name in plan['relevant']) or '- None detected in the returned file list.'
    old_sha = plan['old']['commit']
    body = f'''WoW Forever UI source advanced to **{new['version']}**.

[Upstream changes](https://github.com/{SOURCE}/compare/{old_sha}...{new['commit']})

This draft records the new source baseline and updates TOC interface metadata when necessary. It does not modify addon Lua or claim support for the new client. The candidate passed our existing Lua regression checks before this PR was opened; those mocks do not run the new WoW client.

Potentially relevant source files:
{relevant}

{'The file list may be truncated; inspect the full upstream comparison.' if plan['truncated'] else ''}

Before merging, inspect pet action and secure handler API changes, make any required Lua fixes, and test both rings in game, including press/release, combat and non-Hunter key bindings. Run **Addon checks** manually on this branch if you make changes: PRs opened with GITHUB_TOKEN do not automatically trigger other workflows. This workflow does not merge or publish releases.
'''
    result = api(f'repos/{repo}/pulls', {'title': f"Review WoW Forever {new['version']} compatibility",
                 'head': branch, 'base': 'main', 'body': body, 'draft': True})
    print('Opened compatibility review: ' + result['html_url'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument('--prepare', action='store_true')
    choice.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    prepare() if args.prepare else publish()
