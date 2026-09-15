"""Direct native execution emitted from typed shared flow/effect declarations."""
import plistlib
from . import Artifact,HEADER
from .common import expression
from ..shared_logic import c_alias
from ..ir import ScalarType,ABIType,Reference


def quoted(value):
    from ..ir import Literal
    return expression(Literal(value,ScalarType.STRING),'ios')


def value(expr):return 'self.s_'+expr.name if isinstance(expr,Reference) else expression(expr,'ios')


def logic_call_effect(effect, app):
    """Publish only a validated shared string, then dispatch exactly one flow."""
    from ..shared_logic import call_expression
    call=call_expression(app,effect,'ios',lambda item,prefix:value(item))
    return ('let logicResult: String\ndo { logicResult = '+call+
            ' } catch { self.f_'+effect.failure+'(navigate); return }\nself.s_'+effect.target+
            ' = logicResult\nself.f_'+effect.success+'(navigate)\nreturn')


def native_operation_effect(effect, contract):
    """Emit one scalar call with atomic result publication and authored failure."""
    from ..native_operation import NATIVE_OPERATION_MAX_STRING_BYTES
    from ..flow_ir import Projection
    from ..media_ir import MediaProjection
    lines=[];arguments=[]
    for index,(argument,parameter) in enumerate(zip(effect.arguments,contract.parameters)):
        if isinstance(argument,Projection):
            operand=value(argument.value)
            raw=('('+operand+' ? Int32(1) : Int32(0))') if argument.operation=='flag' else operand+('.unicodeScalars.count' if argument.operation=='length' else '.utf8.count')
        elif isinstance(argument,MediaProjection):
            operand='self.m_'+argument.value.name
            raw='('+operand+' != nil)' if argument.operation=='hasMedia' else '('+operand+'?.'+{'mediaBytes':'byteLength','mediaWidth':'width','mediaHeight':'height'}[argument.operation]+' ?? 0)'
        else:raw=value(argument)
        local='nativeArgument'+str(index)
        if parameter.type==ScalarType.INT:
            lines.append('guard let '+local+' = Int32(exactly: '+raw+') else { self.f_'+effect.failure+'(navigate); return }')
        else:lines.append('let '+local+' = '+raw)
        arguments.append(local)
    suspends=getattr(contract,'suspends',False)
    call=('try ' if contract.throws else '')+('await ' if suspends else '')+'NativeOperation_'+contract.name+'.invoke('+', '.join(arguments)+')'
    if contract.execution == 'worker' or suspends:
        native_type={ScalarType.INT:'Int32',ScalarType.STRING:'String',ScalarType.BOOL:'Bool'}[contract.result]
        worker=['try Task.checkCancellation()', 'let nativeResult = '+call]
        if contract.result==ScalarType.STRING:
            worker.append('guard nativeResult.utf8.count <= '+str(NATIVE_OPERATION_MAX_STRING_BYTES)+' else { throw NativeEffectFailure.responseLimit }')
        worker.extend(['try Task.checkCancellation()', 'return nativeResult'])
        task=('Task.detached(priority: .userInitiated) { @Sendable' if contract.execution=='worker' else 'Task { @MainActor @Sendable')
        return ('nativeWorkerGeneration &+= 1; nativeWorkerTask?.cancel(); nativeWorkerTask = nil\n'
                'let nativeGeneration = nativeWorkerGeneration\n'+'\n'.join(lines)+'\n'
                'let nativeWork = '+task+' () async throws -> '+native_type+' in\n'+
                '\n'.join(worker)+'\n}\n'
                'nativeWorkerTask = Task { @MainActor [weak self] in\n'
                'let outcome: Result<'+native_type+', Error>\n'
                'do {\nlet result = try await withTaskCancellationHandler(operation: { try await nativeWork.value }, onCancel: { nativeWork.cancel() })\n'
                'outcome = .success(result)\n} catch { outcome = .failure(error) }\n'
                'guard !Task.isCancelled, let self, nativeGeneration == self.nativeWorkerGeneration else { return }\n'
                'self.nativeWorkerTask = nil\n'
                'switch outcome {\ncase .success(let nativeResult):\nself.s_'+effect.target+' = nativeResult\nself.f_'+effect.success+'(navigate)\n'
                'case .failure: self.f_'+effect.failure+'(navigate)\n}\n}\nreturn')
    lines.append('let nativeResult = '+call)
    if contract.result==ScalarType.STRING:
        lines.append('guard nativeResult.utf8.count <= '+str(NATIVE_OPERATION_MAX_STRING_BYTES)+' else { self.f_'+effect.failure+'(navigate); return }')
    lines.extend(['self.s_'+effect.target+' = nativeResult','self.f_'+effect.success+'(navigate); return'])
    source='do {\n'+'\n'.join(lines)+'\n}'
    if contract.throws:source+=' catch { self.f_'+effect.failure+'(navigate); return }'
    return source


