# The ready-creating and per-sample sample buffers on a release that has neither

iOS 6 carries `CMSampleBufferCreate` and `CMSampleBufferCreateForImageBuffer` with their
`dataReady`/`makeDataReadyCallback` parameters - `AVCapturePhotoOutput.m` and
`AVCaptureDevice+VideoZoom7.m` already call both that way and are gated green in the 6.1.3 band. What it
does not carry is the iOS 8 spelling of the same thing with the readiness fixed on, the per-sample walk
of iOS 8, or the block-taking creators of iOS 12.2. Five functions, all written over the release's own
six, so none of them has to know what a `CMSampleBuffer` is made of.

## The two ready creators

`CMSampleBufferCreateReady` and `CMSampleBufferCreateReadyWithImageBuffer` are the release's own calls
with `dataReady` true and no callback. Nothing else to decide: the buffer is the host's, with the host's
timing, the host's sample sizes and the host's data. Measured over 4 sample counts x 5 timing counts,
with and without a data buffer, and with no out pointer: 143 answers, all the same as the host's
(`tests/backports/host/coremedia7/createready.m`).

## The per-sample walk

`CMSampleBufferCallBlockForEachSample` reads the sample buffer's own sample-size array and per-sample
timing, and for each sample builds a one-sample buffer over *that sample's bytes* with
`CMBlockBufferCreateWithBufferReference`, which the release exports. The release's private
`CMSampleBufferCallForEachSample` was not used: it is a different function with a different contract,
and its signature is not in any SDK on this machine.

Two things the port does not reproduce, both measured:

- **A buffer built with fewer timing entries than samples.** The host answers for the first sample and
  then gives `kCMSampleBufferError_BufferHasNoSampleTimingInfo`; the port asks the release for each
  sample's timing and gives the same error for the first one too. 10 of 12 such answers agree. The
  port's is the release's own answer, unaltered, which is the most defensible reading of "containing its
  timing" in Apple's own words.
- **The temporary buffer's length.** The host's temporary buffer spans the whole data buffer (12 bytes
  for a buffer of one 8-byte sample); the port's is exactly the sample. The sample's own bytes, the
  sample count, the sample size and the timing are the same, and those are what the test compares - the
  total length is not part of the claim, because handing a handler 12 bytes for an 8-byte sample is not
  what "referring to the sample data" means.

## The two block-taking creators

`CMSampleBufferCreateWithMakeDataReadyHandler` and
`CMSampleBufferCreateForImageBufferWithMakeDataReadyHandler` build the buffer with the release's own
creator at the readiness asked for and, when it was not ready, run the handler over the finished buffer
and answer the handler's own status; a failure releases the buffer and leaves the out parameter null,
which is what the host does.

**The handler runs inside the creator, before it returns, where the release runs it at
`CMSampleBufferMakeDataReady`.** That is the limit, and it is written down rather than papered over.

## What the host does, measured

- The handler has **not** run when `CMSampleBufferCreateWithMakeDataReadyHandler` returns
  (`create 0, data ready 0, ran 0`); it runs on the next `CMSampleBufferMakeDataReady`
  (`0, data ready 1, ran 1`). With `dataReady` YES it never runs, and `MakeDataReady` does not call it.
- A handler returning non-zero gives `MakeDataReady -12345`, and the buffer stays not ready but valid.
- A marker object captured by the handler is **never** deallocated on this machine: not after
  `MakeDataReady`, not after `CMSampleBufferInvalidate`, not after `CFRelease`. The host does not release
  the block with the buffer.

## The wall is not a wall, and what is left of it

This release's `CMSampleBufferCreate` takes a `makeDataReadyCallback` and a `makeDataReadyRefcon` at
`ios(4.0)`, and `CMSampleBufferSetInvalidateCallback` is public at `ios(4.0)` too - the same declaration
`CMSampleBufferSetInvalidateHandler` has in 8.0, with a C callback where that one has a block. So the
release can call the handler itself, at the moment the application asks, with a copied block as the
refcon and a C trampoline in front of it; the argument order of the invalidation setter was measured
rather than assumed, because with the callback third instead of second it stores the refcon as the
function pointer and the process dies inside `CMSampleBufferInvalidate`.

### The holder as an attachment, and what is still missing

The block's lifetime is the buffer's if the holder is attached to the buffer: the attachments are
released with the buffer, whatever path the buffer takes. `CMSetAttachment` is public at `ios(4.0)`, so
nothing private is involved, and the trampoline only calls the block and never frees.

**Measured, what the attachment is visible to**, with `CMSetAttachment(sbuf, CFSTR("CharonMakeDataReadyHolder"), value,
kCMAttachmentMode_ShouldNotPropagate)` on a sample buffer the release created:

| query | answer |
| --- | --- |
| `CMCopyDictionaryOfAttachments(..., kCMAttachmentMode_ShouldPropagate)` | `(null)` - not there |
| `CMCopyDictionaryOfAttachments(..., kCMAttachmentMode_ShouldNotPropagate)` | the key is there |
| `CMSampleBufferGetSampleAttachmentsArray(sbuf, true)` | one entry, **its key list is empty** |
| `CMGetAttachment(sbuf, kCMAnyOtherKey, NULL)` | `NULL` |
| the host's own creator, with or without a handler | leaves **no** attachment at all |
| after `CMSampleBufferInvalidate` | gone, in both modes |

