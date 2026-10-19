#import "CharonAVContentKey.h"
#import <AVFoundation/AVContentKeySession.h>
#import <Foundation/Foundation.h>

@implementation AVContentKeyResponse {
    CharonContentKeyResponseKind _kind;
    NSData *_keyData;
    NSData *_initializationVector;
    NSData *_authorizationTokenData;
}

+ (instancetype)contentKeyResponseWithFairPlayStreamingKeyResponseData:(NSData *)keyResponseData
{
    return [[self alloc] initWithKind:CharonContentKeyResponseKindFairPlay keyData:keyResponseData
                 initializationVector:nil authorizationTokenData:nil];
}

+ (instancetype)contentKeyResponseWithClearKeyData:(NSData *)clearKeyData initializationVector:(NSData *)initializationVector
{
    return [[self alloc] initWithKind:CharonContentKeyResponseKindClearKey keyData:clearKeyData
                 initializationVector:initializationVector authorizationTokenData:nil];
}

+ (instancetype)contentKeyResponseWithAuthorizationTokenData:(NSData *)authorizationTokenData
{
    return [[self alloc] initWithKind:CharonContentKeyResponseKindAuthorizationToken keyData:nil
                 initializationVector:nil authorizationTokenData:authorizationTokenData];
}

- (instancetype)initWithKind:(CharonContentKeyResponseKind)kind keyData:(NSData *)keyData
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

- (CharonContentKeyResponseKind)charonKind
{
    return _kind;
}

- (NSData *)charonKeyData
{
    return _keyData;
}

- (NSData *)charonInitializationVector
{
    return _initializationVector;
}

- (NSData *)charonAuthorizationTokenData
{
    return _authorizationTokenData;
}

@end
