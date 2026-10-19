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

        section = @"no filter: ";
        {
            AVAssetExportSession *each = [[AVAssetExportSession alloc] initWithAsset:source
                                                                          presetName:AVAssetExportPresetPassthrough];
            [each exportAsynchronouslyWithCompletionHandler:^{}];
            row(@"filter round-trips", each.metadataItemFilter ? @"YES" : @"NO");
            row(@"metadata after the export", identifiers_of(each.metadata));
            row(@"the filter still reads back", each.metadataItemFilter ? @"YES" : @"NO");
        }
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
        section = @"own metadata: ";
        {
            AVMetadataItem *own = [AVMetadataItem new];
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
