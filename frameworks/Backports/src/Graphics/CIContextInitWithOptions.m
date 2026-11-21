#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>

@implementation CIContext (RevenantInitWithOptions)

#if defined(REVENANT_HOST_BUILD)
- (instancetype)initWithRevenantOptions:(NSDictionary *)options
#else
- (instancetype)initWithOptions:(NSDictionary *)options
#endif
{
    self = [object_getClass(self) contextWithOptions:options];
    return self;
}

@end
