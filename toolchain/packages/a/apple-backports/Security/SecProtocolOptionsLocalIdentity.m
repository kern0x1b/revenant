#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

@interface CharonSecProtocolLocalIdentity : NSObject <OS_sec_protocol_options>
{
    __strong sec_identity_t _localIdentity;
}
- (void)charonSetLocalIdentity:(sec_identity_t)identity;
- (sec_identity_t)charonLocalIdentity;
@end

@implementation CharonSecProtocolLocalIdentity
- (void)charonSetLocalIdentity:(sec_identity_t)identity
{
    _localIdentity = identity;
}
- (sec_identity_t)charonLocalIdentity { return _localIdentity; }
@end

void sec_protocol_options_set_local_identity(sec_protocol_options_t options, sec_identity_t identity)
{
    if (![options isKindOfClass:CharonSecProtocolLocalIdentity.class])
        return;
    [(CharonSecProtocolLocalIdentity *)options charonSetLocalIdentity:identity];
}
