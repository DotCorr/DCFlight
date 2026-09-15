"""Read-only MCP stdio server, protocol 2025-03-26. No app-side endpoint."""
import json
import sys
from dataclasses import asdict
from . import __version__
from .frontends import read_json
from .registry import Registry
from .validate import lower


def object_schema(properties, required=()):
    return {'type': 'object', 'properties': properties, 'required': list(required), 'additionalProperties': False}


TOOLS = [
    {'name': 'registry_search', 'description': 'Search reviewed semantic capabilities and their native mappings.',
     'inputSchema': object_schema({'query': {'type': 'string'}})},
    {'name': 'app_schema', 'description': 'Return the JSON authoring schema.', 'inputSchema': object_schema({})},
    {'name': 'validate_app', 'description': 'Validate a JSON app and inspect its typed canonical IR without executing it.',
     'inputSchema': object_schema({'app': {'type': 'object'}}, ('app',))}
]


class Server:
    def __init__(self):
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
            response['result'] = {'tools': TOOLS}
        elif method == 'tools/call':
            try:
                name, args = params.get('name'), params.get('arguments', {})
                if not isinstance(args, dict):
                    raise ValueError('arguments must be an object')
                descriptor = next((t for t in TOOLS if t['name'] == name), None)
                if descriptor is None:
                    raise ValueError('Unknown tool')
                schema = descriptor['inputSchema']
                if set(args) - set(schema['properties']) or not set(schema['required']) <= set(args):
                    raise ValueError('Unknown or missing arguments')
                if name == 'registry_search':
                    query = args.get('query', '')
                    if not isinstance(query, str):
                        raise ValueError('query must be a string')
                    result = self.registry.search(query)
                elif name == 'app_schema':
                    result = self.registry.schema()
                else:
                    result = asdict(lower(args['app'], self.registry))
                response['result'] = {'content': [{'type': 'text', 'text': json.dumps(result)}], 'isError': False}
            except (ValueError, KeyError, TypeError, RecursionError) as error:
                response['result'] = {'content': [{'type': 'text', 'text': str(error)}], 'isError': True}
        else:
            response['error'] = {'code': -32601, 'message': 'Method not found'}
        return response


def serve(input_stream=None, output_stream=None):
    input_stream = input_stream or sys.stdin
    output_stream = output_stream or sys.stdout
    server = Server()
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
