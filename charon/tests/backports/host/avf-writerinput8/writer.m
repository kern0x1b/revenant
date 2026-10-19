//  writer.m
//  The 8.0 multi-pass writer input, asked once and compiled twice.
//
//  THIS ONE FILE, TWICE:
//
//    the host half   compiled with the real <AVFoundation/AVFoundation.h> and linked against this
//                    machine's own AVFoundation. Every answer is Apple's own, and this half is the ORACLE:
//                    the expectations the port is held to are read from it and from nothing else.
//    the port half   compiled with -I standin, so <AVFoundation/AVFoundation.h> is the stand-in release -
//                    an AVAssetWriterInput with no pass machinery, an AVAssetWriter whose -startWriting
//                    means something - and linked with packages/a/apple-backports/AVFoundation/
//                    AVAssetWriterInputMultiPass8.m UNMODIFIED. The port's categories land on the
//                    stand-in's classes and the answers are the port's own.
//
//  Why the stand-in and not Apple's classes with the port linked over them: this Mac's AVAssetWriterInput
//  carries the whole 8.0 family, and the port's guard would - correctly - refuse to install over a release
//  that has it, so a link against the real classes would test the guard and nothing else. The stand-in is
//  shaped like the release the port runs on, which is what the family is written for.
//
//  Because the sequence is ONE source, the two halves cannot drift: every row is asked at the same point
//  in the same order, so a difference in a value is a difference in behaviour and a difference in a ROW is
//  a difference in the sequence itself, which run.sh reports rather than hides.
//
//  Three configurations, because the header makes the family settings-dependent and the port's answer
//  differs between two of them:
//
//    switch-off   the default: -performsMultiPassEncodingIfSupported is never set.
//    switch-on    it is set to YES before the writer starts. Apple's own class answers YES to
//                 -canPerformMultiplePasses and runs a real second pass; the port answers NO, which is
//                 the difference the port's file writes down and run.sh's ALLOWANCES name.
//    only         no member of the family is called at all and the pass is ended with the release's own
//                 -markAsFinished, which is what a 6.1.3 client does.
//
//  Every row is printed as `key | value` so a harness can join the two tables on the key without parsing
//  prose, and a value is never inferred: each one is what the object returned or what it raised.
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <stdio.h>

static int rowIndex;
static NSString *currentConfiguration = @"";

static void row(const char *key, NSString *value)
{
    rowIndex++;
    printf("%s%s | %s\n", currentConfiguration.UTF8String, key, value.UTF8String);
    fflush(stdout);
}

static void configure(NSString *name)
{
    currentConfiguration = [name stringByAppendingString:@": "];
}

// A real writer input, and a subclass that records the release's own -markAsFinished so a caller can see
// whether marking a PASS finished also finished the INPUT. The port's answer to that question is the
// whole point of the family, and it cannot be read off a source file.
@interface CharonSpyInput : AVAssetWriterInput
@property (nonatomic, strong) NSMutableArray<NSString *> *invoked;
@end

@implementation CharonSpyInput

- (instancetype)initWithProbeMediaType:(AVMediaType)mediaType outputSettings:(NSDictionary *)settings
{
    // The release's own factory, so the instance is a real writer input and not something this probe
    // invented. The release's -initWithMediaType:outputSettings: throws NSInvalidArgumentException
    // without AVVideoWidthKey and AVVideoHeightKey, measured by running this probe with only
    // AVVideoCodecKey, so both keys are always here.
    self = [super initWithMediaType:mediaType outputSettings:settings];
    if (self) {
        _invoked = [NSMutableArray array];
    }
    return self;
}

- (void)markAsFinished
{
    [self.invoked addObject:@"markAsFinished"];
    [super markAsFinished];
}

@end

static NSURL *charon_scratchURL(NSString *name)
{
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"charon-avf-%@-%@-%u.mov", name,
                                       [[NSUUID UUID] UUIDString], getpid()]]];
}

// The video settings this machine can actually encode, asked of the release's own
// -canApplyOutputSettings:forMediaType: on a real writer rather than hard-coded, so the probe measures a
// writer that started and not a writer that refused.
static NSDictionary *charon_encodableSettings(void)
{
    NSDictionary *settings = @{AVVideoCodecKey: AVVideoCodecTypeH264,
                               AVVideoWidthKey: @16, AVVideoHeightKey: @16};
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:charon_scratchURL(@"ask")
                                                     fileType:AVFileTypeQuickTimeMovie
                                                        error:NULL];
    if (![writer canApplyOutputSettings:settings forMediaType:AVMediaTypeVideo])
        return nil;
    return settings;
}

