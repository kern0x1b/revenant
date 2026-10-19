# JSContext, JSValue, JSVirtualMachine and JSManagedValue, the objects over iOS 6's own engine

Source: SDK 16.4's own JSContext.h/JSValue.h/JSVirtualMachine.h/JSManagedValue.h/JSExport.h for the
contract; `coordination/corpus/caches/6.0.tsv` for what iOS 6 itself exports; `tests/backports/host/jscontext`
for behaviour. That test is a differential: the same `checks.m` runs first against the host's own
JavaScriptCore.framework, which ships these four classes and is the oracle every expectation has to pass,
then against the backport, renamed at compile time and linked over the host's C API. Both answer 151 of
151.

**Measured on the release's engine.** The same `checks.m`, built as a device binary against the band's
library, answers 151 of 151 on an iPad 2 running 6.1.3 (the 2012 engine). Its blocks-and-structs matrix
differs from the host's in 31 of 351 lines:
- 4 are an out-of-range double taken as `long long` or `unsigned long long` (1e20, Infinity), where C leaves
  the conversion undefined: the host (arm64) saturates, while armv7's libSystem `__fixdfdi` wraps modulo 2^64
  and answers 0 for an infinity. Reasoned, not measured: the release's `CallbackArgument` casts the number
  too, so on armv7 it goes through the same conversion.
- 27 are every `CGRect` line, whose object lists the same four keys in another order (host
  `y,x,width,height`, iPad `y,width,x,height`), with the same values: the struct is made from a dictionary
  literal, as the release makes it, so the order is how 6.1.3's CoreFoundation enumerates that dictionary.
  Not compared with the release on armv7.

What the engine does differently, and what the port does about it, is below under "The release's
engine, measured".

## What iOS 6 already carries

`facts/JavaScriptCore/JavaScriptCoreExports.md` said thirteen C API names, from an iPad 2 asked one by one
with `dlsym` after every framework had loaded. That undercounts: `coordination/corpus/caches/6.0.tsv`, built
from the release's own export table rather than a running process's memory, names 93 `JS`-prefixed symbols in
the framework (`awk -F'\t' '$2=="JavaScriptCore" && $1~/^_JS/' 6.0.tsv | sort -u | wc -l`), including
`JSEvaluateScript`, `JSObjectCallAsFunction`, `JSObjectSetProperty`, `JSClassCreate` and the rest of what a
real bridge needs - not just the thirteen the device probe happened to ask for and find loaded. The dlsym
probe is not wrong about what it found; it is silent about what it never asked.

## Private C API this uses, and why

Every call below is exported by the release but declared in no public header - WebKit's own private
headers, which the release's own Objective-C bridge (iOS 7 and later) is built on. The public C API has no
equivalent, so there is no public mechanism to prefer:

| Call | Declared in | Why nothing public does it | Exported by (6.0.tsv ladder) |
| --- | --- | --- | --- |
| `JSWeakObjectMapCreate/Set/Get/Remove` | `JSWeakObjectMapRefPrivate.h` | the only reference to a JavaScript object the collector clears; `JSValueProtect` only keeps. JSManagedValue, the one-wrapper-per-object cache and the per-global Promise constructor need a reference that does not keep | 6.0, 7.0.1, 10.3.4, 12.0, 16.0, 18.0 |
| `JSObjectGet/Set/DeletePrivateProperty` | `JSObjectRefPrivate.h` | a property script cannot see, enumerate or change: a promise's state, a managed-reference node | same six |
| `_protocol_getMethodTypeEncoding` (libobjc) | objc-runtime's private header | a JSExport method's extended type encoding - the class of each argument; `protocol_getMethodDescription` answers `@` for every class | same six |

Measured with `grep "^<symbol>\t" coordination/corpus/caches/<release>.tsv` over 6.0, 7.0.1, 10.3.4, 12.0,
16.0 and 18.0: every one is exported by all six. The host's own JavaScriptCore imports `__protocol_getMethodTypeEncoding` (and
`__Block_signature`), `dyld_info -imports /System/Library/Frameworks/JavaScriptCore.framework/JavaScriptCore`:
the release's bridge reads method encodings the same way. A block's signature is not on this list: it is read as the
documented clang Block ABI lays it out (below), not through `_Block_signature`.

