// AVContentKeySession103.m - AVContentKeySession and AVContentKeyRequest as of 10.3: the session that asks an application
// for a content key, the request it sends the application, and the recipients that receive the key a response gives.
// The key systems carried are the three the host has: ClearKey (11.0), FairPlay Streaming (10.3) and the authorization
// token system (13.0). The host's behaviour is measured by tests/backports/host/avf-contentkey-session, which asks the
// same questions of macOS's AVFoundation and of this file renamed; facts/AVFoundation/ContentKeySession.md says what is
// measured, what is not, and what the port does not carry.
//
// What the host does, measured:
//   * a request is delivered to the delegate only when the initialization data is nil; non-nil data made no callback
//     (probe case C3). A delegate that implements -contentKeySession:didProvideContentKeyRequests:forInitializationData:
//     gets that callback, for nil data too, and not the singular one.
//   * a request starts RequestingResponse (0). An accepted clear key response makes it ReceivedResponse (1), and then the
//     delegate's contentKeyRequestDidSucceed and each recipient's key callback happen, in an order the host varies run to
//     run. A response the host cannot use makes it Failed (5), and the delegate's didFailWithError is called with the
//     host's error, whose shape the host also varies run to run (facts/AVFoundation/ContentKeySession.md).
//   * -processContentKeyResponseError: makes the request Failed with the error given, and the delegate hears that error.
//   * a FairPlay request's options carry ProtocolVersionsKey = [1]; the other systems' requests carry none.
#import "CharonAVContentKey.h"
#import <AVFoundation/AVContentKeySession.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface AVContentKeySession ()
- (void)charon_failRequest:(AVContentKeyRequest *)request error:(NSError *)error;
- (void)charon_acceptRequest:(AVContentKeyRequest *)request;
- (void)charon_succeedRequest:(AVContentKeyRequest *)request keyData:(NSData *)keyData
         initializationVector:(NSData *)initializationVector;
@end

@interface AVContentKeyRequest ()
- (instancetype)initWithSession:(AVContentKeySession *)session identifier:(id)identifier
             initializationData:(NSData *)initializationData options:(NSDictionary<NSString *, id> *)options;
- (void)charon_finishWithStatus:(AVContentKeyRequestStatus)status error:(NSError *)error;
@end

// The clear key vectors the host accepts: 8 and 16 bytes, the two lengths the port's CTR and CBC modes take (measured: a
// zero-filled 16-byte key and a zero-filled vector of each length from 0 to 34, in ten host runs; 8 and 16 were accepted
// in every run and no other length was). Any key length is accepted at the response. A vector longer than 34 bytes is
// not measured and is refused the same way.
static BOOL CharonClearKeyVectorIsAccepted(NSUInteger length)
{
    return length == 8 || length == 16;
}

// The refusal of a vector the host does not take. The host's error is not stable across its runs: CoreMedia -12160 in
// about half, and AVFoundation -11800 wrapping NSOSStatus -12160 in the rest (facts/AVFoundation/ContentKeySession.md). The
// port gives the CoreMedia one, the shape the host gave most often.
static NSError *CharonClearKeyVectorError(void)
{
    return [NSError errorWithDomain:@"CoreMediaErrorDomain" code:-12160 userInfo:nil];
}

// The error the host gives a FairPlay response it cannot use, and a response of the wrong kind for the key system. The
// host's shape is not stable: CoreMedia -12158 in 17 of 20 answers to the same payload, and AVFoundation -11800 wrapping
// NSOSStatus -12158 in the rest. The port gives the CoreMedia one, the shape the host gave most often.
static NSError *CharonResponseRefusedError(void)
{
    return [NSError errorWithDomain:@"CoreMediaErrorDomain" code:-12158 userInfo:nil];
}

// The three key systems the host's session takes; any other name is refused with the host's own reason.
static BOOL CharonIsSupportedKeySystem(NSString *keySystem)
{
    return [keySystem isEqualToString:AVContentKeySystemClearKey] || [keySystem isEqualToString:AVContentKeySystemFairPlayStreaming]
        || [keySystem isEqualToString:AVContentKeySystemAuthorizationToken];
}

#pragma mark - AVContentKeyRequest

@implementation AVContentKeyRequest {
    __weak AVContentKeySession *_session;
    AVContentKeyRequestStatus _status;
    NSError *_error;
    id _identifier;
    NSData *_initializationData;
    NSDictionary<NSString *, id> *_options;
    AVContentKeySystem _keySystem;
}

- (instancetype)initWithSession:(AVContentKeySession *)session identifier:(id)identifier
             initializationData:(NSData *)initializationData options:(NSDictionary<NSString *, id> *)options
{
    self = [super init];
    if (self) {
        _session = session;
        _status = AVContentKeyRequestStatusRequestingResponse;
        _identifier = [identifier copy];
        _initializationData = [initializationData copy];
        _options = [options copy];
        _keySystem = [session.keySystem copy];
    }
    return self;
}

