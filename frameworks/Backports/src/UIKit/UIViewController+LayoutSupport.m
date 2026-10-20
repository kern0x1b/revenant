#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_top_support_key;
static const char revenant_bottom_support_key;

@interface RevenantLayoutSupport : UILayoutGuide <UILayoutSupport>
@property (nonatomic, assign) BOOL top;
@end

@implementation RevenantLayoutSupport

@synthesize top;

- (CGFloat)length
{
    UIEdgeInsets insets = self.owningView.safeAreaInsets;
    return self.top ? insets.top : insets.bottom;
}

@end

static RevenantLayoutSupport *revenant_support(UIViewController *controller, BOOL top)
{
    const void *key = top ? &revenant_top_support_key : &revenant_bottom_support_key;
    RevenantLayoutSupport *support = objc_getAssociatedObject(controller, key);
    if (support)
        return support;
    UIView *view = controller.view;
    support = [[RevenantLayoutSupport alloc] init];
    support.top = top;
    support.identifier = top ? @"UIViewControllerTopLayoutGuide" : @"UIViewControllerBottomLayoutGuide";
    objc_setAssociatedObject(controller, key, support, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [view addLayoutGuide:support];
    UILayoutGuide *safe = view.safeAreaLayoutGuide;
    NSMutableArray *constraints = [NSMutableArray arrayWithObjects:
        [support.leftAnchor constraintEqualToAnchor:view.leftAnchor],
        [support.rightAnchor constraintEqualToAnchor:view.rightAnchor], nil];
    if (top) {
        [constraints addObject:[support.topAnchor constraintEqualToAnchor:view.topAnchor]];
        [constraints addObject:[support.bottomAnchor constraintEqualToAnchor:safe.topAnchor]];
    } else {
        [constraints addObject:[support.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]];
        [constraints addObject:[support.topAnchor constraintEqualToAnchor:safe.bottomAnchor]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    return support;
}

@implementation UIViewController (RevenantLayoutSupport)

- (id<UILayoutSupport>)topLayoutGuide
{
    return revenant_support(self, YES);
}

- (id<UILayoutSupport>)bottomLayoutGuide
{
    return revenant_support(self, NO);
}

@end