HELPERS=r'''import Foundation
import Security
import CoreFoundation

enum NativeEffectFailure: Error { case invalidResponse, responseLimit, secureStore, invalidAddress }
enum NativeJSONScalar {
    static func field(_ root: Any, path: [String]) throws -> Any {
        var current=root
        for key in path { guard let object=current as? [String:Any],let next=object[key],!(next is NSNull) else { throw NativeEffectFailure.invalidResponse };current=next }
        return current
    }
    static func string(_ root: Any, path: [String]) throws -> String {
        guard let value=try field(root,path:path) as? String else { throw NativeEffectFailure.invalidResponse };return value
    }
    static func bool(_ root: Any, path: [String]) throws -> Bool {
        guard let value=try field(root,path:path) as? NSNumber,CFGetTypeID(value)==CFBooleanGetTypeID() else { throw NativeEffectFailure.invalidResponse };return value.boolValue
    }
    static func int(_ root: Any, path: [String]) throws -> Int32 {
        guard let value=try field(root,path:path) as? NSNumber,CFGetTypeID(value) != CFBooleanGetTypeID(),
              !["f","d"].contains(String(cString:value.objCType)),value.doubleValue >= Double(Int32.min),value.doubleValue <= Double(Int32.max) else { throw NativeEffectFailure.invalidResponse }
        return value.int32Value
    }
}
enum NativeURLComponent {
    static func encode(_ value: String) -> String {
        value.utf8.map { byte in
            if (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || [45,46,95,126].contains(byte) { return String(UnicodeScalar(byte)) }
            return String(format:"%%%02X",byte)
        }.joined()
    }
}
final class NativeHTTPTransport: NSObject, URLSessionTaskDelegate {
    private var session: URLSession!
    override init() {
        super.init()
        let configuration=URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest=25;configuration.timeoutIntervalForResource=25
        configuration.httpCookieStorage=nil;configuration.urlCache=nil
        session=URLSession(configuration:configuration,delegate:self,delegateQueue:nil)
    }
    func close() { session.invalidateAndCancel() }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func send(url: URL, method: String, body: [String:Any], bearer: String?, rawBody: Data? = nil, maxBytes: Int = 8_388_608) async throws -> (Data,Int) {
        try Task.checkCancellation()
        var request=URLRequest(url:url);request.httpMethod=method;request.setValue("application/json",forHTTPHeaderField:"Accept")
        if let rawBody { request.httpBody=rawBody;request.setValue("image/jpeg",forHTTPHeaderField:"Content-Type") }
        else if !body.isEmpty { request.httpBody=try JSONSerialization.data(withJSONObject:body);request.setValue("application/json",forHTTPHeaderField:"Content-Type") }
        if let bearer { request.setValue("Bearer "+bearer,forHTTPHeaderField:"Authorization") }
        let (bytes,response)=try await session.bytes(for:request)
        defer { bytes.task.cancel() }
        guard let response=response as? HTTPURLResponse else { throw NativeEffectFailure.invalidResponse }
        guard response.expectedContentLength <= Int64(maxBytes) else { throw NativeEffectFailure.responseLimit }
        var data=Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maxBytes else { throw NativeEffectFailure.responseLimit }
            data.append(byte)
        }
        return (data,response.statusCode)
    }
}
enum NativeSecureStore {
    private static func query(_ key: String) throws -> [String:Any] {
        guard let bundle=Bundle.main.bundleIdentifier else { throw NativeEffectFailure.secureStore }
        return [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:bundle+"."+NativeEffectConfiguration.secureNamespace,kSecAttrAccount as String:key]
    }
    static func read(_ key: String) throws -> String {
        var parameters=try query(key);parameters[kSecReturnData as String]=true;parameters[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?;let status=SecItemCopyMatching(parameters as CFDictionary,&result)
        if status==errSecItemNotFound { return "" }
        guard status==errSecSuccess,let data=result as? Data,let text=String(data:data,encoding:.utf8) else { throw NativeEffectFailure.secureStore };return text
    }
    static func write(_ key: String, value: String) throws {
        let parameters=try query(key),data=Data(value.utf8)
        let status=SecItemUpdate(parameters as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status==errSecItemNotFound {
            var addition=parameters;addition[kSecValueData as String]=data;addition[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(addition as CFDictionary,nil)==errSecSuccess else { throw NativeEffectFailure.secureStore }
        } else if status != errSecSuccess { throw NativeEffectFailure.secureStore }
    }
    static func delete(_ key: String) throws {
        let status=SecItemDelete(try query(key) as CFDictionary)
        guard status==errSecSuccess || status==errSecItemNotFound else { throw NativeEffectFailure.secureStore }
    }
}
'''


