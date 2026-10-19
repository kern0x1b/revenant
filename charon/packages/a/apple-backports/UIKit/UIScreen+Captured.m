#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_captured_key;

static BOOL charon_screen_captured(UIScreen *screen)
{
    UIScreen *main = [UIScreen mainScreen];
    UIScreen *mirrored = [main respondsToSelector:@selector(mirroredScreen)] ? main.mirroredScreen : nil;
    return screen == main ? mirrored != nil : screen == mirrored;
}

static void charon_screens_changed(void)
{
    for (UIScreen *screen in [UIScreen screens]) {
        BOOL captured = charon_screen_captured(screen);
        BOOL was = [objc_getAssociatedObject(screen, &charon_captured_key) boolValue];
        if (was == captured)
            continue;
        objc_setAssociatedObject(screen, &charon_captured_key, @(captured), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[NSNotificationCenter defaultCenter] postNotificationName:UIScreenCapturedDidChangeNotification object:screen];
    }
}

__attribute__((constructor)) static void charon_install_captured(void)
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    for (NSNotificationName name in @[UIScreenDidConnectNotification, UIScreenDidDisconnectNotification, UIScreenModeDidChangeNotification])
        [center addObserverForName:name object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) { charon_screens_changed(); }];
}

@implementation UIScreen (CharonCaptured)

- (BOOL)isCaptured
{
    return charon_screen_captured(self);
}

@end
