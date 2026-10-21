#import <UIKit/UIKit.h>

@interface UIStoryboardUnwindSegueSource (RevenantInit)
- (instancetype)initRevenantWithSourceViewController:(UIViewController *)sourceViewController unwindAction:(SEL)unwindAction sender:(id)sender;
@end

@implementation UIStoryboardUnwindSegueSource {
    UIViewController *_sourceViewController;
    SEL _unwindAction;
    id _sender;
}

- (instancetype)initRevenantWithSourceViewController:(UIViewController *)sourceViewController unwindAction:(SEL)unwindAction sender:(id)sender
{
    if ((self = [super init])) {
        _sourceViewController = sourceViewController;
        _unwindAction = unwindAction;
        _sender = sender;
    }
    return self;
}

- (UIViewController *)sourceViewController
{
    return _sourceViewController;
}

- (SEL)unwindAction
{
    return _unwindAction;
}

- (id)sender
{
    return _sender;
}

@end
