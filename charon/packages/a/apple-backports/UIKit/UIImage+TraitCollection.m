#import <UIKit/UIKit.h>

@implementation UIImage (CharonTraitCollection)

- (UITraitCollection *)traitCollection
{
    return [UITraitCollection traitCollectionWithDisplayScale:self.scale];
}

@end
