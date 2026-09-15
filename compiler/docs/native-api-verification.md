# Native API verification

The catalog is a development artifact. Indexing a declaration, emitting a call,
compiling it against an SDK, and executing it are separate evidence levels.
A successful sampled sweep is not complete platform coverage.

## iOS dependency type names and availability

Pass dependency symbolgraphs explicitly when SDK signatures use renamed imported
nominals. Resolution uses exact Swift symbol identities, not spelling guesses.
The verifier records dependency graph hashes and compiler source hashes; descriptor
export rejects changed or missing inputs. Already canonical referenced types also
inherit their dependency availability constraints.

```sh
python3 tools/verify_ios_api_batch.py \
  --module UIKit=/path/to/UIKit-graphs \
  --type-module CloudKit=/path/to/CloudKit-graphs \
  --ios-version 18.0 --swift-version 6 --limit 0 \
  --output /path/to/fresh-native-report.json
```

The packaged `dcflight api verify-ios` command also accepts `--type-module`.
`--import` adds a Swift import; it does not provide type identity or availability
metadata. Use `--type-module` for dependency type resolution.

The standalone verifier exits unsuccessfully when native candidates fail or no
candidate passes. Skipped target-incompatible declarations remain in its report.
Exporting/indexing a report preserves individual pass/rejection/skip states; a
catalog import is not a release approval.

## Android exact SDK checks

```sh
python3 tools/verify_android_api.py \
  --api /path/to/android-api.txt \
  --android-jar /path/to/android-35/android.jar \
  --javac /path/to/jdk/bin/javac --android-core --limit 50000 \
  --report /path/to/native-report.json
```

`--android-core` resolves Java core types against Android boot stubs instead of
host JDK classes. Reports identify the API input, SDK archive, generated probes,
verifier, and compiler sources by SHA-256. Compiler changes during a sweep
invalidate certification. The dependency scan inspects actual class references.
This checks native compilation, not runtime permission grants or device behavior.

Bytecode ingestion reads exact class files from the locked archive, including
InnerClasses access/static flags. Public static nested constructors are available;
true instance inner constructors and inaccessible enclosing classes remain
rejected. Generic owners still require explicit concrete type arguments.

## Release limits

An API's availability can depend on SDK version, deployment target, feature flags,
actor/thread context, entitlements, permission grants, and hardware. Tests must
identify those contexts. The current registry does not establish a complete public
platform denominator or execution coverage. SDK catalog size must never be used as
proof that every native app can be authored or that Snap is production-ready.
