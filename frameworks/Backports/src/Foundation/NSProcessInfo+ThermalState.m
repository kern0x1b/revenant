#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

NSString *const BACKPORT_IMPL(NSProcessInfoThermalStateDidChangeNotification) = @"NSProcessInfoThermalStateDidChangeNotification";

@implementation NSProcessInfo (RevenantThermalState)

- (NSProcessInfoThermalState)thermalState
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"NSProcessInfo.thermalState answers nominal on iOS 6: the release reports no thermal pressure level, so an application is never told to back off");
    });
    return NSProcessInfoThermalStateNominal;
}

@end
