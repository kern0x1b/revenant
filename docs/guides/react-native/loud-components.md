# Missing native components and stubs fail loudly

The host must never show an application that looks fine while a native component or module is not there. Two places keep that rule.

## Fabric components

React Native's codegen writes `RCTThirdPartyComponentsProvider.mm`, a dictionary literal of `NSClassFromString` calls. A class that is
not linked becomes `nil`, and the dictionary literal raises at start, so the application does not open. A silent fix would drop the
component and every view of it would render as nothing.

```
./xmakew l -P . frameworks/ReactNative/tools/loud_provider.lua --source RCTThirdPartyComponentsProvider.mm --output FILE [--optional A,B]
```

writes the copy the host builds instead. A component whose class is missing is left out of the dictionary, written to the log as
`rn-host: MISSING COMPONENT <name>: the class <class> is not linked into this host`, and reported as a React Native error with the
same words. Only the components named in `--optional`, the ones the application itself declares optional, are skipped without a
word. On the Paseo application the tool turns 73 entries into `RNHOST_ADD` calls, the same file the spike's `sed` script made.

## Stubs

A stub module only registers its name so that the JavaScript import works. Every function of it calls `StubReport.called` first, which
writes `rn-host: STUB CALLED <module>.<function> is a stub in this build; nothing was done` to the log, so a feature that is absent
shows up in the host log and in the coverage table (`docs/reference/react-native/coverage.md`, status `stub`) and is never taken for a
working one.
