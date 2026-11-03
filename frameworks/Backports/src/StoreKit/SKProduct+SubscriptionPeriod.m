#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface SKProduct (RevenantSubscriptionPeriod)
@property (nonatomic, readonly, nullable) SKProductSubscriptionPeriod *subscriptionPeriod;
@end

@implementation SKProduct (RevenantSubscriptionPeriod)

- (SKProductSubscriptionPeriod *)subscriptionPeriod {
    return nil;
}

@end
