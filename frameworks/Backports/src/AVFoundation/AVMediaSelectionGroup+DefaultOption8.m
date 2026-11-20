#import <AVFoundation/AVFoundation.h>

@interface AVMediaSelectionOption (RevenantDefault7)
- (BOOL)isDefault;
@end

@implementation AVMediaSelectionGroup (RevenantDefaultOption8)

- (AVMediaSelectionOption *)defaultOption
{
    for (AVMediaSelectionOption *option in self.options) {
        if ([option respondsToSelector:@selector(isDefault)] && [option isDefault])
            return option;
    }
    return self.options.firstObject;
}

@end
