// The PhotosUI/PhotosUI.h the port's own picker sources are compiled against when the differential
// below builds them for the host. It is a transcription, not a copy: the declarations the port's
// six sources name, with the same shapes the iOS 16.4 SDK's headers give them, and nothing else.
//
// Why a transcription at all: the port's PHPickerFilter, PHPickerConfiguration and
// PHPickerViewController have the same names as the host's own, so a host binary that held both
// would install the port's categories over the host's classes and the "host" answers would be the
// port's - the trap the review of the ImageIO pixel differential found, where the port probe was the
// host. This header is on the include path ahead of the SDK's, so <PhotosUI/PhotosUI.h> resolves here
// and the host's PhotosUI framework is never linked into the port's binary. The host's own answers
// come from the other binary, and run.sh compares the two.
//
// Each declaration names where it is transcribed from. PHAssetPlaybackStyle is the one that is not
// in PhotosUI at all: PHPicker.h of the SDK uses the type and gets it from PHLivePhotoView.h's
// <Photos/Photos.h>, and here it is written out from PhotosTypes.h:118-125 of the same SDK.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// PhotosTypes.h:118
typedef NS_ENUM(NSInteger, PHAssetPlaybackStyle) {
    PHAssetPlaybackStyleUnsupported = 0,
    PHAssetPlaybackStyleImage = 1,
    PHAssetPlaybackStyleImageAnimated = 2,
    PHAssetPlaybackStyleLivePhoto = 3,
    PHAssetPlaybackStyleVideo = 4,
    PHAssetPlaybackStyleVideoLooping = 5,
};

// PHPicker.h:23 of the SDK names the class and never uses it in this header's own declarations.
@class PHPhotoLibrary;

// PHPicker.h:24
typedef NS_ENUM(NSInteger, PHPickerConfigurationAssetRepresentationMode) {
    PHPickerConfigurationAssetRepresentationModeAutomatic = 0,
    PHPickerConfigurationAssetRepresentationModeCurrent = 1,
    PHPickerConfigurationAssetRepresentationModeCompatible = 2,
};

// PHPicker.h:30
typedef NS_ENUM(NSInteger, PHPickerConfigurationSelection) {
    PHPickerConfigurationSelectionDefault = 0,
    PHPickerConfigurationSelectionOrdered = 1,
};

// PHPicker.h:48
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

// PHPicker.h:167
@interface PHPickerConfiguration : NSObject <NSCopying>
@property (nonatomic) PHPickerConfigurationAssetRepresentationMode preferredAssetRepresentationMode;
@property (nonatomic) PHPickerConfigurationSelection selection;
@property (nonatomic) NSInteger selectionLimit;
@property (nonatomic, copy, nullable) PHPickerFilter *filter;
@property (nonatomic, copy) NSArray<NSString *> *preselectedAssetIdentifiers;
- (instancetype)initWithPhotoLibrary:(PHPhotoLibrary *)photoLibrary;
- (instancetype)init;
@end

// PHPicker.h:207
@interface PHPickerResult : NSObject
@property (nonatomic, readonly) NSItemProvider *itemProvider;
@property (nonatomic, readonly, nullable) NSString *assetIdentifier;
@end

// PHPicker.h:220. The SDK's own header has three shapes for this class and picks one; the port's
// 16.0 object needs nothing of a superclass but its own name, and this differential is not a test of
// UIKit, so the smallest of the SDK's three is the one transcribed here.
@interface PHPickerViewController : NSObject
@property (nonatomic, copy, readonly) PHPickerConfiguration *configuration;
- (instancetype)initWithConfiguration:(PHPickerConfiguration *)configuration;
- (void)deselectAssetsWithIdentifiers:(NSArray<NSString *> *)identifiers;
- (void)moveAssetWithIdentifier:(NSString *)identifier afterAssetWithIdentifier:(nullable NSString *)afterIdentifier;
@end

NS_ASSUME_NONNULL_END
