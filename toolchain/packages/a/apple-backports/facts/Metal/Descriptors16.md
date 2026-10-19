# The 16.0 descriptors: what they are, what Apple's own objects answer, and what a caller gets

Four rows of `registry/Metal/absent_Metal.json` sat at `absent` with the SDK's own declaration as
their whole `source`, which is an assertion. Three of them - `MTLAccelerationStructurePassDescriptor`,
`MTLAccelerationStructurePassSampleBufferAttachmentDescriptor` and
`MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray` - were the same object member for
member as `MTLComputePassDescriptor`'s own family, which this port already carries, so they were not
blocked on anything and are now `implemented` with the object in `Metal/MTLDescriptors16.m`. The
fourth, `MTLIOCommandQueueDescriptor`, is data in the same way and is carried for the same reason,
with the queue it describes left absent and saying so.

**The claim, in one line:** all four are plain data holders that ask the device nothing, so they are
carried exactly, and nothing in this port applies any of them - which is stated in each row rather
than left for a caller to find out.

## The commands, and their output

Everything below was run from the repository root. The differential is the one that has to be re-run
by a reviewer, and it is the one that ends the row:

```
sh tests/backports/host/metal-census/descriptors16.sh
```

It builds the port for this host with the four classes renamed (`charonHost_…`), proves with `nm` that
the port's own classes - not the host framework's - are the ones in the binary, compares every
property with Apple's own object of the same class, and then runs six mutations, one per class and
one per member nothing else in the file shares. Its run ends:

```
  the DEVICE object defines all 4 under Apple's own names: _OBJC_CLASS_$_MTLAccelerationStructurePassDescriptor and 3 more
  the port's classes are DEFINED in the binary: 4 of 4
MTLAccelerationStructurePassSampleBufferAttachmentDescriptor
  ok   fresh: sampleBuffer is nil on both sides - and it is NOT measured, for the reason in the facts file
  ok   fresh: startOfEncoderSampleIndex: the port 18446744073709551615 and Apple's own object 18446744073709551615
  ok   fresh: endOfEncoderSampleIndex: the port 18446744073709551615 and Apple's own object 18446744073709551615
  ok   fresh: startOfEncoderSampleIndex is MTLCounterDontSample, the header's 'no sample'
  ok   after a set: startOfEncoderSampleIndex = 3: the port 3 and Apple's own object 3
  ok   after a set: endOfEncoderSampleIndex = 4: the port 4 and Apple's own object 4
  ok   copy: startOfEncoderSampleIndex: the port 3 and Apple's own object 3
  ok   copy: endOfEncoderSampleIndex: the port 4 and Apple's own object 4
MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray
  ok   a fresh pass descriptor's array is there on both sides, and the port's needs no device
  ok   four reads of indices 0 to 3 each answer an attachment on Apple's side
  ok   four reads of indices 0 to 3 each answer an attachment on the port's side
  ok   the four slots are four distinct attachments on Apple's side
  ok   the four slots are four distinct attachments on the port's side
  ok   two reads of one index are the same attachment on both sides: an unwritten slot is kept
  ok   after a write at 1: startOfEncoderSampleIndex: the port 11 and Apple's own object 11
  ok   after a write at 1: endOfEncoderSampleIndex: the port 12 and Apple's own object 12
  ok   a write copies: the attachment read back is not the one handed in, on either side
  ok   slot 0 after the write at 1: unchanged on both sides: the port 18446744073709551615 and Apple's own object 18446744073709551615
  ok   after a nil write at 1: startOfEncoderSampleIndex is back to the default: the port 18446744073709551615 and Apple's own object 18446744073709551615
  ok   after a nil write at 1: endOfEncoderSampleIndex is back to the default: the port 18446744073709551615 and Apple's own object 18446744073709551615
  ok   a nil write resets the slot to a NEW default attachment, on either side
       raised NSInvalidArgumentException: objectAtIndexedSubscript:: attachmentIndex(4) must be < 4
  ok   index 4 is refused by the port: no attachment is handed back
MTLAccelerationStructurePassDescriptor
  ok   both sides are a kind of the class the case names; Apple's is a private subclass of it
  ok   sampleBufferAttachments is there on a fresh descriptor on both sides
  ok   a copy of the pass descriptor is made on both sides
  ok   a copy's array is a different object from the original's, on either side
  ok   slot 2 of the ORIGINAL after a write through the copy's array: unchanged on both sides: the port 18446744073709551615 and Apple's own object 18446744073709551615
MTLIOCommandQueueDescriptor
  ok   fresh: maxCommandBufferCount - Apple's own default, which the header does not state: the port 64 and Apple's own object 64
  ok   fresh: Apple's own maxCommandBufferCount is 64, the number the port carries
  ok   fresh: priority: the port 1 and Apple's own object 1
  ok   fresh: priority is MTLIOPriorityNormal, NOT the enumeration's own zero
  ok   fresh: type: the port 0 and Apple's own object 0
  ok   fresh: maxCommandsInFlight: the port 0 and Apple's own object 0
  ok   fresh: scratchBufferAllocator is nil on both sides, and it is not measured
  ok   after a set: maxCommandBufferCount = 7: the port 7 and Apple's own object 7
  ok   after a set: priority = Low: the port 2 and Apple's own object 2
  ok   after a set: type = Serial: the port 1 and Apple's own object 1
  ok   after a set: maxCommandsInFlight = 9: the port 9 and Apple's own object 9
  ok   copy: maxCommandBufferCount: the port 7 and Apple's own object 7
  ok   copy: priority: the port 2 and Apple's own object 2
  ok   copy: type: the port 1 and Apple's own object 1
  ok   copy: maxCommandsInFlight: the port 0 and Apple's own object 0
  ok   Apple's own -copyWithZone: does not carry maxCommandsInFlight, and the port matches that
no device was created: 43 checks, each one against Apple's own object
all checks passed
the control: a mutation that does not compile is RUN FAILED, not red
  ok   RUN FAILED: the broken mutation did not build, and no binary was left to run
the mutations: one per class, and one per member nothing else shares
  red    fresh: startOfEncoderSampleIndex: the port 0 and Apple's own object 18446744073709551615
  red    four reads of indices 0 to 3 each answer an attachment on the port's side
  red    a write copies: the attachment read back is not the one handed in, on either side
  red    a fresh pass descriptor's array is there on both sides, and the port's needs no device
  red    fresh: maxCommandBufferCount - Apple's own default, which the header does not state: the port 0 and Apple's own object 64
  red    copy: maxCommandsInFlight: the port 9 and Apple's own object 0
descriptors16: the differential is green, the control is RUN FAILED, and all six mutants are red
```

