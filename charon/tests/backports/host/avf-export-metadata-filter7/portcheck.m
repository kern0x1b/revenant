//  portcheck.m - the PORT's metadataItemFilter step, against the stand-in release in standin/.
//
//  Compiled with -I standin, so <AVFoundation/AVFoundation.h> is a release-shaped AVAssetExportSession with
//  no 7.0 member, and linked with the port's own AVFoundation/AVAssetExportSessionMetadataItemFilter7.m
//  UNMODIFIED. The port's guard therefore sees a release that has not arrived and installs, which is what
//  happens on 6.1.3 and cannot happen on this machine - and the guard member is printed, so a run where it
//  did not install says so instead of passing.
//
//  The rows it prints are the ones writer.m prints for the same three cases, so the two tables join on the
//  key. What is on the session afterwards is the whole of the port's step: nil when no filter is set, the
//  RELEASE's own filtered answer when one is, and the caller's own array untouched when the caller set one.
//
//  One row of the PORT's table is compared against another row of the PORT's table and not against the
//  host: `sharing filter: metadata after the export` must be exactly `release filter: sharing filter over
//  the source`, which is the release's own filtering entry point's answer for the source's own array.
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <stdio.h>

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

int main(void)
{
    @autoreleasepool {
        section = @"";
        Class sessionClass = [AVAssetExportSession class];
        row(@"CONTROL concrete session class", NSStringFromClass(sessionClass));
        // The guard's own member. The port reads it to ask whether the release carries 7.0, and the
        // stand-in deliberately does not declare it, so the port installs. A run where this reads PRESENT
        // measured the port declining to install.
        row(@"CONTROL the guard's member audioTimePitchAlgorithm",
            class_getInstanceMethod(sessionClass, @selector(audioTimePitchAlgorithm)) ? @"PRESENT" : @"ABSENT");
        row(@"CONTROL the class carries the port's property",
            class_getInstanceMethod(sessionClass, @selector(metadataItemFilter)) ? @"PRESENT" : @"ABSENT");

        AVAsset *source = [AVAsset new];
        AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:source
                                                                        presetName:AVAssetExportPresetPassthrough];
        row(@"CONTROL dispatched IMP",
            [NSString stringWithFormat:@"%p", (void *)[session methodForSelector:@selector(exportAsynchronouslyWithCompletionHandler:)]]);
        row(@"CONTROL class IMP",
            [NSString stringWithFormat:@"%p",
             (void *)method_getImplementation(class_getInstanceMethod(sessionClass,
                                                                      @selector(exportAsynchronouslyWithCompletionHandler:)))]);
        row(@"CONTROL the source's own common metadata", identifiers_of(source.commonMetadata));

        section = @"release filter: ";
        AVMetadataItemFilter *sharing = [AVMetadataItemFilter metadataItemFilterForSharing];
        row(@"sharing filter present", sharing ? @"YES" : @"NO");
        row(@"sharing filter over the source",
            identifiers_of([AVMetadataItem metadataItemsFromArray:source.commonMetadata
                                        filteredByMetadataItemFilter:sharing]));

        // 1. no filter: the step must not run
        section = @"no filter: ";
        {
            AVAssetExportSession *each = [[AVAssetExportSession alloc] initWithAsset:source
                                                                          presetName:AVAssetExportPresetPassthrough];
            [each exportAsynchronouslyWithCompletionHandler:^{}];
            row(@"filter round-trips", each.metadataItemFilter ? @"YES" : @"NO");
            row(@"metadata after the export", identifiers_of(each.metadata));
            row(@"the filter still reads back", each.metadataItemFilter ? @"YES" : @"NO");
        }
        // 2. a filter and no metadata of the caller's: the step runs
        section = @"sharing filter: ";
        {
            AVAssetExportSession *each = [[AVAssetExportSession alloc] initWithAsset:source
                                                                          presetName:AVAssetExportPresetPassthrough];
            each.metadataItemFilter = sharing;
            row(@"filter round-trips", each.metadataItemFilter ? @"YES" : @"NO");
            [each exportAsynchronouslyWithCompletionHandler:^{}];
            row(@"metadata after the export", identifiers_of(each.metadata));
            row(@"the filter still reads back", each.metadataItemFilter ? @"YES" : @"NO");
        }
        // 3. a filter and the caller's own metadata: the header says the filter is never applied to it
        section = @"own metadata: ";
        {
            AVMetadataItem *own = [AVMetadataItem new];
            // The same identifier writer.m's own metadata item reads back (AVMetadataCommonKeyTitle), so
            // the "own metadata" row is the same string on both sides and a difference in it is a
            // difference in what the port did rather than in what each program built.
            [own setValue:@"common/title" forKey:@"identifier"];
            AVAssetExportSession *each = [[AVAssetExportSession alloc] initWithAsset:source
                                                                          presetName:AVAssetExportPresetPassthrough];
            each.metadata = @[own];
            each.metadataItemFilter = sharing;
            row(@"filter round-trips", each.metadataItemFilter ? @"YES" : @"NO");
            [each exportAsynchronouslyWithCompletionHandler:^{}];
            row(@"metadata after the export", identifiers_of(each.metadata));
            row(@"the filter still reads back", each.metadataItemFilter ? @"YES" : @"NO");
        }
        section = @"";
        row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
    }
    return 0;
}
