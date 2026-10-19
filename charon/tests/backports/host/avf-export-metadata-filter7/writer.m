//  writer.m
//  AVAssetExportSession.metadataItemFilter: the property, and the step that applies it. ONE file,
//  compiled twice, against a real export of a real file.
//
//    -DCHARN_PORT_HALF=0   no port object in the link: every answer is Apple's, and this half is the
//                          ORACLE.
//    -DCHARN_PORT_HALF=1   the port's own AVFoundation/AVAssetExportSessionMetadataItemFilter7.m in the
//                          link; the property is read and written through the PORT's accessors and the
//                          export is started through the PORT's interposed implementation.
//
//  Three cases, because the header names two conditions and the default is the third:
//  AVAssetExportSession.h:383-386 says a nil value for this key means no filter is applied, which is the default, and that
//  the filter is not applied to metadata that was set through the metadata property.
//
//    no filter            the step must not run, and the session's metadata must stay nil
//    filter, no metadata  the step runs, and what it leaves is exactly what the release's own filtering
//                         entry point answers for the source's array - the row below, which both halves
//                         ask and which is therefore the release's answer and not the port's
//    filter, own metadata the caller's own array is left exactly as it was
//
//  **What the oracle decides, and the one row that differs.** Apple's own session writes the kept items
//  into the OUTPUT FILE and leaves `metadata` nil; this release has no member that hands the file a list,
//  so the port leaves them on the session and lets the release's own export write them. That one row
//  differs, ALLOWANCES names it, and the row the check holds the port to is the equality with the
//  release's own filtered answer.
//
//  The concrete class of an export session on this machine IS AVAssetExportSession (printed as a control),
//  so a message send reaches the port's interposed method here; the port half still calls it through its
//  own IMP, so that what is measured is the port's implementation and not the one the runtime would pick.
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <stdio.h>

#ifndef CHARN_PORT_HALF
#define CHARN_PORT_HALF 0
#endif

static int rowIndex;
static NSString *section = @"";

static void row(NSString *key, NSString *value)
{
    rowIndex++;
    printf("%s\n", [[NSString stringWithFormat:@"%@%@ | %@", section, key, value] UTF8String]);
    fflush(stdout);
}

static NSString *identifiers_of(NSArray<AVMetadataItem *> *items)
{
    if (!items)
        return @"nil";
    NSMutableArray *identifiers = [NSMutableArray array];
    for (AVMetadataItem *item in items)
        [identifiers addObject:item.identifier ?: @"(nil)"];
    return identifiers.count ? [identifiers componentsJoinedByString:@","] : @"(none)";
}

// A real movie, written with the release's own writer, so the export has a source. It carries no common
// metadata: a filter over an empty array keeps nothing, which is a weaker measurement than one over a
// populated file and is said so here rather than glossed - what it does establish is that the step RUNS
// (nil becomes the release's filtered answer) and that the caller's own array is never touched.
static NSURL *write_source(void)
{
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                          [NSString stringWithFormat:@"charon-export-filter-%u.mov", getpid()]]];
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeQuickTimeMovie error:NULL];
    NSDictionary *settings = @{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @16, AVVideoHeightKey: @16};
    if (!writer || ![writer canApplyOutputSettings:settings forMediaType:AVMediaTypeVideo])
        return nil;
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                     outputSettings:settings];
    [writer addInput:input];
    if (![writer startWriting])
        return nil;
    [writer startSessionAtSourceTime:kCMTimeZero];
    [input markAsFinished];
    [writer endSessionAtSourceTime:kCMTimeZero];
    [writer finishWriting];
    return url;
}

#if CHARN_PORT_HALF
static void charon_set_filter(AVAssetExportSession *session, AVMetadataItemFilter *filter)
{
    IMP port = method_getImplementation(class_getInstanceMethod([AVAssetExportSession class],
                                                              @selector(setMetadataItemFilter:)));
    ((void (*)(id, SEL, id))port)(session, @selector(setMetadataItemFilter:), filter);
}

static AVMetadataItemFilter *charon_get_filter(AVAssetExportSession *session)
{
    IMP port = method_getImplementation(class_getInstanceMethod([AVAssetExportSession class],
                                                              @selector(metadataItemFilter)));
    return ((AVMetadataItemFilter *(*)(id, SEL))port)(session, @selector(metadataItemFilter));
}

