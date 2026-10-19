#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

@interface CharonSecProtocolData : NSObject <OS_sec_protocol_options>
{
    __strong dispatch_data_t _dhParams;
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
    if (!psk || !identity)
        return;
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

void sec_protocol_options_set_tls_diffie_hellman_parameters(sec_protocol_options_t options,
                                                            dispatch_data_t dh_params)
{
    if (![options isKindOfClass:CharonSecProtocolData.class])
        return;
    [(CharonSecProtocolData *)options charonSetDHParams:dh_params];
}

void sec_protocol_options_add_pre_shared_key(sec_protocol_options_t options, dispatch_data_t psk,
                                             dispatch_data_t psk_identity)
{
    if (![options isKindOfClass:CharonSecProtocolData.class])
        return;
    [(CharonSecProtocolData *)options charonAddPSK:psk identity:psk_identity];
}
