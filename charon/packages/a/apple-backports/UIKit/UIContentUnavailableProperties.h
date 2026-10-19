// UIContentUnavailableProperties.h - the four classes the empty-state API of iOS 17.0 needs and the
// build SDK does not declare, declared here so the library compiles against a 16.4 SDK, exactly as
// CharonTraits17.h does for the traits: what the SDK's own headers do not carry is written here from
// the 26.2 headers, and the guard is __has_include so the file compiles against either - the build
// SDK, which has no UIContentUnavailable*, and the newer SDK the host differential compiles against,
// where these classes are the system's own and redeclaring them would be a duplicate.
//
// The implementations are in UIContentUnavailableProperties.m. What the host answers was measured
// first (facts/UIKit/UIContentUnavailable17.md, M1).

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

#endif   // !__has_include(<UIKit/UIContentUnavailableTextProperties.h>)

NS_ASSUME_NONNULL_END

#endif   // CHARON_CONTENTUNAVAILABLE_PROPERTIES_H
