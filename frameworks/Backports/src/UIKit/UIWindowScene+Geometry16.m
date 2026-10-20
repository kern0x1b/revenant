#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIWindowScene (RevenantGeometry16)

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
