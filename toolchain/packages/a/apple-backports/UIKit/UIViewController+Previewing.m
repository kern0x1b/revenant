#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char revenant_previewing_key;

static void revenant_say_previewing(void)
{
    revenant_menus_say_once(@"previewing", @"UIViewController.registerForPreviewingWithDelegate:sourceView:: iOS 6 runs on screens that do not measure force, so the context is registered and the delegate is never asked for a preview, which is what a release whose force touch capability is unavailable does");
}

@interface RevenantPreviewingContext : NSObject <UIViewControllerPreviewing>
@property (nonatomic, weak, readonly) id<UIViewControllerPreviewingDelegate> delegate;
@property (nonatomic, strong, readonly) UIView *sourceView;
@property (nonatomic, assign) CGRect sourceRect;
- (instancetype)initWithDelegate:(id<UIViewControllerPreviewingDelegate>)delegate sourceView:(UIView *)sourceView;
@end

@implementation RevenantPreviewingContext {
    UIGestureRecognizer *_recognizer;
}

@synthesize delegate = _delegate, sourceView = _sourceView, sourceRect = _sourceRect;

- (instancetype)initWithDelegate:(id<UIViewControllerPreviewingDelegate>)delegate sourceView:(UIView *)sourceView
{
    self = [super init];
    if (!self)
        return nil;
    _delegate = delegate;
    _sourceView = sourceView;
    _sourceRect = CGRectNull;
    _recognizer = [[UIGestureRecognizer alloc] initWithTarget:nil action:NULL];
    return self;
}

- (UIGestureRecognizer *)previewingGestureRecognizerForFailureRelationship
{
    return _recognizer;
}

@end

@implementation UIViewController (RevenantPreviewing)

- (id<UIViewControllerPreviewing>)registerForPreviewingWithDelegate:(id<UIViewControllerPreviewingDelegate>)delegate sourceView:(UIView *)sourceView
{
    revenant_say_previewing();
    NSMutableArray *registered = objc_getAssociatedObject(self, &revenant_previewing_key);
    if (!registered) {
        registered = [NSMutableArray array];
        objc_setAssociatedObject(self, &revenant_previewing_key, registered, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (RevenantPreviewingContext *found in registered) {
        if (found.sourceView == sourceView)
            return found;
    }
    RevenantPreviewingContext *context = [[RevenantPreviewingContext alloc] initWithDelegate:delegate sourceView:sourceView];
    [registered addObject:context];
    return context;
}

- (void)unregisterForPreviewingWithContext:(id<UIViewControllerPreviewing>)previewing
{
    NSMutableArray *registered = objc_getAssociatedObject(self, &revenant_previewing_key);
    if (previewing)
        [registered removeObjectIdenticalTo:previewing];
}

@end
