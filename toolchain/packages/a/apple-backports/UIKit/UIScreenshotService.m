#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char revenant_service_key;

@implementation UIScreenshotService {
@private
    __weak id<UIScreenshotServiceDelegate> _delegate;
    __weak UIWindowScene *_windowScene;
}

- (instancetype)initRevenantWithWindowScene:(UIWindowScene *)windowScene
{
    if ((self = [super init]))
        _windowScene = windowScene;
    return self;
}

- (id<UIScreenshotServiceDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIScreenshotServiceDelegate>)delegate
{
    _delegate = delegate;
    if (delegate)
        revenant_menus_say_once(@"screenshot-service", @"UIScreenshotService: iOS 6 takes screenshots itself and asks an application for no PDF, so the delegate is never called");
}

- (UIWindowScene *)windowScene
{
    return _windowScene;
}

@end

@implementation UIWindowScene (RevenantScreenshotService)

- (UIScreenshotService *)screenshotService
{
    UIScreenshotService *service = objc_getAssociatedObject(self, &revenant_service_key);
    if (!service) {
        service = [[UIScreenshotService alloc] initRevenantWithWindowScene:self];
        objc_setAssociatedObject(self, &revenant_service_key, service, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return service;
}

@end