def enhance(app,files):
    flows=getattr(app,'flow_actions',())
    workers=any(c.execution == 'worker' or getattr(c,'suspends',False) for c in getattr(app,'native_operations',()))
    collections={c.name:c for c in getattr(app,"collections",())}
    media=getattr(app,"media_states",())
    def media_node(node):return node.capability in ("localImage","remoteImage") or any(media_node(child) for child in node.children)
    camera_resources=getattr(app,"camera_resources",())
    needs_device=bool(camera_resources or getattr(app,"permission_descriptions",()) or getattr(app,"map_config",None))
    needs_media=needs_device or bool(media) or media_node(app.root) or any(media_node(route.body) for route in getattr(app,"routes",()))
    if not flows and not collections and not needs_media:return
    from ..media_ir import PickPhotoEffect,ClearMediaEffect,MediaBody,MediaProjection
    from ..flow_ir import Projection,SetEffect,NavigateEffect,RequestEffect,ResponseOutput,SecureEffect,InvokeEffect,CancelEffect,PathTemplate,ClearCollectionEffect,ClockEffect,ReadCollectionEffect,NativeOperationEffect,LogicCallEffect
    from ..device_ir import PermissionEffect,CameraFacingEffect,CapturePhotoEffect,LocationEffect
    types={state.name:state.initial.type for state in app.states}
    def effects(items):
        result=[]
        for effect in items:
            if isinstance(effect,SetEffect):result.append('self.s_'+effect.target+' = '+value(effect.value))
            elif isinstance(effect,LogicCallEffect):
                result.append(logic_call_effect(effect,app))
            elif isinstance(effect,NativeOperationEffect):
                contract=next(c for c in app.native_operations if c.name==effect.operation)
                result.append(native_operation_effect(effect,contract))
            elif isinstance(effect,NavigateEffect):result.append('navigate('+quoted(effect.action)+')')
            elif isinstance(effect,PermissionEffect):
                call='NativePermission.camera()' if effect.capability=='camera' else 'self.nativeLocation.authorize()'
                result.append('nativeDeviceGeneration &+= 1; let generation=nativeDeviceGeneration; nativeDeviceTask?.cancel(); nativeLocationInstance?.cancel()\nnativeDeviceTask=Task { @MainActor [weak self] in\nguard let self else { return }; let status=await '+call+'\nguard generation==self.nativeDeviceGeneration,!Task.isCancelled else { return }\nself.s_'+effect.status_target+'=status\nif status==1 { self.f_'+effect.success+'(navigate) } else { self.f_'+effect.failure+'(navigate) }\n}\nreturn')
            elif isinstance(effect,LocationEffect):
                result.append('nativeDeviceGeneration &+= 1; let generation=nativeDeviceGeneration; nativeDeviceTask?.cancel(); nativeLocationInstance?.cancel()\nnativeDeviceTask=Task { @MainActor [weak self] in\nguard let self else { return }; let coordinate=await self.nativeLocation.read(timeoutMs:'+str(effect.timeout_ms)+')\nguard generation==self.nativeDeviceGeneration,!Task.isCancelled else { return }\nguard let coordinate else { self.f_'+effect.failure+'(navigate); return }\nself.s_'+effect.latitude_target+'=coordinate.latitude;self.s_'+effect.longitude_target+'=coordinate.longitude;self.s_'+effect.accuracy_target+'=coordinate.accuracy;self.f_'+effect.success+'(navigate)\n}\nreturn')
            elif isinstance(effect,CameraFacingEffect):
                result.append('let generation=nativeDeviceGeneration\ncamera_'+effect.resource+'.face(front:'+('true' if effect.facing=='front' else 'false')+') { [weak self] succeeded in\nguard let self,generation==self.nativeDeviceGeneration else { return }\nif succeeded { self.f_'+effect.success+'(navigate) } else { self.f_'+effect.failure+'(navigate) }\n}\nreturn')
            elif isinstance(effect,CapturePhotoEffect):
                o=effect.options
                options='NativePhotoOptions(maxInputBytes: '+str(o.max_input_bytes)+', maxPixels: '+str(o.max_decoded_pixels)+', maxEdge: '+str(o.max_edge)+', qualityPercent: '+str(o.jpeg_quality)+', maxOutputBytes: '+str(o.max_output_bytes)+')'
                result.append('nativePhotoGeneration &+= 1;let generation=nativePhotoGeneration;nativeCancelAcquisition?();nativePhotoRequest=nil;nativePhotoTarget='+quoted(effect.target)+'\nlet camera=camera_'+effect.resource+';nativeCancelAcquisition={ [weak camera] in camera?.cancelCapture() }\ncamera.capture(options:'+options+') { [weak self] result in\nguard let self,generation==self.nativePhotoGeneration else { return }\nself.nativePhotoTarget=nil;self.nativeCancelAcquisition=nil\nswitch result {\ncase .selected(let media):self.m_'+effect.target+'=media;self.f_'+effect.success+'(navigate)\ncase .cancelled:self.f_'+effect.cancel+'(navigate)\ncase .failed:self.f_'+effect.failure+'(navigate)\n}\n}\nreturn')
            elif isinstance(effect,ClockEffect):
                result.append('guard let now = Int32(exactly: Date().timeIntervalSince1970.rounded(.down)), now >= 0 else { self.f_'+effect.failure+'(navigate); return }; self.s_'+effect.target+' = now')
            elif isinstance(effect,ReadCollectionEffect):
                collection=collections[effect.collection]
                lines=['guard let selected = self.c_'+effect.collection+'.first(where: { $0.f_'+collection.key+' == '+value(effect.key)+' }) else { self.f_'+effect.failure+'(navigate); return }']
                lines.extend('let selectedOutput'+str(i)+' = selected.f_'+output.path[0] for i,output in enumerate(effect.outputs))
                lines.extend('self.s_'+output.target+' = selectedOutput'+str(i) for i,output in enumerate(effect.outputs))
                lines.append('self.f_'+effect.success+'(navigate); return');result.append('\n'.join(lines))
            elif isinstance(effect,ClearCollectionEffect):result.append('self.c_'+effect.target+' = []')
            elif isinstance(effect,CancelEffect):result.append('requestGeneration &+= 1; requestTask?.cancel(); requestTask = nil'+('; nativeWorkerGeneration &+= 1; nativeWorkerTask?.cancel(); nativeWorkerTask = nil' if workers else '')+('; nativePhotoGeneration &+= 1; nativeCancelAcquisition?(); nativeCancelAcquisition=nil; nativePhotoRequest = nil; nativePhotoTarget = nil' if media else '')+('; nativeDeviceGeneration &+= 1; nativeDeviceTask?.cancel(); nativeLocationInstance?.cancel()' if needs_device else ''))
            elif isinstance(effect,InvokeEffect):result.append('self.f_'+effect.action+'(navigate); return')
            elif isinstance(effect,ClearMediaEffect):
                result.append('self.m_'+effect.target+' = nil; if nativePhotoTarget == '+quoted(effect.target)+' { nativePhotoGeneration &+= 1; nativeCancelAcquisition?(); nativeCancelAcquisition=nil; nativePhotoRequest = nil; nativePhotoTarget = nil }')
            elif isinstance(effect,PickPhotoEffect):
                o=effect.options
                options='NativePhotoOptions(maxInputBytes: '+str(o.max_input_bytes)+', maxPixels: '+str(o.max_decoded_pixels)+', maxEdge: '+str(o.max_edge)+', qualityPercent: '+str(o.jpeg_quality)+', maxOutputBytes: '+str(o.max_output_bytes)+')'
                result.append('nativePhotoGeneration &+= 1; nativeCancelAcquisition?(); nativeCancelAcquisition=nil; let generation = nativePhotoGeneration; nativePhotoTarget = '+quoted(effect.target)+'\n'+
                    'nativePhotoRequest = NativePhotoRequest(options: '+options+') { [weak self] result in\n'+
                    'guard let self, generation == self.nativePhotoGeneration else { return }\nself.nativePhotoRequest = nil; self.nativePhotoTarget = nil\nswitch result {\n'+
                    'case .selected(let media): self.m_'+effect.target+' = media; self.f_'+effect.success+'(navigate)\n'+
                    'case .cancelled: self.f_'+effect.cancel+'(navigate)\ncase .failed: self.f_'+effect.failure+'(navigate)\n}\n}\nreturn')
            elif isinstance(effect,SecureEffect):
                if effect.operation=='read':operation='self.s_'+effect.target+' = try NativeSecureStore.read('+quoted(effect.key)+')'
                elif effect.operation=='write':operation='try NativeSecureStore.write('+quoted(effect.key)+', value: self.s_'+effect.target+')'
                elif effect.operation=='delete':operation='try NativeSecureStore.delete('+quoted(effect.key)+')'
                else:raise ValueError('Unsupported secure operation')
                result.append('do { '+operation+' } catch { effectFailure = '+quoted('secure.'+effect.operation)+'; self.f_'+effect.failure+'(navigate); return }')
            elif isinstance(effect,RequestEffect):
                transport=getattr(app,'transport',None)
                if transport is None:raise ValueError('HTTP effects require shared transport')
                snapshots=[]
                if isinstance(effect.path,PathTemplate):
                    parts=[quoted(transport.base_url.rstrip('/'))]
                    for index,part in enumerate(effect.path.parts):
                        if isinstance(part,Reference):
                            local='requestPath'+str(index)
                            snapshots.append('let '+local+' = String('+value(part)+')')
                            parts.append('NativeURLComponent.encode('+local+')')
                        else:parts.append(quoted(part.value))
                    address=' + '.join(parts)
                else:address=quoted(transport.base_url.rstrip('/')+effect.path)
                raw_media=isinstance(effect.body,MediaBody)
                body='[:]' if raw_media else '['+', '.join(quoted(key)+': '+value(item) for key,item in effect.body)+']' if effect.body else '[:]'
                bearer=value(effect.bearer) if effect.bearer is not None else 'nil'
                status='self.s_'+effect.status_target+' = Int32(status); ' if effect.status_target else ''
                zero='self.s_'+effect.status_target+' = 0; ' if effect.status_target else ''
                if raw_media:snapshots.append('guard let requestMedia = self.m_'+effect.body.source.name+'?.data else { '+zero+'self.f_'+effect.failure+'(navigate); return }')
                validate=[];assign=[]
                for index,output in enumerate(effect.outputs):
                    if output.target in collections:
                        decoder='Collection_'+output.target+'.decode';prefix='c_'
                    else:
                        decoder='NativeJSONScalar.'+types[output.target].value;prefix='s_'
                    validate.append('let output'+str(index)+' = try '+decoder+'(json, path: ['+', '.join(quoted(p) for p in output.path)+'])')
                    if getattr(output,'mode','replace')=='append':
                        if output.target not in collections:raise ValueError('Append requires collection output')
                        validate.append('let merged'+str(index)+' = try Collection_'+output.target+'.appending(self.c_'+output.target+', output'+str(index)+')')
                        assign.append('self.c_'+output.target+' = merged'+str(index))
                    else:assign.append('self.'+prefix+output.target+' = output'+str(index))
                decode=('let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])\n'+'\n'.join(validate)+'\n'+'\n'.join(assign)) if effect.outputs else ''
                result.append('''requestGeneration &+= 1
requestTask?.cancel()
let generation=requestGeneration
let requestBody: [String:Any] = '''+body+'''
let requestBearer: String? = '''+bearer+'\n'+'\n'.join(snapshots)+'''
requestTask=Task { @MainActor [weak self] in
    guard let self,generation==self.requestGeneration,!Task.isCancelled else { return }
    do {
        guard let url=URL(string: '''+address+''') else { throw NativeEffectFailure.invalidAddress }
        let (data,status)=try await self.effectTransport.send(url:url,method: '''+quoted(effect.method)+''',body:requestBody,bearer:requestBearer'''+(',rawBody:requestMedia' if raw_media else '')+''')
        guard generation==self.requestGeneration,!Task.isCancelled else { return }
        guard (200..<300).contains(status) else { '''+status+'self.f_'+effect.failure+'''(navigate); return }
        '''+decode+'''
        '''+status+'self.f_'+effect.success+'''(navigate)
    } catch is CancellationError { }
      catch { guard generation==self.requestGeneration,!Task.isCancelled else { return }; '''+zero+'self.f_'+effect.failure+'''(navigate) }
}
return''')
            else:raise ValueError('Unsupported shared effect: '+type(effect).__name__)
        return '\n'.join(result)
    methods=[]
    for flow in flows:
        start='effectFailure = nil\n'
        if flow.function:
            signature=next(function for function in app.logic.functions if function.name==flow.function)
            arguments=[]
            range_failure=('self.f_'+flow.failure+'(navigate); return') if flow.failure else 'effectFailure = "policy.argumentRange"; return'
            for index,(argument,abi) in enumerate(zip(flow.arguments,signature.parameters)):
                raw=value(argument.value)+('.unicodeScalars.count' if argument.operation=='length' else '.utf8.count') if isinstance(argument,Projection) else ('0' if isinstance(argument,MediaProjection) else value(argument))
                if isinstance(argument,Projection) and argument.operation=="flag":raw="("+value(argument.value)+" ? Int32(1) : Int32(0))"
                if isinstance(argument,MediaProjection):
                    ref='self.m_'+argument.value.name
                    raw='('+ref+' != nil)' if argument.operation=='hasMedia' else '('+ref+'?.'+{'mediaBytes':'byteLength','mediaWidth':'width','mediaHeight':'height'}[argument.operation]+' ?? 0)'
                if abi in (ABIType.BOOL,ABIType.UTF8):arguments.append(raw)
                elif abi in (ABIType.INT32,ABIType.UINT32):
                    local='argument'+str(index);kind='Int32' if abi==ABIType.INT32 else 'UInt32'
                    start+='guard let '+local+' = '+kind+'(exactly: '+raw+') else { '+range_failure+' }\n';arguments.append(local)
                else:raise ValueError('Flow ABI requires int32/uint32/bool')
            callee='AppLogicUTF8.f_'+flow.function if ABIType.UTF8 in signature.parameters else c_alias(app,flow.function)
            call=('try ' if ABIType.UTF8 in signature.parameters else '')+callee+'('+', '.join(arguments)+')'
            code='('+call+' ? Int64(1) : Int64(0))' if signature.returns==ABIType.BOOL else 'Int64('+call+')'
            if signature.returns not in (ABIType.BOOL,ABIType.INT32,ABIType.UINT32):raise ValueError('Unsupported flow result ABI')
            if flow.failure and signature.returns==ABIType.UINT32:
                code='Int64(try AppLogicUTF8.signed('+call+'))'
            if flow.failure:
                start+='let policyCode: Int64\ndo { policyCode = '+code+' } catch { self.f_'+flow.failure+'(navigate); return }\n'
                code='policyCode'
            body=start+'switch '+code+' {\n'+'\n'.join('case '+str(case.code)+':\n'+(effects(case.effects) or 'break') for case in flow.cases)+'\ndefault: effectFailure = "policy.unhandled"\n}'
        else:
            if len(flow.cases)!=1 or flow.cases[0].code!=0:raise ValueError('Unconditional flow requires one zero case')
            body=start+effects(flow.cases[0].effects)
        methods.append('    @MainActor func f_'+flow.id+'(_ navigate: @escaping (String) -> Void) {\n'+body+'\n    }')
    path='ios/App/Generated/AppModel.swift';artifact=files[path]
    addition='''
    @Published private(set) var effectFailure: String?
    private var requestGeneration: UInt64 = 0
    private var requestTask: Task<Void,Never>?
    private let effectTransport = NativeHTTPTransport()
    deinit { requestTask?.cancel(); effectTransport.close() }
'''+ '\n'.join('@Published var c_'+c.name+': [Collection_'+c.name+'] = []' for c in collections.values())+'\n'+ '\n'.join(methods)+'\n'
    if media:
        addition+='\n@Published var nativePhotoRequest: NativePhotoRequest?\nprivate var nativePhotoGeneration: UInt64 = 0\nprivate var nativePhotoTarget: String?\nprivate var nativeCancelAcquisition: (() -> Void)?\n'+'\n'.join('@Published var m_'+m.name+': NativePreparedMedia?' for m in media)+'\n'
    if needs_device:
        addition+='\nprivate var nativeDeviceGeneration: UInt64=0\nprivate var nativeDeviceTask: Task<Void,Never>?\n@MainActor private var nativeLocationInstance: NativeLocation?\n@MainActor private var nativeLocation: NativeLocation { if let nativeLocationInstance { return nativeLocationInstance };let value=NativeLocation();nativeLocationInstance=value;return value }\n'+'\n'.join('let camera_'+c.id+' = NativeCamera()' for c in camera_resources)+'\n'
        addition=addition.replace('deinit { requestTask?.cancel();','deinit { nativeDeviceTask?.cancel(); requestTask?.cancel();')
        from .ios_device import emit as emit_device
        emit_device(files)
    if needs_media:
        from .ios_media import emit
        emit(files)
    timers=getattr(app,'timers',())
    if timers:
        addition+='\nprivate var nativeTimers: [Task<Void,Never>] = []\nprivate var nativeTimersStarted = false\n@MainActor func startSharedTimers() {\nguard !nativeTimersStarted else { return }; nativeTimersStarted = true\n'
        for timer in timers:
            addition+='nativeTimers.append(Task { @MainActor [weak self] in\nwhile !Task.isCancelled {\ndo { try await Task.sleep(nanoseconds: '+str(timer.interval_ms*1_000_000)+') } catch { return }\nguard !Task.isCancelled else { return }; self?.f_'+timer.action+'({ _ in assertionFailure("timer.navigation") })\n}\n})\n'
        addition+='}\n'
        addition=addition.replace('deinit { requestTask?.cancel(); effectTransport.close() }','deinit { requestTask?.cancel(); effectTransport.close(); nativeTimers.forEach { $0.cancel() } }')
    if workers:
        addition+='\nprivate var nativeWorkerGeneration: UInt64 = 0\nprivate var nativeWorkerTask: Task<Void,Never>?\n'
        addition=addition.replace('deinit {', 'deinit { nativeWorkerTask?.cancel();')
    if getattr(app,'initial_action',None):
        addition+='    private var initialFlowStarted = false\n    @MainActor func startInitialFlow(_ navigate: @escaping (String) -> Void) { guard !initialFlowStarted else { return }; initialFlowStarted = true; f_'+app.initial_action+'(navigate) }\n'
    content=artifact.content.replace('import Combine','import Combine\nimport Foundation').rstrip();assert content.endswith('}')
    files[path]=Artifact(content[:-1]+addition+'}\n',artifact.ownership)
    namespace=getattr(app,'transport',None)
    configuration='enum NativeEffectConfiguration { static let secureNamespace = '+quoted(namespace.base_url.rstrip('/') if namespace else '')+' }\n'
    files['ios/App/Generated/NativeEffects.swift']=Artifact(HEADER+configuration+HELPERS+collection_source(collections.values()))
    transport=getattr(app,'transport',None)
    if transport or needs_device:
        info={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':app.name,'CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0','CFBundleVersion':'1','LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False}}
        for capability,purpose in getattr(app,'permission_descriptions',()):info[{'camera':'NSCameraUsageDescription','location':'NSLocationWhenInUseUsageDescription'}[capability]]=purpose
        if transport and transport.development:info['NSAppTransportSecurity']={'NSAllowsLocalNetworking':True}
        files['ios/Native/TransportInfo.plist']=Artifact(plistlib.dumps(info).decode())
        project='ios/App.xcodeproj/project.pbxproj';source=files[project]
        files[project]=Artifact(source.content.replace('GENERATE_INFOPLIST_FILE = YES;','GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Native/TransportInfo.plist;'),source.ownership)


