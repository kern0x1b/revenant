#import <UIKit/UIKit.h>

@interface UIOpenURLContext (CharonScenes)
- (instancetype)initCharonWithURL:(NSURL *)URL options:(UISceneOpenURLOptions *)options;
@end

@interface UISceneOpenURLOptions (CharonScenes)
- (instancetype)initCharonWithSourceApplication:(NSString *)sourceApplication annotation:(id)annotation openInPlace:(BOOL)openInPlace;
@end

@interface UISceneConnectionOptions (CharonScenes)
- (instancetype)initCharonWithURLContexts:(NSSet *)URLContexts sourceApplication:(NSString *)sourceApplication;
@end

@interface UISceneSession (CharonScenes)
- (instancetype)initCharonWithRole:(UISceneSessionRole)role configuration:(UISceneConfiguration *)configuration persistentIdentifier:(NSString *)persistentIdentifier;
- (void)charon_setScene:(UIScene *)scene;
@end

@interface UIStatusBarManager (CharonScenes)
- (instancetype)initCharon;
@end

@interface UIScene (CharonScenes)
- (void)charon_setActivationState:(UISceneActivationState)state;
@end

@interface UIApplication (CharonScenes)
- (UIWindowScene *)charon_scene;
@end

UIWindowScene *charon_scene(void);
