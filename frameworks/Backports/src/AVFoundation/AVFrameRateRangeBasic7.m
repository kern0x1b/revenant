#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@interface AVFrameRateRange (RevenantBasic7)

- (instancetype)initRevenantWithMin:(float)min max:(float)max;

@end

@implementation AVFrameRateRange (RevenantBasic7)

- (instancetype)initRevenantWithMin:(float)min max:(float)max
{
    if ((self = [super init])) {
        objc_setAssociatedObject(self, @selector(minFrameRate), @(min), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @selector(maxFrameRate), @(max), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

- (float)minFrameRate
{
    return [objc_getAssociatedObject(self, @selector(minFrameRate)) floatValue];
}

- (float)maxFrameRate
{
    return [objc_getAssociatedObject(self, @selector(maxFrameRate)) floatValue];
}

@end