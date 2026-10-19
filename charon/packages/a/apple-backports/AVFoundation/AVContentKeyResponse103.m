// AVContentKeyResponse103.m - AVContentKeyResponse as of 10.3, with its three factories as they came: FairPlay
// Streaming key response data (10.3), clear key data with its initialization vector (11.0) and authorization token
// data (13.0). A response is the answer an application gives a content key request. Its header declares no property,
// so an application never reads one back; the session reads it when the response is processed, through the internal
// accessors in CharonAVContentKey.h, and the session (AVContentKeySession103.m) decides what the response does.
//
// Measured by tests/backports/host/avf-contentkey-values: each factory returns an object of the class for any data it
// is given, nil included, and refuses nothing. The host builds one private subclass per factory; the port builds one
// class and records the kind of the factory that made it, which no declared member exposes.
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

// The values are kept as given, copied so a caller's mutable data changes nothing already made. A nil or empty value is
// kept as it is: the host refuses none of them at the factory. The session refuses what it cannot use, when it takes the
// response (AVContentKeySession103.m).
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
