"""AOT application logic packaging. All compiler work finishes before native builds."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from .backends import Artifact, HEADER
from .dcdart import compile_logic
from .ir import ABIType
from .validate import Diagnostic

C_TYPES = {ABIType.INT32: 'int32_t', ABIType.UINT32: 'uint32_t', ABIType.UINT64: 'uint64_t', ABIType.BOOL: 'bool'}
UTF8_MAX_BYTES = 1048576
UTF8_TOTAL_BYTES = 4194304


def has_utf8(function):
    return function.returns == ABIType.UTF8 or any(t.value == 'utf8' for t in function.parameters)


def abi_parameters(function):
    """Expand logical borrowed strings without exposing addresses to app input."""
    return tuple(native for typ in function.parameters for native in
                 (('uint64_t', 'uint32_t') if typ.value == 'utf8' else (C_TYPES[typ],))) + (('uint64_t', 'uint32_t') if function.returns == ABIType.UTF8 else ())


def abi_declaration(function):
    if function.returns == ABIType.UTF8:
        check_output_capacity(function)
    params = ', '.join(t + ' a' + str(i) for i, t in enumerate(abi_parameters(function))) or 'void'
    return physical_result(function) + ' ' + function.name + '(' + params + ');'


def swift_utf8_wrapper(function, alias):
    if function.returns == ABIType.UTF8:
        return swift_utf8_result_wrapper(function, alias)
    swift = {ABIType.INT32:'Int32', ABIType.UINT32:'UInt32', ABIType.UINT64:'UInt64', ABIType.BOOL:'Bool'}
    args = ', '.join('_ a'+str(i)+': '+('String' if t.value=='utf8' else swift[t]) for i,t in enumerate(function.parameters))
    lines = ['static func f_'+function.name+'('+args+') throws -> '+swift[function.returns]+' {', 'var total = 0']
    strings = [i for i,t in enumerate(function.parameters) if t.value=='utf8']
    for i in strings:
        lines += ['let n'+str(i)+' = a'+str(i)+'.utf8.prefix('+str(UTF8_MAX_BYTES+1)+').count',
                  'guard n'+str(i)+' <= '+str(UTF8_MAX_BYTES)+' else { throw AppLogicInputFailure.invalidInput }',
                  'total += n'+str(i),
                  'guard total <= '+str(UTF8_TOTAL_BYTES)+' else { throw AppLogicInputFailure.invalidInput }']
    for i in strings:lines += ['let b'+str(i)+' = Array(a'+str(i)+'.utf8)']
    for i in strings:
        lines += ['return b'+str(i)+'.withUnsafeBufferPointer { p'+str(i)+' in']
    native=[]
    for i,t in enumerate(function.parameters):
        if t.value=='utf8': native += ['p'+str(i)+'.isEmpty ? UInt64(0) : UInt64(UInt(bitPattern: p'+str(i)+'.baseAddress!))', 'UInt32(p'+str(i)+'.count)']
        else:native.append('a'+str(i))
    lines += ['return '+alias+'('+', '.join(native)+')'] + ['}']*len(strings) + ['}']
    return '\n'.join(lines)


SWIFT_UTF8_HELPERS = """    static func unsigned(_ value: Int32) throws -> UInt32 {
        guard value >= 0 else { throw AppLogicInputFailure.invalidInput }
        return UInt32(value)
    }
    static func signed(_ value: UInt32) throws -> Int32 {
        guard value <= UInt32(Int32.max) else { throw AppLogicInputFailure.invalidInput }
        return Int32(value)
    }
