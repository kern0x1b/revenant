# The top of the Metal 4 command chain, and the three measurements that decide how far it goes

**Update:** the four sparse-mapping members (group (c) below, and the `inert` entries they name) are no longer
inert. They refuse each call with the text Metal's own assertion gives, as measured on the macOS 26 host, and
`facts/Metal/SparseMapping26.md` holds the measurements. The account below is the history of the inert version.

Six rows: `MTL4CommandQueueDescriptor` and its two members, `MTL4CommandBufferOptions` and its one,
and `MTL4CommandQueueErrorDomain`. They are plain data holders, they are in
`Metal/MTL4CommandChain26.m`, and every default is Apple's own.

## The commands and their output

```
sh tests/backports/host/metal-census/chain26.sh
```

```
the top of the Metal 4 command chain, against Apple's own objects:
  the port's descriptors are DEFINED in the binary, under their renamed names
  ok   the control: ZZZNoSuchNameRevenantR16 is not a class of this framework
  ok   the control: ZZZNoSuchNameRevenantR16 is not a symbol of anything loaded
  ok   MTL4CommandQueueErrorDomain resolves to a string
  ok   MTL4CommandQueueErrorDomain -> MTL4CommandQueueErrorDomain
the two descriptors, fresh, on both sides
  ok   queue descriptor: label is nil on both sides
  ok   queue descriptor: feedbackQueue is a member on both sides
  ok   queue descriptor: feedbackQueue is nil on both sides
  ok   queue descriptor: the label is a copy, so changing the caller's string changes neither
  ok   queue descriptor: a copy carries the label each side holds
  ok   buffer options: logState is nil on both sides
  ok   buffer options: APPLE's copy carries the member, which is nil here
  ok   buffer options: the PORT's copy carries it too, which is nil here
AND WHY THE QUEUE IS NOT IN THIS CASE, measured from Apple's side
  ok   this machine has a Metal device
  ok   APPLE's device answers -newMTL4CommandQueue, so a live queue is possible here
  ok   and its fresh label is nil, which is the queue's own measured default
  ok   APPLE's own -newCommandQueueWithDescriptor: RAISES here: -[MTL4CommandQueueDescriptor disableIOFencing]: unrecognized selector sent to instance 0x...
  ok   APPLE's own queue does not implement -beginCommandBufferWithAllocator: here: -[AGXG16XFamilyCommandQueue_mtlnext beginCommandBufferWithAllocator:]: unrecognized selector sent to instance 0x...
14 checks
all checks passed
the control: a mutation that does not compile is RUN FAILED, not red
  ok   RUN FAILED: the broken mutation did not build, and the compiler said why
  ok   and no binary was left to run
the mutations: one per thing the port decides here
  red    queue descriptor: the label is a copy, so changing the caller's string changes neither
  red    queue descriptor: a copy carries the label each side holds
chain26: the differential is green, the control is RUN FAILED, and both mutants are red
```

## RETRACTION: two of the three walls in the first version of this page were my own probe's mistakes

The first version of this page reported three walls that stopped the Metal 4 command chain. **Two of
them were wrong, and they were wrong because the probe asked the wrong objects.** Both are retracted here
and the corrected measurement is in the table below.

**RETRACTED 1: "`-[MTLDevice newCommandQueueWithDescriptor:]` raises, in Apple's own code."** That
selector is **Metal 3's** factory. Metal 4's is `-[MTLDevice newMTL4CommandQueueWithDescriptor:error:]`
(MTLDevice.h:1271), and **it answers with a queue and no error when given a real
`MTL4CommandQueueDescriptor`** - measured:

```
   newMTL4CommandQueueWithDescriptor:error: (a REAL descriptor) -> a queue, error (nil)
```

What raises is Metal 3's `newCommandQueueWithDescriptor:` handed a **Metal 4** descriptor: Apple's Metal 3
queue sends `-disableIOFencing` to it, which the 26.2 descriptor does not have. So the exception was
never Metal 4 refusing anything; it was my probe handing a Metal 4 object to a Metal 3 call.

**RETRACTED 2: "there is no Metal 4 command buffer to compare against on this machine."**
`-beginCommandBufferWithAllocator:` is a method of **`MTL4CommandBuffer`** (MTL4CommandBuffer.h:71), not
of the queue, and the probe sent it to a queue - where it is trivially absent, because it is not that
object's method. The buffer comes from `-[MTLDevice newCommandBuffer]` (MTLDevice.h:1278) and the
allocator from `-[MTLDevice newCommandAllocator]` (MTLDevice.h:1240). Asked properly, **the whole live
chain exists on this machine**, and it is in the table.

