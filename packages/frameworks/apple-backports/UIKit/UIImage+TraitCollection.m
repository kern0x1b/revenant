#import <UIKit/UIKit.h>

@implementation UIImage (RevenantTraitCollection)

- (UITraitCollection *)traitCollection
{
    return [UITraitCollection traitCollectionWithDisplayScale:self.scale];
}

@end
