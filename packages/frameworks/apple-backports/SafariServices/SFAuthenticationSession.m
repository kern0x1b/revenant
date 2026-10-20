#import "RevenantSafari.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSMutableSet *active_sessions(void)
{
    static NSMutableSet *sessions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sessions = [NSMutableSet set]; });
    return sessions;
}

static __weak SFAuthenticationSession *current_session;

static UIViewController *top_controller(UIWindow *window)
{
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController)
        controller = controller.presentedViewController;
    return controller;
}

static void when_settled(UIViewController *controller, int attempts, dispatch_block_t block)
{
    if (attempts > 0 && (controller.isBeingPresented || controller.isBeingDismissed || controller.presentedViewController.isBeingPresented || controller.presentedViewController.isBeingDismissed)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            when_settled(controller, attempts - 1, block);
        });
        return;
    }
    block();
}

static void when_gone(UIViewController *presenter, UIViewController *shown, int attempts, dispatch_block_t block)
{
    if (attempts > 0 && presenter.presentedViewController == shown) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            when_gone(presenter, shown, attempts - 1, block);
        });
        return;
    }
    block();
}

static void dismiss_then_attempt(UIViewController *shown, int attempts, dispatch_block_t block);

static void dismiss_then(UIViewController *shown, dispatch_block_t block)
{
    dismiss_then_attempt(shown, 50, block);
}

static void dismiss_then_attempt(UIViewController *shown, int attempts, dispatch_block_t block)
{
    if (attempts > 0 && (!shown.presentingViewController || shown.isBeingPresented || shown.isBeingDismissed)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dismiss_then_attempt(shown, attempts - 1, block);
        });
        return;
    }
    UIViewController *presenter = shown.presentingViewController;
    if (!presenter) {
        block();
        return;
    }
    [presenter dismissViewControllerAnimated:YES completion:^{
        when_gone(presenter, shown, 40, block);
    }];
}

@interface SFAuthenticationSession () <SFSafariViewControllerDelegate>
@end

@implementation SFAuthenticationSession {
    NSURL *_URL;
    NSString *_callbackScheme;
    SFAuthenticationCompletionHandler _handler;
    BOOL _running;
    RevenantSafariPage *_controller;
}

@synthesize revenant_presentationWindow = _presentationWindow;

- (instancetype)init
{
    return [self initWithURL:nil callbackURLScheme:nil completionHandler:nil];
}

- (instancetype)initWithURL:(NSURL *)URL callbackURLScheme:(NSString *)callbackURLScheme completionHandler:(SFAuthenticationCompletionHandler)completionHandler
{
    self = [super init];
    if (self) {
        _URL = [URL copy];
        _callbackScheme = [callbackURLScheme copy];
        _handler = [completionHandler copy];
    }
    return self;
}

- (NSError *)revenant_canceledError
{
    return [NSError errorWithDomain:SFAuthenticationErrorDomain code:SFAuthenticationErrorCanceledLogin userInfo:nil];
}

- (void)revenant_completeWithURL:(NSURL *)URL error:(NSError *)error
{
    if (!_running)
        return;
    _running = NO;
    SFAuthenticationCompletionHandler handler = _handler;
    _controller.delegate = nil;
    _controller = nil;
    [active_sessions() removeObject:self];
    if (handler)
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(URL, error);
        });
}

- (UIViewController *)revenant_presenter
{
    UIWindow *window = self.revenant_presentationWindow ?: [UIApplication sharedApplication].keyWindow ?: [[UIApplication sharedApplication].windows firstObject];
    return top_controller(window);
}

- (BOOL)revenant_acceptsScheme:(NSString *)scheme
{
    if (_callbackScheme)
        return [scheme caseInsensitiveCompare:_callbackScheme] == NSOrderedSame;
    for (NSDictionary *type in [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"])
        for (NSString *declared in type[@"CFBundleURLSchemes"])
            if ([scheme caseInsensitiveCompare:declared] == NSOrderedSame)
                return YES;
    return NO;
}

- (void)revenant_present:(RevenantSafariPage *)controller from:(UIViewController *)presenter attempts:(int)attempts
{
    when_settled(presenter, attempts, ^{
        if (self->_controller != controller)
            return;
        UIViewController *top = [self revenant_presenter];
        if (top != presenter && attempts > 0) {
            [self revenant_present:controller from:top attempts:attempts - 1];
            return;
        }
        [presenter presentViewController:controller animated:YES completion:nil];
    });
}

- (BOOL)start
{
    if (_running)
        return NO;
    SFAuthenticationSession *previous = current_session;
    if (previous != self)
        [previous cancel];
    _running = YES;
    current_session = self;
    [active_sessions() addObject:self];
    NSString *scheme = _URL.scheme.lowercaseString;
    UIViewController *presenter = ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) ? [self revenant_presenter] : nil;
    if (!presenter) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self revenant_completeWithURL:nil error:[self revenant_canceledError]];
        });
        return YES;
    }
    RevenantSafariPage *controller = [[RevenantSafariPage alloc] initWithURL:_URL];
    controller.delegate = self;
    controller.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleCancel;
    __weak SFAuthenticationSession *weak = self;
    controller.callbackMatcher = ^BOOL(NSURL *URL) {
        return [weak revenant_acceptsScheme:URL.scheme];
    };
    controller.callback = ^(NSURL *URL) {
        SFAuthenticationSession *session = weak;
        if (!session || !session->_running)
            return;
        RevenantSafariPage *shown = session->_controller;
        session->_controller = nil;
        shown.delegate = nil;
        when_settled(shown, 50, ^{
            void (^finish)(void) = ^{
                [session revenant_completeWithURL:URL error:nil];
            };
            dismiss_then(shown, finish);
        });
    };
    _controller = controller;
    [self revenant_present:controller from:presenter attempts:50];
    return YES;
}

- (void)cancel
{
    if (!_running)
        return;
    RevenantSafariPage *shown = _controller;
    shown.delegate = nil;
    void (^finish)(void) = ^{
        [self revenant_completeWithURL:nil error:[self revenant_canceledError]];
    };
    _controller = nil;
    if (!shown || !shown.isViewLoaded) {
        dispatch_async(dispatch_get_main_queue(), finish);
        return;
    }
    when_settled(shown, 50, ^{
        dismiss_then(shown, finish);
    });
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    [self revenant_completeWithURL:nil error:[self revenant_canceledError]];
}

@end
