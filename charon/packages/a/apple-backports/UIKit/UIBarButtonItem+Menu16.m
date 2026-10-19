#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation UIBarButtonItem (CharonMenu16)

- (instancetype)initWithPrimaryAction:(UIAction *)primaryAction menu:(UIMenu *)menu
{
    if ((self = [self initWithPrimaryAction:primaryAction]))
        self.menu = menu;
    return self;
}

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem primaryAction:(UIAction *)primaryAction menu:(UIMenu *)menu
{
    if ((self = [self initWithBarButtonSystemItem:systemItem primaryAction:primaryAction]))
        self.menu = menu;
    return self;
}

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image target:(id)target action:(SEL)action menu:(UIMenu *)menu
{
    if ((self = [self initWithTitle:title style:UIBarButtonItemStylePlain target:target action:action])) {
        if (image)
            self.image = image;
        self.menu = menu;
    }
    return self;
}

@end