- (AVContentKeyRequestStatus)status
{
    return _status;
}

- (NSError *)error
{
    return _error;
}

- (id)identifier
{
    return _identifier;
}

- (NSData *)initializationData
{
    return _initializationData;
}

- (NSDictionary<NSString *, id> *)options
{
    return _options;
}

// Measured NO for a clear key request and for a FairPlay request with nil initialization data; the port makes no request
// persistable, since the persistable path is not carried (facts/AVFoundation/ContentKeySession.md).
- (BOOL)canProvidePersistableContentKey
{
    return NO;
}

- (BOOL)renewsExpiringResponseData
{
    return NO;
}

- (AVContentKeySpecifier *)contentKeySpecifier
{
    return [AVContentKeySpecifier contentKeySpecifierForKeySystem:_keySystem identifier:_identifier options:_options];
}

// The key is handed to the recipients, not returned here: the host answers nil for the request (measured, after an
// accepted clear key response).
- (AVContentKey *)contentKey
{
    return nil;
}

- (void)charon_finishWithStatus:(AVContentKeyRequestStatus)status error:(NSError *)error
{
    _status = status;
    _error = error;
}

- (void)processContentKeyResponse:(AVContentKeyResponse *)response
{
    if (_status != AVContentKeyRequestStatusRequestingResponse) return;
    AVContentKeySession *session = _session;
    if ([_keySystem isEqualToString:AVContentKeySystemFairPlayStreaming]) {
        // No FairPlay Streaming decryptor on 6.1.3: every FairPlay response is one this port cannot use.
        [session charon_failRequest:self error:CharonResponseRefusedError()];
        return;
    }
    if ([_keySystem isEqualToString:AVContentKeySystemClearKey]) {
        // A response of another kind is refused with the FairPlay error: the host's answer to a mismatch is not measured.
        if (response.charonKind != CharonContentKeyResponseKindClearKey) {
            [session charon_failRequest:self error:CharonResponseRefusedError()];
            return;
        }
        NSUInteger vectorLength = response.charonInitializationVector.length;
        if (!CharonClearKeyVectorIsAccepted(vectorLength)) {
            [session charon_failRequest:self error:CharonClearKeyVectorError()];
            return;
        }
        [session charon_succeedRequest:self keyData:response.charonKeyData
                  initializationVector:response.charonInitializationVector];
        return;
    }
    // The authorization token system: a token response is accepted; no recipient is given a key for it (not measured).
    if (response.charonKind != CharonContentKeyResponseKindAuthorizationToken) {
        [session charon_failRequest:self error:CharonResponseRefusedError()];
        return;
    }
    [session charon_acceptRequest:self];
}

- (void)processContentKeyResponseError:(NSError *)error
{
    if (_status != AVContentKeyRequestStatusRequestingResponse) return;
    [_session charon_failRequest:self error:error];
}

// The request data a streaming FairPlay key request is made of needs the FairPlay key services, which this port does not
// carry. The answer is the one the host gives when those services are missing: AVFoundation -11800, with the underlying
// status the host gives for each key system (measured on macOS: FairPlay -42650, ClearKey -19154). The token system's
// underlying status is not measured; it is the ClearKey one here.
- (void)makeStreamingContentKeyRequestDataForApp:(NSData *)appIdentifier contentIdentifier:(NSData *)contentIdentifier
                                         options:(NSDictionary<NSString *, id> *)options
                               completionHandler:(void (^)(NSData *, NSError *))handler
{
    NSInteger underlyingCode = [_keySystem isEqualToString:AVContentKeySystemFairPlayStreaming] ? -42650 : -19154;
    NSError *underlying = [NSError errorWithDomain:NSOSStatusErrorDomain code:underlyingCode userInfo:nil];
    NSError *error = [NSError errorWithDomain:AVFoundationErrorDomain code:-11800 userInfo:@{
        NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"An unknown error occurred (%ld)", (long)underlyingCode],
        NSLocalizedDescriptionKey: @"The operation could not be completed",
        NSUnderlyingErrorKey: underlying,
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(nil, error);
    });
}

// Persistence is refused on the ClearKey system with the host's own reason (measured). The port refuses it on every
// system: the FairPlay answer is not measured on the host, and no persistable key is carried.
- (BOOL)respondByRequestingPersistableContentKeyRequestAndReturnError:(NSError **)outError
{
    [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeyRequest respondByRequestingPersistableContentKeyRequestAndReturnError:] %@ does not support key persistence", _keySystem];
    return NO;
}

