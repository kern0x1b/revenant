#import "CharonMenus.h"
#import <objc/runtime.h>

static const char charon_service_key;

@implementation UIScreenshotService {
@private
    __weak id<UIScreenshotServiceDelegate> _delegate;
    __weak UIWindowScene *_windowScene;
}

- (instancetype)initCharonWithWindowScene:(UIWindowScene *)windowScene
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
        charon_menus_say_once(@"screenshot-service", @"UIScreenshotService: iOS 6 takes screenshots itself and asks an application for no PDF, so the delegate is never called");
}

- (UIWindowScene *)windowScene
{
    return _windowScene;
}

@end

@implementation UIWindowScene (CharonScreenshotService)

- (UIScreenshotService *)screenshotService
{
    UIScreenshotService *service = objc_getAssociatedObject(self, &charon_service_key);
    if (!service) {
        service = [[UIScreenshotService alloc] initCharonWithWindowScene:self];
        objc_setAssociatedObject(self, &charon_service_key, service, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return service;
}

@end
