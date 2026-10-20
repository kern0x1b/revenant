# The stream task, iOS 9.0, over the release's own stream pair

`NSURLSessionStreamTask` with its seven methods, the two factories that make one, the two `NSStream`
factories they are built on, and three of the four `NSURLSessionStreamDelegate` callbacks -- the fourth
is declared and never sent, and the section below says why and what was measured about it.

## The class of that name, which iOS 8.0-8.4.1 carry and no release exports before 9.0

The class this port carries is an ALIAS of a class of Revenant's own, and the reason is measured, not
guessed. Every held armv7 rung, read with `objc.inventory` for the class list and `dyld.load` for the
export trie (`.agent-work/measure/stream-export.lua` in the worktree that wrote this, run against
`$HOME/.revenant/dyld`):

| release | `NSURLSessionStreamTask` in `__objc_classlist` | image | `_OBJC_CLASS_$_NSURLSessionStreamTask` exported |
| --- | --- | --- | --- |
| 6.0, 6.0.2, 6.1, 6.1.3, 6.1.4, 6.1.6 | no | - | no |
| 7.0, 7.0.1, 7.0.6, 7.1, 7.1.1, 7.1.2 | no | - | no |
| 8.0, 8.0.2, 8.1, 8.1.1, 8.1.2, 8.1.3, 8.2, 8.3, 8.4, 8.4.1 | **yes** | CFNetwork | **no** |
| 9.0 and later (held: 9.0 ... 18.0) | yes | CFNetwork | yes, with its metaclass |

So the two answers differ on exactly the ten 8.x rungs, and that is the whole of the case:

* **Nothing to ask the release for.** `objc.code_map` over the same caches says what that class is on
  8.0 and on 8.4.1: `superclass NSURLSessionTask`, **0 own instance variables, 0 own methods**, no
  protocols, and no category anywhere in either release adding one. Nothing in either release carries
  `-readDataOfMinLength:maxLength:timeout:completionHandler:`, `-captureStreams` or
  `-streamTaskWithHostName:port:` either -- those names first appear in 9.0, and there they are on
  `__NSCFURLLocalStreamTask`, a private subclass, while the class of the SDK's name stays the empty
  shell. A class the release carries and cannot answer for is nothing to ask, so the first of the two
  routes is measured to be unavailable on every release, and a class implementation in
  `Foundation/NSURLSessionStreamTask9.m` would put a second class of that name into every process on
  every band from 8.0 on.
* **So the name is an alias** (`revenant_alias.h`), which is what this tree already does for a name a
  release carries and does not export: CarPlay's `CPListItem` (`CarPlay/CPListItem.m`), UIKit's
  `NSTextList` and `NSTextTab`. What is new here is that the release carries the class in *some* of
  the releases a band is built for and in none of the others, which the three existing aliases never
  had to answer for -- measured above, they are carried on 6.1.3, 7.1.2, 8.0, 8.4.1 and 9.0 alike.

What the library's loader (`attach.c`) then does, per release, is what `revenant_alias.h` says and this
page measured on the bands:

| band | what the proxy is | what an application gets |
| --- | --- | --- |
| 9.0 and later | the band drops the object and re-exports the release's own class and metaclass (`band()`), so the port's members are not in the process at all | the release's own task, which is `__NSCFURLLocalStreamTask`'s public face |
| 8.0 - 8.4.1 | `revenant_reparent` makes `RevenantNSURLSessionStreamTask` a subclass of CFNetwork's class (no instance variable of its own, so the two instance sizes are equal and the re-parent is kept) and `revenant_adopt_methods` gives that class all ten methods the proxy carries | an instance of **CFNetwork's own class**, which answers the seven methods, `-captureStreams`, the factories' construction method and the delegate sends |
| 6.0 - 7.1.2 | there is no class of that name, so the loader has nothing to re-parent onto and nothing to adopt into: the proxy **is** the class | an instance of `RevenantNSURLSessionStreamTask`, which answers the same seven methods over the same `NSStream` pair |

