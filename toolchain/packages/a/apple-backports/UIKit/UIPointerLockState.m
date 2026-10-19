#import "RevenantMenus.h"
#import <objc/runtime.h>

NSString *const UIPointerLockStateDidChangeNotification = @"UIPointerLockStateDidChangeNotification";
NSString *const UIPointerLockStateSceneUserInfoKey = @"scene";

static const char revenant_lock_key;

@implementation UIPointerLockState

- (instancetype)initRevenant
{
    return [super init];
}

- (BOOL)isLocked
{
    return NO;
}

@end

@interface UIPointerLockState (RevenantInit)
- (instancetype)initRevenant;
@end

@implementation UIScene (RevenantPointerLockState)

- (UIPointerLockState *)pointerLockState
{
    UIPointerLockState *state = objc_getAssociatedObject(self, &revenant_lock_key);
    if (!state) {
        state = [[UIPointerLockState alloc] initRevenant];
        objc_setAssociatedObject(self, &revenant_lock_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

@end

@implementation UIViewController (RevenantPointerLock)

- (UIViewController *)childViewControllerForPointerLock
{
    return nil;
}

- (BOOL)prefersPointerLocked
{
    return NO;
}

- (void)setNeedsUpdateOfPrefersPointerLocked
{
    revenant_menus_say_once(@"pointer-lock", @"UIViewController.prefersPointerLocked: this release has no pointing device, so a preference for a locked pointer is never asked for and the scene's pointer lock state stays unlocked");
}

@end
