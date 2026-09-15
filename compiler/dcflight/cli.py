import argparse
import json
import sys
import subprocess
from dataclasses import asdict
from pathlib import Path
from . import __version__
from .audit import audit
from .compiler import compile_app
from .frontends import load
from .ingest import ingest
from .registry import Registry
from .validate import lower


def main(argv=None):
    parser = argparse.ArgumentParser(prog='dcflight')
    parser.add_argument('--version', action='version', version=__version__)
    sub = parser.add_subparsers(dest='command', required=True)
    command = sub.add_parser('create', help='Create an editable app and both native projects')
    command.add_argument('directory')
    command.add_argument('--name', default='My First App')
    command.add_argument('--id', default='com.example.myapp')
    command = sub.add_parser('run', help='Build and launch a project in iOS Simulator')
    command.add_argument('directory')
    command.add_argument('--device', help='Simulator UDID; defaults to a booted simulator or an available iPhone')
    for name in ('validate', 'inspect'):
        command = sub.add_parser(name)
        command.add_argument('source')
    command = sub.add_parser('compile')
    command.add_argument('source')
    command.add_argument('--out', required=True)
    command.add_argument('--target', action='append', choices=('ios', 'android'))
    command.add_argument('--dry-run', action='store_true')
    sub.add_parser('schema')
    command = sub.add_parser('registry')
    command.add_argument('query', nargs='?', default='')
    command = sub.add_parser('audit')
    command.add_argument('output')
    command = sub.add_parser('ingest')
    command.add_argument('source')
    command.add_argument('--format', required=True, choices=('apple-symbolgraph', 'android-api'))
    command.add_argument('--sdk', required=True)
    command.add_argument('--out', required=True)
    sub.add_parser('mcp')
    args = parser.parse_args(argv)
    try:
        registry = Registry()
        if args.command == 'create':
            from .develop import create_project
            result = create_project(args.directory, args.name, args.id)
        elif args.command == 'run':
            from .develop import run_ios
            result = run_ios(args.directory, args.device)
        elif args.command == 'compile':
            result = compile_app(args.source, args.out, tuple(args.target or ('ios', 'android')), args.dry_run, registry)
        elif args.command in ('validate', 'inspect'):
            app = lower(load(args.source), registry)
            result = asdict(app) if args.command == 'inspect' else {'valid': True, 'nodes': len(app.nodes())}
        elif args.command == 'schema':
            result = registry.schema()
        elif args.command == 'registry':
            result = registry.search(args.query)
        elif args.command == 'audit':
            result = audit(args.output)
        elif args.command == 'ingest':
            result = ingest(args.source, args.format, args.sdk)
            Path(args.out).parent.mkdir(parents=True, exist_ok=True)
            Path(args.out).write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
            result = {'symbols': len(result['symbols']), 'output': args.out}
        else:
            from .mcp import serve
            serve()
            return 0
        print(json.dumps(result, indent=2))
        return 1 if isinstance(result, dict) and result.get('passed') is False else 0
    except (ValueError, OSError, KeyError, TypeError, RecursionError, subprocess.CalledProcessError) as error:
        print(json.dumps({'error': str(error)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
