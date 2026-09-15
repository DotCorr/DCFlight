#!/usr/bin/env python3
"""Compile bounded generic method or typed-owner probes; never execute SDK calls.

Each supplied candidate is repeated across a method's type parameters. This is
sampled specialization evidence, not exhaustive generic coverage or catalog approval.
The receiver mode checks reachable instance members with concrete owner arguments.
The constructor mode checks creation with concrete owner arguments and optional
constructor-owned type candidates, repeated across each constructor's formals.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.platforms.android_api import AndroidAPI, JavaValue, _split


def probes(api, candidates):
    accepted, rejected = [], []
    for member in sorted(api.members.values(), key=lambda m: m.id):
        if member.kind != 'method' or not member.java_type.startswith('<'):
            continue
        depth, end = 1, 1
        while end < len(member.java_type) and depth:
            if member.java_type[end] == '<': depth += 1
            elif member.java_type[end] == '>': depth -= 1
            end += 1
        if depth:
            rejected.append({'id':member.id,'reason':'Unbalanced method formals'})
            continue
        count = len(_split(member.java_type[1:end-1]))
        for candidate in candidates:
            types = [candidate] * count
            record = {'id':member.id, 'typeArguments':types}
            try:
                specialized = api.specialize(member.id, types)
                arguments = [JavaValue.reference('argument'+str(i), p.java_type)
                             for i,p in enumerate(specialized.parameters)]
                receiver = None if member.static else JavaValue.reference('receiver', api._receiver_type(member.owner))
                emitted = api.emit(member.id, arguments, receiver, type_arguments=types)
                parameters = [p.java_type+' argument'+str(i) for i,p in enumerate(specialized.parameters)]
                if receiver: parameters.insert(0, receiver.java_type+' receiver')
                body = emitted.source+';' if emitted.java_type == 'void' else 'return '+emitted.source+';'
                record.update(resultType=emitted.java_type, expression=emitted.source,
                              method='public static '+emitted.java_type+' probe('+', '.join(parameters)+') throws Throwable { '+body+' }')
                accepted.append(record)
            except ValueError as error:
                rejected.append({**record,'reason':str(error)})
    return accepted, rejected


def owner_probes(api, receivers):
    """Sample all catalogued instance members reachable from concrete receivers."""
    accepted, rejected = [], []
    for receiver_type in receivers:
        receiver = JavaValue.reference('receiver', receiver_type)
        for member in sorted(api.members.values(), key=lambda m: m.id):
            if member.static or member.kind not in ('method', 'field'):
                continue
            if not api.is_assignable(receiver.java_type, member.owner):
                continue
            record = {'id':member.id, 'receiverType':receiver_type}
            try:
                resolved = api.resolve_member(member.id, receiver_type=receiver.java_type)
                arguments = [JavaValue.reference('argument'+str(i), p.java_type)
                             for i,p in enumerate(resolved.parameters)]
                emitted = api.emit(member.id, arguments, receiver)
                parameters = [receiver.java_type+' receiver'] + [
                    p.java_type+' argument'+str(i) for i,p in enumerate(resolved.parameters)]
                body = emitted.source+';' if emitted.java_type == 'void' else 'return '+emitted.source+';'
                record.update(resultType=emitted.java_type, expression=emitted.source,
                              method='public static '+emitted.java_type+' probe('+', '.join(parameters)+') throws Throwable { '+body+' }')
                accepted.append(record)
            except ValueError as error:
                rejected.append({**record,'reason':str(error)})
    return accepted, rejected



def constructor_probes(api, constructed_types, candidates=None):
    accepted, rejected = [], []
    for constructed_type in constructed_types:
        owner = constructed_type.partition('<')[0]
        for member in sorted(api.members.values(), key=lambda m: m.id):
            if member.kind != 'ctor' or member.owner != owner:
                continue
            record = {'id':member.id, 'constructedType':constructed_type, 'typeArguments':None}
            try:
                prefix = api._callable_type_prefix(member)
                count = 0
                if prefix.startswith('<'):
                    depth, end = 1, 1
                    while end < len(prefix) and depth:
                        if prefix[end] == '<': depth += 1
                        elif prefix[end] == '>': depth -= 1
                        end += 1
                    if depth: raise ValueError('Unbalanced constructor formals')
                    count = len(_split(prefix[1:end-1]))
            except ValueError as error:
                rejected.append({**record,'reason':str(error)})
                continue
            choices = [[candidate] * count for candidate in candidates] if count and candidates else [None]
            for types in choices:
                record = {'id':member.id, 'constructedType':constructed_type, 'typeArguments':types}
                try:
                    resolved = api.resolve_member(member.id, constructed_type=constructed_type, type_arguments=types)
                    arguments = [JavaValue.reference('argument'+str(i), p.java_type)
                                 for i,p in enumerate(resolved.parameters)]
                    emitted = api.emit(member.id, arguments, constructed_type=constructed_type, type_arguments=types)
                    parameters = [p.java_type+' argument'+str(i) for i,p in enumerate(resolved.parameters)]
                    record.update(resultType=emitted.java_type, expression=emitted.source,
                                  method='public static '+emitted.java_type+' probe('+', '.join(parameters)+') throws Throwable { return '+emitted.source+'; }')
                    accepted.append(record)
                except ValueError as error:
                    rejected.append({**record,'reason':str(error)})
    return accepted, rejected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--android-jar',type=Path,required=True)
    parser.add_argument('--javac',type=Path,required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--type',dest='candidates',action='append')
    mode.add_argument('--receiver',dest='receivers',action='append')
    mode.add_argument('--construct',dest='constructed_types',action='append')
    parser.add_argument('--constructor-type',dest='constructor_candidates',action='append',
                        help='Candidate repeated across constructor-owned formals; requires --construct')
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--batch-size',type=int,default=100)
    args = parser.parse_args()
    if args.constructor_candidates and not args.constructed_types: parser.error('--constructor-type requires --construct')
    if args.report.exists(): parser.error('Use a fresh report path')
    if not 1 <= args.batch_size <= 500 or len(args.candidates or args.receivers or args.constructed_types)>16: parser.error('Invalid sweep bounds')
    if len(args.constructor_candidates or [])>16: parser.error('Invalid constructor candidate bounds (maximum 16)')
    raw = args.source.read_bytes(); api = AndroidAPI(raw.decode())
    if args.constructed_types: selected, rejected = constructor_probes(api,args.constructed_types,args.constructor_candidates)
    elif args.receivers: selected, rejected = owner_probes(api,args.receivers)
    else: selected, rejected = probes(api,args.candidates)
    compiled, failed = [], []
    with tempfile.TemporaryDirectory(prefix='dcflight-generic-sweep-') as folder:
        work = Path(folder); jar = work/'android.jar'; shutil.copyfile(args.android_jar,jar)
        sdk_hash = hashlib.sha256(jar.read_bytes()).hexdigest()
        def compile_batch(batch):
            with tempfile.TemporaryDirectory(dir=work) as batch_folder:
                directory = Path(batch_folder); files = []
                for index, record in enumerate(batch):
                    path = directory/('Probe'+str(index)+'.java')
                    source = 'public class Probe'+str(index)+' { '+record['method']+' }\n'
                    path.write_text(source); files.append(path)
                command = [str(args.javac.resolve()),'-source','8','-target','8','-Xlint:unchecked','-Werror','-bootclasspath',str(jar),'-d',str(directory),*[str(p) for p in files]]
                result = subprocess.run(command,capture_output=True,text=True,timeout=120)
            if result.returncode == 0:
                compiled.extend(batch)
            elif len(batch)>1:
                half = len(batch)//2; compile_batch(batch[:half]); compile_batch(batch[half:])
            else:
                failed.append({**batch[0],'diagnostic':result.stderr})
        for start in range(0,len(selected),args.batch_size):
            compile_batch(selected[start:start+args.batch_size])
            print(json.dumps({'checked':min(start+args.batch_size,len(selected)), 'total':len(selected),
                              'compiled':len(compiled),'failed':len(failed)}),flush=True)
    report = {'scope':__doc__, 'sourceSHA256':hashlib.sha256(raw).hexdigest(),
              'sdkSHA256':sdk_hash,'javacVersion':subprocess.check_output([str(args.javac.resolve()),'-version'],text=True).strip(),
              'compilerSHA256':hashlib.sha256(Path(sys.modules[AndroidAPI.__module__].__file__).read_bytes()).hexdigest(),
              'compileOptions':['-source','8','-target','8','-Xlint:unchecked','-Werror','-bootclasspath','captured Android SDK jar'],
              'candidateTypes':args.candidates,'receiverTypes':args.receivers,'constructedTypes':args.constructed_types,
              'constructorCandidateTypes':args.constructor_candidates,'compiled':compiled,'failed':failed,'rejected':rejected,
              'counts':{'compiled':len(compiled),'failed':len(failed),'rejected':len(rejected)}}
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report['counts']))


if __name__ == '__main__': main()
