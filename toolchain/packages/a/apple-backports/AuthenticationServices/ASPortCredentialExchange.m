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

@synthesize credential = _credential;
@synthesize error = _error;
@synthesize cancelled = _cancelled;
@synthesize configurationCompleted = _configurationCompleted;
@synthesize expiryAsked = _expiryAsked;
@synthesize expired = _expired;

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
