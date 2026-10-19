// UIContentUnavailableConfiguration.h - the configuration of the empty-state API of iOS 17.0 and the
// content view that draws it, declared because the BUILD SDK does not declare them.
//
// The build SDK is 16.4 and neither class is in a header under its UIKit.framework/Headers, which is the
// same position UIContentUnavailableProperties.h states for the three property bags and the state, so
// this sits beside that header and takes its guard from the same place: __has_include, so a future build
// SDK that ships these names uses the system's own declaration and this file steps aside.
//
// The declarations are read from the SDK that declares these names, charon/.agent-work/sdk-26.2's
// iPhoneOS26.2.sdk/System/Library/Frameworks/UIKit.framework/Headers, and every default the
// implementation sets is what the host measured first
// (facts/UIKit/UIContentUnavailable17.md, M4) - the header states none of them.
//
// A class is a DYLD SYMBOL before it is anything else, so an application that links strongly against
// UIContentUnavailableConfiguration names _OBJC_CLASS_$_UIContentUnavailableConfiguration and dyld has to
// find it.  That is why these two are declared and implemented rather than left to a missing-header error:
// the name must resolve on 6.1.3 and on 4.3.

#ifndef CHARON_UIKIT_CONTENTUNAVAILABLECONFIGURATION_H
#define CHARON_UIKIT_CONTENTUNAVAILABLECONFIGURATION_H

#import <UIKit/UIKit.h>
#import "UIContentUnavailableProperties.h"

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UIContentUnavailableConfiguration.h>)

typedef NS_ENUM(NSInteger, UIContentUnavailableAlignment) {
    UIContentUnavailableAlignmentCenter,
    UIContentUnavailableAlignmentNatural
} API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos);

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface UIContentUnavailableConfiguration : NSObject <UIContentConfiguration, NSSecureCoding>

+ (instancetype)emptyConfiguration;
+ (instancetype)loadingConfiguration;
+ (instancetype)searchConfiguration;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, readonly) UIContentUnavailableImageProperties *imageProperties;

@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSAttributedString *attributedText;
@property (nonatomic, readonly) UIContentUnavailableTextProperties *textProperties;

@property (nonatomic, copy, nullable) NSString *secondaryText;
@property (nonatomic, copy, nullable) NSAttributedString *secondaryAttributedText;
@property (nonatomic, readonly) UIContentUnavailableTextProperties *secondaryTextProperties;

@property (nonatomic, strong) UIButtonConfiguration *button;
@property (nonatomic, readonly) UIContentUnavailableButtonProperties *buttonProperties;

@property (nonatomic, strong) UIButtonConfiguration *secondaryButton;
@property (nonatomic, readonly) UIContentUnavailableButtonProperties *secondaryButtonProperties;

@property (nonatomic) UIContentUnavailableAlignment alignment;
@property (nonatomic) UIAxis axesPreservingSuperviewLayoutMargins;
@property (nonatomic) NSDirectionalEdgeInsets directionalLayoutMargins;

@property (nonatomic) CGFloat imageToTextPadding;
@property (nonatomic) CGFloat textToSecondaryTextPadding;
@property (nonatomic) CGFloat textToButtonPadding;
@property (nonatomic) CGFloat buttonToSecondaryButtonPadding;

@property (nonatomic, strong) UIBackgroundConfiguration *background;

@end

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface UIContentUnavailableView : UIView <UIContentView>

- (instancetype)initWithConfiguration:(UIContentUnavailableConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, copy) UIContentUnavailableConfiguration *configuration;

@property (nonatomic, getter=isScrollEnabled) BOOL scrollEnabled;

@end

#endif   // !__has_include(<UIKit/UIContentUnavailableConfiguration.h>)

NS_ASSUME_NONNULL_END

#endif   // CHARON_UIKIT_CONTENTUNAVAILABLECONFIGURATION_H
