#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@implementation UICollectionViewLayoutAttributes (RevenantAffineTransform)

- (CGAffineTransform)transform
{
    CATransform3D transform = self.transform3D;
    return CATransform3DIsAffine(transform) ? CATransform3DGetAffineTransform(transform) : CGAffineTransformIdentity;
}

- (void)setTransform:(CGAffineTransform)transform
{
    self.transform3D = CATransform3DMakeAffineTransform(transform);
}

@end
