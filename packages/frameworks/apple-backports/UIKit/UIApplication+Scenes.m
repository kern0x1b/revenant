#import "RevenantScenes.h"
#import "../RevenantSayOnce.h"

static void revenant_say_once(NSString *key, NSString *text)
{
    revenant_say_once_for(key, text);
}

static void revenant_scene_error(void (^handler)(NSError *), NSInteger code)
{
    if (!handler)
        return;
    NSError *error = [NSError errorWithDomain:UISceneErrorDomain code:code userInfo:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
    });
}

@implementation UIApplication (RevenantScenes)

- (UIWindowScene *)revenant_scene
{
    return revenant_scene();
}

- (NSSet<UIScene *> *)connectedScenes
{
    UIWindowScene *scene = revenant_scene();
    return scene ? [NSSet setWithObject:scene] : [NSSet set];
}

- (NSSet<UISceneSession *> *)openSessions
{
    UIWindowScene *scene = revenant_scene();
    return scene ? [NSSet setWithObject:scene.session] : [NSSet set];
}

- (BOOL)supportsMultipleScenes
{
    return NO;
}

- (void)requestSceneSessionActivation:(UISceneSession *)sceneSession userActivity:(NSUserActivity *)userActivity options:(UISceneActivationRequestOptions *)options errorHandler:(void (^)(NSError *))errorHandler
{
    if (sceneSession && sceneSession == revenant_scene().session)
        return;
    revenant_scene_error(errorHandler, 0);
}

- (void)requestSceneSessionDestruction:(UISceneSession *)sceneSession options:(UISceneDestructionRequestOptions *)options errorHandler:(void (^)(NSError *))errorHandler
{
    revenant_scene_error(errorHandler, 1);
}

- (void)requestSceneSessionRefresh:(UISceneSession *)sceneSession
{
    revenant_say_once(@"scene-refresh", @"UIApplication requestSceneSessionRefresh: has no scene snapshot to refresh on this release and does nothing");
}

@end
