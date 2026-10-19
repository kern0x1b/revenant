#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const char charon_export_filter;

@interface AVAssetExportSession (CharonMetadataItemFilter7)
- (AVMetadataItemFilter *)metadataItemFilter;
- (void)setMetadataItemFilter:(AVMetadataItemFilter *)metadataItemFilter;
@end

@implementation AVAssetExportSession (CharonMetadataItemFilter7)

- (AVMetadataItemFilter *)metadataItemFilter
{
    return objc_getAssociatedObject(self, &charon_export_filter);
}

- (void)setMetadataItemFilter:(AVMetadataItemFilter *)metadataItemFilter
{
    objc_setAssociatedObject(self, &charon_export_filter, metadataItemFilter, OBJC_ASSOCIATION_RETAIN);
}

@end

static void charon_apply_export_filter(AVAssetExportSession *session)
{
    AVMetadataItemFilter *filter = objc_getAssociatedObject(session, &charon_export_filter);
    if (!filter || session.metadata)
        return;
    NSArray<AVMetadataItem *> *copied = [AVMetadataItem metadataItemsFromArray:session.asset.commonMetadata
                                                    filteredByMetadataItemFilter:filter];
    if (copied)
        session.metadata = copied;
}

@interface CharonExportMetadataFilterInstaller : NSObject
@end

@implementation CharonExportMetadataFilterInstaller

+ (void)load
{
    Class session = [AVAssetExportSession class];
    if (class_getInstanceMethod(session, @selector(audioTimePitchAlgorithm)))
        return;

    IMP original = class_getMethodImplementation(session, @selector(exportAsynchronouslyWithCompletionHandler:));
    if (!original)
        return;
    class_replaceMethod(session, @selector(exportAsynchronouslyWithCompletionHandler:),
                        imp_implementationWithBlock(^(AVAssetExportSession *self_, void (^handler)(void)) {
        ((void (*)(id, SEL, id))original)(self_, @selector(exportAsynchronouslyWithCompletionHandler:), handler);
        charon_apply_export_filter(self_);
    }), "ccharon_exportAsynchronouslyWithCompletionHandler");
}

@end
