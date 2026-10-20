#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

@interface RevenantSecProtocolBlocks : NSObject <OS_sec_protocol_options>
{
    __strong sec_protocol_key_update_t _keyUpdate;
    __strong dispatch_queue_t _keyUpdateQueue;
    __strong sec_protocol_challenge_t _challenge;
    __strong dispatch_queue_t _challengeQueue;
    __strong sec_protocol_verify_t _verify;
    __strong dispatch_queue_t _verifyQueue;
}
- (void)revenantSetKeyUpdate:(sec_protocol_key_update_t)block queue:(dispatch_queue_t)queue;
- (void)revenantSetChallenge:(sec_protocol_challenge_t)block queue:(dispatch_queue_t)queue;
- (void)revenantSetVerify:(sec_protocol_verify_t)block queue:(dispatch_queue_t)queue;
- (BOOL)revenantHasKeyUpdate;
- (BOOL)revenantHasChallenge;
- (BOOL)revenantHasVerify;
@end

@implementation RevenantSecProtocolBlocks
- (void)revenantSetKeyUpdate:(sec_protocol_key_update_t)block queue:(dispatch_queue_t)queue
{
    _keyUpdate = block;
    _keyUpdateQueue = queue;
}
- (void)revenantSetChallenge:(sec_protocol_challenge_t)block queue:(dispatch_queue_t)queue
{
    _challenge = block;
    _challengeQueue = queue;
}
- (void)revenantSetVerify:(sec_protocol_verify_t)block queue:(dispatch_queue_t)queue
{
    _verify = block;
    _verifyQueue = queue;
}
- (BOOL)revenantHasKeyUpdate { return _keyUpdate != NULL; }
- (BOOL)revenantHasChallenge { return _challenge != NULL; }
- (BOOL)revenantHasVerify { return _verify != NULL; }
@end

void sec_protocol_options_set_key_update_block(sec_protocol_options_t options,
                                               sec_protocol_key_update_t key_update_block,
                                               dispatch_queue_t key_update_queue)
{
    if (![options isKindOfClass:RevenantSecProtocolBlocks.class])
        return;
    [(RevenantSecProtocolBlocks *)options revenantSetKeyUpdate:key_update_block queue:key_update_queue];
}

void sec_protocol_options_set_challenge_block(sec_protocol_options_t options,
                                              sec_protocol_challenge_t challenge_block,
                                              dispatch_queue_t challenge_queue)
{
    if (![options isKindOfClass:RevenantSecProtocolBlocks.class])
        return;
    [(RevenantSecProtocolBlocks *)options revenantSetChallenge:challenge_block queue:challenge_queue];
}

void sec_protocol_options_set_verify_block(sec_protocol_options_t options,
                                           sec_protocol_verify_t verify_block,
                                           dispatch_queue_t verify_block_queue)
{
    if (![options isKindOfClass:RevenantSecProtocolBlocks.class])
        return;
    [(RevenantSecProtocolBlocks *)options revenantSetVerify:verify_block queue:verify_block_queue];
}