static NSString *describeRanges(AVAssetWriterInputPassDescription *description)
{
    if (!description)
        return @"nil";
    NSMutableArray *parts = [NSMutableArray array];
    for (NSValue *value in description.sourceTimeRanges) {
        CMTimeRange range = value.CMTimeRangeValue;
        [parts addObject:[NSString stringWithFormat:@"{%lld/%d,%lld/%d}",
                          (long long)range.start.value, (int)range.start.timescale,
                          (long long)range.duration.value, (int)range.duration.timescale]];
    }
    return parts.count ? [parts componentsJoinedByString:@" "] : @"[]";
}

// ---- Waiting for the pass description, with a bound and not with a sleep. ----
//
// AVAssetWriterInput.h:485 says currentPassDescription starts out nil and takes its first non-nil value during
// the start of writing (-startWriting), and :504 says that after the pass is marked finished, the receiver
// decides whether another pass is needed and the description changes, usually asynchronously. :492 says the
// block runs once more so the client can mark the input finished in response. So the deliveries this harness depends on are the release's own promises,
// and the only question left is WHEN to look. The two waits below are how, and neither is a sleep:
//
//   * charon_wait_for_calls waits on a semaphore the block signals, with a deadline. It answers "did the
//     promised invocation arrive", and reports NO when the deadline passed.
//   * charon_settle waits for the promised invocations and then for a QUIET interval with no further
//     one. That is what "the analysis has finished" looks like from outside: with the switch on, Apple's
//     class may nominate a second pass or may not, and which one it does is its own answer - but either way
//     there is a last invocation, and until a quiet interval has passed the harness has not seen it.
//
// THE BOUNDS ARE MEASURED, not chosen to make a run pass. On this machine, with this Mac's own class, the
// invocation after -markCurrentPassAsFinished arrives 3 ms after the call when the machine is idle and 11 ms
// when four other heavy host tests are running beside it (measured over five rounds of eight each,
// .agent-work/runs/w-avf4/load-timing.sh). The quiet interval below is twenty times the worst of those, and
// the overall bound is generous enough that a missed delivery is a fact about the run rather than a fact
// about the timing.
//
// AND A RUN THAT MISSED ONE SAYS SO. Every count the waits decide is printed through
// charon_count_value, which prints the marker instead of a number when a promised delivery did not arrive,
// and run.sh refuses to cache a host table carrying that marker. A table whose count is a race is not a
// measurement, and the earlier version of this harness cached one: the coordinator's gate read
// "currentPassDescription after markAsFinished host=[{0/1,0/0}]" and
// "markAsFinished after the final pass invocation host=[RAISED NSInternalInconsistencyException]" from a
// table built once under load, and every later run in that tree reported unexplained=2.
static const double kCharonPassBoundSeconds = 2.0;    // the longest a promised invocation is waited for
static const double kCharonPassQuietSeconds = 0.25;   // no further invocation for this long: settled

// The marker, and the two functions that produce it.
static NSString *charon_timedOutMarker(void)
{
    return [NSString stringWithFormat:@"TIMED-OUT-%gs", kCharonPassBoundSeconds];
}

static NSString *charon_count_value(BOOL settled, NSInteger count)
{
    return settled ? [NSString stringWithFormat:@"%ld", (long)count] : charon_timedOutMarker();
}

static dispatch_time_t charon_deadline(double seconds)
{
    return dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * (double)NSEC_PER_SEC));
}

// atLeast invocations, then a quiet interval with no further one. Returns NO when the promised invocations
// did not arrive inside the bound, and YES when the last one has been seen and nothing has followed it.
// atLeast is 1 where the header promises an invocation (:492, in response to -markCurrentPassAsFinished -
// one that begins the next pass if another is warranted, and one final one either way) and 0 where it
// promises none (a pass that had already begun when the block was registered, and anything before
// -startWriting), because a wait with nothing to wait for cannot time out and must not pretend to.
static BOOL charon_settle(dispatch_semaphore_t semaphore, NSInteger atLeast)
{
    for (NSInteger index = 0; index < atLeast; index++) {
        if (dispatch_semaphore_wait(semaphore, charon_deadline(kCharonPassBoundSeconds)) != 0)
            return NO;
    }
    while (dispatch_semaphore_wait(semaphore, charon_deadline(kCharonPassQuietSeconds)) == 0)
        ;   // another invocation arrived inside the quiet window, so it is not settled yet
    return YES;
}

