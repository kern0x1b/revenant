#import "CharonMenus.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@implementation UIHoverGestureRecognizer

@dynamic zOffset, altitudeAngle;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 170500
@dynamic rollAngle;
#endif

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    if ((self = [super initWithTarget:target action:action]))
        charon_menus_say_once(@"hover-recognizer", @"UIHoverGestureRecognizer: this release has no pointing device, so the recognizer never leaves the possible state");
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.state = UIGestureRecognizerStateFailed;
}

@end