What survives is the fourth wall, which was never about Apple's answers at all: the port's own queue and
everything under it are EAGL-backed, and `OpenGLES/EAGL.h` is a device framework, so no **host** case can
build them. That is why the oracle is a captured table and the port's chain is verified on the device.

## The expectations table, and how to regenerate it

`tests/backports/host/metal-census/chain-expectations.txt` is Apple's own output, committed. It is
produced by a script, so a future SDK that changes an answer shows up as a **diff on the table** rather
than as a claim in a commit message:

```
sh tests/backports/host/metal-census/chain-oracle.sh > tests/backports/host/metal-census/chain-expectations.txt
```

The port's chain is checked against that table by a HOST-FREE case on the device or in the emulator, and
every row whose answer depends on the GPU is recorded as a difference rather than asserted - see the
last section.

**THE TABLE REGENERATES BYTE FOR BYTE, and that had to be arranged**: Apple's `-description` carries the
object's ADDRESS, so a table built from it differed on seven lines every run and `git diff` on the
committed table was always dirty - which is the one thing a table in a repository must not be. Every
object in it prints as `<ClassName>` and never as a pointer. Verified by running it twice:

```
$ sh tests/backports/host/metal-census/chain-oracle.sh > /tmp/exp2.txt && \
    diff tests/backports/host/metal-census/chain-expectations.txt /tmp/exp2.txt && echo IDENTICAL
IDENTICAL on a second run
```

### What the live chain answers on this machine

```
the device: Apple M4 Pro
ZZZNoSuchNameRevenantR16 -> nil (right)

MTL4CommandQueue, both ways the 26.2 header declares them
   newMTL4CommandQueue -> <AGXG16XFamilyCommandQueue_mtlnext>
   a fresh queue's label              -> (nil)
   its device                         -> <AGXG16SDevice>
   newMTL4CommandQueueWithDescriptor:error: (a REAL descriptor) -> a queue, error (nil)

MTL4CommandAllocator, MTLDevice.h:1240
   newCommandAllocator -> <AGXG16XFamilyCommandAllocator_mtlnext>
   label                              -> (nil)
   device                             -> <AGXG16SDevice>

MTL4CommandBuffer, MTLDevice.h:1278
   newCommandBuffer -> <AGXG16XFamilyCommandBuffer_mtlnext>
   a fresh buffer's label             -> (nil)
   device                             -> <AGXG16SDevice>
   commandQueue                       -> not a member of AGXG16XFamilyCommandBuffer_mtlnext
   status before begin                -> not a member of AGXG16XFamilyCommandBuffer_mtlnext

beginCommandBufferWithAllocator:, MTL4CommandBuffer.h:71
   beginCommandBufferWithAllocator: answered without raising
   status after begin                 -> not a member of AGXG16XFamilyCommandBuffer_mtlnext

the two encoders
   renderCommandEncoderWithDescriptor: -> (nil)
   computeCommandEncoder -> <AGXG16XFamilyComputeContext_mtlnext>
   compute encoder label              -> (nil)
   compute encoder commandBuffer      -> <AGXG16XFamilyCommandBuffer_mtlnext>
   compute pushDebugGroup: answered
   compute popDebugGroup: answered

endEncoding on each encoder that exists, then endCommandBuffer
   compute endEncoding answered
   endCommandBuffer answered
   status at the end                  -> not a member of AGXG16XFamilyCommandBuffer_mtlnext

and the queue's commit, which is NOT ASKED and why
   -[MTL4CommandQueue commit:count:] with an ENDED buffer: Segmentation fault in Apple's
       own framework, measured (exit 139) - so the row is recorded as not answerable
       rather than measured, and the port refuses it instead of calling through
```

Three of those lines are answers a reader would not guess, and two of them are absences:

* **`MTL4CommandBuffer` HAS NO `status` AND NO `commandQueue` MEMBER.** Measured with
  `respondsToSelector:` first, after a `valueForKey:@"status"` raised `NSUnknownKeyException` and killed
  the first run - so the port's buffer must not grow either, and its status is whatever the queue's commit
  leaves rather than a property of its own.
* **`renderCommandEncoderWithDescriptor:` ANSWERS nil for a fresh `MTL4RenderPassDescriptor`** - no
  attachments, no exception. That is the shape the port has to match.
