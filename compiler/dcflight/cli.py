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


def authoring_options(command):
    command.add_argument('--evaluate-dart', action='store_true',
                         help='Execute trusted local Dart buildApp() authoring code')
    command.add_argument('--dart-sdk', default='dart', help='Dart executable for opted-in authoring')


def main(argv=None):
    parser = argparse.ArgumentParser(prog='dcflight')
    parser.add_argument('--version', action='version', version=__version__)
    sub = parser.add_subparsers(dest='command', required=True)
    command = sub.add_parser('create', help='Create an editable app and both native projects')
    command.add_argument('directory')
    command.add_argument('--name', default='My First App')
    command.add_argument('--id', default='com.example.myapp')
    command = sub.add_parser('run', help='Build and launch an iOS or Android project')
    command.add_argument('directory')
    command.add_argument('--device', help='iOS Simulator UDID or Android device serial')
    command.add_argument('--platform', choices=('ios','android'), default='ios')
    command.add_argument('--android-sdk')
    command.add_argument('--java-home')
    command.add_argument('--gradle')
    command.add_argument('--build-only', action='store_true')
    authoring_options(command)
    for name in ('validate', 'inspect'):
        command = sub.add_parser(name)
        command.add_argument('source')
        authoring_options(command)
    command = sub.add_parser('compile')
    command.add_argument('source')
    command.add_argument('--out', required=True)
    command.add_argument('--target', action='append', choices=('ios', 'android'))
    command.add_argument('--dry-run', action='store_true')
    authoring_options(command)
    command = sub.add_parser('schema')
    command.add_argument('--authoring-version',type=int,choices=(1,2),default=1)
    command = sub.add_parser('registry')
    command.add_argument('query', nargs='?', default='')
    command = sub.add_parser('audit')
    command.add_argument('output')
    command = sub.add_parser('ingest')
    command.add_argument('source')
    command.add_argument('--format', required=True, choices=('apple-symbolgraph', 'android-api'))
    command.add_argument('--sdk', required=True)
    command.add_argument('--out', required=True)
    command = sub.add_parser('mcp')
    command.add_argument('--catalog')
    command = sub.add_parser('mcp-config', help='Print an MCP client configuration block for this compiler')
    command.add_argument('--client', default='generic')
    command = sub.add_parser('design-guidance', help='Platform-first authoring guidance and the design-companion registration')
    command.add_argument('topic', nargs='?', default=None,
                         help='overview, list, navigation, form, cards or tabbar')
    command = sub.add_parser('doctor', help='Check installed native toolchains (Xcode, Android, Dart, dcdart)')
    command.add_argument('--install', action='store_true', help='Opt in to installing missing dev toolchains')
    command.add_argument('--tool', action='append', default=[], help='Install only these tools (dart, dcc)')
    command = sub.add_parser('module', help='Resolve and verify development-time native dependencies')
    modules = command.add_subparsers(dest='module_command', required=True)
    item = modules.add_parser('install')
    item.add_argument('manifest')
    item.add_argument('--out', required=True)
    item.add_argument('--gradle', default='gradle')
    item.add_argument('--java-home')
    item.add_argument('--android-project',help='Resolve against this trusted Android app runtime graph to align shared dependencies')
    item = modules.add_parser('verify')
    item.add_argument('lock')
    item = modules.add_parser('export-android')
    item.add_argument('lock')
    item.add_argument('--catalog',required=True)
    item.add_argument('--javap',default='javap')
    item.add_argument('--sdk',type=int,default=35)
    command = sub.add_parser('sdk', help='Index, search and use actual native SDK APIs')
    sdk = command.add_subparsers(dest='sdk_command',required=True)
    for name in ('search','get','coverage','emit','emit-sequence','emit-operation','index-android','index-android-core','index-android-sdk','index-ios','verify-ios','verify-ios-invocations','verify-android-availability','plan-android-specializations','plan-ios-type-dependencies','verify-android-specializations','test-android-values'):
        item = sdk.add_parser(name)
        if name not in ('verify-ios-invocations','plan-ios-type-dependencies'):
            item.add_argument('--catalog',
                              help='SDK catalog; defaults to $DCFLIGHT_SDK_CATALOG or ~/.dcflight/sdk-catalog/sdk.sqlite')
        if name == 'search':
            item.add_argument('query',nargs='?',default='')
            item.add_argument('--platform',choices=('ios','android'))
            item.add_argument('--scope')
            item.add_argument('--supported',action='store_true')
            item.add_argument('--limit',type=int,default=20)
            item.add_argument('--offset',type=int,default=0)
        elif name == 'get':
            item.add_argument('id')
            item.add_argument('--platform',required=True,choices=('ios','android'))
            item.add_argument('--scope')
        elif name in ('emit','emit-sequence','emit-operation'):
            item.add_argument('invocation',help='JSON file containing a typed native API invocation')
            if name == 'emit-operation':authoring_options(item)
        elif name=='test-android-values':
            item.add_argument('--sdk',type=Path,required=True)
            item.add_argument('--java-home',type=Path,required=True)
            item.add_argument('--serial',required=True)
            item.add_argument('--api-level',type=int,default=35)
            item.add_argument('--build-tools',default='35.0.0')
            item.add_argument('--report',type=Path,required=True)
        elif name=='plan-ios-type-dependencies':
            item.add_argument('--capture',type=Path,required=True)
            item.add_argument('--output',type=Path,required=True)
            item.add_argument('--module',action='append')
            item.add_argument('--timeout',type=int,default=1800)
            item.add_argument('--min-free-mb',type=int,default=1024)
        elif name=='plan-android-specializations':
            item.add_argument('--scope',required=True)
            item.add_argument('--output',type=Path,required=True)
            item.add_argument('--max-trials',type=int,default=250000)
        elif name=='verify-android-specializations':
            from .android_specialization_verification import add_arguments
            add_arguments(item)
        elif name=='verify-android-availability':
            from .android_availability_verification import add_arguments
            add_arguments(item,catalog=False)
        elif name=='verify-ios-invocations':
            from .ios_invocation_evidence import add_arguments
            add_arguments(item)
        elif name=='verify-ios':
            item.add_argument('source',help='Directory containing plain or compressed SDK symbol graphs')
            item.add_argument('--module',required=True)
            item.add_argument('--report',required=True)
            item.add_argument('--limit',type=int,default=0)
            item.add_argument('--batch-size',type=int,default=200)
            item.add_argument('--ios-version',default='18.0')
            item.add_argument('--sdk-environment',choices=('iphonesimulator','iphoneos'),default='iphonesimulator')
            item.add_argument('--swift-version',choices=('5','6'),default='5')
            item.add_argument('--import',dest='additional_imports',action='append',default=[])
            item.add_argument('--type-module',action='append',default=[],metavar='MODULE=SYMBOLGRAPH_DIR')
        elif name.startswith('index-'):
            item.add_argument('source')
            if name in ('index-android','index-android-core'):item.add_argument('--sdk',type=int,default=35)
            if name=='index-android-sdk':
                item.add_argument('--sdk',type=int)
                item.add_argument('--api-versions')
            if name in ('index-android-core','index-android-sdk'):item.add_argument('--javap',default='javap')
    args = parser.parse_args(argv)
    try:
        if 'catalog' in vars(args) and args.catalog is None and getattr(args, 'sdk_command', None):
            from .mcp import discover_catalog
            discovered = discover_catalog()
            if discovered:
                args.catalog = str(discovered)
            elif args.sdk_command not in ('verify-android-availability',):
                raise ValueError('No SDK catalog found. Pass --catalog, set DCFLIGHT_SDK_CATALOG, '
                                 'or place a catalog at ~/.dcflight/sdk-catalog/sdk.sqlite '
                                 '(create one with: dcflight sdk index-ios/--android …)')
        registry = Registry()
        if args.command == 'create':
            from .develop import create_project
            result = create_project(args.directory, args.name, args.id)
        elif args.command == 'run':
            if args.platform == 'android':
                from .android_develop import run_android
                result = run_android(args.directory,args.device,args.android_sdk,args.java_home,args.gradle,args.build_only,
                                     evaluate_dart=args.evaluate_dart, dart=args.dart_sdk)
            else:
                if args.build_only:raise ValueError('--build-only currently applies to Android')
                from .develop import run_ios
                result = run_ios(args.directory, args.device, evaluate_dart=args.evaluate_dart, dart=args.dart_sdk)
        elif args.command == 'compile':
            result = compile_app(args.source, args.out, tuple(args.target or ('ios', 'android')), args.dry_run, registry,
                                 evaluate_dart=args.evaluate_dart, dart=args.dart_sdk)
        elif args.command in ('validate', 'inspect'):
            if args.evaluate_dart:
                from .evaluated_frontend import load_evaluated
                data = load_evaluated(args.source, args.dart_sdk)
            else:
                data = load(args.source)
            app = lower(data, registry)
            result = asdict(app) if args.command == 'inspect' else {'valid': True, 'nodes': len(app.nodes())}
        elif args.command == 'schema':
            if args.authoring_version==2:
                from .navigation_ir import schema
                result=schema(registry)
            else:result = registry.schema()
        elif args.command == 'registry':
            result = registry.search(args.query)
        elif args.command == 'mcp-config':
            from .mcp import mcp_config
            result = mcp_config(args.client)
        elif args.command == 'design-guidance':
            from .design_companion import guidance
            result = guidance(args.topic)
        elif args.command == 'doctor':
            from . import doctor
            if args.install or args.tool:
                result = doctor.install(args.tool or None,
                                        progress=lambda row: print(json.dumps(row), file=sys.stderr, flush=True))
            else:
                result = doctor.status()
        elif args.command == 'audit':
            result = audit(args.output)
        elif args.command == 'ingest':
            result = ingest(args.source, args.format, args.sdk)
            Path(args.out).parent.mkdir(parents=True, exist_ok=True)
            Path(args.out).write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
            result = {'symbols': len(result['symbols']), 'output': args.out}
        elif args.command == 'module':
            from .modules.resolve import install, verify
            if args.module_command == 'install':
                result = install(args.manifest,args.out,gradle=args.gradle,java_home=args.java_home,android_project=args.android_project)
            elif args.module_command == 'export-android':
                from .modules.export import export_android
                result = export_android(args.lock,args.catalog,javap=args.javap,sdk=args.sdk)
            else:
                lock = verify(args.lock)
                result = {'valid':True,'module':lock['module']['id'],'artifacts':len(lock['artifacts']),'verification':lock['verification']}
        elif args.command == 'sdk':
            from .catalog import Catalog
            from .native_api import NativeAPI,index_android,index_ios_sweep
            if args.sdk_command=='test-android-values':
                from .android_verification import run
                args.catalog=Path(args.catalog)
                result=run(args,progress=False)
            elif args.sdk_command=='plan-ios-type-dependencies':
                from .ios_type_dependency_batch import plan_batch
                if args.min_free_mb < 0:raise ValueError('Disk floor must be nonnegative')
                report=plan_batch(args.capture,args.output,modules=args.module,timeout=args.timeout,
                                  disk_floor=args.min_free_mb*1024*1024,
                                  progress=lambda row:print(json.dumps(row),file=sys.stderr,flush=True))
                result={'output':str(args.output),'modules':len(report['modules']),
                        'planned':sum(row['status']=='planned' for row in report['modules']),
                        'rejected':sum(row['status']=='rejected' for row in report['modules']),
                        'nativeTested':0,'catalogMutation':False}
            elif args.sdk_command=='plan-android-specializations':
                from .android_generic_invocation import plan_catalog
                from .c_callback_recovery import reject_symlinks
                result=plan_catalog(args.catalog,args.scope,max_trials=args.max_trials)
                reject_symlinks(args.output.absolute())
                args.output.parent.mkdir(parents=True,exist_ok=True)
                with args.output.open('x') as stream:json.dump(result,stream,indent=2)
                result={'output':str(args.output),'candidateCount':result['candidateCount'],'planned':len(result['requests']),'unplanned':len(result['unplanned']),'nativeVerified':False}
            elif args.sdk_command=='verify-android-specializations':
                from .android_specialization_verification import run
                result=run(args)
            elif args.sdk_command=='verify-android-availability':
                from .android_availability_verification import run
                result=run(args,progress=True)
            elif args.sdk_command=='verify-ios-invocations':
                from .ios_invocation_evidence import run
                result=run(args)
            elif args.sdk_command=='verify-ios':
                from .ios_verification import verify_and_index, parse_type_modules
                result=verify_and_index(args.catalog,args.source,args.module,args.report,limit=args.limit,batch_size=args.batch_size,ios_version=args.ios_version,swift_version=args.swift_version,additional_imports=args.additional_imports,type_modules=parse_type_modules(args.type_module),sdk_environment=args.sdk_environment)
            elif args.sdk_command=='index-android-sdk':
                from .modules.export import index_android_sdk
                result=index_android_sdk(args.source,args.catalog,javap=args.javap,sdk=args.sdk,**({'api_versions':args.api_versions} if args.api_versions else {}))
            elif args.sdk_command=='index-android-core':
                from .modules.export import index_android_core
                result=index_android_core(args.source,args.catalog,javap=args.javap,sdk=args.sdk)
            elif args.sdk_command=='index-android':result=index_android(args.catalog,args.source,args.sdk)
            elif args.sdk_command=='index-ios':result=index_ios_sweep(args.catalog,args.source)
            elif args.sdk_command=='emit':result=NativeAPI(args.catalog).emit(load(args.invocation))
            elif args.sdk_command=='emit-operation':
                from .native_operation import emit_operation
                if args.evaluate_dart:
                    from .evaluated_frontend import load_evaluated_operation
                    document=load_evaluated_operation(args.invocation,args.dart_sdk)
                else:
                    document=load(args.invocation)
                result=emit_operation(NativeAPI(args.catalog),document)
            elif args.sdk_command=='emit-sequence':
                from .native_sequence import emit_sequence
                result=emit_sequence(NativeAPI(args.catalog),load(args.invocation))
            else:
                with Catalog(args.catalog) as catalog:
                    if args.sdk_command=='search':result=catalog.search(args.query,args.platform,args.scope,args.supported,args.limit,args.offset)
                    elif args.sdk_command=='get':result=catalog.get(args.platform,args.id,args.scope)
                    else:result=catalog.coverage()
        else:
            from .mcp import serve
            serve(catalog=args.catalog)
            return 0
        print(json.dumps(result, indent=2))
        return 1 if isinstance(result, dict) and result.get('passed') is False else 0
    except (ValueError, OSError, KeyError, TypeError, RecursionError, subprocess.CalledProcessError) as error:
        print(json.dumps({'error': str(error)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
