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

static NSURL *write_source(void)
{
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                          [NSString stringWithFormat:@"revenant-export-filter-%u.mov", getpid()]]];
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
static void revenant_set_filter(AVAssetExportSession *session, AVMetadataItemFilter *filter)
{
    IMP port = method_getImplementation(class_getInstanceMethod([AVAssetExportSession class],
                                                              @selector(setMetadataItemFilter:)));
    ((void (*)(id, SEL, id))port)(session, @selector(setMetadataItemFilter:), filter);
}

static AVMetadataItemFilter *revenant_get_filter(AVAssetExportSession *session)
{
    IMP port = method_getImplementation(class_getInstanceMethod([AVAssetExportSession class],
                                                              @selector(metadataItemFilter)));
    return ((AVMetadataItemFilter *(*)(id, SEL))port)(session, @selector(metadataItemFilter));
}

static void revenant_start_export(AVAssetExportSession *session, dispatch_block_t handler)
{
    IMP port = method_getImplementation(class_getInstanceMethod([AVAssetExportSession class],
                                                              @selector(exportAsynchronouslyWithCompletionHandler:)));
    ((void (*)(id, SEL, id))port)(session, @selector(exportAsynchronouslyWithCompletionHandler:), handler);
}
#else
static void revenant_set_filter(AVAssetExportSession *session, AVMetadataItemFilter *filter)
{
    session.metadataItemFilter = filter;
}

static AVMetadataItemFilter *revenant_get_filter(AVAssetExportSession *session)
{
    return session.metadataItemFilter;
}

static void revenant_start_export(AVAssetExportSession *session, dispatch_block_t handler)
{
    [session exportAsynchronouslyWithCompletionHandler:handler];
}
#endif

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
                                                   [NSString stringWithFormat:@"revenant-export-out-%@-%u.mov", label, getpid()]]];
    session.outputFileType = AVFileTypeQuickTimeMovie;
    if (own)
        session.metadata = own;
    revenant_set_filter(session, filter);
    row(@"filter round-trips", revenant_get_filter(session) ? @"YES" : @"NO");

    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    revenant_start_export(session, ^{
        dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    row(@"metadata after the export", identifiers_of(session.metadata));
    row(@"the filter still reads back", revenant_get_filter(session) ? @"YES" : @"NO");
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

        section = @"release filter: ";
        AVMetadataItemFilter *sharing = [AVMetadataItemFilter metadataItemFilterForSharing];
        row(@"sharing filter present", sharing ? @"YES" : @"NO");
        row(@"sharing filter over the source",
            identifiers_of([AVMetadataItem metadataItemsFromArray:[AVURLAsset URLAssetWithURL:source options:nil].commonMetadata
                                        filteredByMetadataItemFilter:sharing]));

        one_export(@"no filter", source, nil, nil);
        one_export(@"sharing filter", source, sharing, nil);

        AVMutableMetadataItem *own = [[AVMutableMetadataItem alloc] init];
        own.keySpace = AVMetadataKeySpaceCommon;
        own.key = AVMetadataCommonKeyTitle;
        own.value = @"revenant";
        one_export(@"own metadata", source, sharing, @[own]);

        section = @"";
        row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
    }
    return 0;
}
