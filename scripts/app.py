import argparse
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
APP = BUILD / 'Mac Utils.app'
HELPER = APP / 'Contents/Library/LoginItems/FolderHelper.app'
APP_ID = 'dev.marius.macutils'
HELPER_ID = 'dev.marius.macutils.folderhelper'


def run(*args, capture=False, allowed=(0,)):
    res = subprocess.run(args, cwd=ROOT, text=True, capture_output=capture)
    if res.returncode not in allowed:
        raise RuntimeError(res.stderr.strip() if capture else f'{args[0]} exited with {res.returncode}')
    return res.stdout.strip() if capture else None


def signing_identity():
    if os.environ.get('SIGN_ID'):
        return os.environ['SIGN_ID']

    res = subprocess.run(
        ['/usr/bin/security', 'find-identity', '-v', '-p', 'codesigning'],
        text=True, capture_output=True,
    )
    return 'mac-utils Dev' if '"mac-utils Dev"' in res.stdout else '-'


def build():
    metadata = json.loads((ROOT / 'package.json').read_text())
    run('swift', 'build', '-c', 'release')
    binaries = Path(run('swift', 'build', '-c', 'release', '--show-bin-path', capture=True))
    identity = signing_identity()
    BUILD.mkdir(exist_ok=True)

    with tempfile.TemporaryDirectory(prefix='.bundle-', dir=BUILD) as directory:
        bundle = Path(directory) / APP.name
        helper = bundle / 'Contents/Library/LoginItems/FolderHelper.app'
        for target, executable, resource in (
            (bundle, 'MacUtils', 'Info.plist'),
            (helper, 'FolderHelper', 'HelperInfo.plist'),
        ):
            macos = target / 'Contents/MacOS'
            macos.mkdir(parents=True)
            shutil.copy2(binaries / executable, macos / executable)
            with (ROOT / 'Resources' / resource).open('rb') as source:
                info = plistlib.load(source)
            info['CFBundleShortVersionString'] = metadata['version']
            info['CFBundleVersion'] = str(metadata['config']['buildNumber'])
            with (target / 'Contents/Info.plist').open('wb') as destination:
                plistlib.dump(info, destination, sort_keys=False)

        for target in (helper, bundle):
            run('/usr/bin/codesign', '--force', '--sign', identity, str(target))
            run('/usr/bin/codesign', '--verify', '--strict', str(target))

        previous = Path(directory) / 'previous.app'
        if APP.exists():
            APP.rename(previous)
        try:
            bundle.rename(APP)
        except OSError:
            if previous.exists():
                previous.rename(APP)
            raise

    print(f'Built {APP} {metadata["version"]} ({metadata["config"]["buildNumber"]})')
    print(f'Signing identity: {identity}')
    if identity == '-':
        print('Ad-hoc build: macOS privacy permissions may need granting again after rebuilding.')


def format_sources(check=False):
    action = ['lint', '--strict'] if check else ['format', '--in-place']
    run('xcrun', 'swift-format', *action, '--recursive', 'Sources', 'Package.swift')


def stop_helper():
    run('/usr/bin/pkill', '-x', 'FolderHelper', allowed=(0, 1))


def start_helper():
    if not HELPER.exists():
        raise RuntimeError('Build the app first with npm run build or bun run build.')
    run('/usr/bin/open', '-g', str(HELPER))


def main():
    actions = (
        'dev', 'build', 'start', 'restart', 'check', 'format', 'format-check', 'clean',
        'helper-start', 'helper-stop', 'keys-status', 'keys-reset', 'permissions-reset',
    )
    parser = argparse.ArgumentParser(description='Build and manage Mac Utils on macOS 27.')
    parser.add_argument('action', choices=actions)
    action = parser.parse_args().action

    if action == 'build':
        build()
    elif action == 'dev':
        run('swift', 'run', 'MacUtils')
    elif action in ('start', 'restart'):
        if action == 'restart':
            build()
            stop_helper()
            run('/usr/bin/pkill', '-x', 'MacUtils', allowed=(0, 1))
        if not APP.exists():
            raise RuntimeError('Build the app first with npm run build or bun run build.')
        run('/usr/bin/open', str(APP))
    elif action == 'check':
        format_sources(check=True)
        for resource in sorted((ROOT / 'Resources').glob('*.plist')):
            run('/usr/bin/plutil', '-lint', str(resource))
        run('swift', 'build')
    elif action in ('format', 'format-check'):
        format_sources(check=action == 'format-check')
    elif action == 'clean':
        run('swift', 'package', 'clean')
        if BUILD.exists():
            shutil.rmtree(BUILD)
    elif action == 'helper-start':
        start_helper()
    elif action == 'helper-stop':
        stop_helper()
    elif action == 'keys-status':
        run('/usr/bin/hidutil', 'property', '--get', 'UserKeyMapping')
    elif action == 'keys-reset':
        run('/usr/bin/hidutil', 'property', '--set', '{"UserKeyMapping":[]}')
    elif action == 'permissions-reset':
        for identifier in (APP_ID, HELPER_ID):
            run('/usr/bin/tccutil', 'reset', 'Accessibility', identifier)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError) as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
