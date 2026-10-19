#import <UIKit/UIKit.h>

@implementation UIView (CharonAnchorPoint16)

// The view's spelling of its layer's anchor point, which the release's CALayer has.
- (CGPoint)anchorPoint
{
    return self.layer.anchorPoint;
}

- (void)setAnchorPoint:(CGPoint)anchorPoint
{
    self.layer.anchorPoint = anchorPoint;
}

@end
