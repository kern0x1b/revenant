#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ARPlaneExtent : NSObject <NSSecureCoding>

@property (nonatomic, readonly) float rotationOnYAxis;

@property (nonatomic, readonly) float width;

@property (nonatomic, readonly) float height;

@end

NS_ASSUME_NONNULL_END
