#import <CoreNFC/CoreNFC.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// The reader sessions of CoreNFC on a device with no NFC radio, as the host's CoreNFC answers them (facts/CoreNFC/NFCReaderSession.md):
// the session is never ready, its initializers answer nil for a delegate that cannot take the session's first callback, and a
// session that is begun is invalidated at once with NFCReaderErrorUnsupportedFeature, on the session's queue.

NSErrorDomain const NFCErrorDomain = @"NFCError";

NSString * const NFCISO15693TagResponseErrorKey = @"ISO15693TagResponseErrorCode";

@interface NFCReaderSession (CharonReaderSession)
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

// A session invalidated before it is begun is never begun: nothing is called after that, as the host measures.
- (void)beginSession
{
    if (_invalidated) {
        return;
    }
    _begun = YES;
    [self charon_reportUnsupported];
}

- (void)invalidateSession
{
    if (!_begun) {
        _invalidated = YES;
        return;
    }
    [self charon_reportUnsupported];
}

// The session has no radio, so it is invalidated with the unsupported-feature error. The block holds the session until the
// callback is made: the framework keeps a session whose callback is due, so an application need not hold it (measured).
- (void)charon_reportUnsupported
{
    dispatch_async(_sessionQueue, ^{
        NSError *error = [NSError errorWithDomain:NFCErrorDomain code:NFCReaderErrorUnsupportedFeature userInfo:nil];
        id delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(readerSession:didInvalidateWithError:)]) {
            [delegate readerSession:self didInvalidateWithError:error];
        }
    });
}

// Keeps the delegate and the queue. A nil queue is the session's own serial queue, which the host also makes.
- (instancetype)initReaderWithDelegate:(id)delegate queue:(dispatch_queue_t)queue
{
    if ((self = [super init])) {
        _delegate = delegate;
        _sessionQueue = queue ?: dispatch_queue_create("org.charon.nfc.session", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

@end

@implementation NFCNDEFReaderSession

// The host answers nil for a nil delegate, and for one that cannot take a message the session reads.
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

// The host answers nil for a nil delegate, and for one that cannot take the session becoming active.
- (instancetype)initWithDelegate:(id<NFCReaderSessionDelegate>)delegate queue:(dispatch_queue_t)queue
{
    if (![delegate respondsToSelector:@selector(readerSessionDidBecomeActive:)]) {
        return nil;
    }
    return [self initReaderWithDelegate:delegate queue:queue];
}

@end