// The form the 16.4 header declares as deprecated for iOS 10.3 to 11.2: the same refusal, with no error to return.
- (void)respondByRequestingPersistableContentKeyRequest
{
    [self respondByRequestingPersistableContentKeyRequestAndReturnError:NULL];
}

@end

#pragma mark - AVContentKeySession

@implementation AVContentKeySession {
    AVContentKeySystem _keySystem;
    NSURL *_storageURL;
    __weak id<AVContentKeySessionDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    NSMutableArray *_recipients;
    NSData *_protectionSessionIdentifier;
}

+ (instancetype)charon_sessionWithKeySystem:(AVContentKeySystem)keySystem storageURL:(NSURL *)storageURL
{
    if (!CharonIsSupportedKeySystem(keySystem)) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeySession initWithKeySystem:storageDirectoryAtURL:legacyWebKitCompatibilityMode:] input keySystem is not supported"];
    }
    // Only the FairPlay system keeps a storage directory (measured: ClearKey and the token system refuse one, with their
    // own reason). The directory is recorded as given; this port writes nothing into it (facts/AVFoundation/ContentKeySession.md).
    if (storageURL && ![keySystem isEqualToString:AVContentKeySystemFairPlayStreaming]) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeySession initWithKeySystem:storageDirectoryAtURL:legacyWebKitCompatibilityMode:] %@ does not support storage URL", keySystem];
    }
    AVContentKeySession *session = [[self alloc] init];
    session->_keySystem = [keySystem copy];
    session->_storageURL = storageURL;
    session->_recipients = [NSMutableArray array];
    uint8_t identifier[16];
    arc4random_buf(identifier, sizeof identifier);
    session->_protectionSessionIdentifier = [NSData dataWithBytes:identifier length:sizeof identifier];
    return session;
}

+ (instancetype)contentKeySessionWithKeySystem:(AVContentKeySystem)keySystem
{
    return [self charon_sessionWithKeySystem:keySystem storageURL:nil];
}

+ (instancetype)contentKeySessionWithKeySystem:(AVContentKeySystem)keySystem storageDirectoryAtURL:(NSURL *)storageURL
{
    return [self charon_sessionWithKeySystem:keySystem storageURL:storageURL];
}

- (AVContentKeySystem)keySystem
{
    return _keySystem;
}

- (NSURL *)storageURL
{
    return _storageURL;
}

- (id<AVContentKeySessionDelegate>)delegate
{
    return _delegate;
}

- (dispatch_queue_t)delegateQueue
{
    return _delegateQueue;
}

- (void)setDelegate:(id<AVContentKeySessionDelegate>)delegate queue:(dispatch_queue_t)delegateQueue
{
    _delegate = delegate;
    _delegateQueue = delegateQueue;
}

- (NSArray<id<AVContentKeyRecipient>> *)contentKeyRecipients
{
    return [_recipients copy];
}

- (void)addContentKeyRecipient:(id<AVContentKeyRecipient>)recipient
{
    [_recipients addObject:recipient];
}

- (void)removeContentKeyRecipient:(id<AVContentKeyRecipient>)recipient
{
    [_recipients removeObjectIdenticalTo:recipient];
}

// A request with initialization data produces no callback on the host (measured), so none is made here. A request with nil
// data goes to the delegate's batch callback when it has one, and to its singular callback otherwise. Callbacks run on the
// delegate's queue; the main queue when none was given (the host's queue rule for nil is not measured).
- (void)processContentKeyRequestWithIdentifier:(id)identifier initializationData:(NSData *)initializationData
                                       options:(NSDictionary<NSString *, id> *)options
{
    if (initializationData) return;
    NSMutableDictionary *requestOptions = [NSMutableDictionary dictionaryWithDictionary:options ?: @{}];
    if ([_keySystem isEqualToString:AVContentKeySystemFairPlayStreaming] && !requestOptions[AVContentKeyRequestProtocolVersionsKey]) {
        requestOptions[AVContentKeyRequestProtocolVersionsKey] = @[@1];
    }
    AVContentKeyRequest *request = [[AVContentKeyRequest alloc] initWithSession:self identifier:identifier
                                                             initializationData:nil options:requestOptions];
    id<AVContentKeySessionDelegate> delegate = _delegate;
    dispatch_async(_delegateQueue ?: dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(contentKeySession:didProvideContentKeyRequests:forInitializationData:)]) {
            // The 16.4 protocol does not declare this selector (iOS 17.4 in the 26.2 header), so the send is typed by hand.
            void (*sendBatch)(id, SEL, id, id, id) = (void (*)(id, SEL, id, id, id))objc_msgSend;
            sendBatch(delegate, @selector(contentKeySession:didProvideContentKeyRequests:forInitializationData:), self, @[request], nil);
        } else if ([delegate respondsToSelector:@selector(contentKeySession:didProvideContentKeyRequest:)]) {
            [delegate contentKeySession:self didProvideContentKeyRequest:request];
        }
    });
}

