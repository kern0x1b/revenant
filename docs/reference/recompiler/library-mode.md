# Library mode

What `XL_LIBRARY=1` builds, the loader API, and what was measured on the iPhone 4S (iOS 6.1.3) with a host of about
85 MB resident. [Why it is built this way](../../explanation/recompiler/library-mode.md); [the commands](../../guides/recompiler/build-and-translate.md#translate-a-library).

## Build interface

`XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua <input>.dylib includes.h out/ [guest images]` writes
`out/<name>.dylib` and `out/<name>-classes.dylib`; the two files go into one folder, and the second is found by its name.

| Variable | Meaning | Default |
|---|---|---|
| `XL_LIBRARY` | build a dylib instead of an executable | unset |
| `XL_BASE` | address of the first guest segment: where the loader maps the guest image | `0x10000000` |
| `XL_INSTALL_NAME` | install name of the output | `@rpath/<name>.dylib` |
| `XL_SWIFT_HOST_ANCESTORS` | Swift classes with an Objective-C ancestor are host objects with a twin | unset |
| `XL_REPLACES` | guest images that stand for system libraries | unset |
| `XL_NAMESPACE` | prefix of the Objective-C class names of every guest image but the first (the runtime and the overlays); `none` leaves the names as they are | `XLG.` |
| `BACKPORTS_DIR` | folder with the `lib*Backports.dylib` of the app's build: the imports the iOS 6.1.3 shared cache lacks and the Backports export bind to them | unset |
| `XL_PROXY_CLASSES` | `1` keeps every class the Backports export bound to them, also one the iOS 6 cache has (the binding before 2026-11-15; a negative control) | unset |

A library for an app that ships the Backports is translated with `BACKPORTS_DIR`. Without it every weak import the cache
lacks (`NSURLComponents`, `NSURLQueryItem`, `NSURLSession`, `NSISO8601DateFormatter`, `WKWebView`, `NSDateInterval`, the
`NSURL*Key` constants and the like) is left unbound and is nil or zero on the phone, even though the app carries the
class; the translation lists them in `weak-absent.txt` and, for classes, in `uncovered-classes.txt`. With it the library
gets one load command for each Backports library it uses (`-dead_strip_dylibs` drops the others), by that library's
install name, `/usr/lib/revenant/org.revenant.backports/lib<Name>Backports.dylib`; the app has to have those files, as an
app of revenant's build has through the package `org.revenant.backports`. The registry and the loader do not change.
The reCAPTCHA Enterprise SDK needs it. Translated without `BACKPORTS_DIR` (2026-11-15, main e54eefda5 with the check
below) its `uncovered-classes.txt` lists 14 class references: `NSURLComponents`, `NSURLQueryItem`, `NSURLSession`,
`NSURLSessionConfiguration`, `NSISO8601DateFormatter`, `NSMeasurement`, `NSDimension`, the two
`NSAttributedStringMarkdown*` classes, `WKWebView`, `WKWebViewConfiguration`, `DCAppAttestService`, and `OS_dispatch_queue`
and `OS_dispatch_source`, which the cache has but its `libSystem` does not export as symbols. `weak-absent.txt` lists 70 weak
imports (`NSDateInterval`, `NSPersonNameComponents`, 25 `NSURL*` key constants and others). With it (main 7bdac1e30) the first
list is empty, the second has 28 left that the Backports do not export, and the library has strong load commands for ten
Backports libraries (AVFAudio, CoreData, CoreFoundation, CoreGraphics, DeviceCheck, Foundation, Security, System, UIKit, WebKit).

A class reference is covered, and bound strongly, when it is bound to a Backports library, or to a system library whose
copy in the iOS 6.0 cache exports the symbol (`dyld.exported_by`, the check the import check of the translation applies), or,
for a flat lookup, when the class is in `classes_armv7.json` of that cache. The others are uncovered: the translation
imports them weakly (`macho.weaken_classrefs`), so a phone that lacks them has nil and not a failed load. Until 2026-11-15
the check read the class list as an array, which a JSON object is not (`#` is 0), so the cache's classes never counted and
the same translation listed 66 references, every class the library imports, `NSObject` and `NSString` among them; a Backports
library counted as covering a class it only imported, not one it exports. Every one of the 14 is exported by a Backports library
of main 7bdac1e30, so `BACKPORTS_DIR` covers all of them.

### Which class binds to the proxy and which to the system library

The Backports come first in the link, so every class symbol they export binds to them, whether or not the iOS 6 cache has the
class: a Backports library exports `_OBJC_CLASS_$_X` as an alias of its proxy `RevenantX`
([how the Backports load](../../explanation/backports-loading.md)). After the link the translator moves part of those
binds back, in `bind_system_classes` of `recompiler/tools/translate.lua`, with `rebind` of
`toolchain/modules/apple/macho.lua`: a class symbol (`_OBJC_CLASS_$_X` and `_OBJC_METACLASS_$_X`) that the library imports from
a Backports library is rebound to the system library the SDK links it from, unless one of these holds, in this order:

| Kept on the Backports because | Why |
|---|---|
| the class is not in `classes_armv7.json` of the iOS 6.0 cache (the deployment floor, `e.dyld`) | the system has no such class; the proxy registers one (`+load`) |
| `XL_PROXY_CLASSES=1` | the negative control |
| the class is in `frameworks/Backports/tools/shadowed-classes.txt` (`CASpringAnimation`) | the system class lacks members the proxy has, and the proxy is the one that has them |
| a Backports library exports `___revenant_override_OBJC_CLASS_$_X` | the same marker `revenant.rebind` reads: the library says it replaces the system symbol |
| the iOS 6.0 cache does not export the symbol from the library the SDK links it from (`OS_dispatch_queue`, `OS_dispatch_source` from `libSystem.B.dylib`) | the class exists, but a strong bind to a library that does not export it fails when dyld loads the image; the import check of the translation names it |
| the SDK links no system library for the symbol | nothing to rebind to |

The system library is found by linking a probe object with a reference to each class symbol, against the frameworks of the
real link and without the Backports, and reading which library each symbol is imported from. A library that the
`-dead_strip_dylibs` link dropped (`UIKit`, when only `UIDevice` came from the Backports) gets its load command from `rebind`,
with the versions the probe link recorded; the link has `-Wl,-headerpad,0x400` for the room. The load commands of the
Backports libraries stay, because `attach.c` runs when such a library loads, and adds to the system class what the proxy
has and the system class lacks (the members of the newer SDK, protocols, properties) and reparents a proxy that has no
instance variables under the system class. A caller bound to the system class therefore gets the same members, and a guest
class whose superclass is `NSMutableDictionary` inherits from the system class, not from a proxy.

`system-classes.txt` lists the rebound symbols (`symbol`, the Backports library it left, the install name it moved to) and
`proxy-classes.txt` those that stay (`symbol`, library, reason). The reCAPTCHA Enterprise SDK (2026-11-15, main 78e295235
with this change): 23 binds move to the system library (`NSMutableDictionary` with its metaclass, `NSSet`, `NSNumber`,
`NSNull`, `NSTimeZone`, `NSUUID`, `NSJSONSerialization`, `NSPropertyListSerialization`, `NSRegularExpression`, `NSLock`,
`NSRecursiveLock`, `NSIndexSet`, `NSMutableIndexSet`, `NSNotification`, `NSException`, `NSInvocation`, `NSMethodSignature`,
`NSEnumerator`, `NSDecimalNumber`, `NSAssertionHandler`, `NSFileSecurity` and `UIDevice`), 21 stay (19 absent from the
cache, among them `NSURLComponents`, `NSURLQueryItem`, `NSURLSession`, `NSMeasurement`, `WKWebView` and `DCAppAttestService`,
and the two dispatch classes). The binary has one load command more than before, for `UIKit`, and 92,480 bytes more of bind
opcodes (`rebind` writes the bind stream without the compression of the linker); the registry and the guest image are byte
for byte those of the translation without the change (drop6), because only the host part's binds moved.

Why: `RCAx_GPBAutocreatedDictionary`, a guest class of the SDK, has `NSMutableDictionary` as its superclass, and with the
Backports first its superclass bind named `RevenantNSMutableDictionary`, whose declared superclass is `NSDictionary`. The
Backports repair that at load when the proxy has no instance variables (`revenant_reparent`), but the binding should not
depend on that. The ObjC categories of the guest images were scanned (2026-11-15, the SDK and the guest `libswiftCore` and
`libswiftFoundation` of main 78e295235): 10 categories in two images, the five of `libswiftFoundation` (on `NSKeyedUnarchiver`,
`NSDictionary`, `NSMutableDictionary`, `NSObject` and `NSBundle`) and the five of `libswiftCore` (on guest classes); only
`NSMutableDictionary` is a class that a Backports library exports and the cache has, and the
Backports carry its dictionary selectors as a category of their own (`NSDictionary+SwiftOverlay.m`). The SDK itself
declares no category. The superclasses of its guest classes are `NSObject`, `_SwiftObject`, `NSData`, `NSError`,
`NSMutableArray` and `NSMutableDictionary`; only the last is exported by a Backports library.

The output is two dylibs. The first, `<name>.dylib`, has two kinds of content:

| Part | Where | Holds |
|---|---|---|
| host `__TEXT`, `__DATA`, `__LINKEDIT` | wherever dyld puts the dylib (it is linked at address 0 and slid) | lifted code, runtime, the table of slots |
| `__XGUEST,__image` | a section in the file, read-only, aligned to 16 KiB; dyld maps it and nobody reads it there | the guest image: the guest's segments as bytes, to be mapped at the addresses the guest was linked at |

There are no guest segments in the link any more (`__X<n>TEXT`, `__X<n>DATA` are gone), and no window under `XL_BASE`: the
host part does not depend on where the guest is. Exports are `_xl_library_class`, `_xl_library_diagnostics`,
`_xl_library_init` and one `_xl_objc_category_<n>` for each Objective-C category of the guest (the registry refers to
them); the check fails on anything else.

The second, `<name>-classes.dylib`, is the registry: the lists that libobjc reads when it loads an image, and nothing
else. It has `__DATA,__objc_classlist` (the guest's classes, by their guest address), `__objc_protolist` (its
protocols, by address), `__objc_catlist` (the categories, which are the first dylib's `xl_objc_category_<n>` structures,
bound by dyld) and `__objc_imageinfo`; no code, no exports, a dependency on the first dylib by its install name. It
is separate because libobjc registers the classes of an image while `dlopen` loads it, and reads the class
structures then: they are in the guest image, which the library maps only after dyld has placed the first dylib and
relocated the slots that point into it. The first dylib has none of these lists. The registry is loaded after the
guest image is in place and before the guest's initializers run.

### The integer width of a method the SDK does not declare

The guest's methods reach the armv7 host through stubs (`xl_imp_<n>`) that the host runtime registers in its Objective-C
tables, so that a message sent by host code runs guest code. A stub has the host's calling convention, so it needs the
host's type of each parameter. For a method that an SDK header declares, the types are the header's (`NSInteger` is `int`
on armv7). For a method that no header declares the translator has only the guest's type encoding, and the arm64
encoding does not tell `Int`, `NSInteger` and `long` (all of them `q`, `Q` unsigned) from `Int64` and `long long`
(also `q`): the armv7 callers pass the first group in one register and the second in two (low word in `r3`, high word at
`[sp]`, no alignment to an even register on iOS).

A stub that reads two words where the caller passed one takes a high word from the caller's stack. It was the crash of
the real RecaptchaEnterprise SDK on the 4S: the Swift runtime of the app (armv7, `Int` is 32 bits) sends
`+newTaggedNSStringWithASCIIBytes_:length_:` to `__StringStorage`; the guest's `NSObject` category
(`createTaggedString(bytes:count:)`, the stub reads `count` as `q`) answers, and `CFStringCreateWithBytes` got
`0x<garbage>00000006` for a count of 6 (`argument 2 value … does not fit the host type`). A caller in the guest does not
pass through the stub: the guest finds the guest implementation itself.

The rule of `xlgen` (`HostScalar`) for a method with no SDK declaration takes the host type from the class that carries it:

- a category on a system class (any class the guest imports, `NSObject` included), a class that has a system class other than
  `NSObject` among its ancestors, and a Swift class (its name begins with `_Tt`) can be called by host code with the host's
  headers or the host's Swift. A top-level `q` is the host's `long`, `Q` the `unsigned long`, `^q` and `^Q` (not const) a
  pointer to one (an out slot, converted as for `NSInteger *`). The report line says so: `host IMP from guest type
  encoding Q24@0:8q16 (q/Q as 32-bit long: category on system class NSObject) as L12@0:4l8`.
- any other class (an Objective-C class of the guest that derives from `NSObject` alone, such as the protobuf runtime of
  the SDK) is reached by host code only through methods that an SDK header declares, so the guest's own 64-bit type stays:
  `q24@0:8q16` becomes `q16@0:4q8`. The 280 methods with a `q` or `Q` in that group in the report of drop8 include real
  `int64_t` and `uint64_t` parameters (`-[RCAx_GPBInt64Array valueAtIndex:]`, `-[RCAx_GPBUInt64Array addValue:]`,
  `-[RCAx_GPBCodedInputStream readInt64]`).

The limit: a method in the first group that takes a real `Int64`/`UInt64`/`long long` and that no header declares would be
read as one word. The encoding cannot tell them apart; the Swift symbol of the `@objc` thunk can. The methods of the
first group in the SDK image and its overlays (`libswiftCore`, `libswiftFoundation`; the 15 report lines of drop8), each read
from the mangled name of the thunk (`nm`, `xcrun swift-demangle`; the name of the `@objc` thunk ends in `To`):

| method | class that carries it | parameter or result | Swift type |
| --- | --- | --- | --- |
| `newTaggedNSStringWithASCIIBytes_:length_:` | category on `NSObject` (`createTaggedString(bytes:count:)`) | `count` | `Int` |
| `initWithBytes:length:` | `__NSSwiftData`, a subclass of `NSData` | `length` | `Int` |
| `insertObjects:count:atIndex:` | `_SwiftNSMutableArray` | `count`, `at` | `Int`, `Int` |
| `initWithObjects:forKeys:count:` | `__EmptyDictionarySingleton` | `count` | `Int` |
| `initWithObjects:forKeys:count:` | the generic Swift dictionary storage (same selector and encoding; its thunk has no symbol) | `count` | `Int` (the `NSDictionary` initializer's `NSUInteger`) |
| `getCString:maxLength:encoding:` | `__StringStorage`, `__SharedStringStorage` | `maxLength`, `encoding` | `Int`, `UInt` |
| `_fastUTF8StringContents:utf8Length:` | `__StringStorage`, `__SharedStringStorage` | `utf8Length` | `UnsafeMutablePointer<UInt>` |
| `retainCount` (class and instance), `_cfTypeID` | `_SwiftObject` | result | `NSUInteger`, `CFTypeID` (unsigned long; the thunks have no symbol, the Objective-C declarations decide) |
| `initWithAction:` | `RecaptchaAction` | `action` | `RecaptchaActionType`, an `@objc` enum with the default raw type `Int` (`init(action:)` in the symbol table) |
| `errorCode` | `RecaptchaError` | result | `RecaptchaErrorCode`, an `@objc` enum of raw type `Int` |
| `rcbxd:` | `RCbwz` | result | `Int` (`rcbxd([Int]) -> Int`) |

None of them takes an `Int64` or `UInt64`. A new image has to be checked the same way: translate it, take the lines of
`report.txt` that say `q/Q as 32-bit long`, find the guest address of each stub's `imp` in the manifest, and read the
symbol of the thunk.

A guest block that the host calls (a completion handler, `enumerateObjectsUsingBlock:`) and a guest method that the
host calls through the word trampoline of a Swift class (a method with no typed stub, only parameters of one word) have the
same ambiguity, and the same answer: a `q` is a host `NSInteger` of one word, a `Q` an `NSUInteger`. The word the host passes
is widened to the guest's register by its sign: `-5` is `-5`, the host's `NSNotFound` (`0x7fffffff`, `INT_MAX`) is the arm64
`NSNotFound` (`INT64_MAX`), `INT_MIN` is `INT64_MIN`; a `Q` is zero-extended and the host's `UINT_MAX` is `UINT64_MAX`. A
`q` result of the guest comes back as its low word, with `INT64_MAX` and `INT64_MIN` mapped to the host's `INT_MAX` and
`INT_MIN` and `UINT64_MAX` to `UINT_MAX`. The word used to be zero-extended whatever its sign: a block that took an
`NSInteger` got `4294967291` for `-5`. A block whose signature has an `i`, `s`, `c` or `B` is unchanged (the guest reads
the low bits of the register).

### A block that the host passes to a guest method that no header declares

The host reaches a guest Swift class's `@objc` method through a host IMP. For a method that an SDK header declares,
`xlgen` types every parameter, a block included (the header gives the block's parameter types). For a method that no
header declares (`+fetchClientWithSiteKey:completion:` and `-executeWithAction:completion:` of the real SDK: the report says
`generic host IMP, block parameter of a method the SDK does not declare`) the guest's encoding is `v32@0:8@16@?24`, which
does not say what the block takes. The host block does: a block that clang or the Swift compiler makes carries its
signature in its descriptor (`BLOCK_HAS_SIGNATURE`, for a Swift closure `v24@?0@8@"NSError"16`). So the runtime makes, for
such a method, a guest block that holds the host block (the same proxy as the typed one: a guest `Block_copy` of it works, the host
block is released when the guest block is) whose invoke function is one generic function that `xlgen` emits in every
translation (`xl_hblock_generic_invoke` and `xl_hblock_generic_descriptor` in `guest.m`). When the guest calls the block,
the runtime reads the host block's signature, converts each of up to four arguments by its kind (an object through
`xl_object_in`, a pointer, an integer of one word: a `q`/`Q` in a host block is a real 64-bit value and is refused) and
widens the result. A method with a `double`, `float` or structure parameter, a block result, or more than four
arguments after `self` and `_cmd` still stops with a message that names its selector and encoding when the host calls it:
`-executeWithAction:withTimeout:completion:` of the SDK has a `Double` and is one of them.

### The guest image (`recompiler/include/xl_guest_image.h`)

The loader, the runtime and `xlate` include one header, which is the format. All numbers are little-endian 32-bit words,
every address, size and offset is a multiple of the 16 KiB granule (the guest is arm64, its segments are 16 KiB
aligned; `xlate` refuses a segment that is not).

| Part | Layout |
|---|---|
| header (at the start of the section) | `magic` `XLGI` (`0x49474c58`), `version` (1), `low`, `high` (the range of the guest, `high` is the end of the last segment), `segment_count` |
| `segment_count` records, right after the header | `address`, `size` (in the guest), `offset` (of its bytes from the start of the section), `length` (bytes in the file: the segment without its zero tail, up to the granule), `protection` (`1` read, `2` write; what the segment has when the library is ready) |
| bytes | each segment's `length` bytes at its `offset`; a segment that is all zeros has `length` 0 |

The slots are not in the section. `xl_guest_slots` (`{address, value}` words, sorted by address) and `xl_guest_slot_count`
are host data of the dylib, because the `value` of a slot is the address of a symbol (a class, an `xl_objc_ro_*` structure,
`__CFConstantStringClassReference`, a system symbol the guest binds to) that dyld relocates when it loads the dylib. A guest
word that holds such an address is zero in the bytes. In a segment of the guest the Objective-C classes and protocols are
ordinary bytes at their own addresses, and the generated code refers to them by number.

### Load order

1. `xl_reserve` reads the header of the file (not the section in memory): refuses a wrong `magic` or `version`, takes
   `[low, high)` with `vm_allocate` at the fixed address and `VM_PROT_NONE`, and takes the size of the host part
   (the sum of the dylib's own segments) anywhere with `VM_PROT_NONE`. If the guest range is held it fails with the
   region that holds it, its range, what it is (an image's path, `malloc`, `stack`, a memory tag) and its size.
   It also refuses a library whose registry file (`<name>-classes.dylib` in the same folder) is not there.
2. `xl_load` gives the host reservation back and `dlopen`s the dylib: dyld takes the first hole that fits, which is the one just
   given back. It calls `xl_library_init`.
3. `xl_library_init` checks the header again (`magic`, `version`, that every segment is inside `[low, high)`, that every slot
   is inside it), checks that `[low, high)` is one untouched `VM_PROT_NONE` range (it writes nothing if it is not), then for
   each segment: `mmap(address, length, READ|WRITE, MAP_FIXED|MAP_PRIVATE)` of the file at the segment's `offset`, and
   `vm_protect` read-write for the zero tail. It writes every slot, applies the segment's `protection`, `dlopen`s the
   registry (libobjc registers the guest's classes, protocols and categories), runs the guest's initializers (once, behind a
   lock) and returns.

Pages of the guest that nothing touches stay clean file pages: they are not in the resident set and the system can drop them.

## Loader API (`recompiler/include/xl_loader.h`)

| Function | Does |
|---|---|
| `xl_reserve(path)` | reads the guest image's header from the file and takes the guest range and room for the host part, `VM_PROT_NONE` (the load order above) |
| `xl_load(path)` | reserves if that was not done, gives the host room back, `dlopen`s, calls `xl_library_init`; the library owns the guest range from then on |
| `xl_load_error()` | text of the last failure |
| `void *xl_find_class(const char *name)` | the Objective-C class (a `Class`, as a pointer) that the loaded library answers to for `name`, or `NULL`: before `xl_load` succeeded, for a `NULL` name, for a name the library has no class of. Calls the library's export `xl_library_class` (found with `dlsym` on the handle of `xl_load`) |

Statuses: `XL_LOAD_OK`, `XL_LOAD_BAD_IMAGE` (not an armv7 dylib, no guest image, a `magic` or `version` that is not read: the message says which, and
the version found; no registry next to the library), `XL_LOAD_RANGE_BUSY` (the guest range is held: the message names the holder; or the reservation is
not an untouched inaccessible range when the library attaches; or no hole of the host's size), `XL_LOAD_DLOPEN_FAILED` (the library or its registry; the message has dyld's text),
`XL_LOAD_MAP_FAILED` (`mmap` or `vm_protect` of the guest's segments failed). A status after the library's initialization has run is final: later
calls return it, and the guest range is given back.

The library reports `XL_LIBRARY_OK`, `XL_LIBRARY_BAD_FORMAT`, `XL_LIBRARY_NOT_RESERVED` or `XL_LIBRARY_MAP_FAILED` from
`xl_library_init` (`xl_guest_image.h`); the loader turns them into the statuses above. Called before `xl_load`
by a host that never reserved, `xl_library_init` answers `XL_LIBRARY_NOT_RESERVED` and maps nothing, and any entry of the
library aborts with "the guest image of the translated library is not attached".

### The class of a name (`xl_find_class`, `xl_library_class`, `objc_setHook_getClass`)

`NSClassFromString(@"RCFClient")` finds a class the library registered under that Objective-C name. It does not find a
Swift class by the name Swift gives it, `"Module.Class"` or the mangled name (`_TtC…`, `$s…`): a Swift class without an
`@objc(name)` is registered under its mangled Objective-C name, and iOS 6 has no `objc_setHook_getClass`, the call that
lets the Swift runtime (`libswiftCore`, iOS 12 and later) answer those names to `NSClassFromString`. The library
provides the call itself, as a bridge (`_objc_setHook_getClass` in `src/runtime/bridge-provides.txt`; the translation
report says `manual bridge xl_manual_objc_setHook_getClass`), so a guest `libswiftCore` installs its
`getObjCClassByMangledName` there. The runtime keeps the hook and asks it as Apple's libobjc does, after its own table
and only for a name the table does not have:

| Who asks | Order |
|---|---|
| the guest's `objc_getClass`, `objc_lookUpClass` and `NSClassFromString` | the registered name (with the `XLG.` prefix rule of the namespaced images), then the installed hook; the answer is the class's shadow |
| the host's `xl_find_class(name)`, through the library's `void *xl_library_class(const char *name)` | the same lookup (`objc_lookUpClass` semantics: the class is not initialized, no class handler) |
| the host's own `NSClassFromString` | the host's libobjc alone: it has no hook, so it does not find a Swift class by `"Module.Class"`; this is the reason for `xl_find_class` |

The first hook a guest installs gets, in `*outOldValue`, a guest function that answers `NO` (Apple's libobjc gives the
default there), so a hook can chain to the one before it. A hook that asks the lookup again from inside itself is not
called a second time on that thread. What the hook answers with is a guest `Class`; the runtime turns it into the host
class (`xl_class_in`) before the host sees it.

The signatures, which are the contract of a host that uses them (`recompiler/include/xl_loader.h`, and the library's
export):

```c
void *xl_find_class(const char *name);       /* loader (xl_loader.c): Class or NULL */
void *xl_library_class(const char *name);    /* export of the library, found with dlsym; the loader calls it */
```

`xl_find_class` is the call a host makes. `xl_library_class` is the library's end of it and is named here because the
list of exports is checked exactly. A host that built its own loader reads the class with `dlsym(handle,
"xl_library_class")`, with the handle of its `dlopen` of the library, after `xl_load` returned `XL_LOAD_OK`; the export
answers `NULL` before the library is ready.

The library check ([below](#the-check)) proves it on the claimed phone: the Objective-C variant installs a hook of its
own in the guest (`RCFHook`) and the Swift variant uses the guest's real `libswiftCore` hook (`xl_find_class("RCFixture.Client")`).

### The address-space map (`XL_LOADER_MAP`)

With `XL_LOADER_MAP` set in the environment to anything but `0`, the loader prints the process's virtual memory to
`stderr` (the runtime's crash handler to the crash log or `stderr`, where its other lines go) in the phases
`before-reserve` (before `xl_reserve` takes anything), `reserve` (after it), `load` (after `xl_load`; a failed call prints
`reserve-failed` or `load-failed`), and, once `xl_library_diagnostics` has installed the handlers, `crash` (a fatal
signal) and `fault` (a guest fault). A host that does not call `xl_library_diagnostics` gets the same handlers from
`xl_library_init` when the environment has `XL_CRASH` or the phone has the flag file `/private/var/revenant/xl-crash`:
a fatal signal then prints the host registers and frames and, from the translated thread's own state, the guest pc, the
registers `x0` to `x7` and the chain of guest frames, which says what guest code called the host function that
crashed. With the variable unset nothing is printed and no region is read. One line per
fact, fields separated by single spaces, addresses and sizes in hex:

| Line | Fields |
|---|---|
| `xl-map PHASE begin`, `xl-map PHASE end` | the walk of one phase |
| `xl-map PHASE region START END SIZE PROT/MAX SHARE TAG NAME` | one mapping from `vm_region_recurse_64` (submaps are entered): `PROT` and `MAX` as `rwx` with `-` for a missing bit, `SHARE` the share mode (`cow`, `private`, `empty`, `shared`, `true_shared`, `private_aliased`, `shared_aliased`), `TAG` the `user_tag` in decimal, `NAME` the path of the image whose segment overlaps it, else `malloc`, `malloc small`, `malloc large`, `malloc tiny` or `stack`, else `-` |
| `xl-map PHASE hole START END SIZE` | a free range of 1 MB or more between two mappings, counted up to `0x40000000` (`XL_VM_MAP_USER_END`), where a 4S process's address space ends; a range above that is not free, it is not there |
| `xl-map PHASE summary mapped=… free=… largest_start=… largest_size=… free_below_0x30000000=…` | totals over the walk (the holes of every size count in `free`) |

Besides the phases above the loader prints `before-dlopen` (after `xl_load` gave the host's room back, right before `dlopen`:
its `largest_size` is the hole dyld has to choose from) and, after `reserve`, one line
`xl-map reserve config host_reserve=0|1 host_size=… host_low=… guest_low=… guest_high=…`.

The code is one header, `include/xl_vm_map.h`, that the loader and the runtime both include.

### `XL_LOG` (the runtime's files on the phone)

A translated process writes nothing under `/private/var/revenant` by default. `XL_LOG` in the environment, or the file
`/private/var/revenant/xl-log` (for an application that SpringBoard launches, which has no environment of its own),
turns on the files that every process used to append to: `xlate-crash.log` (the crash handler and `xl_fault`),
`xl-exit.log` (each exit and each terminating signal, with the guest frames), `xlate-exception.log` (an uncaught
exception), `xl-missing.log` (a selector the null object answered), `xlate-variant-miss.log` and `xlate-nobridge.log`.
A file bigger than 1 MiB is emptied when the next process opens it, so none of them grows without bound. With
the switch off the crash handler prints to stderr, which is where the test below reads it. The files that had a switch
of their own (`xl-trace`, whose ARC lines are now events of the journal below, `xl-collect`, `xl-shadow-log`, `xl-trace-errno`, `xl-sysctl-trace` (a line of `xl-sysctl.log` for each of the first 50 `sysctl`/`sysctlbyname` calls and for every thousandth after them: the name, the class the bridge translates it as, the length before and after, the result and `errno`), `xl-memlog`, `xl-exp-guide-superview`,
`xl-stubs.txt`, `XL_INIT_TRACE`) still need it and are not limited by `XL_LOG`. The library test crashes the host with the
switch (the crash handler's file has the `xlate: signal 6` lines) and without it (the lines are on stderr and the file
is not created).

`xl-trace` is a tool for diagnosing the host, not a way to observe the guest unchanged: it writes a line to
`xlate-msgtrace.log` for every message the guest sends to a host object, and for each one probes the receiver and its
class with two `write` calls to `/dev/null`, so it slows the guest by two system calls and one write per message and
shifts every race and every timing loop (a run with it can pass a place that an untraced run does not, or the other
way round). The flag file is read once, at the first message of the process, so it has to exist before the process
starts; removing it later does not stop a running process. The `rc=` field (the receiver's retain count) is off by
default, because `CFGetRetainCount` sends `retainCount` to every receiver and so is itself a call that can fault on an
object that is being freed; `/private/var/revenant/xl-trace-rc` next to `xl-trace` turns it on. A crash that appears
only in a traced run is not a finding about the guest until it also appears without `xl-trace` (with `xl-crash`, which
prints the host registers and the guest frames and does not change the timing).

`xl-stats` (the flag file `/private/var/revenant/xl-stats`, or `XL_STATS` in the environment; read once, so it has to exist
before the process starts) measures what the bridge costs without a line per message. For every thread that starts or
ends it prints `xlate: threads: created|ended (guest stack N KiB, host stack M KiB): L live, C created, E ended, S KiB of
guest stack live`. Each message that the guest sends to a host object is timed from the entry of `xl_h_objc_msgSend` to the
decision (the routing); a message sent dynamically is timed again across the host call, and after every 20,000th dynamic
message the process prints `xlate: messages: N in all, D of them dynamic; routing R us in all, host call H us in the dynamic
ones (A us each)`, followed by the four dynamic messages (class and selector) that took the most time, with their counts.
It costs two `mach_absolute_time` calls and one lock per message while it is on, and nothing while it is off. It
exists to answer one question that a log cannot, because `XL_LOG` slows the loop it measures: how long one message of a
guest loop takes, and which message it is.

The `xlate: no bridge for -[Class selector]` lines on stderr, with the receiver and the guest frames, belong to the same
switch. They say that a guest message to a host object found no generated bridge, which is not a failure: the message
is then sent through the host method's own type encoding (`xl_dynamic_send`), whose arguments and result may be
objects, classes, selectors, pointers and integers of up to 64 bits, in at most eight arguments counting the receiver
and the selector. A message whose method has a structure, a `float` or a `double` among them, or more arguments, stops
with `xlate: message without a bridge (argument type)` (or `return type`, `stack-passed arguments`) followed by the
class, the selector and the encoding, with the switch on or off.

The lines are written in full (the line, the receiver and the guest registers and frames) for the first three messages of
each class and selector, and the first one also adds the selector to `xlate-nobridge.log`; after that one line says
`N messages so far` for every 10,000th. A guest loop that sends one selector thousands of times (the SDK compares two arrays
of bridged strings with `String ==`, which sends `-[NSString _fastCStringContents:]` twice for each scalar, 18,322 messages in
one run on the 4S) wrote 18.8 MB of the full lines before this limit and kept the process busy for about 20 s; the loop is
finite (the same chain of guest return addresses 9,161 times for each of the two call sites) and the time was the writing. The `xl-collect` flag file is read once, at the first message that has no bridge.

Every table of the runtime that a thread changes after the library has loaded (the proxy tables, the IMP slots, the block
wrappers, the shadow-class tables, the guest IMP cache, the counts above and the variant cache) is read and written under a
lock. The variant cache (`xl_variant_cache`, the guest variant chosen for a host IMP by its type encoding) was the one that
was not: threads of the SDK that sent their first message to the same host method together ran `CFDictionarySetValue` on one
`CFMutableDictionary`, and 3 of the first 30 launches of the real SDK in separate processes on the 4S aborted with
`malloc: *** error for object …: double free` inside it, each with the same host frames (`xl_h_objc_msgSend`, `xl_route`,
`xl_bridge_for`) and the same guest return address in the Foundation image.

### `XL_POOLCHECK` (the journal of object lifetimes)

`XL_POOLCHECK` in the environment, or the file `/private/var/revenant/xl-poolcheck`, turns on a journal of the events that decide
whether an object is released twice or too early: `proxy-new`, `proxy-live` (a proxy that already stood for the guest object),
`proxy-retain`, `proxy-release` and `proxy-autorelease` (with the retain count and the caller's address), `proxy-dealloc`
and `proxy-free` (with the block's size), the `retain`, `release` and `autorelease` the guest sends through the bridge, `pool-push`,
`pool-pop`, the entries of the pool that a `pool-pop` drains (`pool-entry`, read from the pages of the autorelease pool of iOS 6: a
token whose page has not the pool's magic is `pool-pop-bad-token`), `alloc-object`, `create-instance` and `object-dispose`. The events go into a
ring of 262,144 entries (about 7 MiB of zero pages that nothing touches while the switch is off). The ring is written to stderr and to
`/private/var/revenant/xl-journal.log` when the process gets `SIGABRT`, `SIGSEGV` or `SIGBUS` (the handler runs once, then the signal
takes its way as before): a header line with the thread and the counts, the last 3,000 events, and every event of the objects that the last
`pool-pop` of the crashing thread drained, one line each: `xlate-journal: #SEQUENCE t=THREAD OP POINTER extra=… caller=… isa=… CLASS`, ended
by `xlate-journal: end`. `xl_journal_dump(why)` writes the same dump on request.

With the switch off the cost is a flag test: the proxy classes keep `NSObject`'s memory methods (the journal's versions are installed
only when the switch is on, when a proxy class is made), and each journal call tests the flag first and does nothing else. The code
is `src/runtime/journal.m`; `recompiler/tests/proxytable` runs it on the Mac (a run without the switch writes no `xlate-journal` line; a
run with it has the proxy events and the end line). The first use found the drop16 double release of a result that a guest method returns at
+1 (`xl_proxy_owned`, `docs/explanation/recompiler/how-it-works.md`); the pool pages are read only on the device (`vm_read_overwrite`, the layout of
iOS 6's 32-bit `AutoreleasePoolPage`).

### `XL_LOADER_HOST_RESERVE=0` (diagnostics)

A diagnostic switch for comparing placements, not a mode to ship: with `XL_LOADER_HOST_RESERVE=0` in the environment
`xl_reserve` takes only the guest range (at its fixed address) and leaves the room for the host part to `dlopen` at
`xl_load`, which then takes the first hole that fits when it runs. Unset, or any other value, nothing changes. The
risk of the switch is a `dlopen` that finds no hole of the host part's size when `xl_load` runs late in the process's life
(`XL_LOAD_DLOPEN_FAILED`, with dyld's text); `before-dlopen` and its `largest_size` against `host_size` of the config line
measure whether one is there. The library test runs the host with the switch and `XL_LOADER_MAP=1` and expects the same
`ok` names, a config line with `host_reserve=0` and `host_low=0x0`, no inaccessible region of the host part's size after
`xl_reserve`, the guest range still held, and the library's image after `xl_load`.

## The guest stack of a thread

A thread that enters the guest maps its own stack: 16 MiB for the main thread (`XL_GUEST_STACK_MAIN`) and, for every other,
twice the stack the thread itself has (`pthread_get_stacksize_np`: 512 KiB for a libdispatch worker, so 1 MiB), rounded up
to 64 KiB, at least 256 KiB and at most 4 MiB (`XL_GUEST_STACK_THREAD`), in `src/runtime/runtime.c` and
`xl_stack_first` in `xl_tsd_guard.h`. The host stack bounds the depth of a guest call chain first, because every lifted call
is a host call, so twice it leaves a margin. Before this rule every worker took 4 MiB: in a 10-execute run of the Telegram
app (38 threads, 1.05 GB virtual) three mappings failed with errno 12 and the last stack was 1 MiB anyway. The mapping is
virtual and touched on use. When it fails
the runtime says so on stderr (`xlate: the guest stack of a thread could not be mapped with N bytes (errno E), trying half`)
and tries half the size, down to 256 KiB (`XL_GUEST_STACK_FLOOR`); below that the thread stops with a message that names
the call. The lowest page of each stack is `PROT_NONE`, a guard page. A `SIGSEGV` or `SIGBUS` whose address is in that
page prints, before the crash dump, `xlate: the guest stack of this thread overflowed: it holds N bytes (0x… to 0x…) and the
fault is in its guard page; …`, so a stack overflow is told from a bad pointer. The mapping, the halving and the guard are one
function, `xl_stack_map` in `src/runtime/xl_tsd_guard.h`, which the `tsdguard` check runs on the host with a mapper that
fails above a limit and a mapper that always fails.

The stack, the thread-specific page and the state of a thread are released together when the thread ends: they hang on a
`pthread_key_t` whose destructor (`xl_state_destroy`) unmaps the stack, unmaps the page and frees the state, so a thread
that came and went (an `NSURLSession` or `WebThread` worker, a Dispatch worker that the system retires) leaves nothing
behind. A guest call that runs on the thread after the destructor, from the destructor of another key, makes a new state
that the next round of destructors (the system runs up to four) releases in turn. The runtime counts the threads it set up
(`created`, `ended`, the guest stack of the live ones); the count is printed with every stack that had to be halved and with
the failure of a thread's setup, and for every thread that starts or ends under the `xl-stats` flag (below), where
`created - ended` is the number of live threads, to be compared with the thread count of the process: a difference that
grows with each `execute` would be a leak.

The reason for the sizes is the address space of a 32-bit process of iOS 6, about 768 MB below the shared cache, which the
lifted library, the guest arena, the heap and the stacks of every worker share. The real SDK runs more than a dozen threads
(a crash report of the 4S numbers 18), and each takes a stack, so the size of a worker's stack is paid that many times.

## `sysctl` and `sysctlbyname`

`sysctl` and `sysctlbyname` are manual bridges (`src/runtime/sysctl_bridge.m`): the guest's structures are not the host's, so a
value is translated by the layout of its name and not by a size. The kind of a name comes from a table by number and, for
every other name, from the format string that the kernel itself reports (`sysctl` with `{0, 4, mib…}`, the format of an
object), cached for 64 names:

| name | host value | guest value | what the bridge does |
| --- | --- | --- | --- |
| `kern.boottime` | `timeval`, 8 bytes | `timeval`, 16 bytes | `tv_sec` widened to 64 bits, `tv_usec` to 32 plus padding |
| `vm.loadavg` (`S,loadavg`) | `loadavg`, 16 bytes | 24 bytes | the three `fixpt_t` and the scale, widened |
| `kern.proc.all`, `.pid`, `.pgrp`, `.session`, `.tty`, `.uid`, `.ruid`, `.lcid` | `kinfo_proc`, 492 bytes | 648 bytes | every field converted (`extern_proc` 296 bytes, `eproc` 352; pointers zero-extended); the whole list is fetched on the host and `ENOMEM` with length 0 is decided there, because the iOS 6 kernel answers a small buffer with success and no bytes |
| `S,timeval` of another name | 8 bytes | 16 bytes | as `kern.boottime` |
| a format `L` or `LU` (`long`, `unsigned long`) | 4 bytes | 8 bytes | widened, signed or unsigned |
| `S,clockinfo`, `S,xsw_usage`, the `CTL_SYSCTL` tree, `kern.procargs`, `kern.procargs2`, `CTL_NET` `PF_ROUTE` with `NET_RT_DUMP` or `NET_RT_FLAGS` (any other `PF_ROUTE` name is the last row) | the same in both | the same | passed through |
| an `int`, a quad, a string or a node (`hw.ncpu`, `hw.memsize`, `hw.machine`, `kern.ostype`, `kern.osversion`, `kern.hostname`, `kern.argmax`, …) | the same in both | the same | passed through |
| a name that does not exist | | | the host's own error (`ENOENT`), returned as it is |
| any other structure that exists | | | stderr `xlate: sysctl NAME exists on this system but the bridge has no arm64 layout for its value …` and `ENOTSUP` |

A buffer that is too small for a translated value gives `ENOMEM` and a length of 0, as the 64-bit kernel does; a size probe
(no buffer) gives the guest size. A write (`newp`) to a translated name gives `ENOTSUP`. The class of failure that this
replaces: the guest's `_revenant_clock_gettime` (in `libc++.1` and `libswift_Concurrency`) loops until two reads of
`kern.boottime` agree; the 8-byte answer left the second half of the 16-byte buffer as it was, they never agreed, and four
threads spun at full speed. `xl-sysctl-trace` (above) writes a line for each of the first 50 calls and every thousandth after
them. `hostbridges` checks the classes of the table against the Mac's answers (`recompiler/tests/data/hostbridges/expected.txt`)
and on the phone, and `sysctl-unmapped` the last row.

## What the phone's dyld and kernel do

Measured on iOS 6.1.3, armv7:

- `dlopen` of a dylib linked at address 0 slides it into the first hole that fits (`vm_allocate` anywhere): the range that
  `xl_reserve` took and `xl_load` gave back, in the same call.
- On the 4S, `MAP_FIXED|MAP_PRIVATE` of the pages of a file over a `VM_PROT_NONE` `vm_allocate` reservation works: the
  mapping replaces the reservation exactly (the rest of the reservation stays `VM_PROT_NONE`), the bytes are the file's, a
  write copies the page and does not change the file, `vm_protect` to read-only makes a write fault, `vm_protect` to
  read-write over the rest gives zero pages. The probe is 25 checks, all `ok` (small dylib with a `__XGUEST,__image` section at
  file offset `0x4000`).
- A 119 MB dylib prints `dyld: F_ADDFILESIGS failed ... errno=7` (its signature is 1.5 MB) and loads.
- Mapped code that is never run costs about no resident memory.
- A library whose install name is `@executable_path/<leaf>` is found by dyld with no environment: the registry, which depends
  on the library by that name, loads when the host is started without `DYLD_FALLBACK_LIBRARY_PATH` (12 checks in each of 10
  launches and the 4 controls, `XL_LIBRARY_INSTALL_NAME=executable` of the check). A name `@rpath/<leaf>` is found only through
  that variable.

## The check

`./xmakew l -P . <absolute path of>/recompiler/tests/library/check.lua <out> [objc|swift] [--host-only]` builds a fixture
library (`RCFClient`, `RCFToken`, and a category `RCFClient (RCFExtra)`; Objective-C or Swift) and a host app
(`xl-library-host`). The path of the script has to be absolute (the include list it writes holds paths relative to it
otherwise). The fixture is linked with `-no_objc_category_merging`: ld64 merges a category into its class when both are in
one dylib, which leaves the category list empty and the check of the registry with nothing to prove.

The host part of the check is the layout of the output (no `__X<n>` segment, `__LINKEDIT` and `__XGUEST` present, the header
(`magic`, `version`, a range that is granule-aligned and not below `XL_BASE`), exports that are the three entry points
(`_xl_library_class`, `_xl_library_diagnostics`, `_xl_library_init`) and the `_xl_objc_category_<n>` names and nothing else, a registry with only the `__objc_*` sections, no code and no exports). On the
claimed phone the check copies the library and its registry into one folder, runs four negative controls, then grows the
host to `XL_LIBRARY_RESIDENT_MB` (85) `XL_LIBRARY_LAUNCHES` times (1) and expects these names `ok`, then `done` and `exit=0`
in every launch:

| Control | Host argument | Proves |
|---|---|---|
| a range another mapping holds | `@LOW-HIGH` over the guest range, `--expect=busy` | `xl_reserve` refuses, the message names the holder, the occupant's pages are untouched (`occupant.intact`), the class is not registered |
| a guest image format this loader does not read | a copy of the library whose `version` word is 2, `--expect=image` | `xl_reserve` refuses with the version found, nothing is registered |
| a library whose registry is not next to it | the library alone in a folder, `--expect=registry` | `xl_reserve` refuses and names the missing file, no crash |
| an init without a reservation, over a mapping with data | `+LOW-HIGH` (a read-write mapping with a sentinel), `--expect=direct` | `dlopen` of the library and the call of `xl_library_init` without `xl_reserve` is refused, and the occupant's data is intact |

After the launches the check runs the host with `XL_LOADER_MAP=1` and reads the map: the phases `before-reserve`, `reserve`,
`before-dlopen` and `load` each have `begin`, `end`, a `summary`, at least ten regions in ascending order and a hole of 1 MB or more
(at `before-dlopen` one of the host part's size, and the config line names that size);
the guest range has no mapping before `xl_reserve`, is covered by `---` regions after it, together with one `---` region
of the host part's size outside it, and has a readable segment after `xl_load`, which is also the first map that names
the library's own image. Then the host aborts after `xl_library_diagnostics` (`--abort`): with the variable set the crash
handler's output has the `crash` map and the guest range is readable in it; with it unset the handler prints its
`xlate: signal 6` lines and no `xl-map` line, and so do the launches above.

| Name | Proves |
|---|---|
| `reserve`, `load` | the guest range was taken at the guest's own addresses, the library loaded wherever dyld put it |
| `class`, `create` | the public class is found by name and made |
| `methods`, `describe` | calls with `NSInteger` arguments and results, state kept between calls |
| `bundle`, `bundle.path` | the library sees the host's `NSBundle.mainBundle` (same object, same path) |
| `token` | an object result of a public method |
| `category` | a method that a category of the guest adds to a guest class is found (the category is in the registry) |
| `completion`, `completion.thread` | a host block called from the library, on a thread that is not the main one |
| `find.unloaded` | negative control: `xl_find_class` answers `NULL` after `xl_reserve` and before `xl_load` |
| `find.exact` | `xl_find_class("RCFClient")` is the class `NSClassFromString` finds |
| `find.unknown` | negative control: a name that no class and no hook answers (`"RCFixture.Nothing"`) and a `NULL` name give `NULL` |
| `find.thread` | `xl_find_class` from a global-queue thread that is not the one that loaded the library finds the class that needs the hook (`"RCFixture.Hooked"`, `"RCFixture.Client"` in the Swift variant): the hook runs on the thread's own guest stack and state |
| `find.before`, `hook.absent` (Objective-C variant) | negative control: before the guest installs a hook, `"RCFixture.Hooked"` is not found, by `xl_find_class` or by the guest's `objc_getClass`, `objc_lookUpClass` and `NSClassFromString` |
| `hook.old`, `hook.guest`, `hook.exact`, `hook.unknown` (Objective-C variant) | the guest installs a hook (`objc_setHook_getClass`) that answers `"RCFixture.Hooked"` with its class `RCFHooked`: `*outOldValue` is a function that answers `NO`; the guest's three lookups now find the class; a registered name (`RCFClient`, `RCFHooked`) does not call the hook; two unknown names call it twice and stay `Nil` |
| `find.hook` (Objective-C variant) | `xl_find_class("RCFixture.Hooked")` is `RCFHooked`, and the host's own `NSClassFromString(@"RCFixture.Hooked")` is still `Nil` |

The `swift` variant builds the host with Swift code of its own (`hostswift.swift`, armv7, iOS 6.0) and its own
`libswiftCore`, and expects six names more. The host's Swift makes a struct boxed as `AnyObject`, an `[Any]` and a
`String`; `host.m` keeps the class of each and the class of every name in the host's `libswiftCore`:

| Name | Proves |
|---|---|
| `host.bridge.before` | before the library loads, the three are objects that are not of the namespace |
| `host.names` | after `xl_load`, every name of the host runtime answers with the host's class |
| `names.disjoint` | the registry registered classes (the host takes the classes of the library's image and of its registry), and none has the name of a class of the host runtime |
| `host.bridge.after` | after the calls, the three are the same classes with the same contents, and the names still hold |
| `find.swift` | the guest's own `libswiftCore` installed its hook through the bridge: `xl_find_class("RCFixture.Client")` is the class that `NSClassFromString(@"RCFClient")` finds (the Swift name of a class that has an `@objc(RCFClient)` name) |
| `block.generic` | the host sends a private `@objc` method of the Swift class (`probeWithValue:completion:`, in no header) `5` and `-5` with a block `^(id<RCFToken>, NSError *)`: the guest calls the block synchronously with a token of the value, and the host checks `7051` and `6951`; the argument is an `Int` (`q`), so the negative one proves its sign too. A runtime without the generic block bridge stops the host with `the guest method probeWithValue:completion: … takes a block and the translation generated no typed host wrapper for it` |
| `find.host` | negative control: the host's `NSClassFromString(@"RCFixture.Client")` is `Nil` |

| Variable | Meaning |
|---|---|
| `XL_LIBRARY_HOST_RUNTIME` | folder on the phone with the host's runtime and overlays (Telegram13's `Frameworks`); unset: the package's armv7 `libswiftCore`, `libc++` and `libc++abi` are copied next to the host |
| `XL_LIBRARY_HOST_BRIDGING` | the host's Swift imports Foundation, so the `[Any]` and the `String` cross as `NSArray` and `NSString` and their contents are checked; needs a runtime folder with a Foundation overlay iOS 6 can load |
| `XL_LIBRARY_RESIDENT_MB` | resident size the host grows to before it loads the library (85) |

iOS 6.1.3 has no `@rpath` in dyld: a library named `@rpath/libswiftCore.dylib` is found through
`DYLD_FALLBACK_LIBRARY_PATH` by its leaf name, which is how the check starts the host. The package's
`libswiftFoundation` needs `NSDimension`, which iOS 6 lacks, and Telegram's patched overlay does not, hence the two
runtime sources. Without the Foundation overlay Swift boxes an array and a string as `__SwiftValue`, and the check
compares the classes only.

## Measurements

The host grows its heap with 1 MB `malloc` chunks until `task_info` reports 85 MB resident (87 MB counting the frameworks).
`host.m` calls `xl_reserve` first, as an app does from a constructor, so the first row already holds the reservation (the guest
range and the room for the host part). Sizes are K; each cell is the lowest and the highest of 40 launches on the 4S
(iOS 6.1.3), the check of the same commit, `XL_BASE` `0x10000000`.

| Step | Objective-C variant (library 312 KB) | Swift variant (library 162.1 MB, guest libswiftCore, libc++, libc++abi) |
|---|---|---|
| host with the reservation, resident / virtual | 87,340-87,360 / 361,680 | 87,912-87,932 / 536,496 |
| after `xl_reserve` returned | 87,340-87,360 / 361,680 | 88,316-88,344 / 536,496 |
| after `xl_load` | 87,448-87,464 / 378,120 | 90,156-90,176 / 552,944 |
| after the calls | 87,752-87,772 / 378,120 | 92,148-92,172 / 552,944 |
| after the background call | 87,804-87,852 / 395,544-404,760, 2 threads | 92,300-92,368 / 563,276-580,708, 3 to 5 threads |

The Swift variant costs 4.4 MB of resident memory with the first calls done, though its file is 162 MB: only the pages
the run touches become resident, and mapped pages that are never run cost nothing. The threads are the host's main
thread and the workers that `performSelector(inBackground:)` and Dispatch started.

The address map of the Swift variant: the guest image `0x10000000` to `0x10910000` (10 segments, 9.1 MB: the guest
libswiftCore's text is `0x4c4000` at `0x10100000`, its data at `0x105c4000`; 6,438,912 bytes of it are in the library, the zero tails
are not), and a host part that dyld places in a hole of 162 MB (`__TEXT` 104 MiB). Before this layout the host part was
fixed too, at `0x21000000` to `0x2ccd4000` with the guest after it, which is what failed in 3 of 20 launches of Telegram13.

In the 40 launches of the Swift variant the start of the malloc heap was `0x1c500000` 8 times, `0x1cd00000` 7, `0x1d500000` 3,
`0x1e500000` 8, `0x1ed00000` 5, `0x1f500000` 6 and `0x1fd00000` 3 times (and in the 40 of the Objective-C variant at
85 MB all eight starts, `0x1fd00000` 5 times; in the 40 at 22 MB all eight, 6 times): the library loaded in every one. With the
ten launches of the first full check, 130 launches of the host were made without a refusal of the reservation, and
the controls (a held range, a format this loader does not read, a registry that is missing, an init without a
reservation) refused as they must, in every run.

Where the heap, the stack and the images of an app sit, and why, is in [the next section](#the-address-space-of-a-host-on-the-4s).

### The address space of a host on the 4S

iOS 6.1.3, armv7, measured with a probe injected through `DYLD_INSERT_LIBRARIES` into 20 launches of Telegram13 (pass68, 282
images, no taps) and with a console tool that prints where its first `malloc` landed, 400 launches. The probe lists every
region (`vm_region_recurse_64`: range, protection, `user_tag`) when its constructor runs, which is the first code of the
process after libSystem, and again when the library's reservation is asked for; it also logs every `mmap` and `vm_allocate`
that lands between `0x10000000` and `0x30000000` with the frames of its caller.

| Zone | Where | Notes |
|---|---|---|
| images and first-fit mappings | `0x00078000` up to `0x10ebe000`-`0x110bd000` | Telegram13's executable and frameworks (271 MB). The executable slides by up to 1 MB; the frontier moved by 2 MB between the 20 launches. Every `mmap` that is not a malloc region (images, `fd=-1` anonymous mappings of 128 KB and less, file maps) takes the lowest hole that fits |
| free | up to `0x1c500000` | 180 MB at the frontier above |
| malloc heap | one run of tiny (`user_tag` 7, 1 MB) and small (tag 2, 8 MB) regions from a random start | the start is `0x1c500000 + k * 8 MB`, `k` 0 to 7, each value in about one launch of eight: 53, 43, 52, 41, 50, 57, 55 and 48 of 399 console launches, and 4, 1, 1, 4, 2, 4, 1, 3 of the 20 of Telegram13. The regions follow each other upwards from there: the allocator asks for the address after its last region and the kernel gives the next free hole at or above it. In 1 launch of 400 the heap was in the lowest hole (`0x00100000`) instead |
| heap size | 19 MB before the first initializer, 21 to 22 MB when `xl_reserve` runs | dyld's own allocations while it maps the images account for the 19 MB; the initializers of the frameworks add 2 to 3 MB |
| free | from the top of the heap (at most `0x21300000` at `xl_reserve`) to the stack | 233 MB at that heap top |
| stack | top `0x2fe00000`, bottom `0x2fc02000` or higher | the main thread's 1 MB stack plus a random pad of up to 2 MB |
| dyld, shared cache | `0x2fe00000` and above | the shared region `0x30000000` to `0x40000000` is the kernel's |
| end of the address space | `0x40000000` | the process's user addresses end here, 1 GB in all: its own `0x00001000` to `0x30000000` (768 MB) and the kernel's shared region of 256 MB above it (the dyld cache, about 239 MB, and its submap), which the app cannot map into or allocate in. Measured on the 4S by the Telegram13 session (`vm_region` and `vm_allocate` probes): there is no free space above the cache |

When an allocation lands on a reserved range the allocator goes on above it, and once its hint is used up the new
regions go to the lowest holes, which is how a process with a large reservation runs on.

What this means for a range that must be at a fixed address:

- No constructor is early enough to be ahead of the heap: the first initializer already finds 19 MB of it, and the 2 to 3 MB
  between that and `xl_reserve` are of no consequence. The heap's start is the random part, and it is a part of the
  platform, not of the app: a console tool on the same phone has the same eight starts.
- A fixed range that overlaps `0x1c500000` to `0x21300000` fails in one launch of eight. The first design of library mode
  was one such range: the host code and the guest together, 198 MB from `0x21000000` for the 162 MB Swift library. It
  failed 3 of 20 launches of Telegram13 (all of the start `0x1fd00000`), and it fits neither of the free zones (180 MB
  below the heap, 233 MB between the heap and the stack) once the margins of both sides are taken.
- A range below `0x1c500000` is clear of the heap in every launch, and clear of the images by `0x1c500000` minus their frontier.

So the library has two parts that are placed differently. Only the guest image has to be at fixed addresses, because the
guest's pointers are absolute: it is 9.1 MB for the Swift library (`0x10000000` to `0x10910000`). The host part, which is
all the rest of the 162 MB, is linked at address 0 and dyld puts it in whatever hole is large enough (104 MiB of `__TEXT` in
the Swift variant): there are about 410 MB of holes in the two free zones, and it does not matter which one is taken.

### Choosing `XL_BASE`

The guest range `[XL_BASE, XL_BASE + guest size)` has to be inside the part of the first free zone that no launch of the
host app touches:

```
frontier + 64 MiB  <=  XL_BASE  and  XL_BASE + guest size  <=  0x1c500000 - 16 MiB
```

where `frontier` is the highest end of an image of the host app (the measured maximum for Telegram13 is `0x110bd000`, from
20 launches; it moves by about 2 MB between launches, and a changed set of frameworks moves it more). For Telegram13 that
is `[0x150bd000, 0x1b500000)`, 100 MB, and `XL_BASE=0x18000000` leaves 53 MiB for the guest above the base (the Swift
library's guest is 9.1 MB) and 47 MiB below it. The default `0x10000000` is in the middle of Telegram13's images and is
for a host that is not Telegram13. The rule is for the person who builds the drop; whatever the base, a host whose images
or heap hold the range gets `XL_LOAD_RANGE_BUSY` from `xl_reserve` with the name of the holder, never a crash.
The check (`recompiler/tests/library/host.m`) calls `xl_reserve` before it grows its heap, as an app does from a
constructor.

### A host that has its own Swift runtime

The Telegram13 frameworks include an armv7 `libswiftCore.dylib` (7.26 MB) and a patched Foundation overlay. A host with a
Swift runtime and Swift code of its own has classes of the same names as the guest runtime (`__SwiftValue`,
`_TtCs12_SwiftObject`, `__SwiftNativeNSArrayBase`, the array and string storage classes). Without a namespace the
Objective-C runtime printed 31 "Class X is implemented in both .../libswiftCore.dylib and ??. One of the two will be used.
Which one is undefined." warnings when the library loaded, kept either class of a pair, and the shadow of a guest class
whose name the host had (the first one met was `_TtCs27_KeyedEncodingContainerBase`) could not be made.

`XL_NAMESPACE` (default `XLG.`, [why](../../explanation/recompiler/library-mode.md)) registers the guest runtime and the
overlays under the prefix, so the host keeps its names and a clash is the exception:

- the translator writes `XLG.<name>` into the class of every guest image but the first, and three tables into the
  generated code: `xl_namespace_prefix`, `xl_namespaced_classes` (the namespaced Swift classes by guest address),
  `xl_namespace_modules` (the modules whose classes the runtime may make later);
- `xl_build_shadow` registers the shadow of a moved Swift class under the prefix when the class is in the first table
  or its mangled name is in a namespaced module (a generic instantiation the guest runtime made); a class that still
  clashes is registered under `<name>@<guest address>`;
- `objc_getClass`, `objc_lookUpClass` and `class_getName` are manual bridges: a name is looked up under the prefix
  first, a name of a namespaced module only there, and the name the guest gets back has no prefix. They are bridged in an
  executable too; with no prefix they pass the call through.

Measured on the 4S, Swift variant, 40 launches: 15 of 15 `ok` in each (the 11 of the check and the 4 of the Swift
host), no "implemented in both" line. The rows below were measured on the first design (a fixed range at
`XL_BASE=0x2c000000`) and were not repeated with the host's Swift runtime from Telegram13 on the new layout; the second
row is the new layout with the package's runtime (the table above has its counts).

| Host | Resident K: host, loaded, called, end | Virtual | Threads |
|---|---|---|---|
| Telegram13's `libswiftCore` and Foundation overlay, bridging on (`XL_LIBRARY_HOST_BRIDGING`) | 88,000, 90,600, 92,420, 92,504 | about 575 MB | 5 |
| the package's armv7 runtime next to the host (new layout, 40 launches) | 87,912-87,932, 90,156-90,176, 92,148-92,172, 92,300-92,368 | 563 to 581 MB | 3 to 5 |

The host's Swift is the same before and after the library loads: 42 classes of its runtime answer by name with the same
objects, the library registers 33 classes (31 through its registry, 2 that the library itself makes) and none has a name of the host runtime, and the box, the `[Any]` and the
`String` that the host's Swift makes are the same classes with the same contents. The Objective-C variant is 11 of 11.

Not covered: protocols are not namespaced (`objc_getProtocol` is not bridged); `NSClassFromString` and
`NSStringFromClass` are not bridged, so a guest that goes through them meets the prefixed names; the secondary guest
images of an SDK (not the runtime) are namespaced like the runtime, so a host reaches by name only the classes of the
first image.

## Dead-strip and lazy loading

Not built; only measured and analysed.

- `xlate` lifts every function in `LC_FUNCTION_STARTS`, so the 119 MB of the Swift variant is almost all the lifted
  `libswiftCore`.
- The size on the phone is not in the resident set (see the table): pages that are never touched are never read.
  A strip would shrink the file, the install size and the address window (104 MiB of host `__TEXT` in the Swift variant),
  which matters for where the library can be placed (see the Telegram map).
- A strip by reachability from the public classes of the SDK is not trivial: Swift metadata refers to code and to other
  metadata by relative pointers, conformances are found by a runtime scan of a section, and protocol witness tables
  and the Objective-C runtime reach functions by selector. A safe reachability needs the word-by-word scan of data for
  relative references; an unsafe one fails at run time with a trap in a function that was stripped.
- Lazy loading (lifting a function when first called) needs the compiler on the phone and is not planned.

## C++ exceptions from guest code

Objective-C and C++ exceptions work in a library as they do in an executable: `@throw` in a guest frame, an `NSException`
the host raises, `@catch` of a guest subclass, of `NSException` and of `id`, `@finally`, and a C++ `throw` in guest code
with `catch` by value, by reference, by a base class, by `...`, destructors on the way, `std::rethrow_exception` and a
`std::exception_ptr` kept past the handler. A guest image that carries libc++ and libc++abi (the reCAPTCHA SDK does)
throws and catches through the host's libc++abi: [how it works](../../explanation/recompiler/how-it-works.md#decisions-in-the-translator)
describes the routing, and `recompiler/tests/libcxxexceptions` (11 steps, green on the 4S) and `recompiler/tests/libexceptions`
are the checks.

What does not work:

- A host `catch` of a type that a guest image defines (`catch (const std::exception &)` in the host, for a
  `std::runtime_error` that guest libc++ built) does not match, because the guest's `type_info` has no host layout that
  the host's `catch` compares equal to its own; the host's `catch (...)` takes it (`stepEscapeStandard`). A guest `catch` of
  a class that the host throws is not tried by a test: a guest `catch (int)` takes a host `int` and a guest `catch (...)`
  takes a host `std::runtime_error`, an `int`, an `NSException` and a class of the host's own (`stepForeign`), and a guest
  typed `catch` of a host class is not expected to match.
- `__cxa_init_primary_exception`, `__cxa_allocate_dependent_exception` and `__cxa_free_dependent_exception`, which
  libc++'s `std::make_exception_ptr` uses, are absent from iOS 6.1.3's libc++abi; a call is a loud fault.
- A landing pad whose catch names a `type_info` that no guest image defines is dropped, and xlate says how many; a function
  with an exception specification keeps plain calls.

## Not done

- No library with the real reCAPTCHA SDK: the fixture stands for it. The SDK's own translation is block A and B.
- The host's UI and its own use of the library were not run: the fixture host is a console tool, `Telegram13` was not
  modified.
- The guest `libswiftCore` is not shared between two libraries.
- Not run on the phone: a control with `XL_NAMESPACE=none` that shows the duplicate warnings come back; the Swift host with
  the Telegram13 runtime and Foundation overlay (`XL_LIBRARY_HOST_RUNTIME`, `XL_LIBRARY_HOST_BRIDGING`) on the new layout; a
  category written in Swift (the Swift fixture has none, so the registry's category list is run by the Objective-C fixture only).
- Telegram13 itself: the range rule above comes from 20 launches of it with a probe and from the fixture's 130 launches with
  the heap of the host at its random starts; the 40 launches of the app with the library in its ipa wait for that ipa.
