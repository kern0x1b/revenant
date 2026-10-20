# `CMSampleBufferCopyPCMDataIntoAudioBufferList` on a release that has not got it

iOS 6 exports 37 `CMSampleBuffer` functions and this is not one of them; the armv7 cache ladder first
exports it at 7.0. The release does carry everything the copy needs -
`CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer`, `CMBlockBufferCopyDataBytes`,
`CMAudioFormatDescriptionGetStreamBasicDescription` - so the port asks the release for the source list
and the release's own block buffer for the bytes, and every bound, every error and every byte comes from
the release rather than from a second implementation of the format.

## What the host actually requires, measured

The header says the `AudioBufferList` "must contain the same number of channels and its data buffers must
be sized to hold the specified number of frames". The host is stricter and stranger than that, and all
of this was measured on it rather than inferred:

- The destination must be the list the release itself would produce for that buffer: the same number of
  `AudioBuffer`s, each with the same `mNumberChannels`, and each with an `mDataByteSize` of *exactly*
  `numFrames` frames - not more. A 16-byte destination for an 8-byte copy is
  `kCMSampleBufferError_RequiredParameterMissing`, and so is a 4-byte one.
- A destination with a **different** number of buffers from the release's own list is accepted: the
  answer is 0 and nothing is copied.
- The successful copy is always the whole sample buffer. `numFrames` is bounded, not free: a run that
  ends inside the buffer but is not the whole of it is `kCMSampleBufferError_RequiredParameterMissing`.
- The other answers, all measured: a missing or non-audio format is
  `kCMSampleBufferError_InvalidMediaTypeForOperation`; audio that is not `kAudioFormatLinearPCM` (AAC, for
  instance) is `kCMSampleBufferError_InvalidSampleData`; a buffer whose data is not ready, and one that
  has been invalidated, are `kCMSampleBufferError_BufferNotReady`; an offset at or past the end, or a run
  past the end, is `kCMSampleBufferError_SampleIndexOutOfRange`; a null buffer, a null list, a null
  destination pointer and a negative offset are `kCMSampleBufferError_RequiredParameterMissing`. A byte
  offset the block buffer will not accept surfaces the block buffer's own `kCMBlockBufferBadOffsetParameter`
  (-12703), because the copy goes through `CMBlockBufferCopyDataBytes` and the release's bounds check is
  what answers.

## What the claim is, and what was measured against it

`tests/backports/host/coremedia7/pcmdata.m` runs the port's function and the host's side by side over
PCM, AAC, Apple Lossless and mu-law, interleaved and not, 1 to 3 channels, 1 to 16 frames, every
combination of an offset from -100 to 16 and a frame request from -1 to 17, and destination lists with 0
to 3 buffers of several sizes and channel counts, plus a null destination, a not-ready buffer and an
invalidated one.

- **31 456 answers inside the claim, 0 different** - same status, and the same bytes in every buffer.
  The claim is: a destination list with as many buffers as the sample buffer's own, an offset and a frame
  count that are not negative, and interleaved audio or a single channel.
- 60 202 answers outside it, 59 346 of them with the same status. The two shapes outside the claim are a
  negative `numFrames` (which the header does not define, and where the host's answer depends on the
  destination it was handed) and non-interleaved audio with more than one channel, where **the host reads
  past the end of the buffer it was given**: for a two-channel non-interleaved buffer of two 2-byte
  frames it fills the second destination buffer with bytes 9 to 12 of an 8-byte buffer. The port copies
  each channel's own bytes, which is what Apple describes, and the test holds the rest of that answer -
  status, sample count, sizes, the sample's own bytes - to the host.
