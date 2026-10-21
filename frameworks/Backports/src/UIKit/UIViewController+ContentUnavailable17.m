#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantUnavailableConfigurationKey;
static const char RevenantUnavailableViewKey;
static const char RevenantUnavailableScheduledKey;

static void revenant_show_unavailable(UIViewController *controller)
{
    UIView *old = objc_getAssociatedObject(controller, &RevenantUnavailableViewKey);
    [old removeFromSuperview];
    objc_setAssociatedObject(controller, &RevenantUnavailableViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id<UIContentConfiguration> configuration = objc_getAssociatedObject(controller, &RevenantUnavailableConfigurationKey);
    if (!configuration || !controller.isViewLoaded)
        return;
    UIView *view = [configuration makeContentView];
    view.frame = controller.view.bounds;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [controller.view addSubview:view];
    objc_setAssociatedObject(controller, &RevenantUnavailableViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface RevenantContentUnavailable17 : NSObject
@end

@implementation RevenantContentUnavailable17

+ (void)load
{
    if ([UIViewController instancesRespondToSelector:@selector(contentUnavailableConfiguration)])
        return;
    SEL load = @selector(viewDidLoad);
    void (*original)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation([UIViewController class], load);
    class_replaceMethod([UIViewController class], load, imp_implementationWithBlock(^(UIViewController *controller) {
        original(controller, load);
        revenant_show_unavailable(controller);
        [controller setNeedsUpdateContentUnavailableConfiguration];
    }), "v@:");
}

@end

@implementation UIViewController (RevenantContentUnavailable17)

- (id<UIContentConfiguration>)contentUnavailableConfiguration
{
    return objc_getAssociatedObject(self, &RevenantUnavailableConfigurationKey);
}

- (void)setContentUnavailableConfiguration:(id<UIContentConfiguration>)contentUnavailableConfiguration
{
    objc_setAssociatedObject(self, &RevenantUnavailableConfigurationKey, contentUnavailableConfiguration, OBJC_ASSOCIATION_COPY_NONATOMIC);
    revenant_show_unavailable(self);
}

- (UIContentUnavailableConfigurationState *)contentUnavailableConfigurationState
{
    UIContentUnavailableConfigurationState *state = [[UIContentUnavailableConfigurationState alloc] initWithTraitCollection:self.traitCollection];
    state.searchText = self.navigationItem.searchController.searchBar.text;
    return state;
}

- (void)setNeedsUpdateContentUnavailableConfiguration
{
    if ([objc_getAssociatedObject(self, &RevenantUnavailableScheduledKey) boolValue])
        return;
    objc_setAssociatedObject(self, &RevenantUnavailableScheduledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        objc_setAssociatedObject(self, &RevenantUnavailableScheduledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self updateContentUnavailableConfigurationUsingState:self.contentUnavailableConfigurationState];
    });
}

- (void)updateContentUnavailableConfigurationUsingState:(UIContentUnavailableConfigurationState *)state
{
}

@end
