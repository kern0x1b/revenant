#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

UIApplicationOpenExternalURLOptionsKey const UIApplicationOpenURLOptionUniversalLinksOnly = @"UIApplicationOpenURLOptionUniversalLinksOnly";

@implementation UIApplication (CharonOpenURLOptions)

- (void)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options completionHandler:(void (^)(BOOL success))completion
{
    id universalOption = [options objectForKey:UIApplicationOpenURLOptionUniversalLinksOnly];
    BOOL universalLinksOnly = [universalOption isKindOfClass:[NSNumber class]] && [universalOption boolValue];
    if (universalLinksOnly)
        NSLog(@"openURL:options:completionHandler: iOS %@ has no universal links, so %@ opens no application and the handler is called with NO", [UIDevice currentDevice].systemVersion, url);
    BOOL opened = universalLinksOnly ? NO : [self openURL:url];
    if (completion)
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(opened);
        });
}

@end
