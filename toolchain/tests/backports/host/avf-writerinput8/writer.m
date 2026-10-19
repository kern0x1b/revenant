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

@interface CharonSpyInput : AVAssetWriterInput
@property (nonatomic, strong) NSMutableArray<NSString *> *invoked;
@end

@implementation CharonSpyInput

- (instancetype)initWithProbeMediaType:(AVMediaType)mediaType outputSettings:(NSDictionary *)settings
{
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

static const double kCharonPassBoundSeconds = 2.0;
static const double kCharonPassQuietSeconds = 0.25;

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

static BOOL charon_settle(dispatch_semaphore_t semaphore, NSInteger atLeast)
{
    for (NSInteger index = 0; index < atLeast; index++) {
        if (dispatch_semaphore_wait(semaphore, charon_deadline(kCharonPassBoundSeconds)) != 0)
            return NO;
    }
    while (dispatch_semaphore_wait(semaphore, charon_deadline(kCharonPassQuietSeconds)) == 0)
        ;
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

    reportCall(@"performsMultiPassEncodingIfSupported set YES after startWriting", ^{
        input.performsMultiPassEncodingIfSupported = YES;
    });
    row(@"performsMultiPassEncodingIfSupported reads back after startWriting".UTF8String,
        input.performsMultiPassEncodingIfSupported ? @"YES" : @"NO");
    askInputState(@"after setting the switch post-start", input);

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

    [input.invoked removeAllObjects];
    reportCall(@"markCurrentPassAsFinished after startWriting", ^{
        [input markCurrentPassAsFinished];
    });
    BOOL analysisSettled = charon_settle(arrived, 1);
    askInputState(@"after markCurrentPassAsFinished", input);
    row(@"markCurrentPassAsFinished called markAsFinished itself".UTF8String,
        input.invoked.count ? [input.invoked componentsJoinedByString:@","] : @"NO");
    row(@"block calls after markCurrentPassAsFinished".UTF8String, charon_count_value(analysisSettled, calls));
    row(@"block on the given queue after markCurrentPassAsFinished".UTF8String,
        charon_count_value(analysisSettled, onTheGivenQueue));
    row(@"block saw".UTF8String, analysisSettled ? (seen.count ? [seen componentsJoinedByString:@" then "] : @"NONE")
                                                 : charon_timedOutMarker());

    reportCall(@"markCurrentPassAsFinished a second time", ^{
        [input markCurrentPassAsFinished];
    });
    analysisSettled = charon_settle(arrived, 0);
    row(@"block calls after a second markCurrentPassAsFinished".UTF8String, charon_count_value(analysisSettled, calls));

    reportCall(@"markAsFinished after the final pass invocation", ^{
        [input markAsFinished];
    });
    analysisSettled = charon_settle(arrived, 0);
    askInputState(@"after markAsFinished", input);
    row(@"finishWriting".UTF8String, [writer finishWriting] ? @"YES" : @"NO");
    askInputState(@"after finishWriting", input);

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
        reportCall(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData set YES", ^{
            session.canPerformMultiplePassesOverSourceMediaData = YES;
        });
        row(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData reads back".UTF8String,
            session.canPerformMultiplePassesOverSourceMediaData ? @"YES" : @"NO");
        dispatch_semaphore_t exported = dispatch_semaphore_create(0);
        session.outputURL = charon_scratchURL(@"export");
        session.outputFileType = AVFileTypeQuickTimeMovie;
        [session exportAsynchronouslyWithCompletionHandler:^{
            dispatch_semaphore_signal(exported);
        }];
        reportCall(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData set YES after the export started", ^{
            session.canPerformMultiplePassesOverSourceMediaData = YES;
        });
        row(@"AVAssetExportSession canPerformMultiplePassesOverSourceMediaData reads back after the export started".UTF8String,
            session.canPerformMultiplePassesOverSourceMediaData ? @"YES" : @"NO");
        dispatch_semaphore_wait(exported, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    }
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

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
