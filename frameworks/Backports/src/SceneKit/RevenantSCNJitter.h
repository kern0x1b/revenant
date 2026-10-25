#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RevenantSCNJitter : NSObject
+ (NSUInteger)sampleCount;
+ (void)offsetForFrame:(NSUInteger)frame x:(float *)x y:(float *)y;
+ (float)weightForAccumulated:(NSUInteger)accumulated;
@end

NS_ASSUME_NONNULL_END
