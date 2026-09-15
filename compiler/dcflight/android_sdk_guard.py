"""Development-time Gradle check for certificate-qualified Android call sites."""
import re


DIRECTIVE="apply from: 'verified-android-sdk.gradle'"


def active_guard_hook(source, *, filename="verified-android-sdk.gradle"):
    """Accept an unconditional standalone top-level hook; reject ambiguity."""
    if filename not in ("verified-android-sdk.gradle", "native-versions.gradle"):
        raise ValueError("Unknown generated Gradle hook")
    depth=0;quoted=None;block=False;control=False
    for line in source.splitlines(True):
        if not quoted and not block and depth==0 and not control and re.fullmatch(
                r"\s*apply from: '"+re.escape(filename)+r"'\s*;?\s*(?://[^\n]*)?\s*",line):
            return True
        i=0
        while i<len(line):
            if block:
                if line.startswith('*/',i):block=False;i+=2
                else:i+=1
                continue
            if quoted:
                if line[i]=='\\':i+=2
                elif line.startswith(quoted,i):i+=len(quoted);quoted=None
                else:i+=1
                continue
            if line.startswith('//',i):break
            if line.startswith('/*',i):block=True;i+=2;continue
            if line[i] in "\"'":
                quoted=line[i]*3 if line.startswith(line[i]*3,i) else line[i];i+=len(quoted);continue
            if line[i]=='/':return False  # Ambiguous slashy Groovy literal.
            if line[i]=='{':depth+=1
            elif line[i]=='}':
                depth-=1
                if depth<0:return False
            elif depth==0 and (line[i].isalpha() or line[i]=='_'):
                end=i+1
                while end<len(line) and (line[end].isalnum() or line[end]=='_'):end+=1
                if line[i:end] in ('if','else','for','while','do','switch','try','catch','finally','synchronized'):
                    control=True
                i=end;continue
            i+=1
    return False


def gradle_guard(requirements):
    if not requirements:return '// Generated development-time hook; no SDK-qualified conditional calls in this application.\n'
    identities={(row['apiLevel'],row['sdkSha256']) for row in requirements}
    if len(identities)!=1:raise ValueError('Conditional calls require one matching Android SDK snapshot')
    level,digest=next(iter(identities))
    if type(level) is not int or level<1 or not isinstance(digest,str) or not re.fullmatch('[0-9a-f]{64}',digest):
        raise ValueError('Invalid qualified SDK requirement')
    return '''// Generated development-time SDK verification; not packaged in the app.
def dcflightSdkCheck = tasks.register('verifyDcflightAndroidSdk') {
    doLast {
        def sdkJars = android.bootClasspath.findAll { it.name == 'android.jar' }
        if (sdkJars.size() != 1) throw new GradleException('Expected one Android SDK boot JAR')
        def digest = java.security.MessageDigest.getInstance('SHA-256')
        sdkJars[0].withInputStream { input ->
            byte[] buffer = new byte[65536]
            int count
            while ((count = input.read(buffer)) != -1) digest.update(buffer, 0, count)
        }
        def actual = digest.digest().encodeHex().toString()
        if (actual != '%s') throw new GradleException('Android SDK differs from verified conditional API snapshot; reverify against this SDK')
    }
}
tasks.matching { it.name == 'preBuild' }.configureEach { dependsOn(dcflightSdkCheck) }
''' % digest
