//  standin.m - the RELEASE side of tests/backports/host/avf-export-metadata-filter7, implemented.
//
//  A release-shaped export session with no 7.0 member, so the port's guard sees a release that has not
//  arrived and installs, and with the source's own common metadata behind it so the filter has something
//  real to keep or drop. The port's own object is compiled UNMODIFIED against this header and linked
//  against this class, so what runs is the port's step and not a copy of it.
//
//  It implements no member of the 7.0 family. -exportAsynchronouslyWithCompletionHandler: IS the
//  release's own and is implemented here, because the port interposes on it rather than replacing it: the
//  port's implementation calls this one and then does its step.
#import <AVFoundation/AVFoundation.h>

NSString *const AVAssetExportPresetPassthrough = @"AVAssetExportPresetPassthrough";
NSString *const AVFileTypeQuickTimeMovie = @"com.apple.quicktime-movie";

static NSArray *charon_source_metadata(void)
{
    // Two items, one the kind of thing a filter removes and one it keeps, so the step has a choice to
    // make. Built here rather than in a file so nothing in the test depends on writing a movie.
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *identifier in @[@"mdta/keys/copyright", @"mdta/keys/location"]) {
        AVMetadataItem *item = [AVMetadataItem new];
        [item setValue:identifier forKey:@"identifier"];
        [items addObject:item];
    }
    return items;
}

// The stand-in's filter. Apple's class declares only +metadataItemFilterForSharing, and the list it is
// built from is inside a private AVMetadataItemFilterInternal, so the stand-in's answers the one factory
// the SDK declares and hands back a filter with the empty list - which, by the 7.0 semantics the port
// already carries, keeps everything.
@implementation AVMetadataItemFilter

+ (AVMetadataItemFilter *)metadataItemFilterForSharing
{
    return [[AVMetadataItemFilter alloc] init];
}

- (NSArray *)allowList
{
    return @[];
}

@end

@implementation AVMetadataItem {
    NSString *_charon_identifier;
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    // The stand-in's metadata item is built by string, so a setValue: for anything else goes to KVC's
    // own storage rather than being silently dropped.
    if ([key isEqualToString:@"identifier"]) {
        _charon_identifier = [value copy];
        return;
    }
    [super setValue:value forKey:key];
}

- (NSString *)identifier
{
    return _charon_identifier;
}

// The RELEASE's own filtering entry point, so the port has a release to ask and the harness has an
// expectation that is not the port's own answer. 7.0's own semantics, as the port already carries them
// (AVFoundation/AVMetadataItemGroups7.m) and as tests/backports/host/avf-metadata holds against Apple's:
// a filter with no identifiers keeps everything.
+ (NSArray<AVMetadataItem *> *)metadataItemsFromArray:(NSArray<AVMetadataItem *> *)items
                        filteredByMetadataItemFilter:(AVMetadataItemFilter *)filter
{
    if (!items)
        return nil;
    // `allowList` and `identifiers` are inside a private AVMetadataItemFilterInternal on Apple's own
    // class (its header declares only +metadataItemFilterForSharing), so the stand-in asks for the list
    // and treats a filter that cannot name one as the empty list, which keeps everything.
    NSArray *wanted = [filter respondsToSelector:@selector(allowList)] ? [filter allowList] : nil;
    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:items.count];
    for (AVMetadataItem *item in items) {
        if (!wanted.count || [wanted containsObject:item.identifier])
            [kept addObject:item];
    }
    return kept;
}

@end

@implementation AVAsset

- (NSArray *)commonMetadata
{
    return charon_source_metadata();
}

@end

@implementation AVAssetExportSession {
    AVAsset *_charon_asset;
    NSArray<AVMetadataItem *> *_charon_metadata;
    NSURL *_charon_outputURL;
    AVFileType _charon_outputFileType;
    NSUInteger _charon_exports;
}

- (instancetype)initWithAsset:(AVAsset *)asset presetName:(AVAssetExportPreset)presetName
{
    self = [super init];
    if (self)
        _charon_asset = asset;
    return self;
}

- (AVAsset *)asset
{
    return _charon_asset;
}

- (NSArray<AVMetadataItem *> *)metadata
{
    return _charon_metadata;
}

- (void)setMetadata:(NSArray<AVMetadataItem *> *)metadata
{
    _charon_metadata = [metadata copy];
}

- (NSURL *)outputURL
{
    return _charon_outputURL;
}

- (void)setOutputURL:(NSURL *)outputURL
{
    _charon_outputURL = [outputURL copy];
}

- (AVFileType)outputFileType
{
    return _charon_outputFileType;
}

- (void)setOutputFileType:(AVFileType)outputFileType
{
    _charon_outputFileType = [outputFileType copy];
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler
{
    _charon_exports++;
    if (handler)
        handler();
}

@end