static void reportCall(NSString *label, void (^work)(void))
{
    @try {
        work();
        row(label.UTF8String, @"ACCEPTED");
    } @catch (NSException *raised) {
        row(label.UTF8String, [NSString stringWithFormat:@"RAISED %@", raised.name]);
    }
}

// Everything the header says about the state of the pass, read at each state an input passes through.
static void askInputState(NSString *when, AVAssetWriterInput *input)
{
    row([[NSString stringWithFormat:@"canPerformMultiplePasses %@", when] UTF8String],
        input.canPerformMultiplePasses ? @"YES" : @"NO");

    NSString *current = @"NOT-ANSWERED";
    @try {
        current = describeRanges(input.currentPassDescription);
    } @catch (NSException *raised) {
        current = [NSString stringWithFormat:@"RAISED %@", raised.name];
    }
    row([[NSString stringWithFormat:@"currentPassDescription %@", when] UTF8String], current);
}

// ---- the controls: the tables this run read at all. A run that read nothing must not print a table
//      that reads like a measurement. ----
static void askControls(void)
{
    configure(@"CONTROL");
    Class inputClass = [AVAssetWriterInput class];
    Class passClass = NSClassFromString(@"AVAssetWriterInputPassDescription");
    row("CLASS AVAssetWriterInput", inputClass ? @"PRESENT" : @"ABSENT");
    row("CLASS AVAssetWriterInputPassDescription", passClass ? @"PRESENT" : @"ABSENT");
    SEL (^member)(const char *) = ^SEL(const char *name) {
        return NSSelectorFromString([NSString stringWithUTF8String:name]);
    };
    row("SELECTOR markAsFinished",
        class_getInstanceMethod(inputClass, @selector(markAsFinished)) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR charonProbeNoSuchSelector",
        class_getInstanceMethod(inputClass, member("charonProbeNoSuchSelector")) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR performsMultiPassEncodingIfSupported",
        class_getInstanceMethod(inputClass, member("performsMultiPassEncodingIfSupported")) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR setPerformsMultiPassEncodingIfSupported:",
        class_getInstanceMethod(inputClass, member("setPerformsMultiPassEncodingIfSupported:")) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR canPerformMultiplePasses",
        class_getInstanceMethod(inputClass, member("canPerformMultiplePasses")) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR currentPassDescription",
        class_getInstanceMethod(inputClass, member("currentPassDescription")) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR respondToEachPassDescriptionOnQueue:usingBlock:",
        class_getInstanceMethod(inputClass, member("respondToEachPassDescriptionOnQueue:usingBlock:")) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR markCurrentPassAsFinished",
        class_getInstanceMethod(inputClass, member("markCurrentPassAsFinished")) ? @"PRESENT" : @"ABSENT");
    row("SELECTOR sourceTimeRanges",
        passClass && class_getInstanceMethod(passClass, @selector(sourceTimeRanges)) ? @"PRESENT" : @"ABSENT");
}

// ---- the three states before any writer is involved. The switch is set only where the configuration
//      says it is: asking "what does canPerformMultiplePasses read back after the switch is set" inside
//      the switch-OFF configuration would print the same row twice under two names, and a row that is
//      there twice is a row nobody reads twice.
static void askUnattachedStates(NSDictionary *settings, BOOL requestMultiplePasses)
{
    configure(requestMultiplePasses ? @"switch-on unattached" : @"switch-off unattached");
    CharonSpyInput *lonely = [[CharonSpyInput alloc] initWithProbeMediaType:AVMediaTypeVideo
                                                             outputSettings:settings];
    askInputState(@"unattached", lonely);
    if (!requestMultiplePasses)
        return;

    reportCall(@"performsMultiPassEncodingIfSupported set YES", ^{
        lonely.performsMultiPassEncodingIfSupported = YES;
    });
    row(@"performsMultiPassEncodingIfSupported reads back".UTF8String,
        lonely.performsMultiPassEncodingIfSupported ? @"YES" : @"NO");
    askInputState(@"unattached after setting the switch", lonely);
}

