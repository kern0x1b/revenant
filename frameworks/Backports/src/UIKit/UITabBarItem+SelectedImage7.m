#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UITabBarItem (RevenantSelectedImage7)

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage
{
    if ((self = [self initWithTitle:title image:image tag:0]) && selectedImage)
        [self setFinishedSelectedImage:selectedImage withFinishedUnselectedImage:image];
    return self;
}

@end