**A mutation that is red for the right reason.** The second mutation above - the bound - was an abort
trap the first time it ran, not a failed check, because the case asked the port for slot 3 outside a
`@try` and the mutant's exception ended the process before any line was printed. The case now reads
every index through a guarded reader, so a side that refuses a legal index is a red CHECK and the run
carries on. A red test that is red because it crashed is not a test.

## The values, and where each one comes from

Three of the numbers in this file are not in any header. They are Apple's own, measured, and the
measurement is the differential above.

| value | what the header says | what Apple's own object answers |
| --- | --- | --- |
| `startOfEncoderSampleIndex`, `endOfEncoderSampleIndex` on a fresh attachment | nothing; a comment says `MTLCounterDontSample` omits the sample | `18446744073709551615` on both, which is `MTLCounterDontSample` and **not** zero |
| the number of slots in the attachment array | nothing at all | 4: indices 0 to 3 each answer an attachment, index 4 stops the process |
| `maxCommandBufferCount` on a fresh queue descriptor | nothing; only "the maximum number of commandBuffers that can be in flight" | 64 |
| `priority` on a fresh queue descriptor | `MTLIOPriorityHigh = 0` is the enumeration's own zero | `MTLIOPriorityNormal`, which is 1 |
| `type` on a fresh queue descriptor | `MTLIOCommandQueueTypeConcurrent = 0` | 0, the enumeration's own zero |
| `maxCommandsInFlight` on a fresh queue descriptor | "a zero value defaults to the system dependent maximum value" | 0 |

The attachment array's bound and the queue's 64 were measured before the port was written, out of
process, because asking Apple's own object for index 4 does not return - it is a C assertion and the
process stops. One index per invocation:

