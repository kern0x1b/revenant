#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// The multi-pass writer input, iOS 8: the seven members of the AVAssetWriterInputMultiPass category plus
// the class and the one property beside it, and the AVAssetExportSession sibling of the same mechanism.
// This is ONE object and it defines the API of the 8.0 release only.
//
// **The release the port runs on has none of it.** Measured over the held caches with `strings -a`, all
// nine names - performsMultiPassEncodingIfSupported, canPerformMultiplePasses, currentPassDescription,
// respondToEachPassDescriptionOnQueue:usingBlock:, markCurrentPassAsFinished, sourceTimeRanges,
// canPerformMultiplePassesOverSourceMediaData and the AVAssetWriterInputPassDescription class - answer 0
// at 4.3, 6.0, 6.1.3, 7.0 and 7.1 armv7 and are present at 8.0 armv7 (2 each, except markCurrentPassAsFinished
// at 1), with 6.1.3's own whole 113981-name selector set carrying none of them. The control of that search
// is markAsFinished, which is 4.3's own member and is found at every rung (2, 2, 2, 3, 1).
//
// **A single pass is a shape the header allows, not a compromise.** AVAssetWriterInput.h:477 says the first pass
// of -currentPassDescription covers the whole source, from zero to infinity, and that this holds too when
// canPerformMultiplePasses is NO, where a single pass is all there is. And :464 says a source that answers NO only
// has to read sequentially: append all of it once, then finish the input. So an input that answers
// NO and then runs exactly the pass the header describes is answering as documented.
//
// **What Apple's own single-pass input answers, measured, is what this file answers.** Every answer below
// comes from tests/backports/host/avf-writerinput8/probe.m run against this machine's own AVFoundation,
// on a real AVAssetWriter with an H.264 input it really started: currentPassDescription is nil until
// -startWriting and then one time range zero..+infinity; -respondToEachPassDescriptionOnQueue:usingBlock:
// refuses to be called before -startWriting and refuses a second time, and otherwise invokes the block on
// the queue it was given; -markCurrentPassAsFinished makes the description nil at once and invokes the
// block ONE more time, which then sees nil, and does NOT itself call -markAsFinished; a second
// -markCurrentPassAsFinished raises; -markAsFinished on its own leaves the description nil.
// 6.1.3's AVAssetWriter has no member about passes at all, so there is nothing here that re-reads a source.
//
// **The one measured difference is canPerformMultiplePasses with the switch on, and it is not a
// convenience.** Apple's own class answers YES as soon as performsMultiPassEncodingIfSupported is YES -
// measured unattached, attached and after -startWriting - and then runs a genuine second pass, with the
// description non-nil again after -markCurrentPassAsFinished, and -markAsFinished refused in between
// (measured). 6.1.3's writer has no analysis pass to hand out and no re-read: the second pass here would ask
// the client to append the same media a second time to a writer that has been told it is finished, which
// is the call that raises. So this file answers NO always, the client takes the header's NO path, and what
// the setting does is nothing: the header says so for a configuration that cannot benefit (AVAssetExportSession.h:433).
//
// **Three preconditions, and what it takes to see them.** The header states what is implemented: the property
// cannot be set once the receiver's AVAssetWriter has started (:459), the receiver must be attached to a writer
// through -addInput: and the writer must have been told to start (:494 and :514), and the method throws when it is
// called a second time (:496). None of them can be decided from the
// input: AVAssetWriter.h:225 gives a writer its inputs and nothing gives an input its writer, and
// -isReadyForMoreMediaData goes NO and comes back while media is being processed (:155), so it is not a
// latch either. The one place the start is visible is -[AVAssetWriter startWriting], which walks its own
// public -inputs; the one place a pass ends without this file being told is -markAsFinished, and the one
// place an export starts is -exportAsynchronouslyWithCompletionHandler:. So those three release methods
// are interposed on, each after the release's own implementation has run - the idiom
// UIKit/UICollectionView+Prefetching10.m uses for the same reason, and the same guard: nothing is
// installed where the release carries the API.
//
// **The guard reads a member the port does not add**, -preferredMediaChunkDuration, which is 8.0's own
// (measured: 0 at 4.3, 6.0, 6.1.3, 7.0 and 7.1, 2 at 8.0) and is `absent` in the registry, so the answer
// comes from the RELEASE's table whether or not this library's own categories are attached yet. Guarding
// on -markCurrentPassAsFinished instead would read this library's own category where the runtime attaches
// categories before +load, which is the reverse of attach.c's order on the device.

