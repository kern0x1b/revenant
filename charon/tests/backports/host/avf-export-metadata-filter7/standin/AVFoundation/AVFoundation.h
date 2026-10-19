#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

typedef NSString *AVAssetExportPreset;
typedef NSString *AVFileType;

extern NSString *const AVAssetExportPresetPassthrough;
extern NSString *const AVFileTypeQuickTimeMovie;

@interface AVMetadataItemFilter : NSObject
+ (AVMetadataItemFilter *)metadataItemFilterForSharing;
- (NSArray *)allowList;
@end

@interface AVAsset : NSObject
- (NSArray *)commonMetadata;
@end

@interface AVMetadataItem : NSObject
- (NSString *)identifier;
+ (NSArray<AVMetadataItem *> *)metadataItemsFromArray:(NSArray<AVMetadataItem *> *)items
                        filteredByMetadataItemFilter:(AVMetadataItemFilter *)filter;
@end

@interface AVAssetExportSession : NSObject

- (instancetype)initWithAsset:(AVAsset *)asset presetName:(AVAssetExportPreset)presetName;
- (AVAsset *)asset;
- (NSArray<AVMetadataItem *> *)metadata;
- (void)setMetadata:(NSArray<AVMetadataItem *> *)metadata;
- (NSURL *)outputURL;
- (void)setOutputURL:(NSURL *)outputURL;
- (AVFileType)outputFileType;
- (void)setOutputFileType:(AVFileType)outputFileType;
- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler;

- (AVMetadataItemFilter *)metadataItemFilter;
- (void)setMetadataItemFilter:(AVMetadataItemFilter *)metadataItemFilter;

@end