So the key is reachable only by a caller that asks for `ShouldNotPropagate` attachments - which is
exactly the "my own private attachments" query - and by `CMGetAttachment` with that one string. It is
invisible to `CMSampleBufferGetSampleAttachmentsArray`, which is the call an application iterating a
sample buffer's attachments actually makes. A key beginning with `Charon` cannot collide with an Apple
one.

**The CFType holder works, and it settles one more thing.** With the holder as a `CFType` rather than an
Objective-C object - registered under the private name `CharonMakeDataReadyHolder`, with a copy
function that is the identity, a release that frees the block and the holder, and the pointer's own
address as its hash - the port's creators build and run: `create 0`, the buffer not ready, and the block
run exactly once. **The bridged Objective-C refcon was what the release would not accept**; a CFType
refcon it takes.

And the release's own behaviour is then visible, measured, and it is not the host's:

| | system | port |
| --- | --- | --- |
| after the creator | `create 0, ran 0, ready 0` | `create 0, ran 1, ready 0` |
| after `CMSampleBufferMakeDataReady` | `0, ran 1, ready 1` | `-12733, ran 1, ready 0` |

**This release's `CMSampleBufferCreate` calls its makeDataReadyCallback while it creates the buffer when
the buffer is not created data-ready.** That is the release's own behaviour for the `ios(4.0)` callback -
and the host does not do it, because the host's `CMSampleBuffer` has a slot for the block that it arms
itself and runs the handler at the application's `CMSampleBufferMakeDataReady`. So the handler still
runs inside the creator, but now the release makes the call rather than the port, the block is the
buffer's, and a second `CMSampleBufferMakeDataReady` answers `kCMSampleBufferError_BufferNotReady`
because the release has already run it. The trampoline returns the block's own status unchanged, and the
port adds nothing to it.

**What is still missing, and it is a timing, not a lifetime.** The attachment design was written and it
**traps the host test (SIGTRAP) on the port side of the first make-data-ready case**, where the system
side of the *same* case passes (`create 0, ran 0` then `MakeDataReady 0, ran 1, ready 1`). The earlier
attempt, which freed the copied block on whichever of the trampoline and the invalidation hook fired
first, crashed with SIGBUS; the live-holder table that fixed that one was then replaced by the
attachment, and the trap moved to the release's own `CMSampleBufferMakeDataReady`. The tree is back at
the last green commit and this entry stays open, with the registry carrying the one clause that says
where the handler runs.

The next thing to ask, which is cheap and would settle it: does the release assert because the callback
returned 0 **without** the block having made the data ready. Apple's own wording for the callback is
"This callback must make the data ready ... If this callback succeeds and returns 0, the CMSampleBuffer
will then be marked as 'data ready'", and the system's own handler in the same probe also only returned
0 - so if the trap is an assertion about readiness, the difference between the two paths is the *refcon*,
which on the port side is a bridged Objective-C object pointer where the system uses its own storage.

## `CMAudioSampleBufferCreateReadyWithPacketDescriptions` (8.0)

Corpus row 5186, demand rank 192, `LOAD-FAIL` for one application. A packet description is
`mStartOffset`, `mVariableFramesInPacket` and `mDataByteSize` - Apple's own `CoreAudioBaseTypes.h`
declares the struct in the iPhoneOS 16.4 SDK the gate resolves, in iPhoneOS 26.2 and in the macOS SDK,
and the field is `mVariableFramesInPacket`, not `mNumberFrames`, which no SDK on this machine has. A
previous delivery left both this and its 12.2 twin out on the premise that the type is incomplete; that
premise was wrong and the check that refutes it is one `-fsyntax-only` against the port's own SDK.

What the host does, measured over 239 answers in `tests/backports/host/coremedia7/createready.m`:

- **One timing entry and one sizing entry**, the form Apple's own header calls "if all samples have the
  same duration and are in presentation order". With two packets the host answers one entry of
  `1024/44100` at the presentation timestamp it was given, not two.
- **The duration comes from the stream's `mFramesPerPacket`**, not from the description's own
  `mVariableFramesInPacket`: a description of one frame against an AAC stream of 1024 answers
  `1024/44100`.
- **The size is the description's `mDataByteSize`,** and falls back on
  `mFramesPerPacket * bytesPerFrame` when the description has none of its own: a 16-bit linear stream of
  one frame per packet answers 2 bytes whatever the description says.
- Zero samples is `kCMSampleBufferError_InvalidEntryCount`; a presentation timestamp that is not numeric
  is `kCMSampleBufferError_SampleTimingInfoInvalid`; no packet descriptions for a format with no
  per-frame byte size at all (AAC) is `kCMSampleBufferError_RequiredParameterMissing`.

**179 answers inside the claim, none different. 60 outside it, 58 of those the same.** The outside
shape is one I could not pin down: for AAC with a description whose `mDataByteSize` is zero, the host's
sizing array depends on the packet count - one packet gets a zero size entry, two get none - and there
is no rule from outside that distinguishes those two answers. The port answers one size entry in both
cases, which is the one that carries the size the description gave.
