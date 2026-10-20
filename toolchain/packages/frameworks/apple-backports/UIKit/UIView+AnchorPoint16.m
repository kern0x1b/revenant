#import <UIKit/UIKit.h>

@implementation UIView (RevenantAnchorPoint16)

- (CGPoint)anchorPoint
{
    return self.layer.anchorPoint;
}

- (void)setAnchorPoint:(CGPoint)anchorPoint
{
    self.layer.anchorPoint = anchorPoint;
}

@end
