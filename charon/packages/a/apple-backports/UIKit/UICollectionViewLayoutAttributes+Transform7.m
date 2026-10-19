#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// iOS 7.0's affine transform of layout attributes is a view of transform3D, which iOS 6 already keeps and applies to
// the cell: setting it sets transform3D to the affine transform's 3D form, and reading it answers transform3D's affine
// part, or the identity when transform3D is not affine (measured on the host's UIKit under Mac Catalyst;
// facts/UIKit/UICollectionViewLayoutAttributesTransform.md).
@implementation UICollectionViewLayoutAttributes (CharonAffineTransform)

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
