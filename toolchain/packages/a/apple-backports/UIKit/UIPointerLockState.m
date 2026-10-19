#import "CharonMenus.h"
#import <objc/runtime.h>

NSString *const UIPointerLockStateDidChangeNotification = @"UIPointerLockStateDidChangeNotification";
NSString *const UIPointerLockStateSceneUserInfoKey = @"scene";

static const char charon_lock_key;

@implementation UIPointerLockState

- (instancetype)initCharon
{
    return [super init];
}

- (BOOL)isLocked
{
    return NO;
}

@end

@interface UIPointerLockState (CharonInit)
- (instancetype)initCharon;
@end

@implementation UIScene (CharonPointerLockState)

- (UIPointerLockState *)pointerLockState
{
    UIPointerLockState *state = objc_getAssociatedObject(self, &charon_lock_key);
    if (!state) {
        state = [[UIPointerLockState alloc] initCharon];
        objc_setAssociatedObject(self, &charon_lock_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

@end

@implementation UIViewController (CharonPointerLock)

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
    charon_menus_say_once(@"pointer-lock", @"UIViewController.prefersPointerLocked: this release has no pointing device, so a preference for a locked pointer is never asked for and the scene's pointer lock state stays unlocked");
}

@end
