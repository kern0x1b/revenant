# AVCaptureDataOutputSynchronizer and AVCaptureSynchronizedSampleBufferData, iOS 11

Corpus rank 2 by crash exposure, 3 of 3 applications, on `AVCaptureSynchronizedSampleBufferData.sampleBuffer`.
The camera and microphone are real hardware the iPhone 4S and iPad 2 already have; `AVCaptureVideoDataOutput`
and `AVCaptureAudioDataOutput`'s own `-setSampleBufferDelegate:queue:` and sample-buffer delegate
callbacks have been present since iOS 6.0. There is no wall here, only work.

## What the release does

`AVCaptureDataOutputSynchronizer` is initialized with an ordered array of data outputs, the first
acting as master. It takes over each output's own delegate and, once it has data for the master
output and every other output at an equal or later presentation timestamp (or has determined a
given output has none for that timestamp), delivers one `AVCaptureSynchronizedDataCollection` to
its own delegate holding all of them aligned to the master's timestamp.

## What this port does

`AVCaptureDataOutputSynchronizer` supports `AVCaptureVideoDataOutput` and `AVCaptureAudioDataOutput`
in its `dataOutputs` array - the two output kinds `AVCaptureSynchronizedSampleBufferData` is for,
and the corpus's own demand. `-setDelegate:queue:` calls each such output's real, present
`-setSampleBufferDelegate:queue:` with itself as the delegate. On every buffer the master output
delivers (`captureOutput:didOutputSampleBuffer:fromConnection:`), a
`AVCaptureSynchronizedDataCollection` is built and delivered to this port's own delegate holding
the master's new buffer plus whichever buffer was most recently received from every other output
in the array. `AVCaptureSynchronizedSampleBufferData` wraps a real `CMSampleBufferRef`,
`CFRetain`ed on construction and `CFRelease`d on `dealloc`; a buffer reported through
`captureOutput:didDropSampleBuffer:fromConnection:` (real, present since iOS 6.0) instead sets
`sampleBufferWasDropped` and `droppedReason`.

## What differs from the release

This is an honest simplification of the real synchronization algorithm, not a re-implementation of
it: the release holds the master's buffer and *waits* until every other output has caught up to
its timestamp (or is known to have nothing for it) before delivering a callback; this port
delivers immediately on every master buffer, pairing it with whatever the other outputs' most
recent buffer happens to be at that instant, which can be from an earlier timestamp than the
master's if an output is behind. For two outputs both delivering frequently (video paired with
audio, the common case this corpus row is for) the two are close enough in practice that this
rarely matters; it is stated here rather than presented as exact.

`AVCaptureVideoDataOutput`'s `didDropSampleBuffer:fromConnection:` on iOS 6.1.3 carries no reason
for the drop, unlike the header's `AVCaptureOutputDataDroppedReason` enum, which distinguishes late
delivery, exhausted buffer pools and discontinuities; every drop this port reports is
`AVCaptureOutputDataDroppedReasonLateData`, the closest single answer, not measured per drop.

`AVCaptureMetadataOutput` and `AVCaptureDepthDataOutput` are not wired into the synchronizer:
metadata-object synchronization was not the corpus's demand for this pass, and the iPhone 4S and
iPad 2 this port targets have no depth-capable camera at all - a genuine hardware wall, unlike the
sample-buffer path above. `AVCaptureSynchronizedMetadataObjectData` and
`AVCaptureSynchronizedDepthData` are still carried as real classes (an application whose delegate
method signatures name them must not LOAD-FAIL), but this port's synchronizer never constructs
either: `metadataObjects` always answers empty, `depthData` always answers nil.

Not exercised against a running capture session on device this pass; the delegate wiring and the
buffer lifetime (retain/release) are the parts measured by inspection of the real, present
`AVCaptureVideoDataOutput`/`AVCaptureAudioDataOutput` selectors, not by a device run.
