#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@implementation CTTelephonyNetworkInfo (CharonRadioAccess)

- (NSString *)currentRadioAccessTechnology
{
    SEL selector = sel_registerName("radioAccessTechnology");
    if (![self respondsToSelector:selector])
        return nil;
    id holder = ((id (*)(id, SEL))objc_msgSend)(self, selector);
    if (![holder respondsToSelector:selector])
        return nil;
    NSString *technology = ((id (*)(id, SEL))objc_msgSend)(holder, selector);
    if ([technology isEqualToString:@"CTRadioAccessTechnologyWCMDA"])
        return CTRadioAccessTechnologyWCDMA;
    return technology;
}

@end