* **`commit:count:` SUCCEEDS, ON BOTH PATHS, IN A PROCESS OF ITS OWN.** This row was wrong twice before
  it was right, and both corrections are the coordinator's.

  **The first mistake: the C array.** `commit:(const id<MTL4CommandBuffer> _Nonnull[_Nonnull])commandBuffers`
  (MTL4CommandQueue.h:231) declares an array of buffers, and `commit:count:` passed ONE buffer where an
  array was expected, so the framework read the object's own memory as the array's first element. The
  Segmentation fault that produced was mine, and the "this row is not answerable" conclusion that came
  with it went with it.

  **The second mistake: `fork()`.** The re-measurement forked a child from a process that already held a
  device, a queue, an allocator and a buffer. **Metal is not fork-safe**, so a signal from such a child
  says something about the fork and nothing about the commit - and the signal was 11, where an assertion
  would have been 6 (SIGABRT).

  **The third thing was worse than either: a fabrication.** That version printed a line beginning
  `Assertion failed:` and naming `IOGPUMetal4CommandQueue.mm, line 360` **from a fixed string, on any
  signal**. Apple's words, typed by me, presented as a capture. It is deleted; `grep -c "Assertion failed"`
  over the case is 0. A printed imitation of a measurement is worse than no answer, because it survives
  review as data.

  **THE MEASUREMENT, in a process EXECed on its own** - `sh tests/backports/host/metal-census/chain-commit.sh`,
  which is the shape `descriptors26-samplebounds.sh` uses for the same reason. Apple's documented sequence
  runs there in one process per form, with the allocator a local that outlives the commit and is read
  after it, and **both of the process's streams and its exit status are recorded as they are**:

  ```
  ===== form ended =====
  | chain-commit: form ended, process 53532
  |   the device: Apple M4 Pro
  |   allocator AGXG16XFamilyCommandAllocator_mtlnext, queue AGXG16XFamilyCommandQueue_mtlnext, buffer AGXG16XFamilyCommandBuffer_mtlnext
  |   beginCommandBufferWithAllocator: answered
  |   endCommandBuffer answered
  |   about to call: id<MTL4CommandBuffer> list[1] = { buffer }; [queue commit:list count:1];
  |   commit:count: returned
  |   the queue has no -waitForCommandBuffers:, so nothing was waited on
  |   the allocator is still alive after the commit: yes
  | chain-commit: form ended reached the end of main
    the process exited 0

  ===== form open =====
  | chain-commit: form open, process 53540
  |   ... the same, with endCommandBuffer DELIBERATELY NOT CALLED ...
  |   commit:count: returned
    the process exited 0
  ```

  So: **a Metal 4 commit returns, on the header's own path and on the un-ended one alike, and the process
  finishes.** Nothing is raised, nothing is asserted, and stderr is empty in both forms.

  **AND THERE IS NO QUEUE-LEVEL WAIT FOR COMMAND BUFFERS**, which the same run shows: the queue has no
  `-waitForCommandBuffers:`, and `MTL4CommandQueue.h` agrees - its only waits are
  `-waitForEvent:value:` (:274) and `-waitForDrawable:` (:308). That is a real fact about Metal 4 and it is
  the reason the port's queue needs no such member.

## The three measurements the first version gave, and what stands of them

The queue, its two device factories and the capture scope over it are **not** in this page, and each of
the three walls is measured rather than assumed. All three are printed by the case above, from Apple's
own side.

**1. A LIVE METAL 4 QUEUE IS POSSIBLE ON THIS MACHINE, so that is not the reason** - this one stands, and
it is now the first row of the table above.

**2. RETRACTED - see the retraction above.** Metal 4's descriptor factory answers with a queue and no
error. What raises is Metal 3's factory handed a Metal 4 descriptor.

**3. RETRACTED - see the retraction above.** The live command buffer, allocator, compute encoder and the
whole path down to `endCommandBuffer` exist and are measured in the table.

**4. AND THE PORT'S OWN QUEUE IS AN EAGL OBJECT, which stands**, which is a different wall and the reason *this* file
holds only the two descriptors: the queue is a wrapper over the port's `RevenantMetalQueue`, which holds an
EAGL context over OpenGL ES 2.0, and `OpenGLES/EAGL.h` is a DEVICE framework. That is why
`MTL4CommandChain26.m` does not import `RevenantMetal.h` - a host case that `#include`s the file could not
compile it - and why the two descriptors, which hold only values, are measurable while the queue is not.

