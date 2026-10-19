# The twenty-six C API rows the corpus listed as absent, decided against the engine this port actually has

The corpus listed twenty-six rows of JavaScriptCore's C API as absent, every one of them with the same
reason: *the function arrived in iOS N, and nothing in iOS 6 has what it names*. That reason is a
statement about the release's export table, and for these twenty-six it is true and useless at the same
time. The port does not have to answer from the export table. It answers from the engine the release
already carries, and that engine is a whole JavaScriptCore: 885 symbols attributed to the framework in
`coordination/corpus/caches/6.0.tsv`, the ES5 C API end to end - `JSGlobalContextCreate`,
`JSEvaluateScript`, `JSValueToStringCopy`, `JSObjectGetProperty`, `JSClassCreate`, `JSValueIsObjectOfClass` -
and, under them, the engine itself, which evaluates JavaScript. So the question each of the twenty-six
has to answer is not *is the function in the release's table* but **what does the release's engine do
that this function would report, and can the port report it without inventing anything**.

The distinction is the whole family. Twenty-six rows read "absent" is the right answer for most of a
framework that a release does not carry at all. It is the wrong answer for a framework the release
carries in full and whose later API is mostly a matter of asking the engine a question the engine can
answer. Twelve of the twenty-six are such a question; thirteen name a capability the release's engine has
no value for, and stay absent with the capability named; one cannot be answered in either direction and
says so.

Where each group is decided, so that this page can be read against the tree at any revision and found to
match it: the thirteen are in `registry/JavaScriptCore/absent_JavaScriptCore.json`, the twelve in
`registry/JavaScriptCore/capi.json` - eight `implemented`, four `inert`. **This page was first written by
the commit "Name the value JavaScriptCore's thirteen typed-array rows would report on", and at that
revision every one of the twenty-six rows read `absent`**: the other twelve did not exist yet. They are
carried by "Answer the twelve JavaScriptCore C API rows the release's own engine can answer", and the
sentence this paragraph used to hold - that the twelve "are carried" - was written one commit too early,
which is the way this page goes wrong: a claim about work that is not in the range reads as measured. The
number each group has is the number its registry file holds, and the two files are the whole of it.

Those two commits are named by their subjects and not by their hashes, and the reason is worth keeping
beside them. A hash of a commit that is not on main resolves to nothing for a reader of the merged tree -
and it stops resolving even for the band that wrote it, because a rebase rewrites every hash in the series:
this page named both of these by hash, the series was rebased onto a main that had moved, and the two
names were left pointing at objects no branch held. A subject survives that, and a subject is what a reader
goes looking for.

## The engine the release carries, and what it can be asked