Two things about the 6.x/7.x row are worth writing down rather than leaving to be found:

* **`NSClassFromString(@"NSURLSessionStreamTask")` answers nil there.** The class is a class of
  Revenant's own, and the release's own name belongs to no class on such a release -- giving it that
  name would mean a second class of it, which is the collision this shape exists to avoid. Everything
  reached through the name a port links (`[NSURLSessionStreamTask class]`, `+alloc`, the factory in
  `NSURLSession+StreamTask9.m`) answers as the proxy, and `-isKindOfClass:` through the linked
  reference is true; a lookup by string is the one thing that no longer finds it.
* **`-init` is the release's own there**, not the port's: the loader does not add a method the
  release's class already answers somewhere in its chain, and `NSObject` answers `-init`. That is
  why the task's state is made when it is first asked for (`-revenant_state`) and not in `-init`.

## What `-resume` reaches on 8.0 - 8.4.1, and the one step nobody has run

The port's `-resume` is `[self revenant_open]; [super resume];`, and on an 8.x band `[super resume]` is
CFNetwork's own `-[NSURLSessionTask resume]` -- the 8.4 band's `libFoundationBackports.dylib` defines
`NSURLSessionStreamTask` and `NSURLSessionStreamTaskState` and *references* `NSURLSessionTask` "(from
CFNetwork)", so the port's own task class is not in that chain. What that `resume` then drives is not
below the class the port's task is re-parented onto, and that is measured, over the held armv7 caches
with `apple.objc.inventory` (`.agent-work/measure/stream-hierarchy.lua` and `stream-gap.lua` in the
worktree that measured it):

| release | `NSURLSessionStreamTask` | classes below it | the concrete stream task class | `_onqueue_resume` lives on |
| --- | --- | --- | --- | --- |
| 8.0 | 0 own instance methods | **none** | `__NSCFLocalStreamTask` : `__NSCFLocalSessionTask` | both of those |
| 8.4.1 | 0 own instance methods | **none** | `__NSCFLocalStreamTask` : `__NSCFLocalSessionTask` | both of those |
| 9.0 | 0 own instance methods | **none** | `__NSCFURLLocalStreamTask` : `__NSCFURLSessionTask` | not asked on this rung |

