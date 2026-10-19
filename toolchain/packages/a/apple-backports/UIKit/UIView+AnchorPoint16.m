#import <UIKit/UIKit.h>

@implementation UIView (CharonAnchorPoint16)

- (CGPoint)anchorPoint
{
    return self.layer.anchorPoint;
}

- (void)setAnchorPoint:(CGPoint)anchorPoint
{
    self.layer.anchorPoint = anchorPoint;
}

@end
