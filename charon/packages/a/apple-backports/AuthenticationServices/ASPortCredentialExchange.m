#import "ASPortCredentialExchange.h"
#import <AuthenticationServices/AuthenticationServices.h>

@interface ASPortCredentialExchange ()
@property (nonatomic, readwrite, strong) ASPasswordCredential *credential;
@property (nonatomic, readwrite, strong) NSError *error;
@property (nonatomic, readwrite) BOOL cancelled;
@property (nonatomic, readwrite) BOOL configurationCompleted;
@property (nonatomic, readwrite) BOOL expiryAsked;
@property (nonatomic, readwrite) BOOL expired;
@end

@implementation ASPortCredentialExchange

// Named, not auto-synthesized: the library build refuses a property the compiler would synthesize on its
// own (-Werror=objc-missing-property-synthesis).
@synthesize credential = _credential;
@synthesize error = _error;
@synthesize cancelled = _cancelled;
@synthesize configurationCompleted = _configurationCompleted;
@synthesize expiryAsked = _expiryAsked;
@synthesize expired = _expired;

// The context builds one of these per completion, with the values it just recorded. There is no other
// way to make one, so a record cannot claim an exchange the context did not have: every field is what
// the completion that created it actually said, and the flags are set from the same statement as the
// value they accompany rather than by a caller afterwards.
+ (instancetype)exchangeWithCredential:(ASPasswordCredential *)credential
                              expired:(BOOL)expired
                            expiryAsked:(BOOL)expiryAsked
{
    ASPortCredentialExchange *exchange = [[self alloc] init];
    exchange.credential = credential;
    exchange.expired = expired;
    exchange.expiryAsked = expiryAsked;
    return exchange;
}

+ (instancetype)configurationExchange
{
    ASPortCredentialExchange *exchange = [[self alloc] init];
    exchange.configurationCompleted = YES;
    return exchange;
}

+ (instancetype)cancelledExchangeWithError:(NSError *)error
{
    ASPortCredentialExchange *exchange = [[self alloc] init];
    exchange.error = error;
    exchange.cancelled = YES;
    return exchange;
}

@end