- (void)charon_failRequest:(AVContentKeyRequest *)request error:(NSError *)error
{
    [request charon_finishWithStatus:AVContentKeyRequestStatusFailed error:error];
    id<AVContentKeySessionDelegate> delegate = _delegate;
    dispatch_async(_delegateQueue ?: dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(contentKeySession:contentKeyRequest:didFailWithError:)]) {
            [delegate contentKeySession:self contentKeyRequest:request didFailWithError:error];
        }
    });
}

- (void)charon_acceptRequest:(AVContentKeyRequest *)request
{
    [request charon_finishWithStatus:AVContentKeyRequestStatusReceivedResponse error:nil];
    id<AVContentKeySessionDelegate> delegate = _delegate;
    dispatch_async(_delegateQueue ?: dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(contentKeySession:contentKeyRequestDidSucceed:)]) {
            [delegate contentKeySession:self contentKeyRequestDidSucceed:request];
        }
    });
}

// An accepted clear key response: the request is ReceivedResponse, the delegate hears that it succeeded, and then each
// recipient that may require keys is given the key for the request's specifier. The host's order of those two varies
// run to run (five runs: the delegate first in three); the port gives the delegate first.
- (void)charon_succeedRequest:(AVContentKeyRequest *)request keyData:(NSData *)keyData
         initializationVector:(NSData *)initializationVector
{
    [request charon_finishWithStatus:AVContentKeyRequestStatusReceivedResponse error:nil];
    AVContentKey *key = [AVContentKey charon_contentKeyWithSpecifier:request.contentKeySpecifier keyData:keyData
                                                initializationVector:initializationVector];
    id<AVContentKeySessionDelegate> delegate = _delegate;
    NSArray *recipients = [_recipients copy];
    dispatch_async(_delegateQueue ?: dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(contentKeySession:contentKeyRequestDidSucceed:)]) {
            [delegate contentKeySession:self contentKeyRequestDidSucceed:request];
        }
        for (id candidate in recipients) {
            if (![candidate respondsToSelector:@selector(contentKeySession:didProvideContentKey:)]) continue;
            if (![candidate respondsToSelector:@selector(mayRequireContentKeysForMediaDataProcessing)] ||
                ![candidate mayRequireContentKeysForMediaDataProcessing]) continue;
            [candidate contentKeySession:self didProvideContentKey:key];
        }
    });
}

// -expire answers without effect in the measured cases (no persistable key was ever made): the host's effect on a
// persistable key is not measured on this key system, so nothing is expired here.
- (void)expire
{
}

// Persistence, renewal, secure tokens and invalidation are refused by the ClearKey and token systems on the host, each
// with the host's own reason (measured, the ClearKey system). The FairPlay system's persistence is not carried: its
// refusal here is the same text, and that answer is not measured on the host.
- (void)renewExpiringResponseDataForContentKeyRequest:(AVContentKeyRequest *)contentKeyRequest
{
    [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeySession renewExpiringResponseDataForContentKeyRequest:] %@ does not support key renewal", _keySystem];
}

- (void)makeSecureTokenForExpirationDateOfPersistableContentKey:(NSData *)persistableContentKey
                                              completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeySession makeSecureTokenForExpirationDateOfPersistableContentKey:completionHandler:] %@ does not support this operation", _keySystem];
}

- (void)invalidatePersistableContentKey:(NSData *)persistableContentKey options:(NSDictionary<NSString *, id> *)options
                      completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeySession invalidatePersistableContentKey:options:completionHandler:] %@ does not support this operation", _keySystem];
}

- (void)invalidateAllPersistableContentKeysForApp:(NSData *)appIdentifier options:(NSDictionary<NSString *, id> *)options
                                completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeySession invalidateAllPersistableContentKeysForApp:options:completionHandler:] %@ does not support this operation", _keySystem];
}

// The storage's expired-session reports: none is ever written by this port, so none is pending, and removing one is a
// no-op (measured: an empty storage directory answers no reports, and the removal returns).
+ (NSArray<NSData *> *)pendingExpiredSessionReportsWithAppIdentifier:(NSData *)appIdentifier storageDirectoryAtURL:(NSURL *)storageURL
{
    return @[];
}

+ (void)removePendingExpiredSessionReports:(NSArray<NSData *> *)sessionReports withAppIdentifier:(NSData *)appIdentifier
                     storageDirectoryAtURL:(NSURL *)storageURL
{
}

// Sixteen random bytes, made once for the session, as the host gives (measured: 16 bytes, different for each session).
- (NSData *)contentProtectionSessionIdentifier
{
    return _protectionSessionIdentifier;
}

@end