"""


JAVA_UTF8_HELPERS = '''
    public static final class InputFailure extends IllegalArgumentException {
        public InputFailure(String message) { super(message); }
    }
    private static int utf8Length(String value) {
        if (value == null) throw new InputFailure("UTF8 input is null");
        if (value.length() > 1048576) throw new InputFailure("UTF8 input exceeds limit");
        int length = 0;
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            if (c < 0x80) length++;
            else if (c < 0x800) length += 2;
            else if (Character.isHighSurrogate(c)) {
                if (++i >= value.length() || !Character.isLowSurrogate(value.charAt(i)))
                    throw new InputFailure("Malformed UTF16 input");
                length += 4;
            } else if (Character.isLowSurrogate(c)) throw new InputFailure("Malformed UTF16 input");
            else length += 3;
            if (length > 1048576) throw new InputFailure("UTF8 input exceeds limit");
        }
        return length;
    }
'''


def android_utf8_wrapper(function, app_id):
    java = {ABIType.UTF8:'String', ABIType.BOOL:'boolean', ABIType.UINT64:'long', ABIType.INT32:'int', ABIType.UINT32:'int'}
    jni = {ABIType.UTF8:'jbyteArray', ABIType.BOOL:'jboolean', ABIType.UINT64:'jlong', ABIType.INT32:'jint', ABIType.UINT32:'jint'}
    result_java, result_jni = java[function.returns], jni[function.returns]
    output_string = function.returns == ABIType.UTF8
    capacity = check_output_capacity(function) if output_string else None
    strings = [i for i,t in enumerate(function.parameters) if t.value=='utf8']
    args = ', '.join(('String' if t.value=='utf8' else java[t])+' a'+str(i) for i,t in enumerate(function.parameters))
    native_args = ', '.join(('byte[]' if t.value=='utf8' else java[t])+' a'+str(i) for i,t in enumerate(function.parameters))
    lines = ['public static '+result_java+' f_'+function.name+'('+args+') {', 'long total = 0;']
    for i in strings:lines += ['total += utf8Length(a'+str(i)+');', 'if (total > '+str(UTF8_TOTAL_BYTES)+'L) throw new InputFailure("UTF8 inputs exceed aggregate limit");']
    for i in strings:lines += ['byte[] b'+str(i)+' = null;']
    if output_string: lines += ['byte[] resultBytes = null;']
    lines += ['try {']
    for i in strings:lines += ['b'+str(i)+' = a'+str(i)+'.getBytes(java.nio.charset.StandardCharsets.UTF_8);']
    native_call = 'n_'+function.name+'('+', '.join(('b' if t.value=='utf8' else 'a')+str(i) for i,t in enumerate(function.parameters))+')'
    if output_string:
        lines += ['resultBytes = '+native_call+';', 'return new String(resultBytes, java.nio.charset.StandardCharsets.UTF_8);']
    else: lines += ['return '+native_call+';']
    lines += ['} finally {']
    if output_string: lines += ['if (resultBytes != null) java.util.Arrays.fill(resultBytes, (byte)0);']
    for i in strings:lines += ['if (b'+str(i)+' != null) java.util.Arrays.fill(b'+str(i)+', (byte)0);']
    lines += ['}', '}', 'private static native '+('byte[]' if output_string else result_java)+' n_'+function.name+'('+native_args+');']
    cargs = ', '.join(('jbyteArray' if t.value=='utf8' else jni[t])+' a'+str(i) for i,t in enumerate(function.parameters))
    body=['(void)cls;',result_jni+' output = 0;', 'uint64_t total = 0;']
    if output_string: body += ['uint8_t *result_bytes = NULL;']
    for i in strings:body += ['jbyte *b'+str(i)+' = NULL; jboolean copy'+str(i)+' = JNI_FALSE; jsize n'+str(i)+' = 0;']
    for i in strings:
        body += ['if (!a'+str(i)+') { input_fail(env, "UTF8 input is null"); goto cleanup; }',
                 'n'+str(i)+' = (*env)->GetArrayLength(env, a'+str(i)+');',
                 'if (n'+str(i)+' < 0 || n'+str(i)+' > '+str(UTF8_MAX_BYTES)+') { input_fail(env, "UTF8 input exceeds limit"); goto cleanup; }',
                 'total += (uint32_t)n'+str(i)+';']
    body += ['if (total > '+str(UTF8_TOTAL_BYTES)+') { input_fail(env, "UTF8 inputs exceed aggregate limit"); goto cleanup; }']
    for i,t in enumerate(function.parameters):
        if t==ABIType.UINT32:body += ['if (a'+str(i)+' < 0) { input_fail(env, "Unsigned logic argument must be nonnegative"); goto cleanup; }']
    for i in strings:
        body += ['if (n'+str(i)+') { b'+str(i)+' = (*env)->GetByteArrayElements(env, a'+str(i)+', &copy'+str(i)+'); if (!b'+str(i)+') goto cleanup; }',
                 'if (!valid_utf8((const uint8_t*)b'+str(i)+', (uint32_t)n'+str(i)+')) { input_fail(env, "Malformed UTF8 input"); goto cleanup; }']
    native=[]
    for i,t in enumerate(function.parameters):
        if t.value=='utf8':native += ['(uint64_t)(uintptr_t)b'+str(i),'(uint32_t)n'+str(i)]
        else:native += ['('+C_TYPES[t]+')a'+str(i)]
    if output_string:
        body += ['result_bytes = (uint8_t*)calloc('+str(capacity)+', 1);',
                 'if (!result_bytes) { jclass oom = (*env)->FindClass(env, "java/lang/OutOfMemoryError"); if (oom) (*env)->ThrowNew(env, oom, "UTF8 output allocation failed"); goto cleanup; }']
        native += ['(uint64_t)(uintptr_t)result_bytes',str(capacity)]
    body += [physical_result(function)+' result = '+function.name+'('+', '.join(native)+');']
    if output_string:
        body += ['if (result > '+str(capacity)+') { input_fail(env, "UTF8 result failed or exceeds capacity"); goto cleanup; }',
                 'if (!valid_utf8(result_bytes, result)) { input_fail(env, "Malformed UTF8 result"); goto cleanup; }',
                 'output = (*env)->NewByteArray(env, (jsize)result);',
                 'if (!output) goto cleanup;',
                 'if (result) (*env)->SetByteArrayRegion(env, output, 0, (jsize)result, (const jbyte*)result_bytes);']
    if function.returns==ABIType.UINT32:body += ['if (result > INT32_MAX) { input_fail(env, "Logic result exceeds portable Int32 state"); goto cleanup; }']
    if function.returns==ABIType.UINT64:body += ['_Static_assert(sizeof(output)==sizeof(result), "64-bit JNI ABI required"); __builtin_memcpy(&output, &result, sizeof(output));']
    elif not output_string:body += ['output = ('+result_jni+')result;']
    body += ['cleanup:']
    if output_string: body += ['if (result_bytes) { volatile uint8_t *p=result_bytes; for (uint32_t j=0;j<'+str(capacity)+';j++) p[j]=0; free(result_bytes); }']
    for i in reversed(strings):body += ['if (b'+str(i)+') { if (copy'+str(i)+') { volatile uint8_t *p=(volatile uint8_t*)b'+str(i)+'; for (jsize j=0;j<n'+str(i)+';j++) p[j]=0; } (*env)->ReleaseByteArrayElements(env, a'+str(i)+', b'+str(i)+', JNI_ABORT); }']
    body += ['return output;']
    wrapper='JNIEXPORT '+result_jni+' JNICALL Java_'+_jni_name(app_id)+'_SharedLogic_n_1'+_jni_name(function.name)+'(JNIEnv *env, jclass cls'+(', '+cargs if cargs else '')+') {\n'+'\n'.join(body)+'\n}'
    return '\n'.join(lines), wrapper


def jni_utf8_helpers(app_id):
    return '''
_Static_assert(sizeof(void*) == 8, "64-bit borrowed UTF8 ABI required");
static void input_fail(JNIEnv *env, const char *message) {
    jclass type = (*env)->FindClass(env, "'''+app_id.replace('.', '/')+'''/SharedLogic$InputFailure");
    if (type) (*env)->ThrowNew(env, type, message);
}
static bool valid_utf8(const uint8_t *p, uint32_t length) {
    for (uint32_t i=0;i<length;) {
        uint32_t c=p[i++], remaining=0, minimum=0;
        if(c<0x80)continue;
        if(c>=0xc2&&c<=0xdf){c&=31;remaining=1;minimum=0x80;}
        else if(c>=0xe0&&c<=0xef){c&=15;remaining=2;minimum=0x800;}
        else if(c>=0xf0&&c<=0xf4){c&=7;remaining=3;minimum=0x10000;}
        else return false;
        if(remaining>length-i)return false;
        while(remaining--){uint32_t next=p[i++];if((next&0xc0)!=0x80)return false;c=(c<<6)|(next&63);}
        if(c<minimum||c>0x10ffff||(c>=0xd800&&c<=0xdfff))return false;
    }
    return true;
}
'''


def run(args):
    process = subprocess.run([str(a) for a in args], text=True, capture_output=True)
    if process.returncode:
        raise Diagnostic('Native logic tool failed: ' + (process.stderr or process.stdout))
    return process.stdout


def _jni_name(value):
    return value.replace('_', '_1').replace('.', '_')


def c_alias(app, name):
    alias = 'applogic_' + hashlib.sha256(name.encode()).hexdigest()
    names = {function.name for function in app.logic.functions}
    while alias in names:
        alias += '_'
    return alias


def call_expression(app, action, platform, expression):
    signature = next(f for f in app.logic.functions if f.name == action.function)
    values = []
    for argument, abi in zip(action.arguments, signature.parameters):
        value = expression(argument, platform).replace('model.s_', 'self.s_' if platform == 'ios' else 'this.s_')
        if platform == 'ios' and abi == ABIType.UINT32:
            value = ('try AppLogicUTF8.unsigned(' if has_utf8(signature) else 'AppLogicConversions.unsigned(') + value + ')'
        values.append(value)
    callee = 'SharedLogic.f_' + signature.name if platform == 'android' else ('try AppLogicUTF8.f_'+signature.name if has_utf8(signature) else c_alias(app, signature.name))
    call = callee + '(' + ', '.join(values) + ')'
    if platform == 'ios' and signature.returns == ABIType.UINT32:
        call = ('try AppLogicUTF8.signed(' if has_utf8(signature) else 'AppLogicConversions.signed(') + call + ')'
    return call


def rewrite_imports(text, source, prelude):
    """Rewrite literal directive URIs; never touch strings or nested comments."""
    result = []
    i = 0
    def string_end(start):
        quote = text[start]
        delimiter = quote * 3 if text.startswith(quote * 3, start) else quote
        cursor = start + len(delimiter)
        while cursor < len(text):
            if text[cursor] == "\\":
                cursor += 2
            elif text.startswith(delimiter, cursor):
                return cursor + len(delimiter)
            else:
                cursor += 1
        raise Diagnostic('Unterminated DC Dart string')
    while i < len(text):
        start = i
        if text.startswith('//', i):
            end = text.find('\n', i)
            i = len(text) if end < 0 else end
        elif text.startswith('/*', i):
            depth = 1
            i += 2
            while i < len(text) and depth:
                if text.startswith('/*', i): depth += 1; i += 2
                elif text.startswith('*/', i): depth -= 1; i += 2
                else: i += 1
            if depth: raise Diagnostic('Unterminated DC Dart comment')
        elif text[i] in ('"', "'"):
            i = string_end(i)
        elif text[i].isalpha() or text[i] == '_':
            i += 1
            while i < len(text) and (text[i].isalnum() or text[i] == '_'): i += 1
            keyword = text[start:i]
            if keyword in ('import', 'export', 'part'):
                cursor = i
                while cursor < len(text) and text[cursor].isspace(): cursor += 1
                if cursor < len(text) and text[cursor] in ('"', "'"):
                    end = string_end(cursor)
                    uri = text[cursor + 1:end - 1]
                    if any(c in uri for c in ('$', "\\", '"', "'")):
                        raise Diagnostic('DC Dart import URI must be a simple literal path')
                    if uri in ('prelude.dart', 'dc:core.bare'): uri = prelude.as_uri()
                    elif ':' not in uri: uri = (source.parent / uri).resolve().as_uri()
                    result.append(text[start:cursor] + "'" + uri + "'")
                    i = end
                    continue
        else:
            i += 1
        result.append(text[start:i])
    return ''.join(result)


def generate_logic(app, source_path, targets):
    """Return immutable native binaries plus ordinary application ABI glue."""
    if app.logic is None:
        return {}
    base = Path(source_path).resolve().parent
    source = (base / app.logic.source).resolve()
    prelude = (base / app.logic.prelude).absolute()
    if not source.is_file() or not prelude.is_file():
        raise Diagnostic('logic.source and logic.prelude must identify existing files relative to the app manifest')
    dcc = os.environ.get('DCFLIGHT_DCC', 'dcc')
    nm = os.environ.get('DCFLIGHT_NM', shutil.which('llvm-nm') or '/opt/homebrew/opt/llvm/bin/llvm-nm')
    artifacts = {}
    reports = []
    libraries = {}
    with tempfile.TemporaryDirectory(prefix='app-logic-') as temporary:
        root = Path(temporary)
        # DCC's current bootstrap resolves its prelude by exact URI identity.
        # Adapt import locations at development time, preserving other source imports.
        staged = root / 'logic.dart'
        staged.write_text(rewrite_imports(source.read_text(), source, prelude))
        compiled = {}
        native_targets = []
        if 'ios' in targets:
            native_targets += ['ios-arm64', 'ios-simulator-arm64']
        if 'android' in targets:
            native_targets += ['android-arm64']
        for target in native_targets:
            artifact = compile_logic(staged, root / target, target, prelude=prelude, dcc=dcc, nm=nm)
            header = artifact.header.read_text().replace(str(staged), 'application logic')
            artifact.header.write_text(header)
            for function in app.logic.functions:
                declaration = abi_declaration(function)
                if declaration not in header:
                    raise Diagnostic('Declared logic ABI differs from DCC generated header: ' + declaration)
            compiled[target] = artifact
            report = json.loads(artifact.provenance.read_text())
            report['source'] = str(source)
            report['headerSha256'] = hashlib.sha256(header.encode()).hexdigest()
            report['authorSourceSha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
            # Staging path is ephemeral; never persist it as reproducible source identity.
            reports.append(report)
        if 'ios' in targets:
            artifacts['ios/Native/logic-device.o'] = Artifact(compiled['ios-arm64'].object.read_bytes())
            artifacts['ios/Native/logic-simulator.o'] = Artifact(compiled['ios-simulator-arm64'].object.read_bytes())
            header = compiled['ios-arm64'].header.read_text()
            for function in app.logic.functions:
                params = ', '.join(t + ' a' + str(i) for i, t in enumerate(abi_parameters(function))) or 'void'
                values = ', '.join('a' + str(i) for i in range(len(abi_parameters(function))))
                header += 'static inline ' + physical_result(function) + ' ' + c_alias(app, function.name) + '(' + params + ') { return ' + function.name + '(' + values + '); }\n'
            artifacts['ios/Native/logic.h'] = Artifact(header)
            if any(has_utf8(f) for f in app.logic.functions):
                artifacts['ios/App/Generated/AppLogicUTF8.swift'] = Artifact(HEADER+'import Foundation\nenum AppLogicInputFailure: Error { case invalidInput }\nenum AppLogicUTF8 {\n'+SWIFT_UTF8_HELPERS+'\n'.join(swift_utf8_wrapper(f,c_alias(app,f.name)) for f in app.logic.functions if has_utf8(f))+'\n}\n')
            artifacts['ios/Native/Logic.xcconfig'] = Artifact('''SWIFT_OBJC_BRIDGING_HEADER = $(SRCROOT)/Native/logic.h
ARCHS = arm64
OTHER_LDFLAGS[sdk=iphoneos*] = $(inherited) "$(SRCROOT)/Native/logic-device.o"
OTHER_LDFLAGS[sdk=iphonesimulator*] = $(inherited) "$(SRCROOT)/Native/logic-simulator.o"
''')
            artifacts['ios/App/Generated/AppLogicConversions.swift'] = Artifact(HEADER + '''enum AppLogicConversions {
    static func unsigned(_ value: Int32) -> UInt32 {
        precondition(value >= 0, "Unsigned logic argument must be nonnegative")
        return UInt32(value)
    }
    static func signed(_ value: UInt32) -> Int32 {
        precondition(value <= UInt32(Int32.max), "Logic result exceeds portable Int32 state")
        return Int32(value)
    }
}
''')
        if 'android' in targets:
            clang = os.environ.get('DCFLIGHT_ANDROID_CLANG')
            if not clang or not Path(clang).is_file():
                raise Diagnostic('Set DCFLIGHT_ANDROID_CLANG to the Android NDK aarch64-linux-android26-clang executable')
            folder = root / 'android-arm64'
            methods, wrappers = [], []
            for function in app.logic.functions:
                if has_utf8(function):
                    method, wrapper = android_utf8_wrapper(function, app.id)
                    methods.append(method);wrappers.append(wrapper)
                    continue
                result_java = 'boolean' if function.returns == ABIType.BOOL else ('long' if function.returns == ABIType.UINT64 else 'int')
                result_jni = 'jboolean' if function.returns == ABIType.BOOL else ('jlong' if function.returns == ABIType.UINT64 else 'jint')
                java_args = ', '.join(('boolean' if t == ABIType.BOOL else ('long' if t == ABIType.UINT64 else 'int')) + ' a' + str(i) for i, t in enumerate(function.parameters))
                methods.append('    public static native ' + result_java + ' f_' + function.name + '(' + java_args + ');')
                c_args = ', '.join(('jboolean' if t == ABIType.BOOL else ('jlong' if t == ABIType.UINT64 else 'jint')) + ' a' + str(i) for i, t in enumerate(function.parameters))
                body = []
                for i, abi in enumerate(function.parameters):
                    if abi == ABIType.UINT32:
                        body.append('if (a' + str(i) + ' < 0) { fail(env, "Unsigned logic argument must be nonnegative"); return 0; }')
                args = ', '.join('(' + C_TYPES[t] + ')a' + str(i) for i, t in enumerate(function.parameters))
                body.append(C_TYPES[function.returns] + ' result = ' + function.name + '(' + args + ');')
                if function.returns == ABIType.UINT32:
                    body.append('if (result > INT32_MAX) { fail(env, "Logic result exceeds portable Int32 state"); return 0; }')
                if function.returns == ABIType.UINT64:
                    body.append('jlong bits; _Static_assert(sizeof(bits) == sizeof(result), "64-bit JNI ABI required"); __builtin_memcpy(&bits, &result, sizeof(bits)); return bits;')
                else:
                    body.append('return (' + result_jni + ')result;')
                wrappers.append('JNIEXPORT ' + result_jni + ' JNICALL Java_' + _jni_name(app.id) + '_SharedLogic_f_1' + _jni_name(function.name) + '(JNIEnv *env, jclass cls' + (', ' + c_args if c_args else '') + ') { (void)cls; ' + ' '.join(body) + ' }')
            utf8 = any(has_utf8(f) for f in app.logic.functions)
            glue = HEADER + '#include <jni.h>\n#include <stdlib.h>\n#include "logic.h"\nstatic void fail(JNIEnv *env, const char *message) { jclass type = (*env)->FindClass(env, "java/lang/IllegalArgumentException"); if (type) (*env)->ThrowNew(env, type, message); }\n' + (jni_utf8_helpers(app.id) if utf8 else '') + '\n'.join(wrappers) + '\n'
            c = folder / 'logic-jni.c'
            c.write_text(glue)
            library = folder / 'libapplogic.so'
            run([clang, '-shared', '-fPIC', '-Wl,--no-undefined', '-Wl,-soname,libapplogic.so', c, compiled['android-arm64'].object, '-o', library])
            readelf = os.environ.get('DCFLIGHT_READELF', shutil.which('llvm-readelf') or '/opt/homebrew/opt/llvm/bin/llvm-readelf')
            dynamic = run([readelf, '--dynamic', library])
            needed = re.findall(r'\(NEEDED\).*?\[(.*?)\]', dynamic)
            if set(needed) - {'libc.so', 'libdl.so', 'libm.so'}:
                raise Diagnostic('Unexpected native logic dependency: ' + str(needed))
            relative = 'android/app/src/main/jniLibs/arm64-v8a/libapplogic.so'
            data = library.read_bytes()
            artifacts[relative] = Artifact(data)
            libraries[relative] = {'sha256': hashlib.sha256(data).hexdigest(), 'needed': needed}
            artifacts['android/app/src/main/java/' + app.id.replace('.', '/') + '/SharedLogic.java'] = Artifact(HEADER + 'package ' + app.id + ';\npublic final class SharedLogic {\n    static { System.loadLibrary("applogic"); }\n    private SharedLogic() {}\n' + (JAVA_UTF8_HELPERS if utf8 else '') + '\n'.join(methods) + '\n}\n')
            artifacts['android/native-source/logic-jni.c'] = Artifact(glue)
            artifacts['android/native-source/logic.h'] = Artifact(compiled['android-arm64'].header.read_text())
    reports.sort(key=lambda build: build['target'])
    artifacts['.dcflight/logic.json'] = Artifact(json.dumps({'builds': reports, 'libraries': libraries}, indent=2) + '\n')
    return artifacts


def check_output_capacity(function):
    capacity = getattr(function, 'max_output_bytes', None)
    if type(capacity) is not int or not 1 <= capacity <= UTF8_MAX_BYTES:
        raise Diagnostic('UTF8 results require maxOutputBytes in 1..1048576')
    return capacity


def physical_result(function):
    return 'uint32_t' if function.returns == ABIType.UTF8 else C_TYPES[function.returns]


def swift_utf8_result_wrapper(function, alias):
    capacity = check_output_capacity(function)
    swift = {ABIType.INT32:'Int32',ABIType.UINT32:'UInt32',ABIType.UINT64:'UInt64',ABIType.BOOL:'Bool',ABIType.UTF8:'String'}
    args = ', '.join('_ a'+str(i)+': '+swift[t] for i,t in enumerate(function.parameters))
    strings = [i for i,t in enumerate(function.parameters) if t==ABIType.UTF8]
    lines = ['static func f_'+function.name+'('+args+') throws -> String {', 'var total = 0']
    for i in strings:
        lines += ['let n'+str(i)+' = a'+str(i)+'.utf8.prefix('+str(UTF8_MAX_BYTES+1)+').count',
                  'guard n'+str(i)+' <= '+str(UTF8_MAX_BYTES)+' else { throw AppLogicInputFailure.invalidInput }',
                  'total += n'+str(i), 'guard total <= '+str(UTF8_TOTAL_BYTES)+' else { throw AppLogicInputFailure.invalidInput }']
    for i in strings: lines += ['let b'+str(i)+' = Array(a'+str(i)+'.utf8)']
    lines += ['var output = [UInt8](repeating: 0, count: '+str(capacity)+')',
              'return try output.withUnsafeMutableBufferPointer { destination in',
              'defer { destination.initialize(repeating: 0) }']
    for i in strings: lines += ['return try b'+str(i)+'.withUnsafeBufferPointer { p'+str(i)+' in']
    native=[]
    for i,t in enumerate(function.parameters):
        if t==ABIType.UTF8: native += ['p'+str(i)+'.isEmpty ? UInt64(0) : UInt64(UInt(bitPattern: p'+str(i)+'.baseAddress!))','UInt32(p'+str(i)+'.count)']
        else:native += ['a'+str(i)]
    native += ['UInt64(UInt(bitPattern: destination.baseAddress!))','UInt32(destination.count)']
    lines += ['let written = '+alias+'('+', '.join(native)+')',
              'guard written <= UInt32(destination.count) else { throw AppLogicInputFailure.invalidInput }',
              'guard let value = String(bytes: destination.prefix(Int(written)), encoding: .utf8) else { throw AppLogicInputFailure.invalidInput }',
              'return value']
    lines += ['}']*(len(strings)+2)
    return '\n'.join(lines)
