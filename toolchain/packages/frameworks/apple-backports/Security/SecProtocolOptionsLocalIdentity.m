#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

@interface RevenantSecProtocolLocalIdentity : NSObject <OS_sec_protocol_options>
{
    __strong sec_identity_t _localIdentity;
}
- (void)revenantSetLocalIdentity:(sec_identity_t)identity;
- (sec_identity_t)revenantLocalIdentity;
@end

@implementation RevenantSecProtocolLocalIdentity
- (void)revenantSetLocalIdentity:(sec_identity_t)identity
{
    _localIdentity = identity;
}
- (sec_identity_t)revenantLocalIdentity { return _localIdentity; }
@end

void sec_protocol_options_set_local_identity(sec_protocol_options_t options, sec_identity_t identity)
{
    if (![options isKindOfClass:RevenantSecProtocolLocalIdentity.class])
        return;
    [(RevenantSecProtocolLocalIdentity *)options revenantSetLocalIdentity:identity];
}
