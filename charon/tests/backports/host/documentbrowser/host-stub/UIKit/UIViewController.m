#import "UIKit/UIViewController.h"

@implementation UIView
@end

// The stand-in superclass: a view controller is asked for its view, and that is all the browser
// needs of UIKit here.
@implementation UIViewController
- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
    (void)nibName;
    (void)bundle;
    return [super init];
}
@end
