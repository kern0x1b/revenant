#import "RevenantScenes.h"

@interface UITraitCollection (RevenantOrientation13)
+ (UITraitCollection *)revenant_traitCollectionWithScreenIdiom:(UIUserInterfaceIdiom)screenIdiom deviceIdiom:(UIUserInterfaceIdiom)deviceIdiom scale:(CGFloat)scale bounds:(CGSize)bounds;
@end

@interface RevenantOrientationWatcher : NSObject
@end

@implementation RevenantOrientationWatcher

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changed:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

+ (void)changed:(NSNotification *)notification
{
    UIWindowScene *scene = revenant_scene();
    id<UIWindowSceneDelegate> delegate = (id<UIWindowSceneDelegate>)scene.delegate;
    if (![delegate respondsToSelector:@selector(windowScene:didUpdateCoordinateSpace:interfaceOrientation:traitCollection:)])
        return;
    NSNumber *old = notification.userInfo[UIApplicationStatusBarOrientationUserInfoKey];
    UIInterfaceOrientation previous = old ? (UIInterfaceOrientation)old.integerValue : scene.interfaceOrientation;
    UIScreen *screen = scene.screen;
    CGSize natural = screen.bounds.size;
    CGSize bounds = UIInterfaceOrientationIsLandscape(previous) ? CGSizeMake(natural.height, natural.width) : natural;
    UIUserInterfaceIdiom idiom = [UIDevice currentDevice].userInterfaceIdiom;
    UITraitCollection *traits = [UITraitCollection revenant_traitCollectionWithScreenIdiom:idiom deviceIdiom:idiom scale:screen.scale bounds:bounds];
    [delegate windowScene:scene didUpdateCoordinateSpace:scene.coordinateSpace interfaceOrientation:previous traitCollection:traits];
}

@end