So the six rows here are the ones whose behaviour can be checked against Apple's own objects, and the
queue with the rest of the chain waits for a decision about how an EAGL-backed object is verified. Each
of the six rows' `effect` says that.

## One harness defect worth naming, because it is the purest form of the control's trap

The control that proves "a mutation that does not compile is RUN FAILED, never red" first named its
scratch file `broken.m.tmp`. **clang does not recognise a `.tmp` extension as a source file**: it
compiled nothing, reported success, and the control passed because no compiler ran. The scratch is
`broken.m` now, and the control also requires an `error:` line in the log - a control that fails because
nothing ran is the same defect as one that fails for the wrong reason.

## What the landing gate of 2026-10-04 found, and the conformance that answers it

The gate for the 6.1.3 band on `land-w19` failed with

```
error: the registry does not describe what the backports carry:
  listed as implemented, but nothing of that name is built: -[MTL4CommandQueue addResidencySet:]; ...
  MTL4CommandQueue.device; MTL4CommandQueue.label
```

**All ten are rows whose spelling names the PROTOCOL, and the check counts a member row from the protocol
object's method list** - `carried_api()` over `objc.binary_inventory` (`modules/apple/backports.lua:1523`) - and
not from a `Revenant*` class's own methods, the port's own classes being its machinery and not names it carries.
The methods were on `RevenantMetal4CommandQueue` and the protocol was nowhere, so ten rows had nothing to answer
for. The four `inert` rows did not fail because only `implemented` rows are held to it.

**THE FIX IS THE CONFORMANCE, and the corpus asked for it**: `MTL4CommandQueue` in
`coordination/corpus/ledger-2026-10-03/Metal.tsv` is a `protocol` row at 26.0 with status `header-ok` and
`needs lift`. `@protocol MTL4CommandQueue` is transcribed into `RevenantMetalProtocols.h` by
`tools/transcribe-protocols.py@52253c0650` - facts only: the base list, every member with its types, `@required` and
`@optional` as sections, and `API_AVAILABLE(ios(26.0))` - and `RevenantMetal4CommandQueue` declares conformance,
which is the only thing that makes clang emit `__OBJC_PROTOCOL_$_MTL4CommandQueue` and its method list. That
tool's own comment carries the measurement: importing the header, using `id<name>` and naming it in
`@protocol()` each emit none of it, and only a declaration that adopts it emits the object.
`conforming_protocols()` then finds this file as the emitter, so the generated per-band source
`MetalBackportsProtocols26.m` does not force the object a second time - the duplicate that
`modules/apple/backports.lua` refuses.

**THE TRANSCRIPTION NEEDED TWO THINGS THE TOOL DID NOT DO**, both measured on 2026-10-04 and both fixed in the
tool rather than in a header written by hand:

* **a type only the 26.2 SDK declares that is not a class.** `MTL4UpdateSparseTextureMappingOperation` and its
  three siblings are typedefs of anonymous structs, and `gather()` returned only ObjC interfaces as the 26.2
  class set, so the tool refused the whole protocol by name for them: `refused: MTL4CommandQueue.
  updateTextureMappings:heap:operations:count: needs MTL4UpdateSparseTextureMappingOperation, which
  iPhoneOS16.4.sdk does not declare`. It keeps the kind of every non-class type now, and writes the declaration
  C needs.
* **a protocol a member's type names that the 16.4 SDK declares nowhere.** `id<MTL4CommandBuffer>` in the two
  commits and `id<MTLResidencySet>` in the four residency members: the 16.4 SDK has no Metal 4 and
  `MTLResidencySet` arrived after it, so the header did not compile at all - "cannot find protocol declaration
  for 'MTL4CommandBuffer'", "no type or protocol named 'MTLResidencySet'". Those are forward declarations now,
  and only those: a protocol the SDK declares is not declared again, and one this file declares with a body is
  not declared twice.

**AND THE TRANSCRIPTION FOUND A SELECTOR THE PORT HAD WRONG**: `heap:operations:count:` over four parameters
for the two update-mapping members, where the port and its rows said `heap:count:` over three. The corpus named
the header's spelling all along - `-[MTL4CommandQueue updateBufferMappings:heap:operations:count:]` - and
nothing compared it, because a `Revenant*` class's methods are what the gate does not count. The same
transcription is what says Metal 4's `label` is `@property (readonly, nullable)` and atomic, so the queue's own
is readonly and atomic too, and the descriptor factory reaches it through `-revenantSetLabel:` - the port's own
seam, in the shape of `-[UIPasteboard revenantRecordOptions:]`, with a row of its own.
## Two more, both in the assertions rather than the code

