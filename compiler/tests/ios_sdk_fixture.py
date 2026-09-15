"""Minimal real SDKSettings fixture for mocked native-process tests."""
import json
from pathlib import Path
def write_sdk(path):
 path=Path(path);path.mkdir(exist_ok=True,parents=True)
 (path/'SDKSettings.json').write_text(json.dumps({'CanonicalName':'iphonesimulator26.2','Version':'26.2','SupportedTargets':{'iphonesimulator':{'LLVMTargetTripleVendor':'apple','LLVMTargetTripleSys':'ios','LLVMTargetTripleEnvironment':'simulator','Archs':['arm64']}}}))
 return path

def fake_toolchain(root,fallback='fixture'):
 sdk=write_sdk(Path(root)/'fake-sdk')
 def output(command,**kwargs):
  if '--show-sdk-path' in command:return str(sdk)
  if '--show-sdk-version' in command:return '26.2'
  return fallback
 return output
