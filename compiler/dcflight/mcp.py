"""Read-only MCP stdio server, protocol 2025-03-26. No app-side endpoint."""
import json
import os
import sys
import sqlite3
from dataclasses import asdict
from pathlib import Path
from . import __version__
from .frontends import read_json
from .registry import Registry
from .validate import lower
from .catalog import Catalog
from .native_api import NativeAPI


def object_schema(properties, required=()):
    return {'type': 'object', 'properties': properties, 'required': list(required), 'additionalProperties': False}


TOOLS = [
    {'name': 'registry_search', 'description': 'Search reviewed semantic capabilities and their native mappings.',
     'inputSchema': object_schema({'query': {'type': 'string'}})},
    {'name': 'app_schema', 'description': 'Return the JSON authoring schema.', 'inputSchema': object_schema({'version': {'type': 'integer', 'enum': [1, 2]}})},
    {'name': 'validate_app', 'description': 'Validate a JSON app and inspect its typed canonical IR without executing it.',
     'inputSchema': object_schema({'app': {'type': 'object'}}, ('app',))}
]


SDK_TOOLS = [
    {'name':'sdk_android_invocation_schema','description':'Read the typed Android invocation schema, including explicit generic owner and callable arguments.','inputSchema':object_schema({})},
    {'name': 'sdk_emit_operation', 'description': 'Emit both native implementations of one shared scalar operation contract. No execution.',
     'inputSchema': object_schema({'operation': {'type': 'object'}}, ('operation',))},
    {'name': 'sdk_emit_sequence', 'description': 'Emit a native block with checked local dataflow; no execution or runtime interpreter.',
     'inputSchema': object_schema({'sequence': {'type': 'object'}}, ('sequence',))},
    {'name': 'sdk_search', 'description': 'Search SDK signatures with bounded pagination. Generic-only unsupported records can accept explicit substitutions; inspect invocationRequirements. Unbound emittable and native-tested remain distinct.',
     'inputSchema': object_schema({'query': {'type': 'string'}, 'platform': {'type': 'string'},
         'scope': {'type': 'string'}, 'emittable_only': {'type': 'boolean'},
         'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100}, 'offset': {'type': 'integer', 'minimum': 0}})},
    {'name': 'sdk_get', 'description': 'Inspect an exact SDK signature, requirements, unsupported reasons and native verification evidence.',
     'inputSchema': object_schema({'platform': {'type': 'string'}, 'id': {'type': 'string'}, 'scope': {'type': 'string'}}, ('platform','id'))},
    {'name': 'sdk_coverage', 'description': 'Read actual SDK inventory, emission and native verification coverage.',
     'inputSchema': object_schema({})},
    {'name': 'sdk_emit', 'description': 'Emit a typed ordinary native API expression. Does not execute platform APIs or edit files.',
     'inputSchema': object_schema({'invocation': {'type': 'object'}}, ('invocation',))}
]


AUTHORING_TOOLS = [
    {'name': 'doctor', 'description': 'Report installed native toolchains (Xcode, Android SDK, Dart, dcdart) and readiness.',
     'inputSchema': object_schema({})},
    {'name': 'doctor_install', 'description': 'Install missing dev toolchains (Dart SDK, dcdart) after explicit user confirmation. Never run without the user asking for installation.',
     'inputSchema': object_schema({'tools': {'type': 'array', 'items': {'type': 'string'}}})},
    {'name': 'mcp_config', 'description': 'Return an MCP client configuration block (command, args, env) for launching this server with its SDK catalog.',
     'inputSchema': object_schema({'client': {'type': 'string'}})},
    {'name': 'compile_app', 'description': 'Compile a trusted local Dart authoring file (buildApp()) into native iOS and Android projects at outDir. Runs the trusted-local Dart toolchain; never call on untrusted files.',
     'inputSchema': object_schema({'source': {'type': 'string'}, 'outDir': {'type': 'string'},
         'target': {'type': 'string', 'enum': ['ios', 'android']}, 'dart': {'type': 'string'}}, ('source', 'outDir'))},
    {'name': 'design_guidance', 'description': 'Platform-first authoring guidance (overview, list, navigation, form, cards, tabbar) plus the default design-companion registration (Appllama MCP + skills). Users may replace the companion with their own skills.',
     'inputSchema': object_schema({'topic': {'type': 'string'}})},
]


def mcp_config(client='generic'):
    """Client-specific launch block for this server, with catalog auto-discovery."""
    executable = Path(sys.argv[0]).resolve()
    command = [str(executable)]
    if executable.name != 'dcflight-mcp':
        command = ['dcflight', 'mcp']
    args = command[1:]
    catalog = discover_catalog()
    env = {}
    if catalog:
        env['DCFLIGHT_SDK_CATALOG'] = str(catalog)
    config = {'command': command[0], 'args': args, 'env': env}
    if client in ('claude', 'claude-desktop', 'claude_desktop'):
        return {'client': 'claude-desktop', 'mcpServers': {'dcflight': config}}
    if client in ('vscode', 'vs-code', 'code'):
        return {'client': 'vscode', 'mcp': {'servers': {'dcflight': dict(config, type='stdio')}}}
    if client in ('cursor',):
        return {'client': 'cursor', 'mcpServers': {'dcflight': config}}
    return {'client': client, 'mcpServers': {'dcflight': config}}


def discover_catalog():
    """Env var first, then the user catalog location; None when absent (tools degrade)."""
    env = os.environ.get('DCFLIGHT_SDK_CATALOG')
    if env:
        path = Path(env).expanduser()
        return path if path.is_file() else None
    default = Path.home() / '.dcflight' / 'sdk-catalog' / 'sdk.sqlite'
    return default if default.is_file() else None


class Server:
    def __init__(self, catalog=None):
        self.catalog = catalog
        self.native_api = NativeAPI(catalog) if catalog else None
        self.tools = TOOLS + SDK_TOOLS + AUTHORING_TOOLS if catalog else TOOLS + AUTHORING_TOOLS
        self.registry = Registry()
        self.initialized = False

    def handle(self, request):
        if not isinstance(request, dict) or request.get('jsonrpc') != '2.0' or not isinstance(request.get('method'), str):
            return {'jsonrpc': '2.0', 'id': None, 'error': {'code': -32600, 'message': 'Invalid request'}}
        method = request['method']
        if 'id' not in request:
            return None
        identity = request['id']
        response = {'jsonrpc': '2.0', 'id': identity}
        params = request.get('params', {})
        if not isinstance(params, dict):
            response['error'] = {'code': -32602, 'message': 'params must be an object'}
            return response
        if method == 'initialize':
            self.initialized = True
            response['result'] = {'protocolVersion': '2025-03-26', 'capabilities': {'tools': {}},
                                  'serverInfo': {'name': 'dcflight', 'version': __version__}}
        elif method == 'ping':
            response['result'] = {}
        elif not self.initialized:
            response['error'] = {'code': -32002, 'message': 'Initialize first'}
        elif method == 'tools/list':
            response['result'] = {'tools': self.tools}
        elif method == 'tools/call':
            try:
                name, args = params.get('name'), params.get('arguments', {})
                if not isinstance(args, dict):
                    raise ValueError('arguments must be an object')
                descriptor = next((t for t in self.tools if t['name'] == name), None)
                if descriptor is None:
                    raise ValueError('Unknown tool')
                schema = descriptor['inputSchema']
                if set(args) - set(schema['properties']) or not set(schema['required']) <= set(args):
                    raise ValueError('Unknown or missing arguments')
                for key, value in args.items():
                    expected = schema['properties'][key].get('type')
                    types = {'string': str, 'integer': int, 'boolean': bool, 'object': dict}
                    if expected in types and type(value) is not types[expected]:
                        raise ValueError(key + ' must have type ' + expected)
                if name == 'doctor':
                    from .doctor import status
                    result = status()
                elif name == 'doctor_install':
                    from .doctor import install
                    result = install(args.get('tools') or None,
                                     progress=lambda row: print(json.dumps(row), file=sys.stderr, flush=True))
                elif name == 'mcp_config':
                    result = mcp_config(args.get('client', 'generic'))
                elif name == 'compile_app':
                    from .compiler import compile_app
                    from .evaluated_frontend import load_evaluated
                    targets = (args['target'],) if 'target' in args else ('ios', 'android')
                    data = load_evaluated(args['source'], args.get('dart') or 'dart')
                    files = compile_app(Path(args['source']), args['outDir'], targets, document=data)
                    result = {'outDir': str(Path(args['outDir']).resolve()),
                              'targets': list(targets), 'files': len(files)}
                elif name == 'design_guidance':
                    from .design_companion import guidance
                    result = guidance(args.get('topic'))
                elif name == 'registry_search':
                    query = args.get('query', '')
                    if not isinstance(query, str):
                        raise ValueError('query must be a string')
                    result = self.registry.search(query)
                elif name == 'app_schema':
                    version = args.get('version', 1)
                    if version not in (1, 2):
                        raise ValueError('Unsupported authoring version')
                    if version == 2:
                        from .navigation_ir import schema as routed_schema
                        result = routed_schema(self.registry)
                    else:
                        result = self.registry.schema()
                elif name == 'sdk_emit_operation':
                    from .native_operation import emit_operation
                    result = emit_operation(self.native_api,args['operation'])
                elif name == 'sdk_emit_sequence':
                    from .native_sequence import emit_sequence
                    result = emit_sequence(self.native_api,args['sequence'])
                elif name == 'sdk_emit':
                    result = self.native_api.emit(args['invocation'])
                elif name=='sdk_android_invocation_schema':
                    from .android_generic_invocation import request_schema
                    result=request_schema()
                elif name.startswith('sdk_'):
                    with Catalog(self.catalog) as catalog:
                        if name == 'sdk_search':
                            result = catalog.search(**args)
                        elif name == 'sdk_get':
                            result = catalog.get(args['platform'], args['id'], args.get('scope'))
                        else:
                            result = catalog.coverage()
                else:
                    result = asdict(lower(args['app'], self.registry))
                response['result'] = {'content': [{'type': 'text', 'text': json.dumps(result)}], 'isError': False}
            except (ValueError, KeyError, TypeError, RecursionError, OSError, sqlite3.Error) as error:
                response['result'] = {'content': [{'type': 'text', 'text': str(error)}], 'isError': True}
        else:
            response['error'] = {'code': -32601, 'message': 'Method not found'}
        return response


def serve(input_stream=None, output_stream=None, catalog=None):
    input_stream = input_stream or sys.stdin
    output_stream = output_stream or sys.stdout
    server = Server(catalog=catalog or discover_catalog())
    for line in input_stream:
        try:
            if len(line) > 8 * 1024 * 1024:
                raise ValueError('Request too large')
            response = server.handle(read_json(line))
        except (ValueError, RecursionError) as error:
            response = {'jsonrpc': '2.0', 'id': None, 'error': {'code': -32700, 'message': str(error)}}
        if response is not None:
            output_stream.write(json.dumps(response) + '\n')
            output_stream.flush()
