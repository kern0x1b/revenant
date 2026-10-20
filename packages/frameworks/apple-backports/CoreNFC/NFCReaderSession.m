#import <CoreNFC/CoreNFC.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSErrorDomain const NFCErrorDomain = @"NFCError";

NSString * const NFCISO15693TagResponseErrorKey = @"ISO15693TagResponseErrorCode";

@interface NFCReaderSession (RevenantReaderSession)
- (instancetype)initReaderWithDelegate:(id)delegate queue:(dispatch_queue_t)queue;
@end

@implementation NFCReaderSession {
    __weak id _delegate;
    dispatch_queue_t _sessionQueue;
    NSString *_alertMessage;
    BOOL _begun;
    BOOL _invalidated;
}

+ (BOOL)readingAvailable
{
    return NO;
}

- (BOOL)isReady
{
    return NO;
}

- (id)delegate
{
    return _delegate;
}

- (dispatch_queue_t)sessionQueue
{
    return _sessionQueue;
}

- (NSString *)alertMessage
{
    return _alertMessage;
}

- (void)setAlertMessage:(NSString *)alertMessage
{
    _alertMessage = [alertMessage copy];
}

- (void)beginSession
{
    if (_invalidated) {
        return;
    }
    _begun = YES;
    [self revenant_reportUnsupported];
}

- (void)invalidateSession
{
    if (!_begun) {
        _invalidated = YES;
        return;
    }
    [self revenant_reportUnsupported];
}

- (void)revenant_reportUnsupported
{
    dispatch_async(_sessionQueue, ^{
        NSError *error = [NSError errorWithDomain:NFCErrorDomain code:NFCReaderErrorUnsupportedFeature userInfo:nil];
        id delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(readerSession:didInvalidateWithError:)]) {
            [delegate readerSession:self didInvalidateWithError:error];
        }
    });
}

- (instancetype)initReaderWithDelegate:(id)delegate queue:(dispatch_queue_t)queue
{
    if ((self = [super init])) {
        _delegate = delegate;
        _sessionQueue = queue ?: dispatch_queue_create("org.revenant.nfc.session", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

@end

@implementation NFCNDEFReaderSession

- (instancetype)initWithDelegate:(id<NFCNDEFReaderSessionDelegate>)delegate
                           queue:(dispatch_queue_t)queue
        invalidateAfterFirstRead:(BOOL)invalidateAfterFirstRead
{
    if (![delegate respondsToSelector:@selector(readerSession:didDetectNDEFs:)]) {
        return nil;
    }
    return [self initReaderWithDelegate:delegate queue:queue];
}

@end

@implementation NFCISO15693ReaderSession

- (instancetype)initWithDelegate:(id<NFCReaderSessionDelegate>)delegate queue:(dispatch_queue_t)queue
{
    if (![delegate respondsToSelector:@selector(readerSessionDidBecomeActive:)]) {
        return nil;
    }
    return [self initReaderWithDelegate:delegate queue:queue];
}

@end