* **A COPY CARRIES WHAT THE DESCRIPTOR HOLDS.** The case first compared a copy against the caller's
  *mutated* string; measured against Apple's own object the copy reads back the label as it stood when it
  was set. The assertion was wrong and the measurement corrected it, and each side's copy is now compared
  to that side's own descriptor.
* **`dlsym` READ THE ADDRESS OF A VARIABLE AS AN OBJECT POINTER.** The error domain's value was first
  fetched with `dlsym` and `[(__bridge id)symbol description]`, which is a Bus error before any output at
  all. It is declared through an asm label now, which reaches the exported variable itself.

## The port's queue, and what is still unverified about it

`Metal/MTL4CommandQueue26.m` carries the Metal 4 queue: the class itself, the device's two factories
and the capture scope over one. It is a **separate file from the two descriptors** because it imports
`RevenantMetal.h`, which reaches `OpenGLES/EAGL.h` -  so the descriptors are host-measurable and this is
not, and the split is the honest shape of the thing:

```
$ clang -target arm64-apple-macos26.0 ... -fsyntax-only MTL4CommandChain26.m   -> builds on a host
$ clang -target arm64-apple-macos26.0 ... -fsyntax-only MTL4CommandQueue26.m   -> does NOT build on a host, as it must not
```

**The package's compile line for `MTL4CommandQueue26.m` carries NO `-I` AT ALL**, measured rather than
assumed - `backports.compile_arguments` over that source in this tree, which is the same function the gate
compiles every backport with (`modules/apple/backports.lua:554-558`, and a library's own sources get no
`includes` of their own - line 928 sets that only for the generated per-band protocol sources):

```
source: .../packages/a/apple-backports/Metal/MTL4CommandQueue26.m
-I flags:
  (none)
everything else: -Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability
                 -Werror=objc-missing-property-synthesis -fmacro-prefix-map=<root>/=
```

So this file reaches `RevenantMetal.h` and `RevenantMetal26Types.h` the way clang resolves a quoted include -
in the including file's own folder - and nothing from another backports folder is on its path at all.

**A BARE SYNTAX CHECK OF THESE TWO FILES GIVES 0 ERRORS AND 5 `-Wunguarded-availability-new` WARNINGS**,
which were 7 before the queue's members moved off the device: `MTLHeapType` and `MTLHazardTrackingMode`
from `RevenantMetal.h:181-182`, `MTLGPUAddress` from `RevenantMetal26Types.h:320` and `MTL4CommandQueueDescriptor`
twice from the two factories. **The library build itself has none of them**, because the package compiles
with `-Wno-unguarded-availability-new -Wno-unguarded-availability` as the line above shows; the two numbers
are of different commands and this page now says which is which. `MTLEvent` is spelled `id` in this file's
event methods rather than `id<MTLEvent>`, which is what takes the count from 7 to 5: iOS 6 has no
`MTLEvent` to name and the SDK annotates the type 12.0 and later, while the selector is the header's either
way, which is what a caller and the registry both see.

**The queue is the port's own `RevenantMetalQueue` under a Metal 4 name.** There is one queue in this port
and it is the one that holds the EAGL context every draw goes through, so a Metal 4 caller asking for a
Metal 4 queue gets the queue that works. `device` answers the port's shared device -  the same answer a
Metal 3 caller gets -  and `label` is nil on a fresh queue and copied when set.

**`commit:count:` COMMITS rather than refusing**, through to the queue underneath, and the C array is
spelled as MTL4CommandQueue.h:231 declares it. That is the row whose three earlier answers were all
wrong, and the measured answer is that the call returns. **It answers on the QUEUE**, which it did not
until the device probe asked: it was written in the `RevenantMetalDevice` category with every other member
of the protocol, so the device answered all fourteen of them and the queue none - see the run below.

**The other twelve members are NOT all refusals, and the first version of this page said they were.** They
are sorted by what this backend actually is - six whose no-op is the right answer and which therefore say
nothing, two that do real work over the port's own event, and four that cannot be done here and say so once
as `inert` - and the sort, with the facts line behind each group, is below. **There is no
`-waitForCommandBuffers:`**, because Metal 4's queue has none either.

