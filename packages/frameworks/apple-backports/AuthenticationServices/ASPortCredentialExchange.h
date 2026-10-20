#ifndef ASPortCredentialExchange_h
#define ASPortCredentialExchange_h

#import <Foundation/Foundation.h>

@class ASPasswordCredential;

@interface ASPortCredentialExchange : NSObject

@property (nonatomic, readonly, strong) ASPasswordCredential *credential;
@property (nonatomic, readonly, strong) NSError *error;
@property (nonatomic, readonly) BOOL cancelled;
@property (nonatomic, readonly) BOOL configurationCompleted;
@property (nonatomic, readonly) BOOL expiryAsked;
@property (nonatomic, readonly) BOOL expired;

+ (instancetype)exchangeWithCredential:(ASPasswordCredential *)credential
                              expired:(BOOL)expired
                          expiryAsked:(BOOL)expiryAsked;
+ (instancetype)configurationExchange;
+ (instancetype)cancelledExchangeWithError:(NSError *)error;

@end

#endif
