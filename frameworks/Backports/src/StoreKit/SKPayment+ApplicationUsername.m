#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

static const void *RevenantPaymentApplicationUsernameKey = &RevenantPaymentApplicationUsernameKey;

@implementation SKPayment (RevenantApplicationUsername)

- (NSString *)applicationUsername
{
    return objc_getAssociatedObject(self, RevenantPaymentApplicationUsernameKey);
}

@end

@implementation SKMutablePayment (RevenantApplicationUsername)

- (void)setApplicationUsername:(NSString *)applicationUsername
{
    objc_setAssociatedObject(self, RevenantPaymentApplicationUsernameKey, applicationUsername, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
