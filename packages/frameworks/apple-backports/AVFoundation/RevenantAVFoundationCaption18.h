#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#if !__has_include(<AVFoundation/AVCaption.h>) && !__has_include(<AVFoundation/AVCaptureReactions.h>)

typedef NS_ENUM(NSInteger, AVCaptionUnitsType) {
	AVCaptionUnitsTypeUnspecified = 0,
	AVCaptionUnitsTypeCells,
	AVCaptionUnitsTypePercent,
};

typedef struct AVCaptionDimension {
	CGFloat value;
	AVCaptionUnitsType units;
} AVCaptionDimension;

typedef struct AVCaptionPoint {
	AVCaptionDimension x;
	AVCaptionDimension y;
} AVCaptionPoint;

typedef struct AVCaptionSize {
	AVCaptionDimension width;
	AVCaptionDimension height;
} AVCaptionSize;

AVF_EXPORT AVCaptionDimension AVCaptionDimensionMake( CGFloat value, AVCaptionUnitsType units )
API_AVAILABLE(macos(12.0), ios(18.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);

AVF_EXPORT AVCaptionPoint AVCaptionPointMake( AVCaptionDimension x, AVCaptionDimension y )
API_AVAILABLE(macos(12.0), ios(18.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);

AVF_EXPORT AVCaptionSize AVCaptionSizeMake( AVCaptionDimension width, AVCaptionDimension height )
API_AVAILABLE(macos(12.0), ios(18.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);

typedef NSString *AVCaptureReactionType NS_TYPED_ENUM API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);

AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeThumbsUp API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);
AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeThumbsDown API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);
AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeBalloons API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);
AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeHeart API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);
AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeFireworks API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);
AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeConfetti API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);
AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeLasers API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);
AVF_EXPORT AVCaptureReactionType AVCaptureReactionTypeRain API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);

AVF_EXPORT NSString *AVCaptureReactionSystemImageNameForType(AVCaptureReactionType reactionType)
API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);

#endif
