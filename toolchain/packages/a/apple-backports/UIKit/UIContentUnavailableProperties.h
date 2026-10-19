#ifndef CHARON_CONTENTUNAVAILABLE_PROPERTIES_H
#define CHARON_CONTENTUNAVAILABLE_PROPERTIES_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UIContentUnavailableTextProperties.h>)

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface UIContentUnavailableTextProperties : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic) BOOL allowsDefaultTighteningForTruncation;
@end

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface UIContentUnavailableImageProperties : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy, nullable) UIImageSymbolConfiguration *preferredSymbolConfiguration;
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGSize maximumSize;
@property (nonatomic) BOOL accessibilityIgnoresInvertColors;
@end

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface UIContentUnavailableButtonProperties : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy, nullable) UIAction *primaryAction;
@property (nonatomic, copy, nullable) UIMenu *menu;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) UIButtonRole role;
@end

API_AVAILABLE(ios(17.0), tvos(17.0)) API_UNAVAILABLE(watchos)
@interface UIContentUnavailableConfigurationState : NSObject <UIConfigurationState>
- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection;
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
@property (nonatomic, strong) UITraitCollection *traitCollection;
@property (nonatomic, strong, nullable) NSString *searchText;
@end

#endif

NS_ASSUME_NONNULL_END

#endif
