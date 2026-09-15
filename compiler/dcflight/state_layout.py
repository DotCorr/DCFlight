"""Canonical caller-owned state records, lowered to plain native data declarations."""
from dataclasses import dataclass
from enum import Enum
import re


RESERVED = set('class struct union enum typedef const static void bool true false null return switch case default if else while for do break continue int long short char float double public private protected import export extends implements new this super get set final var external sizeof'.split())


class FieldType(str, Enum):
    UINT32='uint32'
    UINT64='uint64'
    BOOL='bool'
    UTF8='utf8'


@dataclass(frozen=True)
class Field:
    name: str
    type: FieldType
    capacity: int = 0
    ownership: str = 'caller'

    def __post_init__(self):
        if not isinstance(self.name,str) or not re.fullmatch(r'[a-z][A-Za-z0-9]*',self.name) or self.name in RESERVED:raise ValueError('Field requires a simple lowerCamelCase name')
        if not isinstance(self.type,FieldType):raise ValueError('Unknown canonical field type')
        if self.ownership!='caller':raise ValueError('Only caller-owned storage is supported')
        if self.type==FieldType.UTF8:
            if type(self.capacity) is not int or not 1<=self.capacity<=1048576:raise ValueError('UTF8 capacity must be1..1048576 bytes')
        elif type(self.capacity) is not int or self.capacity!=0:raise ValueError('Only UTF8 fields have capacity')


