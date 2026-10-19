#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"

@interface UICollectionViewLayoutAttributes (CharonHostTransform7)
- (CGAffineTransform)charonHostTransform;
- (void)charonHostSetTransform:(CGAffineTransform)transform;
@end

static NSString *describe(CGAffineTransform t)
{
    return [NSString stringWithFormat:@"[%g %g %g %g %g %g]", t.a, t.b, t.c, t.d, t.tx, t.ty];
}

int main(void)
{
    @autoreleasepool {
        NSIndexPath *path = [NSIndexPath indexPathForItem:0 inSection:0];
        CGAffineTransform affine[] = {CGAffineTransformIdentity, CGAffineTransformMakeScale(2, 0.5), CGAffineTransformMakeRotation(0.3),
                                      CGAffineTransformMakeTranslation(12, -7), CGAffineTransformRotate(CGAffineTransformMakeScale(1.5, 1.5), -1.1)};
        for (size_t index = 0; index < sizeof affine / sizeof affine[0]; index++) {
            UICollectionViewLayoutAttributes *system = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
            UICollectionViewLayoutAttributes *ours = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
            system.transform = affine[index];
            [ours charonHostSetTransform:affine[index]];
            charon_check(CATransform3DEqualToTransform(system.transform3D, ours.transform3D), "setting transform sets transform3D as the system does",
                         describe(affine[index]));
            charon_check(CGAffineTransformEqualToTransform(system.transform, ours.charonHostTransform), "transform reads back as the system's",
                         [NSString stringWithFormat:@"%@ != %@", describe(ours.charonHostTransform), describe(system.transform)]);
        }
        CATransform3D perspective = CATransform3DIdentity;
        perspective.m34 = -1.0 / 500;
        CATransform3D solid[] = {CATransform3DMakeTranslation(0, 0, 10), perspective, CATransform3DMakeRotation(0.4, 1, 0, 0),
                                 CATransform3DMakeAffineTransform(CGAffineTransformMakeScale(3, 3)), CATransform3DMakeScale(2, 2, 1)};
        for (size_t index = 0; index < sizeof solid / sizeof solid[0]; index++) {
            UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
            attributes.transform3D = solid[index];
            charon_check(CGAffineTransformEqualToTransform(attributes.transform, attributes.charonHostTransform),
                         "transform read from a transform3D, affine or not, answers as the system's",
                         [NSString stringWithFormat:@"case %zu: %@ != %@", index, describe(attributes.charonHostTransform), describe(attributes.transform)]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
