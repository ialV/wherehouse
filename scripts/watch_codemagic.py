#!/usr/bin/env python3
import argparse
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path


DEFAULT_KEYWORDS = (
    'failed',
    'error',
    'exception',
    'permission',
    'camera',
    'mobile_scanner',
    'gradle',
)


def load_env_token(env_path: Path) -> str:
    if not env_path.exists():
        return ''
    for line in env_path.read_text().splitlines():
        if line.startswith('CODEMAGIC_API_TOKEN='):
            return line.split('=', 1)[1].strip()
        if line.startswith('CODE_MAGIC_API_KEY='):
            return line.split('=', 1)[1].strip()
    return ''


def fetch_json(url: str, token: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            'x-auth-token': token,
            'Content-Type': 'application/json',
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode('utf-8'))


def build_summary(payload: dict) -> tuple[dict, list[str]]:
    build = payload.get('build', payload)
    actions = build.get('buildActions') or []
    artifacts = build.get('artefacts') or []
    summary = {
        'status': build.get('status'),
        'message': build.get('message'),
        'finishedAt': build.get('finishedAt'),
        'actions': [(a.get('name'), a.get('status')) for a in actions],
        'artifacts': [(a.get('name'), a.get('type'), a.get('url')) for a in artifacts],
    }
    text_parts = [
        str(summary['status'] or ''),
        str(summary['message'] or ''),
        ' '.join(f'{name} {status}' for name, status in summary['actions']),
        ' '.join(name or '' for name, _, _ in summary['artifacts']),
    ]
    return summary, text_parts


def print_summary(summary: dict) -> None:
    print(f"status: {summary['status']} finishedAt: {summary['finishedAt']}")
    if summary['message']:
        print(f"message: {summary['message']}")
    for name, status in summary['actions']:
        print(f'- {name}: {status}')
    for name, kind, url in summary['artifacts']:
        print(f'artifact: {name} ({kind}) {url}')
    print('', flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description='Watch a Codemagic build with sparse output.')
    parser.add_argument('build_id')
    parser.add_argument('--interval', type=int, default=60)
    parser.add_argument('--env', default='.env')
    parser.add_argument('--keyword', action='append', default=[])
    args = parser.parse_args()

    token = os.environ.get('CODEMAGIC_API_TOKEN') or load_env_token(Path(args.env))
    if not token:
        raise SystemExit('Missing CODEMAGIC_API_TOKEN or CODE_MAGIC_API_KEY')

    keywords = tuple(k.lower() for k in (args.keyword or DEFAULT_KEYWORDS))
    url = f'https://api.codemagic.io/builds/{args.build_id}'
    previous = None

    while True:
        try:
            payload = fetch_json(url, token)
        except urllib.error.HTTPError as exc:
            print(f'HTTP error: {exc.code}', flush=True)
            time.sleep(args.interval)
            continue
        except Exception as exc:
            print(f'poll error: {exc}', flush=True)
            time.sleep(args.interval)
            continue

        summary, text_parts = build_summary(payload)
        text = ' '.join(text_parts).lower()
        changed = summary != previous
        matched = any(keyword in text for keyword in keywords)

        if changed or matched:
            print_summary(summary)
            previous = summary

        if summary['status'] in {'finished', 'failed', 'canceled', 'skipped'}:
            return 0 if summary['status'] == 'finished' else 1

        time.sleep(args.interval)


if __name__ == '__main__':
    raise SystemExit(main())