static const char charon_multipass_setting;
static const char charon_multipass_writing;
static const char charon_multipass_description;
static const char charon_multipass_callback;
static const char charon_multipass_queue;
static const char charon_export_multipass;
static const char charon_export_started;

static NSString *const charon_current_pass_key = @"currentPassDescription";

// The pass the header describes and Apple is measured to describe: the whole source, once.
static AVAssetWriterInputPassDescription *charon_first_pass_description(void)
{
    // AV_INIT_UNAVAILABLE on the class, because only a writer hands these out; this is that writer, so
    // the instance is made through the runtime and left as the class the SDK declares
    // (Foundation/NSInflectionRule.m does the same for -automaticRule).
    AVAssetWriterInputPassDescription *description = class_createInstance([AVAssetWriterInputPassDescription class], 0);
    static NSArray *ranges;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ranges = @[[NSValue valueWithCMTimeRange:CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)]];
    });
    objc_setAssociatedObject(description, &charon_multipass_description, ranges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return description;
}

static void charon_will_change_pass(AVAssetWriterInput *input)
{
    // Both properties the header calls key-value observable are observable here for the same reason the
    // transition is worth announcing: the description appears at -startWriting and goes at the end of the
    // pass. -canPerformMultiplePasses never changes on this release, so it never announces anything.
    [input willChangeValueForKey:charon_current_pass_key];
}

static void charon_did_change_pass(AVAssetWriterInput *input)
{
    [input didChangeValueForKey:charon_current_pass_key];
}

// The writer has started: the input's one pass begins. Called from -[AVAssetWriter startWriting] after the
// release's own implementation has answered YES, so this runs once per input whatever -startWriting is.
static void charon_begin_pass(AVAssetWriterInput *input)
{
    if (objc_getAssociatedObject(input, &charon_multipass_writing))
        return;
    objc_setAssociatedObject(input, &charon_multipass_writing, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_will_change_pass(input);
    objc_setAssociatedObject(input, &charon_multipass_description, charon_first_pass_description(),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_did_change_pass(input);
}

// The pass is over, by -markCurrentPassAsFinished or by the release's own -markAsFinished. Called from both,
// and it is the same event in both: the measured host leaves the description nil either way.
static void charon_end_pass(AVAssetWriterInput *input)
{
    if (!objc_getAssociatedObject(input, &charon_multipass_description))
        return;
    charon_will_change_pass(input);
    objc_setAssociatedObject(input, &charon_multipass_description, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_did_change_pass(input);
}

static void charon_invoke_pass_callback(AVAssetWriterInput *input)
{
    dispatch_block_t callback = objc_getAssociatedObject(input, &charon_multipass_callback);
    if (callback)
        callback();
}

static void charon_raise(NSString *reason)
{
    // The name is the one the measured host raises for all three preconditions.
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:nil];
}

@interface AVAssetWriterInput (CharonAVAssetWriterInputMultiPass8)
- (BOOL)performsMultiPassEncodingIfSupported;
- (void)setPerformsMultiPassEncodingIfSupported:(BOOL)performsMultiPassEncodingIfSupported;
- (BOOL)canPerformMultiplePasses;
- (AVAssetWriterInputPassDescription *)currentPassDescription;
- (void)respondToEachPassDescriptionOnQueue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block;
- (void)markCurrentPassAsFinished;
@end

@implementation AVAssetWriterInputPassDescription

// The ranges of the current pass. They are held beside the object because the class the SDK declares
// carries one ivar, AVAssetWriterInputPassDescriptionInternal *_internal, that a category cannot fill and
// a port may not redeclare; the port fills what it can see, which is the time ranges it hands out.
- (NSArray *)sourceTimeRanges
{
    NSArray *ranges = objc_getAssociatedObject(self, &charon_multipass_description);
    return ranges ? [ranges copy] : @[];
}

@end

@implementation AVAssetWriterInput (CharonAVAssetWriterInputMultiPass8)

// The switch is the client's, and it round-trips: the header (AVAssetWriterInput.h:455) makes NO the default, meaning
// no extra analysis pass and no re-encoding of segments. The port keeps whatever was set, so a client that sets it
// and reads it back reads what it set.
- (BOOL)performsMultiPassEncodingIfSupported
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_multipass_setting);
    return stored ? stored.boolValue : NO;
}