`__NSCFLocalStreamTask` carries 13 own instance methods and `__NSCFLocalSessionTask` 88, and **94 of
those 101 are selectors neither `NSURLSessionTask` nor `NSURLSessionStreamTask` answers** -- the whole
`_onqueue_*` layer (`_onqueue_resume`, `_onqueue_suspend`, `_onqueue_cancel`, `_onqueue_newStreams`,
`_onqueue_createBoundStreams`, `_onqueue_issueWrite`, `_onqueue_adjustPoolPriority`,
`_onqueue_completeInitialization`, `_onqueue_didFinishWithError:` and the rest), `_task_onqueue_*`, the
`connection:*` callbacks and the connection's own accessors. `NSURLSessionTask`'s own 147 methods on 8.0
(146 on 8.4.1) hold `-resume`, `-suspend`, `-cancel`, `-_onqueue_adjustPriorityHint:` and
`-_onqueue_releasePowerAsssertion` (the release's own spelling) and **not** `-_onqueue_resume`.

So the port's 8.x task, which the loader lays out from a class with no own instance variable and no own
method, is not below any of that vocabulary, and `[super resume]` is the release's own method driving
it. Whether that raises `unrecognized selector` is **not measured here**, and this page does not claim
either way:

* The metadata names the vocabulary and says which class holds it. It cannot say which selectors
  `-[NSURLSessionTask resume]` sends, because that is in its code and not in its method list.
* The one level that would answer it is the emulator or hardware, and **this machine has no image of a
  release from 8.0 on**: `~/.revenant/firmware/rootfs/iPhone4,1` holds 6.0 and 6.1.3 and
  `~/.revenant/emulator/golden.noindex` four golden images (iPhone2,1 4.0 and 4.3.2, iPhone3,1 4.3.2 and
  7.1.2), while `emulator profile --list` does offer iPhone4,1 and `emulator abi` knows Darwin 14.0.0. So the
  probe is possible and it costs what the skill says: the 8.4.1 iPhone4,1 firmware (1.55 GB) fetched and
  extracted, then one boot past first-boot migration to make the golden image. Nothing was booted and
  nothing was run.
* An 8.x armv7s band cannot be asked either: the newest firmware the emulator has a profile for is iPhone4,1
  at 9.3.6, so 10.3.4 - the top of the armv7s ladder - is not emulable on this machine at all.

One earlier reading of these caches said no class in 8.0 or 8.4.1 carries `-_onqueue_resume` at all,
and it was wrong: `apple.objc.inventory`'s `instance` map is keyed **with the leading sign**, so an
index on the bare selector reads nil while `pairs` yields `-_onqueue_resume`. The measurement above
iterates the map.

**What was NOT fetched, and why the probe never got as far as an image.** Nothing was downloaded and no
image was booted. The probe this section needs was written first and it does not link: with
`apple-backports` at `apple_minimum=8.4.1`, resolved through the same addon and the same
`@addon/revenant/apple-ios` toolchain `coordination/build-gate.lua` uses (`xmake show -t` prints
`-fuse-ld=/Users/<user>/.xmake/packages/l/ld64/956.6/<hash>/bin/ld`), the placement of the band library
into a guest target stops with

    error: build/.../placed/.../libFoundationBackports.dylib is not what the platform runs: a linker
    stamped LC_ENCRYPTION_INFO on a 32-bit ARM library, which iOS 6 refuses to load; link it with ld64

and the band library in the store's own staged tree carries that load command, as does the
`libFoundationBackports.dylib` the sanctioned 8.4.1 gate build wrote, while **Revenant's own ld64 does not
stamp it** - the same trivial armv7 dylib linked both ways on 2026-10-04:

    probe/t-revenant.dylib   LC_ENCRYPTION=0     (clang -fuse-ld=<revenant ld64>)
    probe/t-host.dylib     LC_ENCRYPTION=1     (the host's linker)

`macho.verify`'s `encrypted()` reads that load command on a dylib or a bundle only, which is why the
gate reaches its registry check while a guest target that *carries* the library cannot be placed. So the
measurement this section asks for is blocked one step before the firmware: there is no reason to fetch
1.55 GB of iOS 8.4.1 for an image that could not load a target carrying this band's library. That is a
tree-level question and it is not this page's to answer; what belongs here is that **the 8.x `-resume`
question is still open**, and this is where its answer belongs when the probe can run.

The seven methods are not a CATEGORY on the release's name here, and that is a measured choice too:
a category on `NSURLSessionStreamTask` implements the methods the SDK's own interface declares there,
and clang's `-Wobjc-protocol-method-implementation` says so once per method, which the wave's rules
have no pragma to silence. `CarPlay/CPListItem.m` and `UIKit/NSTextTab.m` each carry that pragma for
the same warning; this file writes the members as a category on Revenant's own name instead, which
ld64 merges into the proxy, and the proxy's method list is what the loader adopts.

## The connection is the release's own, not ours

`+[NSStream getStreamsToHostWithName:port:inputStream:outputStream:]` is
`CFStreamCreatePairWithSocketToHost` and the two halves are bridged into the two stream classes, which
is what iOS 8's own header documents. Measured on the release with
`tools/corpus/cache-value.lua` over the 6.1.3 armv7 cache:

| symbol | the image of 6.1.3 that exports it |
| --- | --- |
| `CFStreamCreatePairWithSocketToHost` | CoreFoundation |
| `CFStreamCreatePairWithSocket` | CoreFoundation |
| `CFStreamCreateBoundPair` | CoreFoundation |
| `CFReadStreamSetProperty`, `CFWriteStreamSetProperty` | CoreFoundation |
| `kCFStreamPropertySocketNativeHandle` | CoreFoundation |
| `kCFStreamPropertySSLContext` | CFNetwork |

Every one of them is public and declared in the SDK's own `CFStream.h` (the SSL context is CFNetwork's,
and CFNetwork.framework is in the iOS SDK). So the resolution, the socket, the buffering, the timeouts
and the native handle are the system's; nothing here reimplements a stream.

**The native handle is inside a `CFData`, not in the value.** `CFStream.h` says what the property
carries, in iPhoneOS16.4 and on the host alike: `kCFStreamPropertySocketNativeHandle` - "Value will be a
CFData containing the native handle". Measured on the host, 2026-10-04, on a pair from
`+[NSStream getStreamsToHostWithName:port:]` opened against a loopback listener of the test's own:

```
kCFStreamPropertySocketNativeHandle is a CFData of 4 bytes
byte 0 = 0x06  byte 1 = 0x00  byte 2 = 0x00  byte 3 = 0x00
the value cast to an int (what this file did)  -> 444811776, getsockname: Bad file descriptor
the four bytes read as an int                  -> 6,            getsockname: 127.0.0.1:62140
```

So `revenant_native_descriptor()` reads the bytes of the `CFData`, and a value that is not a `CFData` or
is shorter than a descriptor is refused by name rather than read as bytes that are not there. That was
the whole of `localAddress`, `localPort`, `remoteAddress` and `remotePort` answering nil, and it was
not a property of the host: the property is a `CFData` here and on iOS alike, so the four rows are the
port's own and the host differential
(`tests/backports/host/streammetrics`) now compares them against the system's answer for the same
socket. Two other public properties of the same object were measured for the record and are not needed:
`kCFStreamPropertySocketRemoteHostName` answers `"127.0.0.1"` and `kCFStreamPropertySocketRemotePortNumber`
answers the listener's port, while there is no public property for the local end at all - the three
socket properties in `CFStream.h` are the native handle, the remote host name and the remote port.

`+[NSStream getBoundStreamsWithBufferSize:inputStream:outputStream:]` is guarded to macOS by the 26.2
header and is named by the iOS surface, so it is carried: the release exports the function, and a pair
bound to a port is what the method promises.

## What the task adds

The task's own bookkeeping: the two streams, the half-closes, the read and the write with their
completion handlers, the secure connection, and three of the four delegate callbacks -- the read side
closing, the write side closing, and the streams being handed over. Each is sent only when the session's
delegate answers to that selector, which is what the header's `@optional` protocol is for, and each goes
on the session's delegate queue where the session has one.

`-init` is carried and `+new` is not. The header **deprecates** both with "please use
`-streamTaskWithHostName:port:` or other NSURLSession methods to create instances", and a deprecation
is a warning rather than a refusal: the port answers `-init`, which is what the release's own
`-[NSURLSessionTask init]` does, and its own factory calls `-initWithSession:hostName:port:`, which
goes through it. The registry says the same thing — `-[NSURLSessionStreamTask init]` is `implemented`
with that reason, and `+[NSURLSessionStreamTask new]` is `absent` because the port does not define a
`+new` that bypasses the factory. What an application should do is what the header says: ask the
session for the task. On the 8.x bands `-init` is the release's own rather than the port's, which is
why nothing in this file depends on it: the state is made on first use (see the section above).

`-stopSecureConnection` is carried and does nothing to a connection that has TLS, because TLS cannot be
taken off a connection once it is on -- which is the header's own reason for deprecating it.

**The negotiated TLS values are asked of the stream only when this task started a TLS session.**
`revenant_negotiated_tls()` reads `kCFStreamPropertySSLContext`, which IS the stream's `SSLContext`, and
then asks the release's own `SSLGetNegotiatedProtocolVersion` / `SSLGetNegotiatedCipher` (both looked up
by name, as the table above says, because this library links neither framework). Asking a stream that
never negotiated does not answer nil: measured on the host, 2026-10-04, `CFReadStreamCopyProperty(stream,
kCFStreamPropertySSLContext)` on an open stream with no TLS session takes the process down before it
returns -- a segfault inside the call, with the key the same flat `dlsym` finds in that process
(`0x1eae53ba8` for the symbol, whose value is the key), so it is the read and not the lookup. So the two
values are read only when `-startSecureConnection` was called on this task, which is the only case where
the release's stream holds a TLS session to ask about. A connection with no TLS reports nil for both,
which is what the host differential measured the system's own transaction saying about one
(`tests/backports/host/streammetrics`, `ok negotiatedTLSProtocolVersion: (nil)`).

