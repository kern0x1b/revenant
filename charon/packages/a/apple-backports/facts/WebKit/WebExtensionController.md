# WKWebExtensionController, WKWebExtensionControllerConfiguration, WKWebExtensionDataRecord

What this family answers **with no web view at all**, and how each answer is held to something.

Every value below was measured on this machine, and every one of them is now **checked on every run**:
`tests/backports/host/webkit/run.sh` builds two programs and compares them.

```
webextension-controller_system.m   the questions, asked of the SYSTEM with no port code in the process,
                                  linked against the real WebKit, and the answers written to a file
webextension-controller_test.m     the same questions asked of the PORT, and the two answers compared
                                  case by case with ur_agree
webextension-controller_scenario.h the questions, in one file, so the two sides cannot be asked
                                  different ones -- compiled twice, once plain and once with the renames
```

The port is compiled for the host with `-DCHARON_HOST_DIFFERENTIAL`, which makes its own headers step
aside so the SDK's declarations are used, and with `renames.sh`'s `-D` flags, which prefix the classes
the port implements so its classes and Apple's live side by side in one process. `dladdr` is what tells
the two apart: without it a build that linked the wrong objects would compare the system against itself
and agree with everything, including a wrong answer. The test proves the port's three classes and its
four exported constants live in this binary and not in the WebKit framework before it compares anything.

## The configuration is a value holder, and persistence is its own fact

```
+[WKWebExtensionControllerConfiguration nonPersistentConfiguration]
  identifier              (nil)            persistent  NO
+[WKWebExtensionControllerConfiguration defaultConfiguration]
  identifier              (nil)            persistent  YES     and NOT the non-persistent object
+[WKWebExtensionControllerConfiguration configurationWithIdentifier:<UUID>]
  identifier              that UUID        persistent  YES
```

**A nil identifier and `persistent == NO` are not the same thing.** The first version of this port derived
one from the other, and the two measurements that say so are the second and the third rows above:
`+defaultConfiguration` answers a **nil identifier with persistent YES**. So the port carries a `_persistent`
flag, set by each constructor, and `-isPersistent` reads it.

`configuration.identifier` is an **NSUUID**, not a string -- the compiler enforced that when it was first
written as a string -- and `+configurationWithIdentifier:` answers nil for anything that is not one, where
the host raises: *"Invalid parameter not satisfying: [identifier isKindOfClass:NSUUID.class]"*, measured.
The port checks rather than throws, which is this family's rule for a wrong argument and is written down
in the code at the check.

## The controller is a real object, and -configuration hands back a copy

```
-[WKWebExtensionController initWithConfiguration:]   a real object
  configuration      NOT the object it was given: measured, isEqual: is NO
  delegate           (nil)
  extensions         0        and still 0 after a real extension was built and handed over
  extensionContexts  0
  +allExtensionDataTypes   three: local, session, synchronized
```

The configuration is a **copy**, and that is why the class is declared `<NSCopying>` here as the 26.2
header declares it (`WKWebExtensionControllerConfiguration.h:41`). Answering the very object the
controller was built with would be the one difference a caller cannot detect, because a configuration
that cannot change hands is indistinguishable from one that has.

**Loading an extension does not add it to `extensions`.** The host still answered 0 after building a real
one and handing it over, and a port that appended it would be answering one more than the release.

## The data-type constants carry the release's VALUES, not the symbols' names

```
WKWebExtensionDataTypeLocal        "local"
WKWebExtensionDataTypeSession      "session"
WKWebExtensionDataTypeSynchronized "synchronized"
```

This port answered the three **symbol names** -- `"WKWebExtensionDataTypeLocal"` and so on. A
`WKWebExtensionDataType` is a string a caller sends to the browser and gets back, and the release's three
are the bare words; a port that answered the symbol name would be answering a name no browser has heard
of, and `+allExtensionDataTypes` would have listed three that match nothing. Nothing noticed, because the
only evidence these rows had was a printer's output transcribed by hand into this file.

## What the port answers its own way, and why

These are cases in the test rather than in the shared scenario, because asking the host about them would
record an answer the port is not meant to match. Each is a named case, checked on every run.

| case | the host | the port | why |
| --- | --- | --- | --- |
| `port.configuration.webViewConfigurationIsNil` | a real `WKWebViewConfiguration` | nil | the port has no web view to make one with |
| `port.configuration.defaultWebsiteDataStoreIsNil` | a real `WKWebsiteDataStore` | nil | the same |
| `port.controller.loadExtensionContext` | raises `NSInternalInconsistencyException` | NO, in `WKWebExtensionContextErrorDomain` | it could not load a context if it tried; the raise is the host's nil-argument check, and the port checks rather than throws |
| `port.controller.unloadExtensionContext` | the same raise | the same answer | nothing was ever loaded |
| `port.controller.extensionContextForNilExtension` | raises | nil | the same rule, same reason |
| `port.class.dataRecord` and the five members, `port.dataRecord.sizeInBytesOfTypes` | cannot be asked: `+new` and `-init` are `NS_UNAVAILABLE` on `WKWebExtensionDataRecord` | built by the port's own `charon_initWithIdentifier:displayName:containedDataTypes:errors:` | there is no host object to compare with, so each member is held to the value the record was built from, and the sizes to the zero an empty record holds |

## The extension families' own 78 records

`webextension.m` measures the extension, pattern, action and context families against a real manifest,
and `run.sh` builds and runs it, which nothing did before. `manifest/manifest.json` is committed beside
it for that reason: the probe's record count is a property of **that** file, and the count it claims (78)
was measured against it. The count it claimed before (77) belonged to a manifest that was never
committed, so the number described a file nobody else could see and the check could not be reproduced.

## What the differential found

It found four real defects in the first version of this port, none of which any build or test had caught,
because the evidence for thirty `implemented` rows was a printer's output read by eye:

1. `+defaultConfiguration` was **not implemented at all**, though a row claimed it.
2. `-isPersistent` derived itself from the identifier, which `+defaultConfiguration` refutes.
3. `-configuration` returned the object it was given, where the release answers a copy.
4. The three data-type constants carried the symbols' names instead of the release's values.

Each is fixed above, and each is now held by a named case that fails if the answer changes. The red
control is the check that this is true: plant a wrong `-uniqueIdentifier`, and `run.sh` answers `FAIL
case port.dataRecord.uniqueIdentifier is what it was built with: PLANTED` and exits 1.
