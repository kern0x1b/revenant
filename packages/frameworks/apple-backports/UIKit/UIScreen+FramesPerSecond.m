#import <UIKit/UIKit.h>

@interface UIScreen (RevenantPrivate)
- (double)_refreshRate;
@end

@implementation UIScreen (RevenantFramesPerSecond)

- (NSInteger)maximumFramesPerSecond
{
    double interval = [self _refreshRate];
    return interval > 0 ? (NSInteger)round(1 / interval) : 60;
}

@end
