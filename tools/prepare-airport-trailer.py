#!/usr/bin/env python3
"""Verify the committed trailer archive and restore a disposable re-edit workspace."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'media' / 'airport-trailer'
ORIGINAL_ROOT = '/home/administrator/Friendslop-Template-airport-baggage'
ORIGINAL_OUTPUT = ORIGINAL_ROOT + '/artifacts/trailer-v2'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'artifacts' / 'airport-trailer-rebuild')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((PACKAGE / 'manifest.json').read_text())
    for record in manifest['files']:
        path = PACKAGE / record['path']
        if path.stat().st_size != record['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != record['sha256']:
            raise SystemExit(f'Archive mismatch: {path}; run git lfs pull if media is a pointer.')
    if args.verify_only:
        print(json.dumps({'verified_files': len(manifest['files']), 'archive': str(PACKAGE)}))
        return
    target = args.output.resolve()
    artifacts = (ROOT / 'artifacts').resolve()
    if not target.is_relative_to(artifacts) or target == artifacts:
        raise SystemExit('Output must be a new subdirectory of this checkout\'s ignored artifacts/.')
    if target.exists():
        raise SystemExit(f'Refusing to overwrite {target}; choose a new --output directory.')
    shutil.copytree(PACKAGE, target)
    local_res_path = 'res://' + target.relative_to(ROOT).as_posix() + '/'
    for path in target.rglob('*'):
        if path.is_file() and path.suffix in {'.py', '.gd', '.json', '.md', '.patch'}:
            content = path.read_text()
            content = content.replace(ORIGINAL_OUTPUT, str(target)).replace(ORIGINAL_ROOT, str(ROOT))
            content = content.replace('res://artifacts/trailer-v2/', local_res_path)
            path.write_text(content)
    print(json.dumps({'verified_files': len(manifest['files']), 'workspace': str(target), 'note': 'Archived originals remain unchanged; only disposable copies have local paths adapted.'}, indent=2))


if __name__ == '__main__':
    main()
