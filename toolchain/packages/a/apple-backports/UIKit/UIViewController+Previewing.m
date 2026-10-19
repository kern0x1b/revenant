#import "CharonMenus.h"
#import <objc/runtime.h>

static const char charon_previewing_key;

static void charon_say_previewing(void)
{
    charon_menus_say_once(@"previewing", @"UIViewController.registerForPreviewingWithDelegate:sourceView:: iOS 6 runs on screens that do not measure force, so the context is registered and the delegate is never asked for a preview, which is what a release whose force touch capability is unavailable does");
}

@interface CharonPreviewingContext : NSObject <UIViewControllerPreviewing>
@property (nonatomic, weak, readonly) id<UIViewControllerPreviewingDelegate> delegate;
@property (nonatomic, strong, readonly) UIView *sourceView;
@property (nonatomic, assign) CGRect sourceRect;
- (instancetype)initWithDelegate:(id<UIViewControllerPreviewingDelegate>)delegate sourceView:(UIView *)sourceView;
@end

@implementation CharonPreviewingContext {
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

@implementation UIViewController (CharonPreviewing)

- (id<UIViewControllerPreviewing>)registerForPreviewingWithDelegate:(id<UIViewControllerPreviewingDelegate>)delegate sourceView:(UIView *)sourceView
{
    charon_say_previewing();
    NSMutableArray *registered = objc_getAssociatedObject(self, &charon_previewing_key);
    if (!registered) {
        registered = [NSMutableArray array];
        objc_setAssociatedObject(self, &charon_previewing_key, registered, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (CharonPreviewingContext *found in registered) {
        if (found.sourceView == sourceView)
            return found;
    }
    CharonPreviewingContext *context = [[CharonPreviewingContext alloc] initWithDelegate:delegate sourceView:sourceView];
    [registered addObject:context];
    return context;
}

- (void)unregisterForPreviewingWithContext:(id<UIViewControllerPreviewing>)previewing
{
    NSMutableArray *registered = objc_getAssociatedObject(self, &charon_previewing_key);
    if (previewing)
        [registered removeObjectIdenticalTo:previewing];
}

@end