def collection_source(collections):
    records=[]
    native={'string':'String','int':'Int32','bool':'Bool'}
    for collection in collections:
        fields=[];decode=[]
        for field in collection.fields:
            fields.append('    let f_'+field.name+': '+native[field.type.value])
            read='try NativeJSONScalar.'+field.type.value+'(object, path: ['+quoted(field.name)+'])'
            if field.default is not None:
                read='(object['+quoted(field.name)+'] == nil || object['+quoted(field.name)+'] is NSNull) ? '+value(field.default)+' : '+read
            decode.append('            let f_'+field.name+' = '+read)
        key=next(f for f in collection.fields if f.name==collection.key)
        records.append('struct Collection_'+collection.name+': Equatable {\n'+'\n'.join(fields)+'\n'+
            '    static func appending(_ previous: [Self], _ incoming: [Self]) throws -> [Self] {\n        var keys = Set(previous.map { $0.f_'+collection.key+' })\n        for row in incoming { guard keys.insert(row.f_'+collection.key+').inserted else { throw NativeEffectFailure.invalidResponse } }\n        return previous + incoming\n    }\n'+
            '    static func decode(_ root: Any, path: [String]) throws -> [Self] {\n'+
            '        guard let rows = try NativeJSONScalar.field(root,path:path) as? [Any] else { throw NativeEffectFailure.invalidResponse }\n'+
            '        var keys = Set<'+native[key.type.value]+'>(); var result: [Self] = []\n'+
            '        for row in rows {\n            guard let object = row as? [String:Any] else { throw NativeEffectFailure.invalidResponse }\n'+'\n'.join(decode)+'\n'+
            '            guard keys.insert(f_'+collection.key+').inserted else { throw NativeEffectFailure.invalidResponse }\n'+
            '            result.append(Self('+', '.join('f_'+f.name+': f_'+f.name for f in collection.fields)+'))\n        }\n        return result\n    }\n}\n')
    return '\n'.join(records)