## The four delegate callbacks: what the release carries, and which three are sent

The four rows are `absent` for the three that are sent and `inert` for the one that is not, and the two
are different claims, so they are measured separately.

**What the release carries.** From the repository root, with no xmake project and no gate:

```
REVENANT_ROOT="$PWD" xmake l tools/corpus/cache-census.lua NSURLSessionStream 6.1.3 4.3 11.0
```

Its output, in full:

```
6.1.3     $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming NSURLSessionStream 0
         classes 11378, of which NSURLSessionStream* 0
         protocols 1171, of which NSURLSessionStream* 0
4.3       $HOME/.revenant/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming NSURLSessionStream 0
         classes 7187, of which NSURLSessionStream* 0
         protocols 564, of which NSURLSessionStream* 0
11.0      $HOME/.revenant/dyld/11.0/dyld_shared_cache_arm64
         images 1258, of which naming NSURLSessionStream 0
         classes 52768, of which NSURLSessionStream* 2 (NSURLSessionStreamTask NSURLSessionStreamTaskTester)
         protocols 8954, of which NSURLSessionStream* 1 (NSURLSessionStreamDelegate)
control: 3 name(s) beginning NSURLSessionStream found in this run, so a zero on another rung
is the release's and not the reader's
```

The two zeros are the two releases this package deploys on, and the control is in the same run: the
same reader, the same prefix, 11.0 answering with the class, the tester class and the protocol. So
6.1.3 and 4.3 carry neither the class nor the protocol, and the four selectors go with them:

```
xmake l tools/cache-index/first-rung.lua NSURLSessionStreamDelegate \
    'URLSession:streamTask:didBecomeInputStream:outputStream:' 'URLSession:readClosedForStreamTask:' \
    'URLSession:writeClosedForStreamTask:' 'URLSession:betterRouteDiscoveredForStreamTask:'
NSURLSessionStreamDelegate	11.0
URLSession:streamTask:didBecomeInputStream:outputStream:	9.0
URLSession:readClosedForStreamTask:	9.0
URLSession:writeClosedForStreamTask:	9.0
URLSession:betterRouteDiscoveredForStreamTask:	9.0
```

That is presence, not a version: the four selectors are in 9.0's cache, and nothing before it carries
them. The SDK 26.2 surface (`coordination/corpus/sdk-26.2-surface.tsv`, lines 12576-12579) declares all
four at 9.0, which is the registry's own `introduced`.

**What the port sends.** Three of the four, and each one only when the delegate answers to that selector.
The two streams go over when the task is resumed and again when `-captureStreams` hands them over; the
read side is reported once, when the peer's end arrives -- the header's own case, the read side closing
and not this object being told to -- or when the application closes that half; the write side goes over
when `-closeWrite` closes it. The arguments are the ones the header's signatures name, at the indices
those signatures give them, on the session's delegate queue.

**The fourth is never sent, and this page used to say otherwise.** The port's library declares the
protocol, so the selector is in its image and `NSProtocolFromString` answers the name, and no call site
anywhere in the tree sends it. That is what `inert` says, and it is not the same claim as the other
three: the release *can* be asked about a route, and the row before said it could not, which was wrong.
Measured:

```
xmake l tools/cache-index/first-rung.lua _SCNetworkReachabilityCreateWithName _SCNetworkReachabilitySetCallback
_SCNetworkReachabilityCreateWithName	3.0
_SCNetworkReachabilitySetCallback	3.0
```

SystemConfiguration's reachability is in 6.1.3, and this same library already reads it -- `NSURLSession.m`
watches a task's host while that task waits for connectivity (`revenant_task_when_connected`). What those
flags answer is whether the host is reachable and over which kind of interface. The header's message
says the *system* has determined that a better route to the host exists, and gives "a wi-fi interface
becoming available" as its example; a change in the flags is this port's own inference from a
reachability answer, and the header's own warning that a new task may still fail is what such a report
invites a caller to get wrong. So the message is not sent, and the decision is written down at the end
of `-startSecureConnection` in `Foundation/NSURLSessionStreamTask9.m`.

**What was not measured.** The three sends were not run on a device. `tests/backports/device/
foundation15batch.m`, which the four rows cited as the device call test until this revision, holds no
stream case at all -- it is `grep -c stream` zero -- so there is no device measurement of these four
messages and none is claimed. What is measured is the release side above, and the object: it compiles
for armv7 and `tools/release-split.lua` walks it clean.


## One divergence, written down

A stream task made here is **not** in the session's `-getTasksWithCompletionHandler:` list. The port's
session keeps that list in its own storage and `NSURLSession+StreamTask9.m` is a category beside it, so
that method answers the data, upload and download tasks and no stream task. The task is otherwise the
port's own: it opens the pair when it is resumed, reads and writes on the resuming thread's run loop,
and calls the delegate. Carrying the stream task inside the session's own implementation, so that
`-getTasksWithCompletionHandler:` and `-invalidateAndCancel` see it, is the change that closes this.

## The object is split, because the release ladder says it has to be

`xmake l tools/release-split.lua <objects>` over the compiled objects of this delivery named

    release-split: 1 file(s) mix more than one release's symbols: NSURLSessionStreamTask9.o
    NSURLSessionStreamTask9.o  MIXED-RELEASES  9.0,none

because that object held the task's own class -- which a release exports from **9.0** -- and the state
class beside it, which **no release exports at all**. The state class is now in an object of its own
(`RevenantStreamTaskState.m`, declared in `RevenantStreamTaskState.h`), so each object holds one release
group, and the same command over the same objects now names no file.

Run over the object this file's own changes produced, compiled with the tree's clang for
`armv7-apple-ios6.0` against the iPhoneOS 16.4 SDK, it prints the two symbols and one release:

```
xmake l tools/release-split.lua <objects> <out> <iPhoneOS16.4.sdk>
release-split: clean, every object file's symbols first-appear in one release (1 files, 2 symbols, 53 releases checked)
NSURLSessionStreamTask9.o	_OBJC_CLASS_$_NSURLSessionStreamTask	9.0
NSURLSessionStreamTask9.o	_OBJC_METACLASS_$_NSURLSessionStreamTask	9.0
```

The object's four defined Objective-C symbols are the release's name and the class of Revenant's own at
one address each, which is what an alias is:

```
nm -gU NSURLSessionStreamTask9.m.o | grep OBJC_CLASS
000035b4 S _OBJC_CLASS_$_RevenantNSURLSessionStreamTask
000035b4 S _OBJC_CLASS_$_NSURLSessionStreamTask
000035a0 S _OBJC_METACLASS_$_RevenantNSURLSessionStreamTask
000035a0 S _OBJC_METACLASS_$_NSURLSessionStreamTask
```

`release-split` and the band machinery read the two symbols under the release's name (the ones under
Revenant's are filtered out as internal, `internal_symbol()`), so what the object carries is 9.0's API
and nothing else, and one `.m` for release 9 it is. What the tool cannot see, and what a reader has to
check by hand here, is the methods: an Objective-C method implementation is not an exported symbol, so
the four callbacks, the seven task methods and the two factories are all invisible to it, and this
file is the record that they are one release's API together.