- (void)setPerformsMultiPassEncodingIfSupported:(BOOL)performsMultiPassEncodingIfSupported
{
    if (objc_getAssociatedObject(self, &charon_multipass_writing))
        charon_raise(@"-[AVAssetWriterInput setPerformsMultiPassEncodingIfSupported:] cannot be called after the input's asset writer has started writing");
    objc_setAssociatedObject(self, &charon_multipass_setting, @(performsMultiPassEncodingIfSupported),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// NO for every input on this release, and the difference from Apple's own class is written down at the top
// of this file and measured there: a YES here would send the client into a re-append that 6.1.3's writer
// refuses. The header's NO path is the one this answer selects: append once, then -markAsFinished.
- (BOOL)canPerformMultiplePasses
{
    return NO;
}

// Nil until the writer has started, one time range zero..+infinity while the pass is live, nil from the end
// of the pass on. Measured: nil unattached, nil attached before -startWriting, {0/1, +infinity} after it,
// nil after -markCurrentPassAsFinished and nil after -markAsFinished.
- (AVAssetWriterInputPassDescription *)currentPassDescription
{
    return objc_getAssociatedObject(self, &charon_multipass_description);
}

- (void)respondToEachPassDescriptionOnQueue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block
{
    if (!objc_getAssociatedObject(self, &charon_multipass_writing))
        charon_raise(@"-[AVAssetWriterInput respondToEachPassDescriptionOnQueue:usingBlock:] cannot be called before the input's asset writer has started writing");
    if (objc_getAssociatedObject(self, &charon_multipass_callback))
        charon_raise(@"-[AVAssetWriterInput respondToEachPassDescriptionOnQueue:usingBlock:] cannot be called more than once on the same input");
    objc_setAssociatedObject(self, &charon_multipass_callback, [block copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &charon_multipass_queue, queue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // The first pass has begun by the time this is called, so the block runs now - on the queue it was
    // given, as the header's parameter description says (AVAssetWriterInput.h:214-215), and
    // not before, which is what the measured host does: nothing was invoked at registration and one
    // invocation arrived on the queue once it drained.
    dispatch_async(queue, ^{
        charon_invoke_pass_callback(self);
    });
}

- (void)markCurrentPassAsFinished
{
    if (!objc_getAssociatedObject(self, &charon_multipass_writing))
        charon_raise(@"-[AVAssetWriterInput markCurrentPassAsFinished] cannot be called before the input's asset writer has started writing");
    if (!objc_getAssociatedObject(self, &charon_multipass_description))
        charon_raise(@"-[AVAssetWriterInput markCurrentPassAsFinished] cannot be called when there is no current pass to mark finished");
    // The header, on what this call does NOT do (AVAssetWriterInput.h:510-512): after each pass the client may keep
    // the results by calling -markAsFinished instead, and a description that is nil at the start of a pass means the
    // client should call -markAsFinished. When canPerformMultiplePasses is NO, the description becomes nil straight
    // after this call. So the pass ends here, and the client is the one that finishes the
    // input - which is what the final invocation of the block is for (:492). The measured host agrees on
    // every one of those, including that -markAsFinished is not called from in here.
    charon_end_pass(self);
    dispatch_queue_t queue = objc_getAssociatedObject(self, &charon_multipass_queue);
    if (queue) {
        dispatch_async(queue, ^{
            charon_invoke_pass_callback(self);
        });
    }
}

@end

@interface AVAssetExportSession (CharonAVAssetExportSessionMultipass8)
- (BOOL)canPerformMultiplePassesOverSourceMediaData;
- (void)setCanPerformMultiplePassesOverSourceMediaData:(BOOL)flag;
@end

@implementation AVAssetExportSession (CharonAVAssetExportSessionMultipass8)

// The export's half of the same mechanism, and it reads as the header documents for a session that cannot
// do more than one pass: NO by default (:433), what the client set read back, and no effect on the export,
// which on this release reads its source once. The measured host answers NO for a passthrough export of a
// file this probe wrote, accepts YES before the export starts and refuses it after ("cannot be set after
// the export has started"); that refusal is reproduced below, from -exportAsynchronouslyWithCompletionHandler:.
- (BOOL)canPerformMultiplePassesOverSourceMediaData
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_export_multipass);
    return stored ? stored.boolValue : NO;
}

- (void)setCanPerformMultiplePassesOverSourceMediaData:(BOOL)flag
{
    if (objc_getAssociatedObject(self, &charon_export_started))
        charon_raise(@"-[AVAssetExportSession setCanPerformMultiplePassesOverSourceMediaData:] cannot be called after the export has started");
    objc_setAssociatedObject(self, &charon_export_multipass, @(flag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface CharonAVAssetWriterInputMultiPass8Installer : NSObject
@end

@implementation CharonAVAssetWriterInputMultiPass8Installer

+ (void)load
{
    // Nothing to install where the release carries the family. -preferredMediaChunkDuration is 8.0's own
    // and the port adds no member of that name, so this reads the release's table and not this library's.
    Class input = [AVAssetWriterInput class];
    if (class_getInstanceMethod(input, @selector(preferredMediaChunkDuration)))
        return;

    // -[AVAssetWriter startWriting] is 4.3's own member and the only place the port can see the writer
    // begin, so it is interposed on and the release's implementation runs first: this observes the
    // release's own transition and never replaces it.
    Class writer = [AVAssetWriter class];
    IMP startWriting = class_getMethodImplementation(writer, @selector(startWriting));
    if (startWriting)
        class_replaceMethod(writer, @selector(startWriting),
                            imp_implementationWithBlock(^BOOL(AVAssetWriter *self_) {
            if (!((BOOL (*)(id, SEL))startWriting)(self_, @selector(startWriting)))
                return NO;
            // -inputs is the release's own public member (AVAssetWriter.h:225), and a writer has no
            // input of its own that names it.
            for (AVAssetWriterInput *each in self_.inputs)
                charon_begin_pass(each);
            return YES;
        }), "ccharon_startWriting");

    // -[AVAssetWriterInput markAsFinished] is the release's own single-pass way of ending an input, and a
    // client that never calls into this family still uses it: the measured host leaves the description nil
    // after it, and without this the port would still be handing out a pass for an input nobody can append
    // to any more.
    IMP markAsFinished = class_getMethodImplementation(input, @selector(markAsFinished));
    if (markAsFinished)
        class_replaceMethod(input, @selector(markAsFinished),
                            imp_implementationWithBlock(^(AVAssetWriterInput *self_) {
            ((void (*)(id, SEL))markAsFinished)(self_, @selector(markAsFinished));
            charon_end_pass(self_);
        }), "ccharon_markAsFinished");

    // The export's start, for the setter's own precondition. -exportAsynchronouslyWithCompletionHandler:
    // is 6.1.3's own member (4.3 and 6.0 carry it too, measured above) and the release's answer is what
    // says an export has begun.
    Class session = [AVAssetExportSession class];
    IMP exportAsynchronously = class_getMethodImplementation(session,
                                                             @selector(exportAsynchronouslyWithCompletionHandler:));
    if (exportAsynchronously)
        class_replaceMethod(session, @selector(exportAsynchronouslyWithCompletionHandler:),
                            imp_implementationWithBlock(^(AVAssetExportSession *self_, dispatch_block_t handler) {
            objc_setAssociatedObject(self_, &charon_export_started, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ((void (*)(id, SEL, id))exportAsynchronously)(self_, @selector(exportAsynchronouslyWithCompletionHandler:), handler);
        }), "ccharon_exportAsynchronouslyWithCompletionHandler");
}

@end