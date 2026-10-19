#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PHAssetPlaybackStyle) {
    PHAssetPlaybackStyleUnsupported = 0,
    PHAssetPlaybackStyleImage = 1,
    PHAssetPlaybackStyleImageAnimated = 2,
    PHAssetPlaybackStyleLivePhoto = 3,
    PHAssetPlaybackStyleVideo = 4,
    PHAssetPlaybackStyleVideoLooping = 5,
};

@class PHPhotoLibrary;

typedef NS_ENUM(NSInteger, PHPickerConfigurationAssetRepresentationMode) {
    PHPickerConfigurationAssetRepresentationModeAutomatic = 0,
    PHPickerConfigurationAssetRepresentationModeCurrent = 1,
    PHPickerConfigurationAssetRepresentationModeCompatible = 2,
};

typedef NS_ENUM(NSInteger, PHPickerConfigurationSelection) {
    PHPickerConfigurationSelectionDefault = 0,
    PHPickerConfigurationSelectionOrdered = 1,
};

@interface PHPickerFilter : NSObject <NSCopying>
@property (nonatomic, class, readonly) PHPickerFilter *imagesFilter;
@property (nonatomic, class, readonly) PHPickerFilter *videosFilter;
@property (nonatomic, class, readonly) PHPickerFilter *livePhotosFilter;
@property (nonatomic, class, readonly) PHPickerFilter *depthEffectPhotosFilter;
@property (nonatomic, class, readonly) PHPickerFilter *burstsFilter;
@property (nonatomic, class, readonly) PHPickerFilter *panoramasFilter;
@property (nonatomic, class, readonly) PHPickerFilter *screenshotsFilter;
@property (nonatomic, class, readonly) PHPickerFilter *screenRecordingsFilter;
@property (nonatomic, class, readonly) PHPickerFilter *cinematicVideosFilter;
@property (nonatomic, class, readonly) PHPickerFilter *slomoVideosFilter;
@property (nonatomic, class, readonly) PHPickerFilter *timelapseVideosFilter;
+ (PHPickerFilter *)playbackStyleFilter:(PHAssetPlaybackStyle)playbackStyle;
+ (PHPickerFilter *)anyFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters;
+ (PHPickerFilter *)allFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters;
+ (PHPickerFilter *)notFilterOfSubfilter:(PHPickerFilter *)subfilter;
@end

@interface PHPickerConfiguration : NSObject <NSCopying>
@property (nonatomic) PHPickerConfigurationAssetRepresentationMode preferredAssetRepresentationMode;
@property (nonatomic) PHPickerConfigurationSelection selection;
@property (nonatomic) NSInteger selectionLimit;
@property (nonatomic, copy, nullable) PHPickerFilter *filter;
@property (nonatomic, copy) NSArray<NSString *> *preselectedAssetIdentifiers;
- (instancetype)initWithPhotoLibrary:(PHPhotoLibrary *)photoLibrary;
- (instancetype)init;
@end

@interface PHPickerResult : NSObject
@property (nonatomic, readonly) NSItemProvider *itemProvider;
@property (nonatomic, readonly, nullable) NSString *assetIdentifier;
@end

@interface PHPickerViewController : NSObject
@property (nonatomic, copy, readonly) PHPickerConfiguration *configuration;
- (instancetype)initWithConfiguration:(PHPickerConfiguration *)configuration;
- (void)deselectAssetsWithIdentifiers:(NSArray<NSString *> *)identifiers;
- (void)moveAssetWithIdentifier:(NSString *)identifier afterAssetWithIdentifier:(nullable NSString *)afterIdentifier;
@end

NS_ASSUME_NONNULL_END