### What the device probe measured, and what is still not verified

**THE PROBE HAS NOW RUN**, on the emulated iPhone3,1 6.1.3 10B329, on 2026-10-04, and this section is what
it said. `tests/backports/device/metalchain-probe` is a small xmake project of its own in the shape of
`vdsp-probe` and `textkit2`: a `@addon/revenant/daemon` target, a `control` file, `run.sh` and `run-guest.sh`.
It builds the port's own Metal folder (59 files, 60 objects with the probe) rather than linking
`libMetalBackports.dylib`, because the shape that links the package does not resolve on this machine today -
`add_requires("revenant@apple-backports", ...)` fails at configure with `error: attempt to call a nil value
(global 'add_configs')`, in a four-line project as well as in this one, and passes an hour later with
nothing in the tree changed. `tests/backports/device/metalchain-probe/xmake.lua` says what that costs: the
probe tests every object the library carries and not the `.deb`.

`metalchain.m` asks **all fourteen** constants of `tests/backports/device/metalchain-expectations.h`, each
by name, and prints `ok`, `FAIL` or `NOT ANSWERED` with the constant's name, so a verdict joins to an
expectation without reading the file. It asks thirteen more besides: the twelve members of
`@protocol MTL4CommandQueue` the port refuses by name, and the capture scope over a Metal 4 queue. A case it cannot reach says which of the two reasons it is - the port
has no such object, or the guest has none to ask - and counts as a failure; nothing is skipped quietly.

```
$ sh tests/backports/device/metalchain-probe/run.sh          # configure, install, the LC_UUID gate
built     LC_UUID F1938D6F-DD61-37FE-BB06-00E0C6AE800C
installed LC_UUID F1938D6F-DD61-37FE-BB06-00E0C6AE800C
installed mtime   0
the two carry the same LC_UUID, so this image holds this build
HASHES MATCH
$ $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/metalchain-probe/run-guest.sh
```

and the run itself:

```
metalchain: the port's Metal 4 chain against Apple's own answers
     an EAGLContext over OpenGL ES 2.0 on this guest: NIL
     an EAGLContext over OpenGL ES 1.1 on this guest: NIL
     MTLCreateSystemDefaultDevice: nil
NOT ANSWERED the_port_device_answers: MTLCreateSystemDefaultDevice gave nil, and the EAGL context line above says why
NOT ANSWERED metalchain_queue_is_vended: there is no device to ask for a queue
NOT ANSWERED metalchain_queue_from_descriptor_has_no_error: there is no device to ask, and the descriptor factory is a method on it
     the Metal 4 queue is RevenantMetal4CommandQueue
ok   metalchain_queue_label_is_nil: a fresh queue's label is nil
ok   metalchain_queue_keeps_its_label: the label the queue is given is the label it answers
NOT ANSWERED metalchain_queue_has_device: the port's queue answers the port's shared device, and there is none on this guest
ok   metalchain_queue_has_no_wait_for_command_buffers: the queue has no such wait
ok   the_ports_own_queue_answers_as_apples_does: the queue under test is an instance of the port's own RevenantMetal4CommandQueue
NOT ANSWERED metalchain_buffer_has_no_status: there is no device to ask for a buffer
... (eight more, the same reason)
FAIL metalchain_commit_returns: the queue answers -commit:count: (Apple's own queue does)
FAIL metalchain_commit_returns_when_not_ended: the queue answers -commit:count: (Apple's own queue does)
ok   MTL4CommandQueue_refusal: the port's -[MTL4CommandQueue addResidencySet:] returns and does not raise
... (twelve of those, one per member the port refuses by name)
ok   MTLCaptureScope_over_a_Metal4_queue: -[MTLCaptureManager newCaptureScopeWithMTL4CommandQueue:] answers a scope over the port's queue
metalchain: 31 check(s), 2 failure(s), 12 not answered
error: fail(exit 1) on iPhone3,1 6.1.3 (10B329) in 0.0 guest s / 4.2 host s at time scale 10
run-guest.sh: 12 refusal(s) reported, 12 refusal line(s) in the guest output
```

