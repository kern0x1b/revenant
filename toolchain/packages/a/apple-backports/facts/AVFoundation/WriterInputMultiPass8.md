# The 8.0 multi-pass writer input on a release that has no passes: what it does, and what Apple's own answers

Eight rows of `registry/AVFoundation/absent_AVFoundation.json`, and one object:
`AVFoundation/AVAssetWriterInputMultiPass8.m`. It defines the API of the **8.0** release only, carries
`AVAssetWriterInputPassDescription` as a class the release does not have, and adds six members to the
release's `AVAssetWriterInput` plus the export session's half of the same mechanism.

**A single pass is a shape the header allows, and it is the shape Apple's own class is in when the switch
is off.** `AVAssetWriterInput.h:477`, on `-currentPassDescription`: "During the first pass, the request will
contain a single time range from zero to positive infinity, indicating that all media from the source
should be appended. This will also be true when canPerformMultiplePasses is NO, in which case only one pass
will be performed." And `:464`, on that property being NO: "your source for media data only needs to
support sequential access. In this case, append all of the source media once and call -markAsFinished."

So the port answers `-canPerformMultiplePasses` NO, runs exactly that one pass, and gives the client the
time range the header describes. Everything below is measured, not assumed.

## The ladder: the release the port runs on has none of it

`strings -a` over each held armv7 cache, one selector per line, with `-markAsFinished` - 4.3's own member -
as the control of the search itself:

| selector | 4.3 | 6.0 | 6.1.3 | 7.0 | 7.1 | 8.0 |
| --- | --- | --- | --- | --- | --- | --- |
| `markAsFinished` (control) | 1 | 2 | 2 | 3 | 2 | 2 |
| `preferredMediaChunkDuration` | 0 | 0 | 0 | 0 | 0 | 2 |
| `preferredMediaChunkAlignment` | 0 | 0 | 0 | 0 | 0 | 2 |
| `sampleReferenceBaseURL` | 0 | 0 | 0 | 0 | 0 | 2 |
| `markCurrentPassAsFinished` | 0 | 0 | 0 | 0 | 0 | 1 |
| `canPerformMultiplePasses` | 0 | 0 | 0 | 0 | 0 | 2 |
| `currentPassDescription` | 0 | 0 | 0 | 0 | 0 | 2 |
| `respondToEachPassDescriptionOnQueue:usingBlock:` | 0 | 0 | 0 | 0 | 0 | 2 |
| `performsMultiPassEncodingIfSupported` | 0 | 0 | 0 | 0 | 0 | 2 |
| `sourceTimeRanges` | 0 | 0 | 0 | 0 | 0 | 2 |
| `canPerformMultiplePassesOverSourceMediaData` | 0 | 0 | 0 | 0 | 0 | 2 |

6.1.3's whole 113 981-name selector set (`~/.charon/dyld/6.1.3/selectors_armv7.txt`) carries none of the ten
either, and 11.0's armv64 set carries all of them. The three names in the second block are the guard's
subject: they are 8.0's own, the port adds no member of any of the three, and `absent_AVFoundation.json`
keeps all three `absent` - so reading one of them says which release this is without ever reading the
port's own work.

**No member of this family is on 6.1.3's `AVAssetWriterInput`, which carries 52 own instance methods and 5
own class methods** (`facts/AVFoundation/AVFoundation80.md`), and 6.1.3's `AVAssetWriter` carries 35 own
instance methods of which none names a pass.

## What Apple's own single-pass input answers, measured on this Mac

`tests/backports/host/avf-writerinput8/writer.m` compiled against the real `<AVFoundation/AVFoundation.h>`
and linked with this machine's own AVFoundation, on a real `AVAssetWriter` with an H.264 input its own
`-canApplyOutputSettings:forMediaType:` accepted, and the writer really started. The switch-off table:

