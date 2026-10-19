#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

// sec_protocol_options_set_local_identity, in its OWN object because it is a different type and a
// different subsystem from the sec_identity_t family beside it: that family wraps sec_identity_t, this
// wraps sec_protocol_options_t. One release per object, and the two must not share a file - that is what
// release-split checks, and a 13.0 object that also held a 16.0 entry point is what the gate refused.
//
//   SecProtocolOptions.h:102  void sec_protocol_options_set_local_identity(sec_protocol_options_t options,
//                                                                       sec_identity_t identity)
//
// NOT EXPORTED BY 6.1.3 - _sec_protocol_options_set_local_identity is absent from that release's export
// trie (Security image at 0x32e79000, 660 exports) - so the port supplies it.
//
// sec_identity_t IS AN OBJECT, and that is the whole reason this file needed no bridge: the preprocessor
// emits it as `NSObject<OS_sec_identity> * __attribute__((objc_independent_class))`, so it is an
// Objective-C pointer, ARC manages a strong ivar of it, and passing it to a method taking the same type
// needs no cast at all. The earlier version took a SecIdentityRef and asked for __bridge, which is what
// clang was pointing at in its note and what I did not read.
//
// THE PATTERN IS THE SIBLING'S: a holder class of its OWN, attached by isKindOfClass:, and NO parent
// re-declared here. CharonSecProtocolBlocks in SecProtocolOptionsBlocks13_0.m does exactly this, and
// re-declaring CharonSecProtocolOptionsHeld in a second translation unit - which the first version did -
// is a duplicate definition of a class the tree already owns, and it is the suspect that was right to be
// suspected.
//
// 6.1.3 HAS NO STACK THAT TAKES A sec_protocol_options_t, so nothing ever reads the identity this holds.
// The row is INERT: callable, the value held, effect stated - the handshake ignores it.

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
    _localIdentity = identity;   // a strong ivar of an ObjC pointer: assignment retains, ARC releases
}
- (sec_identity_t)charonLocalIdentity { return _localIdentity; }
@end

void sec_protocol_options_set_local_identity(sec_protocol_options_t options, sec_identity_t identity)
{
    if (![options isKindOfClass:CharonSecProtocolLocalIdentity.class])
        return;
    [(CharonSecProtocolLocalIdentity *)options charonSetLocalIdentity:identity];
}