**THE TWO COMMITS ARE `owed`, NOT DEFINED, and the run says so.** Both take an array of
`MTL4CommandBuffer` and this port carries no `MTL4CommandBuffer`, so a defined `-commit:count:` would refuse
every buffer a caller could hand it and be right about none; a row that is not `implemented` may not have an
answer the build gives (`modules/apple/backports.lua:2062-2071` collects those into `answered`). The
declarations and the bodies are out of the file, the rows carry the reason "waits on the MTL4CommandBuffer
family", and the two FAIL lines above are what that state looks like from a case.

**THE TWELVE MEMBERS ARE SORTED BY WHAT THIS BACKEND ACTUALLY IS**, because a member that logs "refused"
and returns while its row says `implemented` is a stub. Four groups, and the sort is the claim:

| group | members | status | what the probe asks, on the guest |
| --- | --- | --- | --- |
| (a) the no-op IS the answer | the four residency-set members, the two drawable members | `implemented`, and **no member prints a line** | all four residency members return, and nothing is printed for them |
| (b) done over the port's own objects | `signalEvent:value:`, `waitForEvent:value:` | `implemented` | a `RevenantMetalSharedEvent` is signalled through the queue, the value reads back as 7, and the wait returns at once for it |
| (c) not possible here | the four sparse-mapping members | `inert` | each called TWICE, and the guest's output carries exactly ONE line for it |