// ---- the precondition the header states, asked on an input that is attached but whose writer has not
//      started: the header requires the receiver to be attached to an AVAssetWriter through an earlier -addInput: and to have had -startWriting called before this method runs ----
static void askBeforeStartWriting(NSDictionary *settings, BOOL requestMultiplePasses)
{
    configure(requestMultiplePasses ? @"switch-on before startWriting" : @"switch-off before startWriting");
    NSURL *url = charon_scratchURL(@"early");
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeQuickTimeMovie
                                                         error:NULL];
    CharonSpyInput *input = [[CharonSpyInput alloc] initWithProbeMediaType:AVMediaTypeVideo
                                                            outputSettings:settings];
    if (requestMultiplePasses)
        input.performsMultiPassEncodingIfSupported = YES;
    row(@"canAddInput:".UTF8String, [writer canAddInput:input] ? @"ACCEPTED" : @"REFUSED");
    [writer addInput:input];
    askInputState(@"attached before startWriting", input);

    // A SERIAL queue, and a specific on it, so "how many times did the block run" and "did it run on the
    // queue it was given" are both answered by a wait rather than by a race. dispatch_sync on a serial
    // queue returns only after everything enqueued before it has run.
    dispatch_queue_t queue = dispatch_queue_create("charon.avf.writerinput8", DISPATCH_QUEUE_SERIAL);
    static const char key = 'c';
    dispatch_queue_set_specific(queue, &key, (void *)1, NULL);

    __block NSInteger calls = 0;
    __block NSMutableArray *seen = [NSMutableArray array];
    __block NSInteger onTheGivenQueue = 0;
    dispatch_semaphore_t arrived = dispatch_semaphore_create(0);
    void (^record)(void) = ^{
        calls++;
        [seen addObject:describeRanges(input.currentPassDescription)];
        if (dispatch_get_specific(&key))
            onTheGivenQueue++;
        dispatch_semaphore_signal(arrived);
    };
    reportCall(@"respondToEachPassDescription before startWriting", ^{
        [input respondToEachPassDescriptionOnQueue:queue usingBlock:record];
    });
    reportCall(@"respondToEachPassDescription a second time", ^{
        [input respondToEachPassDescriptionOnQueue:queue usingBlock:record];
    });
    // Nothing is promised before -startWriting - AVAssetWriterInput.h:505 forbids registering before it -
    // so there is nothing to wait FOR, and a quiet interval is what "nothing has arrived" means here.
    BOOL quiet = charon_settle(arrived, 0);
    row(@"block calls before startWriting".UTF8String, charon_count_value(quiet, calls));
    row(@"block on the given queue before startWriting".UTF8String, charon_count_value(quiet, onTheGivenQueue));

    reportCall(@"markCurrentPassAsFinished before startWriting", ^{
        [input markCurrentPassAsFinished];
    });
    reportCall(@"markAsFinished before startWriting", ^{
        [input markAsFinished];
    });
    row(@"markCurrentPassAsFinished called markAsFinished itself".UTF8String,
        input.invoked.count ? [input.invoked componentsJoinedByString:@","] : @"NO");
    [writer cancelWriting];
}

