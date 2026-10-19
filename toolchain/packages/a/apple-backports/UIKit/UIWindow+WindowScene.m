#import <objc/runtime.h>
#import "RevenantScenes.h"

static const char RevenantWindowSceneKey;

@implementation UIWindow (RevenantWindowScene)

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene
{
    if ((self = [self initWithFrame:windowScene.screen.bounds]))
        [self setWindowScene:windowScene];
    return self;
}

- (UIWindowScene *)windowScene
{
    return objc_getAssociatedObject(self, &RevenantWindowSceneKey) ?: revenant_scene();
}

- (void)setWindowScene:(UIWindowScene *)windowScene
{
    objc_setAssociatedObject(self, &RevenantWindowSceneKey, windowScene, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