## The shape of the bridge

Every one of the four classes is a wrapper over the C API the table above confirms: `JSVirtualMachine` a
`JSContextGroupRef`, `JSContext` a `JSGlobalContextRef`, `JSValue` a `JSValueRef` (protected with
`JSValueProtect` for its own lifetime, unprotected in its `-dealloc`), `JSManagedValue` a GC-weak hold on the
JavaScript value itself (JSManagedValue.m and JSVirtualMachine.m describe the graph). An Objective-C object
boxed more than once in a context gets the one wrapper, as the release keeps one.

## Conversions

Measured against the host's JavaScriptCore case by case and written as its JSContainerConvertor walks it
(JSInternal.m, `Convert`):

- `-toObject`: undefined is nil and null NSNull at the top; a wrapped Objective-C object is itself; a `Date`
  is an NSDate (an invalid one an NSDate of NaN); an array is read by its `length`. Array and Date are told
  by the object's own class, as the release asks it: one made in another context of the same virtual
  machine counts, one that only inherits `Array.prototype`/`Date.prototype` does not, and script replacing
  `Array.isArray`, `Object.prototype.toString` or `Date` changes nothing (measured on the host, checks.m
  `CheckOwnClass`). The port asks ES5's own answer - `Array.isArray` and `Object.prototype.toString`'s
  `[object Date]` - of the virtual machine's own context, where no script but the port's runs. Anything
  else - a function, an Error, a RegExp, a boxed number included - is read as a dictionary of its
  enumerable property names, inherited ones included. Inside a container null is NSNull; undefined and a hole are NSNull in an
  array and left out of a dictionary. Every object is converted once: a cycle or a shared reference gives
  back the same Objective-C object, and the walk uses a worklist, not recursion. A getter that throws is
  left out and reported nowhere, as the host reports it nowhere.
- `-toArray`/`-toDictionary`: any object is read as the container asked for (`{a:1}` is an empty array,
  `[5,6]` is `{0:5, 1:6}`), undefined and null are nil, any other primitive is nil and a TypeError
  "Cannot convert primitive to NSArray/NSDictionary" to the context's exceptionHandler.
- `-toString`/`-toDouble`/`-toInt32`/`-toNumber`/`-toDate` that run a throwing `toString`/`valueOf` answer
  nil/NaN/0/NaN/nil and send the exception to the exceptionHandler.

## Arguments by their declared class

A block's or JSExport method's object argument is converted by the class its extended type encoding names
(`@"NSString"`), as the release does - measured on the host for thirteen declared types against thirteen
kinds of value: `JSValue *` receives the value itself (a missing argument is undefined); `id` receives
`-toObject`; `NSString`, `NSNumber`, `NSDate`, `NSArray` and `NSDictionary` receive the matching `-to...`
conversion; any other class receives the bridge's own wrapper of an instance of it, nil for undefined and
null, and for anything else a TypeError "Argument does not match Objective-C Class" is thrown into the
calling script before the block or method runs. A conversion that fails is thrown the same way.
`+currentArguments` holds every JavaScript argument, not only the declared ones.

A block's encoding is read as the documented clang Block ABI (clang's `docs/Block-ABI-Apple.rst`) lays it
out: `flags & BLOCK_HAS_SIGNATURE (1 << 30)`, then the descriptor's signature field, past `copy`/`dispose`
when `BLOCK_HAS_COPY_DISPOSE (1 << 25)` is set. The compiler that built the block writes it, not the
runtime. Measured on the host: the pointer read this way is the very pointer `_Block_signature` answers, for
a global, a capturing and a primitive-typed block. A method's comes from `_protocol_getMethodTypeEncoding`
(table above); a property setter's from the property's own `property_getAttributes`.

A block taking a block, a `Class`, a `SEL`, a pointer, a struct other than CGPoint, CGSize, CGRect and
NSRange, or a class the runtime does not know is no function to JavaScript (`typeof` answers "object"), as
on the host (measured for a block, `Class`, a one-int struct; NSRange and seven `id` arguments are
functions).

