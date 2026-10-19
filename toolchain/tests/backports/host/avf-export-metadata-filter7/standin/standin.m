#import <AVFoundation/AVFoundation.h>

NSString *const AVAssetExportPresetPassthrough = @"AVAssetExportPresetPassthrough";
NSString *const AVFileTypeQuickTimeMovie = @"com.apple.quicktime-movie";

static NSArray *revenant_source_metadata(void)
{
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *identifier in @[@"mdta/keys/copyright", @"mdta/keys/location"]) {
        AVMetadataItem *item = [AVMetadataItem new];
        [item setValue:identifier forKey:@"identifier"];
        [items addObject:item];
    }
    return items;
}

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
    NSString *_revenant_identifier;
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    if ([key isEqualToString:@"identifier"]) {
        _revenant_identifier = [value copy];
        return;
    }
    [super setValue:value forKey:key];
}

- (NSString *)identifier
{
    return _revenant_identifier;
}

+ (NSArray<AVMetadataItem *> *)metadataItemsFromArray:(NSArray<AVMetadataItem *> *)items
                        filteredByMetadataItemFilter:(AVMetadataItemFilter *)filter
{
    if (!items)
        return nil;
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
    return revenant_source_metadata();
}

@end

@implementation AVAssetExportSession {
    AVAsset *_revenant_asset;
    NSArray<AVMetadataItem *> *_revenant_metadata;
    NSURL *_revenant_outputURL;
    AVFileType _revenant_outputFileType;
    NSUInteger _revenant_exports;
}

- (instancetype)initWithAsset:(AVAsset *)asset presetName:(AVAssetExportPreset)presetName
{
    self = [super init];
    if (self)
        _revenant_asset = asset;
    return self;
}

- (AVAsset *)asset
{
    return _revenant_asset;
}

- (NSArray<AVMetadataItem *> *)metadata
{
    return _revenant_metadata;
}

- (void)setMetadata:(NSArray<AVMetadataItem *> *)metadata
{
    _revenant_metadata = [metadata copy];
}

- (NSURL *)outputURL
{
    return _revenant_outputURL;
}

- (void)setOutputURL:(NSURL *)outputURL
{
    _revenant_outputURL = [outputURL copy];
}

- (AVFileType)outputFileType
{
    return _revenant_outputFileType;
}

- (void)setOutputFileType:(AVFileType)outputFileType
{
    _revenant_outputFileType = [outputFileType copy];
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler
{
    _revenant_exports++;
    if (handler)
        handler();
}

@end
