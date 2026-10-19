#import <AVFoundation/AVFoundation.h>

NSString *const AVAssetExportPresetPassthrough = @"AVAssetExportPresetPassthrough";
NSString *const AVFileTypeQuickTimeMovie = @"com.apple.quicktime-movie";

static NSArray *charon_source_metadata(void)
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
    NSString *_charon_identifier;
}

- (void)setValue:(id)value forKey:(NSString *)key
{
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