static void charon_start_export(AVAssetExportSession *session, dispatch_block_t handler)
{
    IMP port = method_getImplementation(class_getInstanceMethod([AVAssetExportSession class],
                                                              @selector(exportAsynchronouslyWithCompletionHandler:)));
    ((void (*)(id, SEL, id))port)(session, @selector(exportAsynchronouslyWithCompletionHandler:), handler);
}
#else
static void charon_set_filter(AVAssetExportSession *session, AVMetadataItemFilter *filter)
{
    session.metadataItemFilter = filter;
}

static AVMetadataItemFilter *charon_get_filter(AVAssetExportSession *session)
{
    return session.metadataItemFilter;
}

static void charon_start_export(AVAssetExportSession *session, dispatch_block_t handler)
{
    [session exportAsynchronouslyWithCompletionHandler:handler];
}
#endif

// One export, and what is on the session afterwards. `own` is a metadata array the caller sets itself.
static void one_export(NSString *label, NSURL *source, AVMetadataItemFilter *filter, NSArray<AVMetadataItem *> *own)
{
    section = [label stringByAppendingString:@": "];
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:[AVURLAsset URLAssetWithURL:source options:nil]
                                                                  presetName:AVAssetExportPresetPassthrough];
    if (!session) {
        row(@"session", @"nil");
        return;
    }
    session.outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                                   [NSString stringWithFormat:@"charon-export-out-%@-%u.mov", label, getpid()]]];
    session.outputFileType = AVFileTypeQuickTimeMovie;
    if (own)
        session.metadata = own;
    charon_set_filter(session, filter);
    row(@"filter round-trips", charon_get_filter(session) ? @"YES" : @"NO");

    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    charon_start_export(session, ^{
        dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    row(@"metadata after the export", identifiers_of(session.metadata));
    row(@"the filter still reads back", charon_get_filter(session) ? @"YES" : @"NO");
}

int main(void)
{
    @autoreleasepool {
        section = @"";
        NSURL *source = write_source();
        row(@"CONTROL source file written", source ? @"YES" : @"NO");
        if (!source) {
            row(@"RUN", @"this machine could not write the source file, so nothing below was measured");
            row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
            return 0;
        }
        AVAssetExportSession *probe = [[AVAssetExportSession alloc] initWithAsset:[AVURLAsset URLAssetWithURL:source options:nil]
                                                                    presetName:AVAssetExportPresetPassthrough];
        row(@"CONTROL concrete session class", NSStringFromClass([(NSObject *)probe class]));
        row(@"CONTROL dispatched IMP",
            [NSString stringWithFormat:@"%p", (void *)[probe methodForSelector:@selector(exportAsynchronouslyWithCompletionHandler:)]]);
        row(@"CONTROL class IMP",
            [NSString stringWithFormat:@"%p",
             (void *)method_getImplementation(class_getInstanceMethod([AVAssetExportSession class],
                                                                      @selector(exportAsynchronouslyWithCompletionHandler:)))]);
        row(@"CONTROL the source's own common metadata",
            identifiers_of([AVURLAsset URLAssetWithURL:source options:nil].commonMetadata));

        // The release's own filtering entry point over the source's own array. Both halves ask it, so this
        // row is the expectation both are held to - and it is the release's answer, because the port
        // already carries +[AVMetadataItem metadataItemsFromArray:filteredByMetadataItemFilter:] and is
        // held against Apple's in tests/backports/host/avf-metadata.
        section = @"release filter: ";
        AVMetadataItemFilter *sharing = [AVMetadataItemFilter metadataItemFilterForSharing];
        row(@"sharing filter present", sharing ? @"YES" : @"NO");
        row(@"sharing filter over the source",
            identifiers_of([AVMetadataItem metadataItemsFromArray:[AVURLAsset URLAssetWithURL:source options:nil].commonMetadata
                                        filteredByMetadataItemFilter:sharing]));

        one_export(@"no filter", source, nil, nil);
        one_export(@"sharing filter", source, sharing, nil);

        // the caller's own metadata, which the header says the filter is never applied to
        AVMutableMetadataItem *own = [[AVMutableMetadataItem alloc] init];
        own.keySpace = AVMetadataKeySpaceCommon;
        own.key = AVMetadataCommonKeyTitle;
        own.value = @"charon";
        one_export(@"own metadata", source, sharing, @[own]);

        section = @"";
        row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
    }
    return 0;
}