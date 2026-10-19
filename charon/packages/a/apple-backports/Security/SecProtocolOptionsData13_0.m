#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// The two dispatch_data setters, from Security/SecProtocolOptions.h:
//
//   354  void sec_protocol_options_set_tls_diffie_hellman_parameters(sec_protocol_options_t,
//                                                                     dispatch_data_t dh_params)
//   373  void sec_protocol_options_add_pre_shared_key(sec_protocol_options_t, dispatch_data_t psk,
//                                                      dispatch_data_t psk_identity)
//
// dispatch_data_t IS AN OBJC OBJECT HERE, so it is held with a __strong ivar and ARC does the retain -
// dispatch_retain and dispatch_release are ARC-FORBIDDEN on it, the same rule that forbids CFRelease and
// -release on an ObjC pointer. That is the whole of the holding story for a dispatch_data value, and it
// is the third time this series has been stopped by it.
//
// THE PRE-SHARED KEY IS A PAIR, and both halves are held: the key bytes without their identity would be
// useless, and an identity without the key names nothing. The list of pairs is the port's own, so a
// caller that adds two gets two, and a caller that releases its own dispatch_data afterwards has left
// the object holding its own reference.

@interface CharonSecProtocolData : NSObject <OS_sec_protocol_options>
{
    __strong dispatch_data_t _dhParams;                  // one setting: a replacement
    // TWO ARRAYS, ONE PER HALF, because a pre-shared key is a PAIR and the halves must stay in step.
    // NOT a C array of __strong pointers: realloc on a __strong ivar is ARC-FORBIDDEN, which the
    // compiler says, and an NSMutableArray is both the ARC-legal form and the one that grows on its own.
    NSMutableArray *_psks;
    NSMutableArray *_pskIdentities;
}
- (void)charonSetDHParams:(dispatch_data_t)params;
- (dispatch_data_t)charonDHParams;
- (void)charonAddPSK:(dispatch_data_t)psk identity:(dispatch_data_t)identity;
- (size_t)charonPSKCount;
- (BOOL)charonPSKAt:(size_t)index psk:(dispatch_data_t *)psk identity:(dispatch_data_t *)identity;
@end

@implementation CharonSecProtocolData
- (instancetype)init
{
    self = [super init];
    if (self) {
        _psks = [[NSMutableArray alloc] init];
        _pskIdentities = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)charonSetDHParams:(dispatch_data_t)params { _dhParams = params; }
- (dispatch_data_t)charonDHParams { return _dhParams; }
- (void)charonAddPSK:(dispatch_data_t)psk identity:(dispatch_data_t)identity
{
    // A PAIR WITH A MISSING HALF IS NOT STORED: a key without an identity names nothing, and an
    // identity without a key is not a pre-shared key. Half a pair in the list would be read back later
    // as though it were whole.
    if (!psk || !identity)
        return;
    // appended TOGETHER, so the two halves cannot fall out of step
    // dispatch_data_t is an OS_dispatch_data, which is an ObjC object but NOT an id in the
    // strict sense, so the cast is explicit in both directions and the read back is bridged.
    [_psks addObject:(id)psk];
    [_pskIdentities addObject:(id)identity];
}
- (size_t)charonPSKCount { return _psks.count; }
- (BOOL)charonPSKAt:(size_t)index psk:(dispatch_data_t *)psk identity:(dispatch_data_t *)identity
{
    if (index >= _psks.count)
        return NO;
    if (psk) *psk = (dispatch_data_t)(id)_psks[index];
    if (identity) *identity = (dispatch_data_t)(id)_pskIdentities[index];
    return YES;
}
@end

//   354
void sec_protocol_options_set_tls_diffie_hellman_parameters(sec_protocol_options_t options,
                                                            dispatch_data_t dh_params)
{
    if (![options isKindOfClass:CharonSecProtocolData.class])
        return;
    [(CharonSecProtocolData *)options charonSetDHParams:dh_params];
}

//   373
void sec_protocol_options_add_pre_shared_key(sec_protocol_options_t options, dispatch_data_t psk,
                                             dispatch_data_t psk_identity)
{
    if (![options isKindOfClass:CharonSecProtocolData.class])
        return;
    [(CharonSecProtocolData *)options charonAddPSK:psk identity:psk_identity];
}
