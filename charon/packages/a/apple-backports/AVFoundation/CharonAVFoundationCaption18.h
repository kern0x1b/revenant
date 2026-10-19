// CharonAVFoundationCaption18.h - the caption geometry types and their three constructors: declarations of
// the iOS 26.2 interface, written for this port from the SDK 26.2 headers the port is written against. That
// is what every band does for surface that arrived after the SDK the toolchain resolves (CoreMedia's
// CharonCMTag26.h, Intents' CharonIntents262.h, CloudKit's CharonCKSyncEngine26.h, CarPlay's and WebKit's).
// The names, types, signatures and availability are the interface's, and nothing here is invented; the
// header's prose and doc comments are not carried. The names the port adds beyond the SDK are listed in the
// delivery for rule R4.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaption.h
//   .../AVCaptureReactions.h
//
// Two departures from the 26.2 interface's declarations, both forced by the SDK the toolchain resolves and both stated
// rather than silent:
//
//   * `API_UNAVAILABLE(visionos)` is DROPPED from every declaration. SDK 16.4's availability.h does not
//     know the word, and expanding it there is `error: expected ','` on the line after the macro's own
//     `visionos` argument - three errors, one per declaration. Nothing is lost by leaving it out: the
//     annotation marks platforms this port does not build for.
//   * the guard is one block for both headers, and it is keyed on AVCaption.h only. The 16.4 SDK ships
//     neither AVCaption.h nor AVCaptureReactions.h, and a newer SDK that ships either declares this
//     itself and must win.
//
// The guard is on the header and not on the type, because C cannot ask whether a typedef exists: SDK
// 16.4 ships AVFoundation/AVFoundation.h and does not declare any of this, and a newer SDK that ships
// AVCaption.h declares it itself and must win.
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

/*!
 @typedef AVCaptureReactionType
 @abstract A string that identifies one of the reaction effects the camera can play into the scene.
*/
typedef NSString *AVCaptureReactionType NS_TYPED_ENUM API_AVAILABLE(macos(14.0), ios(17.0), macCatalyst(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);

// The eight reaction TYPES are the port's own carried constants - SDK 16.4 declares neither the type nor
// any of the names, and AVFoundationGlobals180.m defines the strings. They are declared here so the
// lookup in AVFoundationFunctions180.m compares against the carried value rather than a second copy of
// the text written out beside it.
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