| asked | answer |
| --- | --- |
| unattached: `-canPerformMultiplePasses` | NO |
| unattached: `-currentPassDescription` | nil |
| attached, before `-startWriting`: `-currentPassDescription` | nil |
| `-respondToEachPassDescriptionOnQueue:usingBlock:` before `-startWriting` | **raises** `NSInternalInconsistencyException` |
| the same call a second time | **raises** `NSInternalInconsistencyException` |
| `-markCurrentPassAsFinished` before `-startWriting` | **raises** `NSInternalInconsistencyException` |
| `-markAsFinished` before `-startWriting` | **raises** `NSInternalInconsistencyException` |
| after `-startWriting`: `-canPerformMultiplePasses` | NO |
| after `-startWriting`: `-currentPassDescription` | one range `{0/1,0/0}` - zero to positive infinity |
| `-performsMultiPassEncodingIfSupported` set YES after `-startWriting` | **raises** `NSInternalInconsistencyException` |
| the value reads back after that refused set | what it was (NO) |
| the callback, registered after `-startWriting` | ACCEPTED; nothing invoked at the instant of the call, one invocation on the queue it was given |
| the callback, a second registration | **raises** `NSInternalInconsistencyException` |
| `-markCurrentPassAsFinished` after `-startWriting` | ACCEPTED, and it does **not** call `-markAsFinished` |
| the description right after that | **nil**, at once |
| the block's invocations, 1 -> 2, and what it saw | `{0/1,0/0}` then **nil** - the final invocation is the one the client answers by finishing |
| a second `-markCurrentPassAsFinished` | **raises** `NSInternalInconsistencyException` |
| after the client's own `-markAsFinished`: the description | nil |
| the description when no callback was ever registered and `-markAsFinished` was used | nil |
| `AVAssetExportSession.canPerformMultiplePassesOverSourceMediaData` on a real file | NO |
| the same, set YES before the export starts | ACCEPTED, reads back YES |
| the same, set YES once `-exportAsynchronouslyWithCompletionHandler:` has been called | **raises** `NSInternalInconsistencyException`, still reads YES |

The `-finishWriting` row answers NO in both of the table's runs and is not in the list: nothing was
appended, and a real writer refuses to finish a file with no media in it.

### The one row where this port answers differently, and why

**`-canPerformMultiplePasses` with `-performsMultiPassEncodingIfSupported` set to YES.** Apple's own class
answers YES from the switch alone - unattached, attached, and after `-startWriting` - and then runs a
genuine second pass: the description is non-nil again after `-markCurrentPassAsFinished`, the block is
invoked once rather than twice, and `-markAsFinished` in between raises
("cannot be called between the invocation of markCurrentPassAsFinished and the beginning of the next pass").

This port answers **NO**, and the setting does nothing. The reason is the ladder above: 6.1.3's writer has
no analysis pass to hand out and no member that names one, so a YES would send the client into a re-append
that asks an input to append the same media a second time after it has been told it is finished - which is
the call the release raises on. The header's own answer for a configuration that cannot benefit from the
setting is `AVAssetExportSession.h:433`: "In these cases, setting this property to YES has no effect." The
switch itself is stored and reads back, so a client that sets it and reads it reads what it set, and the
one query that decides a client's course answers the truth.

## Three preconditions, and the only way to see them

Three of the answers above are about whether the input's writer has started, and the input cannot tell:
`AVAssetWriter.h:225` gives a writer its inputs and **nothing gives an input its writer**, and
`-isReadyForMoreMediaData` is not a latch either - `AVAssetWriterInput.h:155` says it "will often change
from NO to YES asynchronously" and that "It is possible for all of an AVAssetWriter's AVAssetWriterInputs
temporarily to return NO". So three release methods are interposed on, each after the release's own
implementation has run, which observes the release's transition and never replaces it:

| interposed | what the port learns | the release's own answer it defers to |
| --- | --- | --- |
| `-[AVAssetWriter startWriting]` (4.3's) | the writer began, so its inputs' one pass begins, and it walks its own public `-inputs` | `-startWriting`'s own YES or NO |
| `-[AVAssetWriterInput markAsFinished]` (4.3's) | the pass ended without the 8.0 family being called at all | the release's own `-markAsFinished` |
| `-[AVAssetExportSession exportAsynchronouslyWithCompletionHandler:]` (4.3's) | the export began, which is what the export switch's precondition is about | the release's own export |

This is the idiom `UIKit/UICollectionView+Prefetching10.m` uses for the same reason, and the guard is the
same shape: **nothing is installed where the release carries the API**, tested by
`class_getInstanceMethod([AVAssetWriterInput class], @selector(preferredMediaChunkDuration))`. That member
is 8.0's own, the port adds none of that name, and the ladder above measures it arriving at 8.0 - so the
read is of the RELEASE's table. Guarding on `-markCurrentPassAsFinished` instead would read this library's
own category on any runtime that attaches categories before `+load`, which is the reverse of the order
`attach.c`'s constructor uses on the device.

## The eight rows

| row | kind | what the caller gets |
| --- | --- | --- |
| `AVAssetWriterInputPassDescription` | class | the class, so `NSClassFromString` answers it and a strong import resolves. It carries the one public member below |
| `-[AVAssetWriterInputPassDescription sourceTimeRanges]` | method | the one time range of the pass: zero to positive infinity |
| `AVAssetWriterInput.performsMultiPassEncodingIfSupported` | property | NO by default, what the client set reads back, and a raise once the writer has started |
| `AVAssetWriterInput.canPerformMultiplePasses` | property | NO, at every state, and the difference with the switch on is measured above |
| `AVAssetWriterInput.currentPassDescription` | property | nil until the writer starts, one range zero..+infinity while the pass is live, nil from the end of the pass |
| `-[AVAssetWriterInput respondToEachPassDescriptionOnQueue:usingBlock:]` | method | the block on the queue the client gave, once per pass, the last time seeing nil; raises before `-startWriting` and on a second registration |
| `-[AVAssetWriterInput markCurrentPassAsFinished]` | method | ends the pass at once, invokes the block one last time, and leaves `-markAsFinished` to the client; raises before `-startWriting` and when there is no pass |
| `AVAssetExportSession.canPerformMultiplePassesOverSourceMediaData` | property | NO by default, what the client set reads back, no effect on the export, and a raise once the export has started |

`AVAssetWriterInputPassDescription` is a **class symbol**, and `absent` for one is what COORDINATION.md
section 2 forbids: `NSClassFromString` would answer nil and a strong import would not link. The port carries
it, which is why the row is `implemented` and not `absent`.

Both properties the header calls key-value observable are observable: the description announces itself at
`-startWriting` and at the end of the pass, from whichever of the two calls ended it.
`-canPerformMultiplePasses` never changes on this release, so it never announces anything - which is the
truth and not an omission.

## The check, and the mutations that must be noticed

`tests/backports/host/avf-writerinput8/`: **one source, compiled twice**. Against the real framework and
this machine's AVFoundation it is the oracle; against `standin/AVFoundation/AVFoundation.h` - a release with
no pass machinery, an `AVAssetWriter` whose `-startWriting` means something, and no
`AVAssetWriterInputPassDescription` at all - and with the port's own object linked in **unmodified**, it is
the port. 109 rows join on the key: 95 agree, 14 differ, and each difference is in `ALLOWANCES` with the
measurement behind it. Six mutations must each turn a right answer wrong, and six controls - the same path
with the unmutated source - must stay green:

| mutant | what it breaks |
| --- | --- |
| `beginpass` | the pass `-startWriting` begins: 20 rows, every `currentPassDescription` after it |
| `ranges` | the range of that pass, positive infinity to zero: 7 rows |
| `finalcall` | the final invocation after the pass ends: 8 rows, including what the block saw |
| `forward` | the leftover's defect, `-markCurrentPassAsFinished` calling `-markAsFinished`: 2 rows |
| `setafter` | the switch setter's own precondition: 3 rows |
| `exportafter` | the export switch's own precondition: 2 rows |

`forward` is here on purpose. It is exactly what `band-SLICE-AVFoundation-absent_AVFoundation-8` built - its
`-markCurrentPassAsFinished` forwarded to the release's `-markAsFinished` - and the header says the opposite
at `:512`: with `canPerformMultiplePasses` NO the description becomes nil, and the final invocation of the
block is what the client answers by calling `-markAsFinished`. A forwarder finishes the input twice.

## Reproducing

    sh tests/backports/host/avf-writerinput8/run.sh                       the differential
    AVFWMUTANT=forward  sh tests/backports/host/avf-writerinput8/run.sh     one mutation, which must be noticed
    AVFWMUTANT=forward CONTROL=1 sh tests/backports/host/avf-writerinput8/run.sh   its control, which must be green

The host table is cached beside the build directory and the port's own table is the baseline a mutant is
judged against; run the script once with no `AVFWMUTANT` before asking for a mutant.

    for r in 4.3 6.0 6.1.3 7.0 7.1 8.0; do
        printf '%-6s ' "$r"
        strings -a ~/.charon/dyld/$r/dyld_shared_cache_armv7 | grep -cxF preferredMediaChunkDuration
    done