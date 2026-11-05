#ifndef REVENANT_UIKIT26_H
#define REVENANT_UIKIT26_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UICornerConfiguration.h>)

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UICornerRadius : NSObject <NSCopying>
+ (instancetype)fixedRadius:(CGFloat)radius;
+ (instancetype)containerConcentricRadius;
+ (instancetype)containerConcentricRadiusWithMinimum:(CGFloat)minimum;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UICornerConfiguration : NSObject <NSCopying>
+ (instancetype)configurationWithRadius:(UICornerRadius *)radius NS_SWIFT_NAME(corners(radius:));
+ (instancetype)configurationWithTopLeftRadius:(nullable UICornerRadius *)topLeftRadius
                                topRightRadius:(nullable UICornerRadius *)topRightRadius
                              bottomLeftRadius:(nullable UICornerRadius *)bottomLeftRadius
                             bottomRightRadius:(nullable UICornerRadius *)bottomRightRadius NS_SWIFT_NAME(corners(topLeftRadius:topRightRadius:bottomLeftRadius:bottomRightRadius:));
+ (instancetype)capsuleConfiguration NS_SWIFT_NAME(capsule());
+ (instancetype)capsuleConfigurationWithMaximumRadius:(CGFloat)maximumRadius NS_SWIFT_NAME(capsule(maximumRadius:));
+ (instancetype)configurationWithUniformRadius:(UICornerRadius *)radius NS_SWIFT_NAME(uniformCorners(radius:));
+ (instancetype)configurationWithUniformTopRadius:(UICornerRadius *)topRadius
                              uniformBottomRadius:(UICornerRadius *)bottomRadius NS_SWIFT_NAME(uniformEdges(topRadius:bottomRadius:));
+ (instancetype)configurationWithUniformLeftRadius:(UICornerRadius *)leftRadius
                                uniformRightRadius:(UICornerRadius *)rightRadius NS_SWIFT_NAME(uniformEdges(leftRadius:rightRadius:));
+ (instancetype)configurationWithUniformTopRadius:(UICornerRadius *)topRadius
                                 bottomLeftRadius:(nullable UICornerRadius *)bottomLeftRadius
                                bottomRightRadius:(nullable UICornerRadius *)bottomRightRadius NS_SWIFT_NAME(uniformTopRadius(_:bottomLeftRadius:bottomRightRadius:));
+ (instancetype)configurationWithUniformBottomRadius:(UICornerRadius *)bottomRadius
                                       topLeftRadius:(nullable UICornerRadius *)topLeftRadius
                                      topRightRadius:(nullable UICornerRadius *)topRightRadius NS_SWIFT_NAME(uniformBottomRadius(_:topLeftRadius:topRightRadius:));
+ (instancetype)configurationWithUniformLeftRadius:(UICornerRadius *)leftRadius
                                    topRightRadius:(nullable UICornerRadius *)topRightRadius
                                 bottomRightRadius:(nullable UICornerRadius *)bottomRightRadius NS_SWIFT_NAME(uniformLeftRadius(_:topRightRadius:bottomRightRadius:));
+ (instancetype)configurationWithUniformRightRadius:(UICornerRadius *)rightRadius
                                      topLeftRadius:(nullable UICornerRadius *)topLeftRadius
                                   bottomLeftRadius:(nullable UICornerRadius *)bottomLeftRadius NS_SWIFT_NAME(uniformRightRadius(_:topLeftRadius:bottomLeftRadius:));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

#endif

#if !__has_include(<UIKit/UISliderTrackConfiguration.h>)

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISliderTick : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISliderTrackConfiguration : NSObject <NSCopying>
@end

#endif

NS_ASSUME_NONNULL_END

#endif