`~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7` carries `JavaScriptCore.framework` in
`/System/Library/PrivateFrameworks` - the path Apple moved to `/System/Library/Frameworks` exactly at
iOS 7.0, the one framework of this package's 21 whose path differs across the covered range, and the
reason `modules/apple/backports.lua`'s `framework_install_path` exists. The image is the 2012 engine.
It is not a stub and it is not inert: `facts/JavaScriptCore/JSContext.md` carries the same checks.m
answering 151 of 151 on an iPad 2 running 6.1.3, over that engine, including a script that throws
(`tests/backports/host/jscontext/checks.m:378` - `Promise` misuse throws a TypeError on the port's
engine too, because the port's Promise is a script the 2012 engine runs), and a `JSContext` whose
`exceptionHandler` receives the thrown value and whose `exception` is then set.

So the port's `JSContext` row answers *there is a JavaScriptCore here* truthfully, and the family below
is built on that answer rather than beside it.

Three measurements of what the engine can hold, all from the release's own files, no device involved:

| question | how | answer |
| --- | --- | --- |
| does the C API have a typed-array entry point? | `tools/cache-index/first-rung.lua`, the oldest held rung carrying each name, over the 50 held rungs | 10.0.1 for all thirteen of `JSObjectMakeTypedArray*`, `JSObjectGetTypedArray*`, `JSObjectGetArrayBuffer*`, `JSObjectMakeArrayBufferWithBytesNoCopy` and `JSValueGetTypedArrayType` |
| does the engine have the classes? | the 6.1.3 armv7 cache's own symbol table, read by the same `names.lua` the index is built from | 300 `JSC::` symbols; `JSC::JSArray` (7) and `JSC::JSString` (2) are among them; `JSC::JSArrayBuffer`, `JSC::JSTypedArray`, `JSC::Symbol` and `JSC::Promise` are **0** |
| is the class count a real control? | same search, same file | `JSC::JSArray` and `JSC::JSString` are found, so a search that cannot see a JSC class is not what produced the four zeroes |
| is any of the twenty-six in the release's own file? | the same 6.1.3 armv7 index, name by name, 568 892 names read from a 244 881 694-byte cache whose header names its own mtime and size | **0 of 26**, with **9 of 9** of the release's own C API found by the same read (`_JSEvaluateScript`, `_JSGlobalContextCreate`, `_JSValueToStringCopy`, `_JSObjectGetProperty`, `_JSObjectSetProperty`, `_JSObjectHasProperty`, `_JSObjectDeleteProperty`, `_JSClassCreate`, `_JSWeakObjectMapCreate`), so the zero is the twenty-six and not the read |

## The thirteen that name a value the engine cannot hold: absent

`JSObjectGetArrayBufferByteLength()`, `JSObjectGetArrayBufferBytesPtr()`, `JSObjectGetTypedArrayBuffer()`,
`JSObjectGetTypedArrayByteLength()`, `JSObjectGetTypedArrayByteOffset()`, `JSObjectGetTypedArrayBytesPtr()`,
`JSObjectGetTypedArrayLength()`, `JSObjectMakeArrayBufferWithBytesNoCopy()`,
`JSObjectMakeTypedArrayWithArrayBufferAndOffset()`, `JSObjectMakeTypedArrayWithArrayBuffer()`,
`JSObjectMakeTypedArrayWithBytesNoCopy()`, `JSObjectMakeTypedArray()`, `JSValueGetTypedArrayType()`.

Every one of the thirteen exists to report on, or to make, a value of a kind only an ES6 engine has. The
release's engine has none: not one `JSC::JSArrayBuffer` and not one `JSC::JSTypedArray` among the 300
`JSC::` symbols its own cache carries, and no C entry point that could make one before 10.0.1.

The tempting move is the obvious one, and it is the wrong one. Nine of the thirteen are getters, and
Apple's own answer for a value that is not a typed array is a zero, a null or `kJSTypedArrayTypeNone` -
so a port that returned those unconditionally would link, would not crash, and would be indistinguishable
from correct to any client that never holds a typed array. It would also be a lie to the one client that
does: a caller asking a typed array for its buffer on an engine where the array was made by something
else - a shim, a polyfill, a typed array from a newer context - would be told 0 by a function that has
not looked. `absent` is the honest end, and its effect says what a client actually sees: a weak reference
that is NULL, and no value to ask about.

Carrying them is not a wrapper's work either. A typed array on the release would have to be a value the
2012 engine knows how to make, index and hand to script, and nothing in this package makes engine values.
The workspace does have a JavaScriptCore that has them: `frameworks/WebKit` builds WebKit 254 with its own
JSC for armv7, where `_JSValueMakeSymbol` and `_JSObjectMakeDeferredPromise` are `T` (defined) symbols.
But both of its `JavaScriptCore.framework` targets declare the *system* framework's install name
(`otool -D` on `build/system/...` and `build/prefixed/...` both answer
`/System/Library/Frameworks/JavaScriptCore.framework/JavaScriptCore`), the engine lives in the dyld shared
cache and cannot be replaced for one process, and bringing it in costs a loader tweak, `DYLD_FRAMEWORK_PATH`,
`DYLD_INSERT_LIBRARIES` and a re-exec. That is an environment substitution, not a backport, and it changes
the WebKit an application gets as well. `coordination/FLEET.md` carries the measurement and the reasoning
("neither a wall nor a layout question: replacing the engine whole"); this file does not repeat it.

## The row that can be answered in neither direction: `JSValueMakeSymbol()`

`JSValueMakeSymbol(ctx, description)` returns a unique value of the symbol type. There is no such value
on this release: `JSC::Symbol` is 0 among the 300 `JSC::` symbols, and no held release before 16.0 exports
the function. It is `absent`, and the row beside it, `JSValueIsSymbol()`, is carried - see below - so a
client has a way to *find out* that a value is not a symbol before it tries to make one.

The same sentence is what `facts/JavaScriptCore/JSContext.md` already carries for the Objective-C row
`+[JSValue valueWithNewSymbolFromDescription:inContext:]`: the context is told a TypeError and the answer
is undefined, rather than a string or an object standing in for a symbol, because a string standing in
for a symbol is a different value that claims to be the same one.
## The eight the release's engine can answer, carried

`registry/JavaScriptCore/capi.json` holds the twelve rows this section is about. The eight that answer
something are built in `JavaScriptCore/JSCAPI9.m` (JSValueIsArray, JSValueIsDate), `JSCAPI16.m`
(JSValueIsSymbol and the four `ForKey`) and `JSCAPI8.m` (JSGlobalContextCopyName), and the ninth, the
one that returns a promise, is built in `JavaScriptCore/JSObjectMakeDeferredPromise16.m` over the
machinery in `RevenantJSPromise.m`. The four carried inert below are in `JSCAPI8.m` and `JSCAPI18.m`.
Each is asked directly by `tests/backports/host/jscontext/checks.m`, which is a differential: the same
file runs first against the host's own JavaScriptCore, which is the oracle, then against the backport
linked over the host's C API. **Both sides answer every check they run and finish with
`checks=all passed`**, and the blocks-and-structs matrix is 351 lines identical on the two.

The number to quote is the run's, not the file's, and the two are not the same count: the run prints
**177** `ok` lines per side (`grep -c '^ok '` on its log), the file carries **181** `check(` statements, of
which **174** are call sites in a host build - the rest are `#ifdef REVENANT_PORT` regions with no `#else`
and the device-only one - and at least one of those sites runs in a loop over three cases with a name built
from the case, so executions are not statements either. "177 of 177" was a number this page carried without
its derivation, and a reader could not reproduce it from the file it described; that is the whole of what is
wrong with it, and it is the same failure this page was written to correct.

**What has verified the twelve, and what has not.** The host's engine is the oracle for every one of them
and every expectation in that file passes on both sides, so what each row answers is measured. What is
**not** measured on these twelve is the release: the Objective-C API beside them has had this same harness
run against the 6.1.3 engine on an iPad 2 (151 of 151 at the time, `facts/JavaScriptCore/JSContext.md`),
and these twelve have not been on a device. The reason is a build, not a doubt: the twelve are new
symbols, so a 6.1.3 binary that calls them needs a `libJavaScriptCoreBackports.dylib` built from this
tree, and a band's own tree is exactly what must not install that package into the shared store - the
store's path is keyed by name and version alone, so every band that requires the package from its own
worktree queues on one lock and one of them overwrites the directory the next is about to read
(`coordination/api-worker-brief.md`, measured 2026-09-27 23:20 with nine processes on that lock). So the
run belongs to whoever gates the merged tree, where the package is built once for everybody. Until it
happens, the honest reading of this section is: the twelve answer the host's answers, and the release's
own engine has not yet been asked.

**What has verified the twelve, and what has not.** The host's engine is the oracle for every one of them
and every expectation in that file passes on both sides, so what each row answers is measured. What is
**not** measured on these twelve is the release: the Objective-C API beside them has the same 177 checks
run against the 6.1.3 engine on an iPad 2 (151 of 151 at the time, `facts/JavaScriptCore/JSContext.md`),
and these twelve have not been on a device. The reason is a build, not a doubt: the twelve are new
symbols, so a 6.1.3 binary that calls them needs a `libJavaScriptCoreBackports.dylib` built from this
tree, and a band's own tree is exactly what must not install that package into the shared store - the
store's path is keyed by name and version alone, so every band that requires the package from its own
worktree queues on one lock and one of them overwrites the directory the next is about to read
(`coordination/api-worker-brief.md`, measured 2026-09-27 23:20 with nine processes on that lock). So the
run belongs to whoever gates the merged tree, where the package is built once for everybody. Until it
happens, the honest reading of this section is: the twelve answer the host's answers, and the release's
own engine has not yet been asked.

| row | what it answers | what it is built on |
| --- | --- | --- |
| `JSValueIsArray()` | whether a value is an array by class | `revenant_js_is_array`, the helper `-isArray` already answers through |
| `JSValueIsDate()` | whether a value is a Date by class | `revenant_js_is_date`, likewise |
| `JSValueIsSymbol()` | false, for every value of an engine with no symbols | the measurement above |
| `JSObjectGetPropertyForKey()` | reads the property a value key names | `JSValueToStringCopy` for the key, the release's own `JSObjectGetProperty` for the read |
| `JSObjectSetPropertyForKey()` | writes it | the release's own `JSObjectSetProperty` |
| `JSObjectHasPropertyForKey()` | whether it is there | the release's own `JSObjectHasProperty` |
| `JSObjectDeletePropertyForKey()` | removes it, and answers true for a property that is not there (ES5 8.12.9) | the release's own `JSObjectDeleteProperty` |
| `JSObjectMakeDeferredPromise()` | a promise and the two functions that settle it | the port's own ES5 promise, the same one `+[JSValue valueWithNewPromiseInContext:fromExecutor:]` hands out |

ToPropertyKey, which the four `ForKey` rows are named for, is ToString for every value this engine can
hold: a string key is itself, a number key is its own string (so it indexes an array), a boolean key is
`"true"`, and an object key runs its own `toString` and can throw - in which case the exception is the
answer, the call answers NULL or false, and nothing is read, written or deleted. A key of the *symbol*
type is the one answer ToPropertyKey gives that ToString does not, and it cannot arise.

### What the two engines answer differently, and what is only measured

- **The attributes of a set are kept by neither engine.** `JSObjectSetPropertyForKey` with
  `kJSPropertyAttributeReadOnly` leaves the property writable on the host's engine and on this one: the
  release's engine keeps no attribute on an object it lays out itself, which `JSValue.m` already names
  from the iPad 2, and the host's own does not either, measured in the same run. So the row promises no
  attribute rather than promising one that arrives.
- **A reaction runs on the next run loop turn here and as the call returns there.** A promise the C API
  resolves runs its reaction on the next run loop turn of the port, because the port's job queue has no
  leave of its own to run at when a C client makes the call itself - the same sentence
  `+[JSValue valueWithNewPromiseInContext:fromExecutor:]` carries. The host drains its microtask queue as
  the outermost call into script returns.
- **A rejection through the C API leaves its reaction unrun, on both engines.** Measured in the same run
  and asserted on neither: a promise, a `then`, a `reject` answered with a value and no exception, and
  the reason still unread after a script entry and a run loop turn - the host's own engine exactly as
  the backport does. The port's own promise does carry a rejection to a reaction when one is made from
  Objective-C (`checks.m`'s `CheckPromises`, which passes on both sides); this is the arrangement
  neither engine runs, and asserting the host's answer would be asserting a measurement.
- **The exception out-parameter the SDK's signature of three of the four property functions carries** is
  passed straight through, so a getter or setter that throws leaves it where the caller reads it. Every
  other call of these four in this package already passes the SDK's arity with NULL there -
  `JSValue.m`'s `NamedProperty`, every property read of `JSExportBridge.m` - and answers correctly on a
  6.1.3 device (`facts/JavaScriptCore/JSContext.md`, 151 of 151 on an iPad 2), so a release whose own
  function takes no such argument is reading none of it.

## The four that are carried inert

`JSGlobalContextSetName`, `JSGlobalContextCopyName`, `JSGlobalContextSetInspectable` and
`JSGlobalContextIsInspectable` are a Web Inspector's two fields for a context: the name it lists the
context under, and whether it may attach. This port carries no Web Inspector - no protocol here that
could be attached - so nothing on it reads either. They are carried rather than absent because the
answer this port can give is the answer a release with no inspector gives, and a client that weak-links
the symbol is answered instead of left to call through NULL; each says so once in the log the first time
an application reaches it, which is what an inert row is.

They are **not bridged** to `-[JSContext setName:]` and `-[JSContext setInspectable:]`, which keep their
own value in the wrapper, and that is stated rather than left to be found. The wrapper registry holds
its values weakly by design, so a store a C client could reach would have to outlive the wrapper and die
with the context; the only such store the release has is a `JSWeakObjectMap`, and it holds JavaScript
values rather than a name. The two APIs were measured not to agree on the host either: Apple's
`JSGlobalContextSetName` writes the global object's own `name()` (JSContextRef.cpp:241), which is the
inspector's field, and not the wrapper's.

Two of the four cannot be compared with a host at all: `JSGlobalContextSetInspectable` and
`JSGlobalContextIsInspectable` are `API_AVAILABLE(macos(NA))` in the SDK, so macOS's own JavaScriptCore
does not carry them and no oracle for them exists on this machine. Their contract is the header's own
round trip - a flag read back what was set - and neither the fact nor the effect claims more than that.

## Which release each object is, and which release each name was published in

**This section used to say `JSCAPI.m` is one release: iOS 6.1.3, by construction, and that nothing in
the release-split check reads the `introduced` fields. The 6.1.3 gate read them, and refused the
object:**

    JavaScriptCoreBackports: JSCAPI.m defines JSGlobalContextCopyName JSGlobalContextSetName from
      iOS 8.0 and JSValueIsArray JSValueIsDate from iOS 9.0
    JavaScriptCoreBackports: JSValue.m defines JSValue from iOS 7.0 and JSObjectMakeDeferredPromise
      from iOS 16.0; an object carries API that arrived in one release

So the claim was wrong twice over, and the second half of it was the part that mattered: the check
does not read `introduced`, and `introduced` is not the number that decides which object an API goes
in. `introduced` is where **Apple published** a name, and it is right about that; what decides the
object is the first held release that **exports** the symbol, read by `modules/apple/dyld.lua`'s
`first_releases()` - the call `modules/apple/backports.lua`'s `check_releases()` makes, so this is the
measurement that refuses the mixed object and not a second opinion on it. Measured with it:

| object | symbol | `first_releases()` | rungs that export it | `introduced` (Apple) |
| --- | --- | --- | --- | --- |
| `JSCAPI8.m` | `JSGlobalContextSetName`, `JSGlobalContextCopyName` | **8.0** | every rung from 8.0 on | 8.0 |
| `JSCAPI9.m` | `JSValueIsArray`, `JSValueIsDate` | **9.0** | every rung from 9.0 on | 9.0 |
| `JSCAPI16.m` | `JSValueIsSymbol`, the four `JSObject...ForKey` | **16.0** | 16.0, 18.0 | 13.0 |
| `JSCAPI18.m` | `JSGlobalContextSetInspectable`, `JSGlobalContextIsInspectable` | **18.0** | 18.0 | 16.4 |
| `JSValue.m` | `JSValue` and its metaclass | **7.0** | every rung from 7.0 on | 7.0 |
| `JSObjectMakeDeferredPromise16.m` | `JSObjectMakeDeferredPromise` | **16.0** | 16.0, 18.0 | 13.0 |

The 13.0 and 16.4 rows read as 16.0 and 18.0 because no release between 12.0 and 16.0 is held, and
none between 16.0 and 18.0: a name Apple published inside a gap is bounded from above by the next rung
that exports it. `tools/release-split.lua` prints the same note about its own ladder when it skips a
major release. No `introduced` value changed, because none of them was wrong.

`RevenantJSPromise.m` is a fifth file and is in **every** band: `nm -gU` on it reports three symbols and
`backports.lua`'s `internal_symbol()` filters all three (two `revenant_js_` entry points and a block
descriptor), so `band()` sees no API of its own and keeps it wherever it is needed. That is what lets
`JSObjectMakeDeferredPromise16.m` reach the promise at all: from iOS 7.0 to 15.x, `JSValue.m` is
re-exported to the release's own `JSValue` and is not in the library, so the promise could not have
stayed in it, and it could not have been a `static inline` in `JSInternal.h` either, because
`PromiseClass` and `CaptureClass` hold their `JSClassRef` in a `dispatch_once` function-local and
`PromiseState` answers by identity. One copy, in a file that exports nothing, is the shape
`toolchain/AGENTS.md` names for exactly this.

Every one of the twenty-six rows is `minimum: 6.0`, and every object above is one release: no object
is claimed from a band that already carries its exports. The four `ForKey` rows are four names of one
release and the thirteen typed-array rows thirteen names of another (10.0), and a protocol conformance
is not a split - nothing here conforms to a protocol.
