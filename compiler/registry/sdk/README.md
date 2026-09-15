# Installed SDK coverage catalog

`current.sqlite` is a development-only catalog rebuilt from the installed iOS 26.2 simulator SDK and Android 35 framework/core inputs. It is not packaged into generated applications. Android signature snapshots are retained in `current.sqlite.sources/`.

Use `python3 -m dcflight sdk coverage --catalog registry/sdk/current.sqlite` to inspect current counts. Native API discovery and emission use the same catalog path. No claim of complete platform capability coverage follows from importing a declaration.

The fresh iOS sweep extracted 294 modules, failed four and left zero pending. Excluded candidates remain recorded in the sweep inventory, including C++ and implementation modules. Failed candidates: CoreAudio_Private, IOKit, MacTypes and Twitter. These require classification or another extraction path; they are not silently considered supported. The scope is the installed simulator SDK, not every device SDK or future SDK release.

Fresh iOS records deliberately start without compilation evidence. Previously verified catalogs remain separate until their exact provenance and identities can be reconciled. Android framework compilation is verified separately; core bytecode import alone does not establish execution or compilation coverage.

The Android inventory covers the selected framework signatures and java/javax/org.w3c.dom/org.xml.sax core classes. AndroidX, vendor APIs, Google Play services, other SDK versions and NDK APIs are not collectively covered by this inventory.

Shared Dart application logic, callbacks, lifecycle, permissions and complete application flows require additional typed contracts and native tests. Both indexed-but-unsupported declarations and missing SDK surfaces remain work to complete.
