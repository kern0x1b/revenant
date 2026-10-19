#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// -[UIWindowScene requestGeometryUpdateWithPreferences:errorHandler:], iOS 16. The port's scene is one fixed window: its windowing mode does not
// allow a programmatic change to the interface orientation, so the request is refused, as the host's own scene refuses it under Mac Catalyst
// (UISceneErrorDomain code 101, measured by tests/backports/host/window-scene-geometry). The refusal is delivered to the handler before the
// request returns, on the calling thread, and a nil handler is allowed and gets nothing.
//
// The description is looked up with the key the host's own UIKit uses, UIWindowScene.orientationRequestNotAllowed, in UIKit's bundle. The
// English given as the default is the answer where the bundle has no such key, which is the iOS 6 release the port runs on: that release has
// no windowing scene, so it has no such key. The host's table carries the key in its localizations, but NSBundle does not reach the German
// translation on the host (facts/UIKit/UIWindowSceneWindowing16.md), so the German text is not claimed.
@implementation UIWindowScene (CharonGeometry16)

- (void)requestGeometryUpdateWithPreferences:(UIWindowSceneGeometryPreferences *)geometryPreferences errorHandler:(void (^)(NSError *error))errorHandler
{
    if (!errorHandler)
        return;
    NSString *message = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"UIWindowScene.orientationRequestNotAllowed"
                                                                                          value:@"The current windowing mode does not allow for programmatic changes to interface orientation."
                                                                                          table:nil];
    errorHandler([NSError errorWithDomain:UISceneErrorDomain code:101 userInfo:@{NSLocalizedDescriptionKey: message}]);
}

@end