```
$ W=.agent-work/runs/metal-r16/probe   # the probe is in the band run output, not in the tree
$ xcrun clang -target arm64-apple-ios16.0-macabi -isysroot $(xcrun --show-sdk-path --sdk macosx) \
      -F $(xcrun --show-sdk-path --sdk macosx)/System/Library/Frameworks \
      -iframework $(xcrun --show-sdk-path --sdk macosx)/System/iOSSupport/System/Library/Frameworks \
      -fobjc-arc -o $W/bound $W/bound.m -framework Foundation -framework Metal
$ timeout 10 $W/bound as 3 read
as index 3 read
  answered an object
$ timeout 10 $W/bound as 4 read
as index 4 read
-[MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray objectAtIndexedSubscript:]:757: failed assertion `attachmentIndex(4) must be < 4'
$ timeout 10 $W/bound as 4 write
as index 4 write
-[MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray setObject:atIndexedSubscript:]:773: failed assertion `attachmentIndex(4) must be < 4'
$ timeout 10 $W/bound compute 4 read
compute index 4 read
-[MTLComputePassSampleBufferAttachmentDescriptorArrayInternal objectAtIndexedSubscript:]:188: failed assertion `attachmentIndex(4) must be < 4'
$ timeout 10 $W/bound render 8 read
render index 8 read
-[MTLRenderPassSampleBufferAttachmentDescriptorArrayInternal objectAtIndexedSubscript:]:1517: failed assertion `attachmentIndex(8) must be < 4'
```

The last two lines are why the bound is four and not a number of this file's choosing: **Apple's own
compute and render arrays have the same bound and the same message**, so this is one bound across the
pass families. The differential asks each side of 0 to 3 and never asks either side of 4.

## What the array does, all of it measured

* **A read of an unwritten slot makes a descriptor and keeps it.** Four reads of indices 0 to 3 answer
  four DISTINCT attachments, and two reads of one index are the same object. A caller can therefore
  fill slot 2 without having filled slot 1.
* **A write copies.** The header says "This always uses 'copy' semantics", and the attachment handed
  in and the one read back are different objects carrying the same values.
* **A nil write resets the slot** to a fresh descriptor whose indices are `MTLCounterDontSample`
  again, which is what the header's "resets that attachment descriptor state to default values" means.
* **The array is not an `NSArray`.** The header declares two members and no superclass, and Apple's own
  object answers no `-count`, no `-objectAtIndex:` and no `-setObject:atIndex:` (all three measured 0).
  This file's array declares exactly those two members and inherits from `NSObject`.

## The queue descriptor's copy, which carries three of the four

A descriptor with `maxCommandBufferCount` 7, `MTLIOPriorityLow`, `MTLIOCommandQueueTypeSerial` and
`maxCommandsInFlight` 9 set copies to **7, Low, Serial and 0** - three of the four carried, and
`maxCommandsInFlight` back at 0 while the original still reads 9. Apple's own `-copyWithZone:` does not carry
that member. The port matches Apple rather than being more faithful than the release is, mutation M6
holds it there, and this paragraph is why: a port that copied the fourth member would hand a caller a
different bound from the one the original carries.

## The three arrays of 14.0 that this one does not share, and do not match

`Metal/MTLDescriptors14.m` carries `MTLComputePassSampleBufferAttachmentDescriptorArray`,
`MTLRenderPassSampleBufferAttachmentDescriptorArray` and
`MTLResourceStatePassSampleBufferAttachmentDescriptorArray`, and the four classes here are the same
shape as those. The code is not shared, for the reason this repository's contract names - a C helper
defined in a file that exports a band's API is left out of a band that already has that API, and the
call is `Undefined symbols` in later bands only, which one gate linking one band never sees - and the
element types differ, so a shared body would still need three forwarders over the twenty lines it
replaces.

**They do not behave the same, and that is worth knowing rather than copying in either direction.** The
three 14.0 arrays grow to whatever index is written, and the bound measurement above found Apple's own
bound is **four** for the compute, render and resource-state arrays as well as for this one - so those
three differ from Metal in exactly the way this one does not. Those are another band's rows and this
band did not touch them; the difference is recorded here so the next band that reads the 14.0 file
knows it is a measurement and not an oversight.

## The one difference from Metal, named

**An index past the end raises here and stops the process there.** Apple's answer is a C assertion
(`attachmentIndex(4) must be < 4`); this port raises a catchable `NSInvalidArgumentException` carrying
the same words, because on this release an uncaught exception prints the condition and aborts just as
an assertion does, and a caller with a bug in its index gets a named condition rather than a trap. The
differential checks the port's refusal and the wording; it cannot check Apple's, because asking would
kill the run, which is why the bound was measured out of process above.

