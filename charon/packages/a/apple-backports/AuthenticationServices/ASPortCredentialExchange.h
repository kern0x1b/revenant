// The port's record of one credential-provider exchange, and the whole of what the port's
// ASCredentialProviderExtensionContext does with a completion: it keeps what the extension decided, where
// the application that owns the extension can read it. On a device the counterpart of a completion is
// the SYSTEM taking the credential and presenting it, and the port has no system to hand one to -- which
// is why the decision, and not the presentation, is what a caller can observe here.
//
// It is an object rather than a struct returned by value, and that is not a matter of taste. A struct
// return is a stret call whose ABI an ordinary message send does not describe, so a caller reading it
// through objc_msgSend would have to model the register shuffling itself to get it right; and an
// immutable object is the stronger thing anyway, because a record handed out by value can be changed by
// whoever holds it, while this one cannot be changed by anyone.
#ifndef ASPortCredentialExchange_h
#define ASPortCredentialExchange_h

#import <Foundation/Foundation.h>

@class ASPasswordCredential;

@interface ASPortCredentialExchange : NSObject

/// The credential the extension selected, or nil for a cancellation or a configuration request.
@property (nonatomic, readonly, strong) ASPasswordCredential *credential;
/// The error from -cancelRequestWithError:, or nil when the exchange was not cancelled.
@property (nonatomic, readonly, strong) NSError *error;
/// YES when the exchange ended in -cancelRequestWithError:.
@property (nonatomic, readonly) BOOL cancelled;
/// YES when the exchange ended in -completeExtensionConfigurationRequest.
@property (nonatomic, readonly) BOOL configurationCompleted;
/// YES when the completion handler was asked whether the credential has expired, and what it said.
@property (nonatomic, readonly) BOOL expiryAsked;
/// That handler's answer, recorded because on a device only the system would have had it.
@property (nonatomic, readonly) BOOL expired;

/// The three builders, declared in the header because the context is a different file and cannot see a
/// private extension. They are the ONLY way to make a record, which is what stops a record from
/// claiming an exchange the context did not have: every field is what the completion that created it
/// said, and the flags are set beside the values they accompany rather than by a caller afterwards.
+ (instancetype)exchangeWithCredential:(ASPasswordCredential *)credential
                              expired:(BOOL)expired
                          expiryAsked:(BOOL)expiryAsked;
+ (instancetype)configurationExchange;
+ (instancetype)cancelledExchangeWithError:(NSError *)error;

@end

#endif
