#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

@implementation HKSource (RevenantIOS9)

+ (nullable NSString *)revenant_processVersion
{
    static NSString *version;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSDictionary *info = [bundle localizedInfoDictionary] ?: [bundle infoDictionary];
        id given = [info objectForKey:@"CFBundleVersion"];
        version = [given isKindOfClass:[NSString class]] ? [given copy] : nil;
    });
    return version;
}

@end