**What a native fix would be:** abort as Apple does rather than raise. It is not done here, and it is
not hidden here.

## The sample buffer, measured with a device

The one row this page used to leave open is the attachment's `sampleBuffer`: it is a DEVICE-MADE
OBJECT, so a comparison that creates no device could say only that a fresh attachment reads nil on
both sides, and the page said so in as many words. **A device is no longer a wall** -
`facts/Metal/DeviceOnThisMachine.md` is the measurement of the machine - so the round trip is measured,
in `tests/backports/host/metal-census/descriptors16.sh`:

```
the sample buffer, with a real MTLCounterSampleBuffer on both sides
  ok   there is a Metal device, which is what this section needs and the one above did not
  ok   Apple's own device has the timestamp counter set the header names
  ok   Apple's own device makes a counter sample buffer, which is what the port is handed
  ok   fresh: sampleBuffer is nil on both sides
  ok   after a set: APPLE's own attachment returns the very object it was given
  ok   after a set: the PORT's attachment returns the very object it was given - identity within its own side
  ok   a copy: APPLE's own copy carries the sample buffer
  ok   a copy: the PORT's copy carries the sample buffer
  ok   through the array: APPLE's own pass descriptor holds the attachment at index 0
  ok   through the array: the PORT's pass descriptor holds the attachment at index 0
  ok   through the array: APPLE's own attachment still holds the real sample buffer
  ok   through the array: the PORT's attachment still holds the real sample buffer
  ok   after a nil at index 0: startOfEncoderSampleIndex is back to the default on both sides: the port 18446744073709551615 and Apple's own object 18446744073709551615
  ok   after a nil at index 0: both sides' attachment has no sample buffer again
57 checks, each one against Apple's own object; the descriptor ones need no device and the sample buffer one does
all checks passed
```

43 checks before this section, 57 after, and a seventh mutant for the part only it can catch. The
buffer is made from the timestamp counter set, which `MTLCounters.h:65` names
(`MTLCommonCounterSetTimestamp`), with one sample and no sample counters of its own - the simplest
buffer the descriptor allows.

**Identity is only ever compared within one side.** Both sides are handed the same object here, and
what is asked is whether each side returns the object IT was given; a pointer is never compared with a
pointer of the other side, because two objects have no address in common.

**The reset is the part only this section can catch.** A nil at a legal index resets that attachment's
state to its default values, and what those defaults are AFTER a set is only observable once something
has been set and taken away again - which needs a device to make the something. The mutant M7 makes the
array keep the old attachment on a nil, and it is red on exactly that check, so the section is not
decoration.

**What is still not measured is the buffer's CONTENTS.** A counter sample buffer's samples are filled
by an encoder resolving counters, and this port vends no acceleration structure command encoder for
one to come from - the absence the section above records. That is a statement about the port and not
about the host.

## What these four objects do NOT do, and which rows say so

Nothing in this port ever reads a descriptor made here. Two facilities are missing and both are
hardware, not effort:

* **The acceleration structure encoder.** `-[MTLCommandBuffer accelerationStructureCommandEncoderWithDescriptor:]`
  needs a ray tracing unit, and the A7 this port targets has none. The encoder protocol's own heap
  rows are `absent` for that reason (`facts/Metal/Heaps.md`), and so are
  `-[MTLHeap newAccelerationStructureWith…]`.
* **The IO command queue.** `-[MTLDevice newIOQueueWithDescriptor:error:]` needs a queue that loads a
  file's bytes into a buffer the GPU reads over a bindless resource path, and there is none here. The
  five `MTLIO*` protocols are `absent` for that reason, and so is the compression context's C API.

So a caller of this file's four rows gets objects it can build, fill, copy and read - and no object
to hand them to. Each row's `effect` says exactly that, which is what `implemented` owes a reader here:
the measured behaviour, including the part that is not there.

## Where the rows are, and what else the file's rows claim

`registry/Metal/absent_Metal.json`, four rows of release 16.0, and the file's other 16.0 rows stay
exactly as they were: the function and constant rows of the IO compressor, the mesh pipeline
descriptor, and the acceleration structure heap methods are other slices' rows, and this band did not
touch them.

The band ends the gate reads are in `facts/Metal/Metal16Absence.md`, which holds the census of the
16.0 band ends for the rows that stay `absent`.
