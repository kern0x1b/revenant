#import <UIKit/UIKit.h>

@interface UIScreen (CharonPrivate)
- (double)_refreshRate;
@end

@implementation UIScreen (CharonFramesPerSecond)

- (NSInteger)maximumFramesPerSecond
{
    double interval = [self _refreshRate];
    return interval > 0 ? (NSInteger)round(1 / interval) : 60;
}

@end
