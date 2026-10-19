#import <UIKit/UIKit.h>

@implementation UIApplication (CharonAlternateIcon)

- (BOOL)supportsAlternateIcons
{
    return NO;
}

- (NSString *)alternateIconName
{
    return nil;
}

- (void)setAlternateIconName:(NSString *)alternateIconName completionHandler:(void (^)(NSError *))completionHandler
{
    if (!completionHandler)
        return;
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{NSLocalizedDescriptionKey: @"The requested operation couldn’t be completed because the feature is not supported."}];
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(error);
    });
}

@end
