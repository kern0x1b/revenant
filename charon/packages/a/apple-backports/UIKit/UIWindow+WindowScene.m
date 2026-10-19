#import <objc/runtime.h>
#import "CharonScenes.h"

static const char CharonWindowSceneKey;

@implementation UIWindow (CharonWindowScene)

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene
{
    if ((self = [self initWithFrame:windowScene.screen.bounds]))
        [self setWindowScene:windowScene];
    return self;
}

- (UIWindowScene *)windowScene
{
    return objc_getAssociatedObject(self, &CharonWindowSceneKey) ?: charon_scene();
}

- (void)setWindowScene:(UIWindowScene *)windowScene
{
    objc_setAssociatedObject(self, &CharonWindowSceneKey, windowScene, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