A block is called as the release calls it: through an `NSInvocation` whose target is the block
(WebKit's ObjCCallbackFunction.mm, `CallbackBlock`), made from the block's encoding with the class names and
block signatures of the extended form left out - the plain encoding `+signatureWithObjCTypes:` documents.
So any number of arguments and every C number, `bool` and the four structs are carried, arguments and
return. A C number argument is converted as the release's `CallbackArgument*` do: char, short, int, long
and their unsigned forms take ECMAScript ToInt32 cast to the type, long long, unsigned long long, float and
double the number cast to the type, bool ToBoolean, the structs `-toPoint`/`-toSize`/`-toRect`/`-toRange`;
a valueOf that throws is thrown into the calling script before the block runs. A returned number is a
number (a char included - so on armv7, where BOOL is `char`, a BOOL return is 0 or 1, not a boolean), a
bool a boolean, a struct JSValue's `+valueWith...` object, built from a dictionary literal as the
release builds it. JSExport methods convert through the same code. Measured on the host for thirteen types
against twenty-seven values (tests/backports/host/jscontext/run.sh diffs the whole matrix against the
host's JavaScriptCore) - the same, value for value. `NSInvocation` invokes a block target on iOS 6.1.3:
measured on the iPad 2 for int, CGRect, object and bool returns with the plain encoding (a probe of its
own, 4 of 4 calls).

A block's function is a function to script as the release's is: `Function.prototype` (read off a function
the engine makes, so a replaced global `Function` changes nothing), read-only `length` 0 and `name` "",
its own `prototype`, call/apply/bind, `[object Function]`; `new` runs the block with no `this` and answers
the object it returns, or a TypeError "Objective-C blocks called as constructors must return an object."

## What differs from the release, named

- **`String(block)`** is the engine's text for an object with a JSClassRef (`function CallbackObject() {
  [native code] }` on the host), where the release's reads `function () { [native code] }`. On the 2012
  engine `Function.prototype.toString` refuses it: `String(block)` throws "TypeError: Type error"
  (measured on the iPad 2), where the release answers a string.
- **Where a JSExport wrapper's properties and methods live.** A property reads and writes through its
  getter and setter, and those accessors are not methods of their own (`typeof obj.setX` is undefined), as
  on the host; but the port answers them on the wrapper itself (`obj.hasOwnProperty('x')` is true), where
  the release keeps them on a prototype object per class (false there).
- **The JavaScript class name of a wrapper** is the bridge's own (`[object CharonOpaqueObject]`,
  `[object CharonExportObject]`) where the host shows the Objective-C class (`[object NSURL]`), so
  `String(wrapper)` differs.
- **Promises** are the release engine's own ES5 script (CharonJSPromise.m, `CharonPromiseSource`) over native
  helpers; a context made by `-init` gets a global `Promise` (the iOS 6 global has none) - writable,
  configurable and not enumerable, as the host's - and a context adopted from a web view page does not. Reactions run when the outermost Objective-C call into JavaScript returns;
  jobs queued with no such call on the stack (script run through the C API directly, a page) run on the
  thread's next run-loop turn. So do jobs a block or JSExport method queues when script run through the C
  API directly called it: the release runs both as the outermost C API call returns, which the 2012
  engine lets nothing outside it see (checks.m holds each side to its own answer). JSValue's property
  accessors do not drain the queue. `valueWithNewPromiseResolvedWithResult:nil` and
  `...RejectedWithReason:nil` raise NSInvalidArgumentException, as the release does (it puts the value
  into an array literal); the port makes that literal before any script runs, so the exception does not
  unwind through the engine's frames.
- **When a wrapped object is released.** A finalizer must not call the C API (JSObjectRef.h,
  `JSObjectFinalizeCallback`), and on the 2012 engine a finalizer runs inside whichever allocation sweeps
  its block (below); the last release of a wrapped object runs its `-dealloc`, which may call the C API (a
  JSValue, a JSManagedValue, a graph token). So a finalizer here only queues the object its wrapper retained, on a
  queue of the thread it runs on - the thread that swept its block. The release hands such objects to the heap
  to release as the collection ends (WebKit's `Heap::releaseSoon`), still inside the call that collected;
  the C API has no end-of-collection hook, so each thread releases what it queued at its own next
  outermost call into script or next run-loop turn, whichever comes first, and at its exit (JSInternal.m,
  `charon_js_release_soon`). Measured on the host (checks.m `CheckReleaseAfterCollection`,
  `CheckReleaseThread`): the release's owner is released by the time the collection returns, the port's
  on the next turn, never inside the collection, never by another thread that calls into script, and a
  thread's turn is not held up by another thread's queue. The one case left: a thread that has no run
  loop and calls into script no more keeps what it queued until it exits, where the release lets go as
  the collection ends (a torn-down virtual machine's objects: measured, the release on its teardown, the
  port at the thread's exit). A `-dealloc` here calls the C API as the release's does: no finalizer here
  releases anything, so none runs inside a collection.
- **Symbols**: the 2012 engine has none. `valueWithNewSymbolFromDescription:` notes a TypeError on the
  context and answers undefined, and `isSymbol` answers NO - an honest refusal at the seam.
- **`-name`** is kept locally rather than shown anywhere, since the release exports no
  `JSGlobalContextSetName`; **`-isInspectable`** is stored and has no other effect. Whether iOS 6's
  webinspectord could list a bare JSGlobalContext at all is not measured.
- **`-isArray`/`-isDate`** answer by the object's own class as `-toObject` does (above), rather than through
  `JSValueIsArray`/`JSValueIsDate`, which iOS 6 does not export (introduced iOS 9).

## The release's engine, measured

On the iPad 2 (6.1.3), with the C API alone (a probe with no backport loaded), and against
JavaScriptCore-7536.26.7's source (OS X 10.8.2's, the same 536 branch):

- **`JSGarbageCollect` does not collect.** It reports an abandoned object graph, which brings the heap's
  collection timer on the thread's run loop forward (`Heap::reportAbandonedObjectGraph`,
  `GCActivityCallbackCF.cpp`); the timer's collection marks and sweeps the whole heap. Measured: 2000
  unreachable objects, none finalized when the call returns, all on the next run-loop turn; a second
  call, once the heap had collected, came seconds later. No collect-now is exported
  (`JSSynchronousGarbageCollectForDebugging` arrives in 7.0.1). `checks.m` on the device asks and turns
  the run loop until an object made unreachable first has been finalized.
- **Finalizers run inside allocations.** A collection that allocation starts leaves the sweep to later
  allocations: the first finalizer ran inside `JSObjectMake`, after 3971 of them. Hence the finalizers' queue above.
- **`JSContextGroupRelease` dropping a group's last reference crashes** once the group holds identifiers:
  it derefs with no lock and without switching to the group's identifier table, so `~StringImpl` finds
  the identifier in the wrong table (SIGSEGV, frames `JSContextGroupRelease` -> `~JSGlobalData` ->
  `Heap::lastChanceToFinalize` -> `~StringImpl`); `JSGlobalContextRelease` dropping it does not. The
  port's `JSVirtualMachine` holds its group only through a global context of its own, so the last
  reference it holds always goes through `JSGlobalContextRelease`. Before this, a context's teardown
  crashed on the device.
- **`JSObjectSetProperty`'s attributes do not take on a global object**: `kJSPropertyAttributeDontEnum`
  gave an enumerable global (`JSGlobalObject::putDirectVirtual` puts the value first, then keeps the
  attributes of what exists); on any other object they take. ES5's `Object.defineProperty` takes on the
  global too, so the global `Promise` is defined through the context's own one, read before any script
  has run there.
- **A weak object map's destroyed callback runs** when its global object is destroyed: once, in the
  collection that took a released context's global object (checks.m's measured line: 1, and still 1
  after the group is gone), where the host runs it never. The port's callback does nothing.
- **ES5**: no `globalThis`, so `checks.m` names the global object as the script's `this`.

## Two build-system defects this port's own files exposed, both in `modules/apple/backports.lua`

**Charon's own internal helpers must not share an object file with a class the band reexports -
fixed.** `charon_js_box`, `charon_js_unbox`, `charon_ns_string`, `charon_js_push_callback` and
`charon_js_pop_callback` used to live in `JSValue.m` and `JSContext.m`, next to the `JSValue`/
`JSContext` classes themselves. `band()` correctly reexports those two classes from the system on
any release from iOS 7.0 (where JavaScriptCore is genuinely there) - and drops their whole object
file doing it, taking the five helpers with it, even though `JSExportBridge.m` (whose own class,
`CharonExportBinding`, is never a real SDK name and so is always kept) calls them
unconditionally on every band. That produced "Undefined symbols: _charon_js_box" at `write_deb`'s
multi-band link only, never at a single-release `build()`, which never reexports anything -
confirmed by instrumenting `link()` directly (not committed): kept every JavaScriptCore object on
the 6.1.3 band, kept only `JSExportBridge.o` on the 7.0 band. Fixed by moving all five, plus the
block/opaque-object `JSClassRef` machinery and the pthread callback frame stack they depend on,
into `JSInternal.m`, which defines nothing but Charon's own names - `band()` always keeps it
regardless of what else in the library gets reexported.

**`-framework X` embeds the SDK's own install path for X, not the band's - fixed, generalized
past JavaScriptCore.** Fixing the helpers above surfaced a second, independent defect: on the
7.0 band, `libJavaScriptCoreBackports.dylib` loaded
`/System/Library/PrivateFrameworks/JavaScriptCore.framework/JavaScriptCore`, which iOS 7.0 does
not carry. Measured directly against both caches (`dyld.load` on `6.1.3` and `7.0`):
`JavaScriptCore` moved from `PrivateFrameworks` to `Frameworks` exactly at iOS 7.0. The 6.1.3
band linked clean only because the SDK's own path happens to still match iOS 6's. Checked all 21
frameworks this package's `LIBRARIES` table names against both ends of the covered range
(`6.1.3` and `10.3.4`) - `JavaScriptCore` is the only one whose path differs; the other 20 are
stable across the whole range, so this was not a second live case, only a first confirmed one.
Fixed generally, not as a JavaScriptCore special case: `framework_install_path()` reads, for
every framework a library links, where that band's own cache actually carries it (the same fact
`stubs()` already reads from the cache for symbols a band reexports, applied to the framework
itself), and `link()` rewrites the one load command afterward with `install_name_tool -change`
where it differs from what the SDK embedded. The ordinary, full-declaration `-framework X` link
stays exactly as it was - tried building a `.tbd` scoped to only this band's own exports instead
(the same technique `stubs()` uses for reexported symbols) and reverted it: it silently dropped
the declarations `UTType.m`'s weak, `API_AVAILABLE`-guarded calls to `_UTTypeIsDeclared`/
`_UTTypeIsDynamic` need to bind as weak imports rather than hard-undefined, since a band-scoped
stub carries no symbol arriving in a later release the same way the band's real firmware does
not - the rewrite-after-linking approach needs no such declaration, since the ordinary
`-framework` link already provides every one the SDK knows about.

**A third defect, found trying to make the first one fail loudly instead of as a bare linker
error, is real and still open.** The idea: after `band()` picks `kept`, check that every
`charon_`/`Charon`-prefixed symbol a kept object references undefined is actually defined
somewhere in `kept`, and name the object and the (likely reexported-away) object that should have
carried it, instead of leaving the discovery to whatever `Undefined symbols` the linker happens to
print. Implemented and reverted (not committed) after it fired a false positive on a single-release
`build()`: `CharonMetalEncoder.o needs _CharonMetalBindEpoch`, naming no provider, for a symbol
that links and runs fine today. The classification of "undefined, external" symbols from the
Mach-O `nlist` table (`kind & 0x0E == 0x00 and kind & 0x01 ~= 0`) does not distinguish a true
`N_UNDF` external reference from a **common symbol** (`N_UNDF` with a nonzero value field, a
tentative definition the linker resolves without another object defining it) or a **weak
definition**, and `_CharonMetalBindEpoch` is one of those, not a true undefined reference. A
version of this check worth trying again needs to read the `nlist` value field (zero for a true
undefined reference, nonzero for a common symbol) and the `N_WEAK_DEF`/`N_WEAK_REF` bits
(`n_desc`, not `n_type`) before deciding a symbol is genuinely missing - left open rather than
shipped half-right, since a check that gives a false positive teaches the next person to ignore
it, and then it misses the real one too.
