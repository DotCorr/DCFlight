"""Couple iOS SDK settings, target triple and retained evidence environment."""
import hashlib,json,re,subprocess
from pathlib import Path
ENVIRONMENTS=('iphonesimulator','iphoneos')
def environment(value='iphonesimulator'):
    if value not in ENVIRONMENTS:raise ValueError('SDK environment must be iphoneos or iphonesimulator')
    return value

def target(environment_name, version):
    environment(environment_name)
    if not isinstance(version,(tuple,list)) or len(version)!=2 or any(type(v) is not int or v<0 for v in version):raise ValueError('Invalid iOS target version')
    return 'arm64-apple-ios'+'.'.join(map(str,version))+('-simulator' if environment_name=='iphonesimulator' else '')

def validate_target(environment_name, triple):
    environment(environment_name)
    m=re.fullmatch(r'arm64-apple-ios(\d+)\.(\d+)(-simulator)?',triple or '')
    if not m or bool(m[3])!=(environment_name=='iphonesimulator'):raise ValueError('SDK environment and target triple disagree')
    return (int(m[1]),int(m[2]))

def sdk_settings(sdk, environment_name):
    environment(environment_name);path=Path(sdk)/'SDKSettings.json';raw=path.read_bytes();settings=json.loads(raw)
    name=settings.get('CanonicalName','');version=settings.get('Version');platform=settings.get('SupportedTargets',{}).get(environment_name,{})
    if not isinstance(version,str) or name!=environment_name+version or platform.get('LLVMTargetTripleVendor')!='apple' or platform.get('LLVMTargetTripleSys')!='ios' or platform.get('LLVMTargetTripleEnvironment')!=('simulator' if environment_name=='iphonesimulator' else '') or 'arm64' not in platform.get('Archs',[]):raise ValueError('SDK settings contradict selected iOS environment')
    return {'sdkEnvironment':environment_name,'sdkSettingsSHA256':hashlib.sha256(raw).hexdigest(),'sdkVersion':version}

def validate_report(report):
    env=environment(report.get('sdkEnvironment','iphonesimulator'))
    validate_target(env,report.get('target'))
    # Even legacy receipts must name an actual simulator SDK; absence is never
    # permission to infer device support or accept contradictory SDK settings.
    actual=sdk_settings(report['sdk'],env)
    if 'sdkEnvironment' in report:
        if any(report.get(k)!=v for k,v in actual.items()):raise ValueError('Native evidence SDK settings/environment changed')
    elif 'sdkSettingsSHA256' in report and report['sdkSettingsSHA256']!=actual['sdkSettingsSHA256']:
        raise ValueError('Native evidence SDK settings changed')
    if 'sdkVersion' in report and report['sdkVersion']!=actual['sdkVersion']:raise ValueError('Native evidence SDK version differs')
    return env

def locate(environment_name='iphonesimulator'):
    environment(environment_name)
    sdk=subprocess.check_output(['xcrun','--sdk',environment_name,'--show-sdk-path'],text=True).strip()
    actual=sdk_settings(sdk,environment_name)
    version=subprocess.check_output(['xcrun','--sdk',environment_name,'--show-sdk-version'],text=True).strip()
    if version!=actual['sdkVersion']:raise ValueError('SDK reported version differs from settings')
    return {'sdk':sdk,**actual}
