#import <UIKit/UIKit.h>
#import <objc/message.h>

@implementation UIScrollView (CharonStopScrolling17)

- (void)stopScrollingAndZooming
{
    [self setContentOffset:self.contentOffset animated:NO];
}

@end