// ---- the whole sequence on one started writer, twice: the switch off, and the switch on ----
static void askFullSequence(NSDictionary *settings, BOOL requestMultiplePasses)
{
    configure(requestMultiplePasses ? @"switch-on" : @"switch-off");
    NSURL *url = charon_scratchURL(@"run");
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeQuickTimeMovie
                                                         error:NULL];
    CharonSpyInput *input = [[CharonSpyInput alloc] initWithProbeMediaType:AVMediaTypeVideo
                                                            outputSettings:settings];
    [writer addInput:input];

    dispatch_queue_t queue = dispatch_queue_create("charon.avf.writerinput8", DISPATCH_QUEUE_SERIAL);
    static const char key = 'c';
    dispatch_queue_set_specific(queue, &key, (void *)1, NULL);
    __block NSInteger calls = 0;
    __block NSMutableArray *seen = [NSMutableArray array];
    __block NSInteger onTheGivenQueue = 0;
    dispatch_semaphore_t arrived = dispatch_semaphore_create(0);

    if (requestMultiplePasses) {
        input.performsMultiPassEncodingIfSupported = YES;
        row(@"performsMultiPassEncodingIfSupported reads back before startWriting".UTF8String,
            input.performsMultiPassEncodingIfSupported ? @"YES" : @"NO");
    }

    row(@"startWriting".UTF8String, [writer startWriting] ? @"YES" : @"NO");
    askInputState(@"after startWriting", input);

    // the header: the switch becomes fixed as soon as the writer, the receiver's AVAssetWriter, has started writing
    reportCall(@"performsMultiPassEncodingIfSupported set YES after startWriting", ^{
        input.performsMultiPassEncodingIfSupported = YES;
    });
    row(@"performsMultiPassEncodingIfSupported reads back after startWriting".UTF8String,
        input.performsMultiPassEncodingIfSupported ? @"YES" : @"NO");
    askInputState(@"after setting the switch post-start", input);

    // the callback the header describes, registered where the header allows it: after -addInput: and
    // after -startWriting
    // A pass that had ALREADY begun when the block was registered is not one the header promises a
    // delivery for (:486 "whenever a NEW pass has begun", and the first pass begins during -startWriting,
    // which is before this call). So this is a bounded wait and not an expectation, and the rows say what
    // arrived inside it. Measured on the host: 0 or 1, and the 1 arrives 1-20 ms after the call whether the
    // machine is idle or four heavy host tests are running beside it - so what moves is Apple's own choice,
    // not a slow delivery.
    reportCall(@"respondToEachPassDescription after startWriting", ^{
        [input respondToEachPassDescriptionOnQueue:queue usingBlock:^{
            calls++;
            [seen addObject:describeRanges(input.currentPassDescription)];
            if (dispatch_get_specific(&key))
                onTheGivenQueue++;
            dispatch_semaphore_signal(arrived);
        }];
    });
    BOOL registrationSettled = charon_settle(arrived, 0);
    row(@"block calls on registration".UTF8String, charon_count_value(registrationSettled, calls));
    row(@"block on the given queue on registration".UTF8String, charon_count_value(registrationSettled, onTheGivenQueue));

    reportCall(@"respondToEachPassDescription a second time after startWriting", ^{
        [input respondToEachPassDescriptionOnQueue:queue usingBlock:^{
            calls++;
            dispatch_semaphore_signal(arrived);
        }];
    });

    // the header: with canPerformMultiplePasses NO, currentPassDescription becomes nil straight after the call that
    // marks the pass finished, and the block is invoked one last time so the client can mark the input finished in response.
    [input.invoked removeAllObjects];
    reportCall(@"markCurrentPassAsFinished after startWriting", ^{
        [input markCurrentPassAsFinished];
    });
    // THE WAIT THAT FIXES THE POISONED TABLE. :492 promises an invocation in response to this call - one
    // that begins the next pass if another is warranted, and one final one so the client can invoke
    // -markAsFinished - and :504 says it arrives after the receiver has analysed, "usually
    // asynchronously". Every row below reads the state AFTER that analysis, so each one first waits for
    // the promised invocations and then for a quiet interval with no further one. Asking before the
    // analysis has landed is what made "currentPassDescription after markAsFinished" and "markAsFinished
    // after the final pass invocation" answers to the machine's load, and the cached table carried them.
    BOOL analysisSettled = charon_settle(arrived, 1);
    askInputState(@"after markCurrentPassAsFinished", input);
    row(@"markCurrentPassAsFinished called markAsFinished itself".UTF8String,
        input.invoked.count ? [input.invoked componentsJoinedByString:@","] : @"NO");
    row(@"block calls after markCurrentPassAsFinished".UTF8String, charon_count_value(analysisSettled, calls));
    row(@"block on the given queue after markCurrentPassAsFinished".UTF8String,
        charon_count_value(analysisSettled, onTheGivenQueue));
    row(@"block saw".UTF8String, analysisSettled ? (seen.count ? [seen componentsJoinedByString:@" then "] : @"NONE")
                                                 : charon_timedOutMarker());

    // a second -markCurrentPassAsFinished, now that there is no pass left to mark: the header does not
    // say it is refused, so it is asked rather than assumed either way
    reportCall(@"markCurrentPassAsFinished a second time", ^{
        [input markCurrentPassAsFinished];
    });
    analysisSettled = charon_settle(arrived, 0);
    row(@"block calls after a second markCurrentPassAsFinished".UTF8String, charon_count_value(analysisSettled, calls));

    // and the client does what the final invocation told it to. With the switch on, Apple's own class
    // is between passes here and refuses, so this is caught like every other refusal: a run that dies
    // half way through prints a table that reads like a measurement and is not one.
    reportCall(@"markAsFinished after the final pass invocation", ^{
        [input markAsFinished];
    });
    // and the same wait once more, because this row's answer is the state the writer input is in AFTER
    // -markAsFinished, which is only the header's documented state once the final invocation has landed.
    analysisSettled = charon_settle(arrived, 0);
    askInputState(@"after markAsFinished", input);
    row(@"finishWriting".UTF8String, [writer finishWriting] ? @"YES" : @"NO");
    askInputState(@"after finishWriting", input);

    // The AVAssetExportSession member of the same mechanism, asked of a REAL asset: the release's own
    // -initWithAsset:presetName: answers nil for a nil asset, so nothing would be measured, and a row
    // that answers NOT-ANSWERED is not a measurement.