The evidence for the sort, one line each: **every resource of this port is CPU-resident whatever the
application asked for** - a buffer is its own bytes and a texture is read and written on the CPU
(`facts/Metal/Blits.md`, "The access hints", and `facts/Metal/Heaps.md`, "Hazard tracking and storage
modes") - so a residency set has nothing to make resident and nothing to unmake it from. It is the same
shape as `-optimizeContentsForCPUAccess:` in that file: doing nothing, because what the call asks for is
already so. The drawable pair rests on the same measured fact that a draw is a call into OpenGL ES 2.0 that
**has already been made by the time it is encoded**, so a drawable is never waiting for anything and never
waiting to be told; `-waitForDrawable:`'s own header says it "returns immediately and doesn't perform any
synchronization on the current thread". The sparse mappings cannot be done because **`MTLHeapTypeSparse` is
refused at creation** and no heap this port makes is one: "a heap is already all of memory and is never
paged" (`facts/Metal/Heaps.md`), so there is no mapping to update and none to copy. `inert` means "declared,
does nothing, and says so once in the log the first time it is used" (`registry/README.md`), and the four now
say so through one helper in the shape of `-[AUAudioUnit revenant_noteInert:why:]` from
`AVFAudio/AUAudioUnit9.m`.

**THE EVENTS DO REAL WORK, and the guest can check it.** `RevenantMetalSharedEvent` carries a state of its own
- a signalled value, a setter, and a wait that blocks until the value is reached
(`Metal/MTLSharedEvent12.m`) - and `@protocol MTLSharedEvent` refines `MTLEvent` in the 26.2 SDK
(`MTLEvent.h:52`), so the port's own event is an `MTLEvent` by shape. It needs no EAGL context, so both are
reachable there:

```
ok   MTL4CommandQueue_signalEvent: -signalEvent:value: returns (yes), and the value reads back as 7, asked for 7
ok   MTL4CommandQueue_waitForEvent: -waitForEvent:value: returns at once for a value the port's event has reached
expected refusal lines: 4
metalchain: 29 check(s), 2 failure(s), 12 not answered
run-guest.sh: 4 refusal line(s) in the guest output, 4 expected
```

**The two failures are the two `owed` commits** and nothing else. Four `Metal:` lines for four `inert`
members, one each, from eight calls - which is the `inert` contract measured rather than asserted.

### The third harness defect in this probe, and it is the same family as the arity one

A helper typed `(id, SEL, id, NSUInteger)` was used for the two members whose last argument is a
**`uint64_t`**, which on armv7 is a register pair: the high word was whatever was in the next register, and
the run printed the value it read back - `FAIL MTL4CommandQueue_signalEvent: -signalEvent:value: returns
(yes), and the value reads back as 44392781971463, asked for 7`. Low word 7, high word rubbish. The fix is a
helper typed `(id, SEL, id, uint64_t)`, and the second run reads back 7. A probe's own signature is part of
what it measures, and printing the number it got is what turned this from "the signal does not work" into
"the probe sent the wrong width".

### Two more harness defects, one of them mine and one of them a correction

* **THE GUEST'S OUTPUT CARRIES THE REFUSAL LINES, and I first wrote that it did not.** The claim came from
  `grep -c "Metal:" run/emulator.log` returning 0, and it was true of THAT file and wrong about the run:
  `xmake emulate run` puts the guest's stdout and stderr in `run.log`, and the run of 2026-10-04 carries
  `metalchain-probe[12:203] Metal: a residency set is refused: ...` for each member. The rows and the
  comment in `metalchain.m` said the opposite and both are corrected here.
* **AN ARITY GUESSED FROM A SELECTOR CRASHED THE GUEST, and the fault says exactly which argument was
  wrong.** The first version of the refusal loop sent `updateBufferMappings:heap:operations:count:` - three arguments
  after the selector - through the two-argument call, so `heap` arrived as the integer `1`, and ARC's
  `objc_storeStrong` for the parameter retained it as an object. The guest died with
  `[cpu] fatal pid=12 pc=0x38dcc522 lr=0x38ddab87 fault=0x1 access=0x1 size=0x4` and
  `[control] thread ... frames=0x1d7f7,...`, and `0x1d7f7` is inside
  `-[RevenantMetal4CommandQueue updateBufferMappings:heap:operations:count:]` in the probe binary. A SIGBUS or a SIGSEGV
  on an address that is a small integer is an argument-count mistake before anything else, and the table of
  members in `metalchain.m` now carries each one's arity rather than matching on `:count:`.

**WHAT IT FOUND, and it is a defect this page did not have: the queue had no members of its own.** The
first run of the day read `metalchain: 18 check(s), 2 failure(s), 12 not answered`, and the two failures
were `metalchain_commit_returns` and `metalchain_commit_returns_when_not_ended` with the line
`FAIL metalchain_commit_returns: the queue answers -commit:count: (Apple's own queue does)`. Every member
of `@protocol MTL4CommandQueue` below `-commit:count:` was written in the `RevenantMetalDevice` category, so
all fourteen answered on the **device** and none on the queue. `nm` on the probe agrees:
`-[RevenantMetalDevice(RevenantMetal4CommandQueue26) commit:count:]` and nothing of that name on
`RevenantMetal4CommandQueue`. They are on the queue now (commit `c102d8edf`), and the twelve that came with
them were then sorted by what this backend is, which took the run from `0 failure(s)` with twelve rows
claiming a refusal the code did not make to `29 check(s), 2 failure(s)` with the two failures being the two
`owed` commits and nothing else.

**WHAT IS STILL NOT VERIFIED, in two named parts.**

1. **The guest cannot make an EAGL context, so every case that needs the port's device is unreachable
   there.** The probe asks for one itself, over ES 2.0 and over ES 1.1, and both answer `NIL`; the run's
   emulator log names the renderer as `Revenant GLES 1.1 Vulkan (SwiftShader Device (LLVM 10.0.0))`. Since
   `RevenantMetalDevice -init` is an `EAGLContext` and returns nil without one
   (`Metal/RevenantMetalDevice.m:30-38`), `MTLCreateSystemDefaultDevice()` answers nil there and the four
   cases `the_port_device_answers`, `metalchain_queue_is_vended`,
   `metalchain_queue_from_descriptor_has_no_error` and `metalchain_queue_has_device` have no object to ask.
   **This is the emulator, not the port**: on hardware the same context is what `facts/Metal/RenderPath.md`
   records an iPhone 4S making at 6.1.3. Answering those four needs a real device, and none is attached
   (`idevice_id -l` prints nothing), so it waits for one rather than being claimed.
2. **The port carries no `MTL4CommandBuffer`, so the ten cases about one cannot be asked at all.** That is
   the next family - the buffer, the allocator and the two encoders - and the eight buffer cases and the two
   commit cases are `missing` in `coordination/corpus/ledger-2026-10-03/Metal.tsv` with reason "no class or
   protocol MTL4CommandBuffer in the built libraries". The queue's half of the commit is measured (it
   answers `-commit:count:` now); the buffer's half is not there to measure.

**THE TWO RUNNER DEFECTS THIS RUN MEASURED**, both of which had stopped a good run rather than a bad one:
the image was found with a `metalchainprobe-*` glob, and `xmake emulate` names an image after the project
**directory** (`plugins/emulate/main.lua`: `(project.name() .. "-" .. hash.strhash32(os.projectdir()))`),
so with two copies of this project the gate compared this build against v-metal's installed copy. And the
gate compared mtimes, where the installed copy reads `mtime 0` on this image - so it stopped a run whose two
LC_UUIDs were the same value. `run.sh` now asks xmake for the image's name and gates on the UUID alone.
