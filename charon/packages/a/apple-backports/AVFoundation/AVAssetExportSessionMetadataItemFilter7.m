#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// AVAssetExportSession.metadataItemFilter, iOS 7.0: the property, and the step that applies it.
//
// **What the release the port runs on has.** 6.1.3's AVAssetExportSession carries 54 own instance methods
// and 23 own class methods, and its whole metadata surface is -metadata/-setMetadata: - the metadata
// export predates 7.0. There is no filter member, no member that names one, and no member that hands the
// export a list of items to translate: when `metadata` is nil the session copies the source asset's own
// metadata across itself. What 7.0 added is this property and the step that reads it.
//
// **The step has exactly one place to live on this release.** The header (AVAssetExportSession.h:379-386) defines an
// export filter as the object that picks which metadata items are carried over from the source asset. Nil, the default,
// means no filter, and metadata set through the metadata property is left alone. So the filter runs when the export
// starts and only when the caller has set no metadata of its own, and on this release the only moment the port can act is
// -[AVAssetExportSession exportAsynchronouslyWithCompletionHandler:] - 6.1.3's own member, measured
// present at 4.3 and at 6.0 as well - which every path into an export goes through.
//
// **What the port filters with is the release's own answer, not a list it built.** The port already carries
// +[AVMetadataItem metadataItemsFromArray:filteredByMetadataItemFilter:] (AVFoundation/AVMetadataItemGroups7.m,
// 7.0's, measured against Apple's own in tests/backports/host/avf-metadata), so the filtering itself is the
// release's semantics and not a re-implementation here; this object hands it the source asset's own
// common metadata and takes what comes back.
//
// **What a caller sees afterwards, measured on this Mac.** Apple's own session leaves `metadata` nil after
// the export starts and writes the filtered items into the output file instead, because there is a file to
// write them to. This release has no member that takes the items for the file, so the port puts them where
// the release will read them - on the session - and the export writes what the filter kept. A caller that
// reads `metadata` after starting an export therefore sees the filtered list here and nil on 7.0; that is
// written down in the row, and it is the price of doing the filter at the only hook the release has.
//
// Nothing here replaces a release method: the interposed implementation calls the release's own
// implementation first and then does the port's step, and it is installed only where the release does not
// carry the property - the same guard and the same idiom as
// AVFoundation/AVAssetWriterInputMultiPass8.m.

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
    // OBJC_ASSOCIATION_RETAIN, because the header says `@property (nonatomic, retain)`: the session holds
    // the filter for its own lifetime and the caller may drop it immediately after setting it.
    objc_setAssociatedObject(self, &charon_export_filter, metadataItemFilter, OBJC_ASSOCIATION_RETAIN);
}

@end

// The one step, named so both the interposed method and a reader of this file can see what it does.
static void charon_apply_export_filter(AVAssetExportSession *session)
{
    AVMetadataItemFilter *filter = objc_getAssociatedObject(session, &charon_export_filter);
    // The header's own two conditions: no filter means no step, and a metadata property the caller set is
    // left alone by the filter (AVAssetExportSession.h:384-386), so a caller's own list stays untouched.
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
    // Nothing to install where the release carries the property. -audioTimePitchAlgorithm is 7.0's own
    // (measured: 0 in 6.1.3's whole 113981-name selector set, 6 at 7.0 and 3 at 8.0 over the armv7 caches,
    // 1 at 11.0 arm64) and the port adds no member of that name - it is `absent` in
    // absent_AVFoundation.json - so the read is of the RELEASE's table whatever order this library's own
    // categories are attached in. Guarding on -metadataItemFilter itself would read this library's own
    // category on any runtime that attaches categories before +load, which is the reverse of the order
    // attach.c's constructor uses on the device.
    Class session = [AVAssetExportSession class];
    if (class_getInstanceMethod(session, @selector(audioTimePitchAlgorithm)))
        return;

    IMP original = class_getMethodImplementation(session, @selector(exportAsynchronouslyWithCompletionHandler:));
    if (!original)
        return;
    class_replaceMethod(session, @selector(exportAsynchronouslyWithCompletionHandler:),
                        imp_implementationWithBlock(^(AVAssetExportSession *self_, void (^handler)(void)) {
        // After the release's own export, not instead of it: the session has begun, the source is known,
        // and the release is about to translate whatever `metadata` holds into the output file.
        ((void (*)(id, SEL, id))original)(self_, @selector(exportAsynchronouslyWithCompletionHandler:), handler);
        charon_apply_export_filter(self_);
    }), "ccharon_exportAsynchronouslyWithCompletionHandler");
}

@end