#import <Foundation/Foundation.h>

NSString *const NSProcessInfoPowerStateDidChangeNotification = @"NSProcessInfoPowerStateDidChangeNotification";

@implementation NSProcessInfo (CharonPowerState)

- (BOOL)isLowPowerModeEnabled
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"NSProcessInfo.lowPowerModeEnabled answers NO on iOS 6: the release has no Low Power Mode, so an application is never told to save energy");
    });
    return NO;
}

@end