@dataclass(frozen=True)
class RecordLayout:
    name: str
    fields: tuple[Field,...]

    def __post_init__(self):
        if not isinstance(self.name,str) or not re.fullmatch(r'[A-Z][A-Za-z0-9]*',self.name):raise ValueError('Record requires a simple UpperCamelCase name')
        if not isinstance(self.fields,tuple) or not self.fields or any(not isinstance(f,Field) for f in self.fields):raise ValueError('Record fields must be a nonempty immutable tuple')
        names=[name for name,_,_ in self.storage_fields()]
        if len(names)!=len(set(names)):raise ValueError('Field names collide after native lowering')
        if self.size>1048576 or sum(f.capacity for f in self.fields)>4*1048576:raise ValueError('Record exceeds storage limits')

    def storage_fields(self):
        fields=[]
        for field in self.fields:
            if field.type==FieldType.UTF8:
                fields.extend([(field.name+'Address','u64',8),(field.name+'Length','u32',4),(field.name+'Capacity','u32',4)])
            else:fields.append((field.name+'Flag' if field.type==FieldType.BOOL else field.name,{FieldType.UINT32:'u32',FieldType.UINT64:'u64',FieldType.BOOL:'u8'}[field.type],{FieldType.UINT32:4,FieldType.UINT64:8,FieldType.BOOL:1}[field.type]))
        return tuple(fields)

    @property
    def size(self):return sum(width for _,_,width in self.storage_fields())

    def dart(self):
        lines=['@packed',f'class {self.name} extends Struct {{',f'  const {self.name}.fromAddress(u64 address) : super.fromAddress(address);']
        for name,typ,_ in self.storage_fields():
            lines.extend([f"  {typ} get {name} => throw UnimplementedError('native record field');",f"  set {name}({typ} value) => throw UnimplementedError('native record field');"])
        lines.append('}')
        return '\n'.join(lines)+'\n'

    def c_header(self):
        n=self.name;types={'u8':'uint8_t','u32':'uint32_t','u64':'uint64_t'}
        lines=['_Static_assert(sizeof(void*) == 8, "64-bit native target required");','#pragma once','#include <stdint.h>','#include <stddef.h>','#include <string.h>','#include <stdbool.h>',f'typedef struct __attribute__((packed)) {n} {{']
        for name,typ,_ in self.storage_fields():lines.append(f'  {types[typ]} {name};')
        lines.append(f'}} {n};');offset=0
        lines.append(f'_Static_assert(sizeof({n}) == {self.size}, "record size drift");')
        for name,_,width in self.storage_fields():
            lines.append(f'_Static_assert(offsetof({n}, {name}) == {offset}, "record offset drift");');offset+=width
        lines.extend([f'typedef struct {{ {n} state;'])
        for f in self.fields:
            if f.type==FieldType.UTF8:lines.append(f'  uint8_t {f.name}Bytes[{f.capacity}];')
        lines.extend([f'}} {n}Owner;',f'static inline void {n}_wipe({n}Owner *owner) {{ volatile uint8_t *p=(volatile uint8_t*)owner; for(size_t i=0;i<sizeof(*owner);i++)p[i]=0; }}',f'static inline void {n}_init({n}Owner *owner) {{ {n}_wipe(owner);'])
        for f in self.fields:
            if f.type==FieldType.UTF8:lines.append(f'  owner->state.{f.name}Address=(uint64_t)(uintptr_t)owner->{f.name}Bytes; owner->state.{f.name}Capacity={f.capacity};')
        lines.append('}')
        lines.append(f'''static inline bool {n}_validUtf8(const uint8_t *p,size_t length) {{
  if(!p && length)return false;
  for(size_t i=0;i<length;) {{
    uint32_t c=p[i++], remaining=0,minimum=0;
    if(c<0x80)continue;
    if(c>=0xc2 && c<=0xdf){{c&=31;remaining=1;minimum=0x80;}}
    else if(c>=0xe0 && c<=0xef){{c&=15;remaining=2;minimum=0x800;}}
    else if(c>=0xf0 && c<=0xf4){{c&=7;remaining=3;minimum=0x10000;}}
    else return false;
    if(remaining>length-i)return false;
    while(remaining--){{uint8_t next=p[i++];if((next&0xc0)!=0x80)return false;c=(c<<6)|(next&63);}}
    if(c<minimum || c>0x10ffff || (c>=0xd800 && c<=0xdfff))return false;
  }}
  return true;
}}''')
        for f in self.fields:
            if f.type==FieldType.UTF8:
                lines.append(f'''static inline bool {n}_set_{f.name}({n}Owner *owner,const uint8_t *bytes,size_t length) {{
  if(length>{f.capacity} || !{n}_validUtf8(bytes,length))return false;
  if(length)memmove(owner->{f.name}Bytes,bytes,length);
  volatile uint8_t *tail=owner->{f.name}Bytes; for(size_t i=length;i<{f.capacity};i++)tail[i]=0;
  owner->state.{f.name}Address=(uint64_t)(uintptr_t)owner->{f.name}Bytes;
  owner->state.{f.name}Length=(uint32_t)length;owner->state.{f.name}Capacity={f.capacity};return true;
}}''')
            elif f.type==FieldType.BOOL:
                lines.append(f'static inline void {n}_set_{f.name}({n}Owner *owner,bool value) {{ owner->state.{f.name}Flag=value?1:0; }}')
        return '\n'.join(lines)+'\n'

    def swift_adapter(self):
        n=self.name
        lines=[f'''import Foundation

final class {n}Storage {{
    enum Failure: Error {{ case closed, borrowed }}
    private let lock = NSRecursiveLock()
    private var owner: UnsafeMutablePointer<{n}Owner>?
    private var borrows = 0
    init() {{
        let pointer = UnsafeMutablePointer<{n}Owner>.allocate(capacity: 1)
        {n}_init(pointer)
        owner = pointer
    }}
    func withAddress<T>(_ operation: (UInt64) throws -> T) throws -> T {{
        lock.lock(); defer {{ lock.unlock() }}
        guard let owner else {{ throw Failure.closed }}
        borrows += 1; defer {{ borrows -= 1 }}
        return try operation(UInt64(UInt(bitPattern: owner)))
    }}
    func close() throws {{
        lock.lock(); defer {{ lock.unlock() }}
        guard borrows == 0 else {{ throw Failure.borrowed }}
        if let owner {{ {n}_wipe(owner); owner.deallocate(); self.owner = nil }}
    }}
    deinit {{ if let owner {{ {n}_wipe(owner); owner.deallocate() }} }}
''']
        for f in self.fields:
            title=f.name[0].upper()+f.name[1:]
            if f.type==FieldType.UTF8:
                lines.append(f'''    func set{title}(_ value: String) throws -> Bool {{
        lock.lock(); defer {{ lock.unlock() }}
        guard let owner else {{ throw Failure.closed }}
        guard borrows == 0 else {{ throw Failure.borrowed }}
        guard value.utf8.count <= {f.capacity} else {{ return false }}
        var bytes = Array(value.utf8)
        defer {{ _ = bytes.withUnsafeMutableBytes {{ storage in storage.initializeMemory(as: UInt8.self, repeating: 0) }} }}
        return bytes.withUnsafeBufferPointer {{ {n}_set_{f.name}(owner, $0.baseAddress, $0.count) }}
    }}''')
            else:
                typ={FieldType.UINT32:'UInt32',FieldType.UINT64:'UInt64',FieldType.BOOL:'Bool'}[f.type]
                assignment=f'{n}_set_{f.name}(owner, value)' if f.type==FieldType.BOOL else f'owner.pointee.state.{f.name} = value'
                lines.append(f'''    func set{title}(_ value: {typ}) throws {{
        lock.lock(); defer {{ lock.unlock() }}
        guard let owner else {{ throw Failure.closed }}
        guard borrows == 0 else {{ throw Failure.borrowed }}
        {assignment}
    }}''')
        return '\n'.join(lines)+'\n}\n'

    def java_adapter(self, package, library='appstate'):
        if not isinstance(package,str) or not re.fullmatch(r'[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)*',package) or any(p in RESERVED for p in package.split('.')):raise ValueError('Invalid Java package')
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9]*',library):raise ValueError('Invalid native library name')
        n=self.name+'Storage'
        lines=[f'''package {package};
public final class {n} implements AutoCloseable {{
    static {{ System.loadLibrary("{library}"); }}
    private long handle = createNative();
    private int borrows;
    private static native long createNative();
    private static native void destroyNative(long handle);
    private void requireOpen() {{ if(handle == 0) throw new IllegalStateException("State is closed"); }}
    private void requireMutable() {{ requireOpen(); if(borrows != 0) throw new IllegalStateException("State is borrowed"); }}
    public synchronized long withAddress(java.util.function.LongUnaryOperator operation) {{
        requireOpen(); borrows++;
        try {{ return operation.applyAsLong(handle); }} finally {{ borrows--; }}
    }}
    public synchronized void close() {{
        if(borrows != 0) throw new IllegalStateException("State is borrowed");
        if(handle != 0) {{ destroyNative(handle); handle=0; }}
    }}''']
        for f in self.fields:
            title=f.name[0].upper()+f.name[1:]
            if f.type==FieldType.UTF8:
                lines.append(f'''    private static native boolean set{title}Native(long handle, byte[] bytes);
    public synchronized boolean set{title}(String value) {{
        requireMutable();
        if(value.length() > {f.capacity})return false;
        java.nio.charset.CharsetEncoder encoder = java.nio.charset.StandardCharsets.UTF_8.newEncoder();
        java.nio.ByteBuffer encoded;
        try {{ encoded=encoder.encode(java.nio.CharBuffer.wrap(value)); }}
        catch(java.nio.charset.CharacterCodingException failure) {{ return false; }}
        byte[] bytes=new byte[encoded.remaining()]; encoded.get(bytes);
        try {{ return set{title}Native(handle,bytes); }}
        finally {{ java.util.Arrays.fill(bytes,(byte)0); if(encoded.hasArray())java.util.Arrays.fill(encoded.array(),(byte)0); }}
    }}''')
            else:
                typ={FieldType.UINT32:'long',FieldType.UINT64:'long',FieldType.BOOL:'boolean'}[f.type]
                validation='if(value < 0 || value > 4294967295L)throw new IllegalArgumentException("uint32 range");' if f.type==FieldType.UINT32 else ''
                lines.append(f'''    private static native void set{title}Native(long handle, {typ} value);
    public synchronized void set{title}({typ} value) {{ requireMutable(); {validation} set{title}Native(handle,value); }}''')
        return '\n'.join(lines)+'\n}\n'

    def jni_adapter(self, package, header='state.h'):
        self.java_adapter(package)  # Validate symbols identically.
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_.-]*\.h',header):raise ValueError('Invalid header filename')
        n=self.name;prefix='Java_'+package.replace('.','_')+'_'+n+'Storage_'
        lines=[f'''#include <jni.h>
#include <stdlib.h>
#include "{header}"
JNIEXPORT jlong JNICALL {prefix}createNative(JNIEnv *env,jclass cls) {{
    (void)cls; {n}Owner *owner=malloc(sizeof(*owner));
    if(!owner){{jclass error=(*env)->FindClass(env,"java/lang/OutOfMemoryError");if(error)(*env)->ThrowNew(env,error,"Native state allocation failed");return 0;}}
    {n}_init(owner);uint64_t value=(uint64_t)(uintptr_t)owner;jlong bits;__builtin_memcpy(&bits,&value,8);return bits;
}}
JNIEXPORT void JNICALL {prefix}destroyNative(JNIEnv *env,jclass cls,jlong handle) {{
    (void)env;(void)cls;{n}Owner *owner=({n}Owner*)(uintptr_t)(uint64_t)handle;if(owner){{{n}_wipe(owner);free(owner);}}
}}''']
        for f in self.fields:
            title=f.name[0].upper()+f.name[1:]
            if f.type==FieldType.UTF8:
                lines.append(f'''JNIEXPORT jboolean JNICALL {prefix}set{title}Native(JNIEnv *env,jclass cls,jlong handle,jbyteArray bytes) {{
    (void)cls; if(!bytes)return JNI_FALSE;
    jsize length=(*env)->GetArrayLength(env,bytes);if(length>{f.capacity})return JNI_FALSE;
    jbyte *data=(*env)->GetByteArrayElements(env,bytes,0);if(!data)return JNI_FALSE;
    bool ok={n}_set_{f.name}(({n}Owner*)(uintptr_t)(uint64_t)handle,(uint8_t*)data,(size_t)length);
    (*env)->ReleaseByteArrayElements(env,bytes,data,JNI_ABORT);return ok?JNI_TRUE:JNI_FALSE;
}}''')
            else:
                typ='jboolean' if f.type==FieldType.BOOL else 'jlong'
                assign=f'{n}_set_{f.name}(owner,value!=0)' if f.type==FieldType.BOOL else f'owner->state.{f.name}=({"uint32_t" if f.type==FieldType.UINT32 else "uint64_t"})value'
                lines.append(f'''JNIEXPORT void JNICALL {prefix}set{title}Native(JNIEnv *env,jclass cls,jlong handle,{typ} value) {{
    (void)env;(void)cls;{n}Owner *owner=({n}Owner*)(uintptr_t)(uint64_t)handle;{assign};
}}''')
        return '\n'.join(lines)+'\n'
