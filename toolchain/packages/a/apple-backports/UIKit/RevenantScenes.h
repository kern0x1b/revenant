#import <UIKit/UIKit.h>

@interface UIOpenURLContext (RevenantScenes)
- (instancetype)initRevenantWithURL:(NSURL *)URL options:(UISceneOpenURLOptions *)options;
@end

@interface UISceneOpenURLOptions (RevenantScenes)
- (instancetype)initRevenantWithSourceApplication:(NSString *)sourceApplication annotation:(id)annotation openInPlace:(BOOL)openInPlace;
@end

@interface UISceneConnectionOptions (RevenantScenes)
- (instancetype)initRevenantWithURLContexts:(NSSet *)URLContexts sourceApplication:(NSString *)sourceApplication;
@end

@interface UISceneSession (RevenantScenes)
- (instancetype)initRevenantWithRole:(UISceneSessionRole)role configuration:(UISceneConfiguration *)configuration persistentIdentifier:(NSString *)persistentIdentifier;
- (void)revenant_setScene:(UIScene *)scene;
@end

@interface UIStatusBarManager (RevenantScenes)
- (instancetype)initRevenant;
@end

@interface UIScene (RevenantScenes)
- (void)revenant_setActivationState:(UISceneActivationState)state;
@end

@interface UIApplication (RevenantScenes)
- (UIWindowScene *)revenant_scene;
@end

UIWindowScene *revenant_scene(void);
