#import "RevenantAVContentKey.h"
#import <AVFoundation/AVContentKeySession.h>
#import <Foundation/Foundation.h>

@implementation AVContentKeyResponse {
    RevenantContentKeyResponseKind _kind;
    NSData *_keyData;
    NSData *_initializationVector;
    NSData *_authorizationTokenData;
}

+ (instancetype)contentKeyResponseWithFairPlayStreamingKeyResponseData:(NSData *)keyResponseData
{
    return [[self alloc] initWithKind:RevenantContentKeyResponseKindFairPlay keyData:keyResponseData
                 initializationVector:nil authorizationTokenData:nil];
}

+ (instancetype)contentKeyResponseWithClearKeyData:(NSData *)clearKeyData initializationVector:(NSData *)initializationVector
{
    return [[self alloc] initWithKind:RevenantContentKeyResponseKindClearKey keyData:clearKeyData
                 initializationVector:initializationVector authorizationTokenData:nil];
}

+ (instancetype)contentKeyResponseWithAuthorizationTokenData:(NSData *)authorizationTokenData
{
    return [[self alloc] initWithKind:RevenantContentKeyResponseKindAuthorizationToken keyData:nil
                 initializationVector:nil authorizationTokenData:authorizationTokenData];
}

- (instancetype)initWithKind:(RevenantContentKeyResponseKind)kind keyData:(NSData *)keyData
        initializationVector:(NSData *)initializationVector authorizationTokenData:(NSData *)authorizationTokenData
{
    self = [super init];
    if (self) {
        _kind = kind;
        _keyData = [keyData copy];
        _initializationVector = [initializationVector copy];
        _authorizationTokenData = [authorizationTokenData copy];
    }
    return self;
}

- (RevenantContentKeyResponseKind)revenantKind
{
    return _kind;
}

- (NSData *)revenantKeyData
{
    return _keyData;
}

- (NSData *)revenantInitializationVector
{
    return _initializationVector;
}

- (NSData *)revenantAuthorizationTokenData
{
    return _authorizationTokenData;
}

@end