AVURLAsset *written = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:written
                                                                    presetName:AVAssetExportPresetPassthrough];
    if (!session) {
        row(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData".UTF8String, @"NO-SESSION");
    } else {
        @try {
            row(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData".UTF8String,
                session.canPerformMultiplePassesOverSourceMediaData ? @"YES" : @"NO");
        } @catch (NSException *raised) {
            row(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData".UTF8String,
                [NSString stringWithFormat:@"RAISED %@", raised.name]);
        }
        // the read/write pair, and the header's own rule that this property is fixed once the export has begun,
        // so it is asked with an export actually in flight, because a property that is locked after
        // a start is a different answer from one that cannot be set after nothing.
        reportCall(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData set YES", ^{
            session.canPerformMultiplePassesOverSourceMediaData = YES;
        });
        row(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData reads back".UTF8String,
            session.canPerformMultiplePassesOverSourceMediaData ? @"YES" : @"NO");
        dispatch_semaphore_t exported = dispatch_semaphore_create(0);
        // the release's own two members an export needs, or -exportAsynchronouslyWithCompletionHandler:
        // raises "outputURL cannot be nil" and nothing below would be measured
        session.outputURL = charon_scratchURL(@"export");
        session.outputFileType = AVFileTypeQuickTimeMovie;
        [session exportAsynchronouslyWithCompletionHandler:^{
            dispatch_semaphore_signal(exported);
        }];
        reportCall(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData set YES after the export started", ^{
            session.canPerformMultiplePassesOverSourceMediaData = YES;
        });
        // and what it read back afterwards, which is the whole of what a stored switch can tell a caller
        row(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData reads back after the export started".UTF8String,
            session.canPerformMultiplePassesOverSourceMediaData ? @"YES" : @"NO");
        dispatch_semaphore_wait(exported, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    }
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

// ---- the release's own way of ending a pass, with none of the 8.0 family called at all: what the port
//      has to answer for a client that only ever uses -markAsFinished ----
static void askMarkAsFinishedOnly(NSDictionary *settings)
{
    configure(@"markAsFinished only");
    NSURL *url = charon_scratchURL(@"only");
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeQuickTimeMovie
                                                         error:NULL];
    CharonSpyInput *input = [[CharonSpyInput alloc] initWithProbeMediaType:AVMediaTypeVideo
                                                            outputSettings:settings];
    [writer addInput:input];
    row(@"startWriting".UTF8String, [writer startWriting] ? @"YES" : @"NO");
    askInputState(@"after startWriting", input);
    [input markAsFinished];
    askInputState(@"after markAsFinished with no pass callback", input);
    [writer finishWriting];
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

int main(void)
{
    @autoreleasepool {
        askControls();
        NSDictionary *settings = charon_encodableSettings();
        if (!settings) {
            configure(@"CONFIGURATION");
            row(@"h264 16x16, no bitrate".UTF8String, @"THIS-MACHINE-ENCODES-NO-H264 so nothing below ran");
            printf("rows: %d\n", rowIndex);
            return 0;
        }
        configure(@"CONFIGURATION");
        row(@"h264 16x16, no bitrate".UTF8String, @"the settings this machine accepts, asked of -canApplyOutputSettings:forMediaType:");

        askUnattachedStates(settings, NO);
        askUnattachedStates(settings, YES);
        askBeforeStartWriting(settings, NO);
        askBeforeStartWriting(settings, YES);
        askFullSequence(settings, NO);
        askFullSequence(settings, YES);
        askMarkAsFinishedOnly(settings);

        configure(@"COUNT");
        row(@"rows".UTF8String, [NSString stringWithFormat:@"%d", rowIndex]);
    }
    return 0;
}
