#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// The three block setters, from Security/SecProtocolOptions.h. The three block TYPES are declared in
// THIS HEADER, not in SecProtocolTypes.h - a grep of the wrong header finds the names only as parameter
// types and not the typedefs, which is how the first attempt at this file found nothing to read.
//
//   652  typedef void (^sec_protocol_key_update_t)(sec_protocol_metadata_t metadata,
//                                                    sec_protocol_key_update_complete_t complete);
//   680  typedef void (^sec_protocol_challenge_t)(sec_protocol_metadata_t metadata,
//                                                   sec_protocol_challenge_complete_t complete);
//   710  typedef void (^sec_protocol_verify_t)(sec_protocol_metadata_t metadata, sec_trust_t trust_ref,
//                                                sec_protocol_verify_complete_t complete);
//
//   729  void sec_protocol_options_set_key_update_block(options, sec_protocol_key_update_t, dispatch_queue_t)
//   748  void sec_protocol_options_set_challenge_block(options, sec_protocol_challenge_t, dispatch_queue_t)
//   767  void sec_protocol_options_set_verify_block(options, sec_protocol_verify_t, dispatch_queue_t)
//
// A BLOCK IS COPIED AND ITS QUEUE IS HELD, the same rule the pre-shared-key selection setter already
// obeys and for the same reason: a stack block is dead when the setter returns, and a block held
// without the queue it was given for is a block held for a queue nobody owns. Assigning to a __strong ivar
// copies; dispatch_retain and dispatch_release are ARC-FORBIDDEN on a dispatch object.
//
// WHAT IS MEASURED AND WHAT IS NOT, so the comment does not overclaim: the case proves the three are
// SEPARATE settings, that a NULL block clears, and that the neighbours are untouched. IT DOES NOT READ
// THE QUEUE BACK - a mutation that deleted `_verifyQueue = queue;` passes this case, because nothing
// looks at the queue. So the queue's holding is the DESIGN and is untested, and the row says that.
//
// THE VERIFY BLOCK IS THE ONLY ONE OF THE THREE THAT RECEIVES a sec_trust_t, and the port supplies that
// type ITSELF: sec_trust_create and sec_trust_copy_ref are BUILT and MEASURED, in
// SecObjectWrappers12_0.m, with the retain balance 1 2 3 2 1 and pointer identity checked on a real
// SecTrustRef. An earlier note here said the wrapper was one of the nine rows still owed; that was
// written before the wrapper family landed and is corrected rather than left to mislead. What is still
// NOT exercised is this block's queue: the case sets each of the three alone with its neighbours read
// back, and no test reads a queue back.

@interface CharonSecProtocolBlocks : NSObject <OS_sec_protocol_options>
{
    __strong sec_protocol_key_update_t _keyUpdate;
    __strong dispatch_queue_t _keyUpdateQueue;
    __strong sec_protocol_challenge_t _challenge;
    __strong dispatch_queue_t _challengeQueue;
    __strong sec_protocol_verify_t _verify;
    __strong dispatch_queue_t _verifyQueue;
}
- (void)charonSetKeyUpdate:(sec_protocol_key_update_t)block queue:(dispatch_queue_t)queue;
- (void)charonSetChallenge:(sec_protocol_challenge_t)block queue:(dispatch_queue_t)queue;
- (void)charonSetVerify:(sec_protocol_verify_t)block queue:(dispatch_queue_t)queue;
- (BOOL)charonHasKeyUpdate;
- (BOOL)charonHasChallenge;
- (BOOL)charonHasVerify;
@end

@implementation CharonSecProtocolBlocks
- (void)charonSetKeyUpdate:(sec_protocol_key_update_t)block queue:(dispatch_queue_t)queue
{
    _keyUpdate = block;
    _keyUpdateQueue = queue;
}
- (void)charonSetChallenge:(sec_protocol_challenge_t)block queue:(dispatch_queue_t)queue
{
    _challenge = block;
    _challengeQueue = queue;
}
- (void)charonSetVerify:(sec_protocol_verify_t)block queue:(dispatch_queue_t)queue
{
    _verify = block;
    _verifyQueue = queue;
}
- (BOOL)charonHasKeyUpdate { return _keyUpdate != NULL; }
- (BOOL)charonHasChallenge { return _challenge != NULL; }
- (BOOL)charonHasVerify { return _verify != NULL; }
@end

//   729
void sec_protocol_options_set_key_update_block(sec_protocol_options_t options,
                                               sec_protocol_key_update_t key_update_block,
                                               dispatch_queue_t key_update_queue)
{
    if (![options isKindOfClass:CharonSecProtocolBlocks.class])
        return;
    [(CharonSecProtocolBlocks *)options charonSetKeyUpdate:key_update_block queue:key_update_queue];
}

//   748
void sec_protocol_options_set_challenge_block(sec_protocol_options_t options,
                                              sec_protocol_challenge_t challenge_block,
                                              dispatch_queue_t challenge_queue)
{
    if (![options isKindOfClass:CharonSecProtocolBlocks.class])
        return;
    [(CharonSecProtocolBlocks *)options charonSetChallenge:challenge_block queue:challenge_queue];
}

//   767
void sec_protocol_options_set_verify_block(sec_protocol_options_t options,
                                           sec_protocol_verify_t verify_block,
                                           dispatch_queue_t verify_block_queue)
{
    if (![options isKindOfClass:CharonSecProtocolBlocks.class])
        return;
    [(CharonSecProtocolBlocks *)options charonSetVerify:verify_block queue:verify_block_queue];
}
