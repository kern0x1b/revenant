#import "RevenantAVContentKey.h"
#import <AVFoundation/AVContentKeySession.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface AVContentKeySession ()
- (void)revenant_failRequest:(AVContentKeyRequest *)request error:(NSError *)error;
- (void)revenant_acceptRequest:(AVContentKeyRequest *)request;
- (void)revenant_succeedRequest:(AVContentKeyRequest *)request keyData:(NSData *)keyData
         initializationVector:(NSData *)initializationVector;
@end

@interface AVContentKeyRequest ()
- (instancetype)initWithSession:(AVContentKeySession *)session identifier:(id)identifier
             initializationData:(NSData *)initializationData options:(NSDictionary<NSString *, id> *)options;
- (void)revenant_finishWithStatus:(AVContentKeyRequestStatus)status error:(NSError *)error;
@end

static BOOL RevenantClearKeyVectorIsAccepted(NSUInteger length)
{
    return length == 8 || length == 16;
}

static NSError *RevenantClearKeyVectorError(void)
{
    return [NSError errorWithDomain:@"CoreMediaErrorDomain" code:-12160 userInfo:nil];
}

static NSError *RevenantResponseRefusedError(void)
{
    return [NSError errorWithDomain:@"CoreMediaErrorDomain" code:-12158 userInfo:nil];
}

static BOOL RevenantIsSupportedKeySystem(NSString *keySystem)
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

- (AVContentKey *)contentKey
{
    return nil;
}

- (void)revenant_finishWithStatus:(AVContentKeyRequestStatus)status error:(NSError *)error
{
    _status = status;
    _error = error;
}

- (void)processContentKeyResponse:(AVContentKeyResponse *)response
{
    if (_status != AVContentKeyRequestStatusRequestingResponse) return;
    AVContentKeySession *session = _session;
    if ([_keySystem isEqualToString:AVContentKeySystemFairPlayStreaming]) {
        [session revenant_failRequest:self error:RevenantResponseRefusedError()];
        return;
    }
    if ([_keySystem isEqualToString:AVContentKeySystemClearKey]) {
        if (response.revenantKind != RevenantContentKeyResponseKindClearKey) {
            [session revenant_failRequest:self error:RevenantResponseRefusedError()];
            return;
        }
        NSUInteger vectorLength = response.revenantInitializationVector.length;
        if (!RevenantClearKeyVectorIsAccepted(vectorLength)) {
            [session revenant_failRequest:self error:RevenantClearKeyVectorError()];
            return;
        }
        [session revenant_succeedRequest:self keyData:response.revenantKeyData
                  initializationVector:response.revenantInitializationVector];
        return;
    }
    if (response.revenantKind != RevenantContentKeyResponseKindAuthorizationToken) {
        [session revenant_failRequest:self error:RevenantResponseRefusedError()];
        return;
    }
    [session revenant_acceptRequest:self];
}

- (void)processContentKeyResponseError:(NSError *)error
{
    if (_status != AVContentKeyRequestStatusRequestingResponse) return;
    [_session revenant_failRequest:self error:error];
}

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

- (BOOL)respondByRequestingPersistableContentKeyRequestAndReturnError:(NSError **)outError
{
    [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeyRequest respondByRequestingPersistableContentKeyRequestAndReturnError:] %@ does not support key persistence", _keySystem];
    return NO;
}

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

+ (instancetype)revenant_sessionWithKeySystem:(AVContentKeySystem)keySystem storageURL:(NSURL *)storageURL
{
    if (!RevenantIsSupportedKeySystem(keySystem)) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVContentKeySession initWithKeySystem:storageDirectoryAtURL:legacyWebKitCompatibilityMode:] input keySystem is not supported"];
    }
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
    return [self revenant_sessionWithKeySystem:keySystem storageURL:nil];
}

+ (instancetype)contentKeySessionWithKeySystem:(AVContentKeySystem)keySystem storageDirectoryAtURL:(NSURL *)storageURL
{
    return [self revenant_sessionWithKeySystem:keySystem storageURL:storageURL];
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
            void (*sendBatch)(id, SEL, id, id, id) = (void (*)(id, SEL, id, id, id))objc_msgSend;
            sendBatch(delegate, @selector(contentKeySession:didProvideContentKeyRequests:forInitializationData:), self, @[request], nil);
        } else if ([delegate respondsToSelector:@selector(contentKeySession:didProvideContentKeyRequest:)]) {
            [delegate contentKeySession:self didProvideContentKeyRequest:request];
        }
    });
}

- (void)revenant_failRequest:(AVContentKeyRequest *)request error:(NSError *)error
{
    [request revenant_finishWithStatus:AVContentKeyRequestStatusFailed error:error];
    id<AVContentKeySessionDelegate> delegate = _delegate;
    dispatch_async(_delegateQueue ?: dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(contentKeySession:contentKeyRequest:didFailWithError:)]) {
            [delegate contentKeySession:self contentKeyRequest:request didFailWithError:error];
        }
    });
}

- (void)revenant_acceptRequest:(AVContentKeyRequest *)request
{
    [request revenant_finishWithStatus:AVContentKeyRequestStatusReceivedResponse error:nil];
    id<AVContentKeySessionDelegate> delegate = _delegate;
    dispatch_async(_delegateQueue ?: dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(contentKeySession:contentKeyRequestDidSucceed:)]) {
            [delegate contentKeySession:self contentKeyRequestDidSucceed:request];
        }
    });
}

- (void)revenant_succeedRequest:(AVContentKeyRequest *)request keyData:(NSData *)keyData
         initializationVector:(NSData *)initializationVector
{
    [request revenant_finishWithStatus:AVContentKeyRequestStatusReceivedResponse error:nil];
    AVContentKey *key = [AVContentKey revenant_contentKeyWithSpecifier:request.contentKeySpecifier keyData:keyData
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

- (void)expire
{
}

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

+ (NSArray<NSData *> *)pendingExpiredSessionReportsWithAppIdentifier:(NSData *)appIdentifier storageDirectoryAtURL:(NSURL *)storageURL
{
    return @[];
}

+ (void)removePendingExpiredSessionReports:(NSArray<NSData *> *)sessionReports withAppIdentifier:(NSData *)appIdentifier
                     storageDirectoryAtURL:(NSURL *)storageURL
{
}

- (NSData *)contentProtectionSessionIdentifier
{
    return _protectionSessionIdentifier;
}

@end
