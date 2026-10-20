# The C API of JavaScriptCore that iOS 6 already exports

The SDK dates the JavaScriptCore headers after iOS 6. An iPad 2 running 6.1.3, asked one by one with `dlsym`
after every framework of the release had loaded, found thirteen of the names the registry would otherwise
have called absent - that count is corrected here, not because the thirteen were wrong, but because the
probe was silent about everything it never asked. `coordination/corpus/caches/6.0.tsv`, built from the
release's own export table rather than a running process's memory, names 93 `JS`-prefixed symbols in the
framework - the full C API a real bridge needs: `JSEvaluateScript`, `JSObjectCallAsFunction`,
`JSObjectSetProperty`, `JSClassCreate`, `JSStringCreateWithCharacters` and the rest, not just the ones the
device probe happened to ask for. `facts/JavaScriptCore/JSContext.md` carries the Objective-C API
(`JSContext`, `JSValue`, `JSVirtualMachine`, `JSManagedValue`, `JSExport`) built over this C API, now
implemented rather than absent.

Source: coordination/corpus/caches/6.0.tsv, the release's own export table, not a running process's memory.

## What the release exports

Every `JS`-prefixed symbol below is exported by JavaScriptCore in iOS 6.0:

`JSCheckScriptSyntax`, `JSClassCreate`, `JSClassRelease`, `JSClassRetain`, `JSContextCreateBacktrace`,
`JSContextGetGlobalContext`, `JSContextGetGlobalObject`, `JSContextGetGroup`, `JSContextGroupCreate`,
`JSContextGroupRelease`, `JSContextGroupRetain`, `JSDisableGCTimer`, `JSEndProfiling`, `JSEvaluateScript`,
`JSGarbageCollect`, `JSGlobalContextCreate`, `JSGlobalContextCreateInGroup`, `JSGlobalContextRelease`,
`JSGlobalContextRetain`, `JSObjectCallAsConstructor`, `JSObjectCallAsFunction`, `JSObjectCopyPropertyNames`,
`JSObjectDeletePrivateProperty`, `JSObjectDeleteProperty`, `JSObjectGetPrivate`,
`JSObjectGetPrivateProperty`, `JSObjectGetProperty`, `JSObjectGetPropertyAtIndex`, `JSObjectGetPrototype`,
`JSObjectHasProperty`, `JSObjectIsConstructor`, `JSObjectIsFunction`, `JSObjectMake`, `JSObjectMakeArray`,
`JSObjectMakeConstructor`, `JSObjectMakeDate`, `JSObjectMakeError`, `JSObjectMakeFunction`,
`JSObjectMakeFunctionWithCallback`, `JSObjectMakeRegExp`, `JSObjectSetPrivate`,
`JSObjectSetPrivateProperty`, `JSObjectSetProperty`, `JSObjectSetPropertyAtIndex`, `JSObjectSetPrototype`,
`JSPropertyNameAccumulatorAddName`, `JSPropertyNameArrayGetCount`, `JSPropertyNameArrayGetNameAtIndex`,
`JSPropertyNameArrayRelease`, `JSPropertyNameArrayRetain`, `JSReportExtraMemoryCost`, `JSStartProfiling`,
`JSStringCopyCFString`, `JSStringCreateWithCFString`, `JSStringCreateWithCharacters`,
`JSStringCreateWithUTF8CString`, `JSStringGetCharactersPtr`, `JSStringGetLength`,
`JSStringGetMaximumUTF8CStringSize`, `JSStringGetUTF8CString`, `JSStringIsEqual`,
`JSStringIsEqualToUTF8CString`, `JSStringRelease`, `JSStringRetain`,
`JSValueCreateJSONString`, `JSValueGetType`, `JSValueIsBoolean`, `JSValueIsEqual`,
`JSValueIsInstanceOfConstructor`, `JSValueIsNull`, `JSValueIsNumber`, `JSValueIsObject`,
`JSValueIsObjectOfClass`, `JSValueIsStrictEqual`, `JSValueIsString`, `JSValueIsUndefined`,
`JSValueMakeBoolean`, `JSValueMakeFromJSONString`, `JSValueMakeNull`, `JSValueMakeNumber`,
`JSValueMakeString`, `JSValueMakeUndefined`, `JSValueProtect`, `JSValueToBoolean`, `JSValueToNumber`,
`JSValueToObject`, `JSValueToStringCopy`, `JSValueUnprotect`, `JSWeakObjectMapClear`,
`JSWeakObjectMapCreate`, `JSWeakObjectMapGet`, `JSWeakObjectMapRemove`, `JSWeakObjectMapSet`.

Missing from that list, and not carried: `JSValueIsArray` and `JSValueIsDate` (iOS 9), `JSGlobalContextSetName`
and `JSGlobalContextCopyName` (iOS 8), everything ArrayBuffer/TypedArray-shaped (iOS 10), the `ForKey`
property functions and `JSObjectMakeDeferredPromise` (iOS 13), `JSValueIsSymbol`/`JSValueMakeSymbol` (iOS
13), and `JSGlobalContextIsInspectable`/`JSGlobalContextSetInspectable` (iOS 16.4) - `registry/JavaScriptCore/absent_JavaScriptCore.json`
carries these by name.

The framework is one of the release's private ones, and what these functions do was not compared with a
newer release: the names are exported, and nothing more is claimed for the C API itself.
