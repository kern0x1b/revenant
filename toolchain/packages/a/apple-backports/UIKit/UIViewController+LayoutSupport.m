#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_top_support_key;
static const char charon_bottom_support_key;

@interface CharonLayoutSupport : UILayoutGuide <UILayoutSupport>
@property (nonatomic, assign) BOOL top;
@end

@implementation CharonLayoutSupport

@synthesize top;

- (CGFloat)length
{
    UIEdgeInsets insets = self.owningView.safeAreaInsets;
    return self.top ? insets.top : insets.bottom;
}

@end

static CharonLayoutSupport *charon_support(UIViewController *controller, BOOL top)
{
    const void *key = top ? &charon_top_support_key : &charon_bottom_support_key;
    CharonLayoutSupport *support = objc_getAssociatedObject(controller, key);
    if (support)
        return support;
    UIView *view = controller.view;
    support = [[CharonLayoutSupport alloc] init];
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

@implementation UIViewController (CharonLayoutSupport)

- (id<UILayoutSupport>)topLayoutGuide
{
    return charon_support(self, YES);
}

- (id<UILayoutSupport>)bottomLayoutGuide
{
    return charon_support(self, NO);
}

@end
