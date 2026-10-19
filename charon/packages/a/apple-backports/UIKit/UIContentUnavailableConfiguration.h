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

#endif

NS_ASSUME_NONNULL_END

#endif
