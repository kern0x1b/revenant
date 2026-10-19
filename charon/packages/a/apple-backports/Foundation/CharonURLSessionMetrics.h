#import <Foundation/Foundation.h>

@interface NSURLSessionTaskTransactionMetrics (CharonNotes)
/* The only three ways anything ever gets into a transaction's numbers, and the loader is what calls
   them. They are split three ways on purpose: the bytes are said when the connection reports them,
   the interface when the response arrives, and the connection when the session registers it, so a
   later call can never zero a number an earlier one put there. A transaction that has not been told
   anything yet reads corelibs' defaults -- zero, NO, unknown -- which is a different statement from
   being told zero. */
- (void)charon_noteBytesSent:(int64_t)sent
              beforeEncoding:(int64_t)before
                     received:(int64_t)received;
- (void)charon_noteInterfaceFlags:(BOOL)cellular
                         expensive:(BOOL)expensive
                       constrained:(BOOL)constrained
                             proxy:(BOOL)proxy;
- (void)charon_noteConnectionReused:(BOOL)reused;
@end

@interface NSURLSessionTaskTransactionMetrics (CharonSocket)
- (void)charon_noteSocketLocalAddress:(NSString *)address port:(NSNumber *)port
                        remoteAddress:(NSString *)remote remotePort:(NSNumber *)remotePort
                    tlsProtocolVersion:(NSNumber *)version cipherSuite:(NSNumber *)cipher;
@end

@interface NSURLSessionTaskTransactionMetrics (CharonWriting)
- (instancetype)initCharonWithRequest:(NSURLRequest *)request fetchType:(NSURLSessionTaskMetricsResourceFetchType)fetchType;
- (void)charon_receivedResponse:(NSURLResponse *)response;
- (void)charon_finished;
- (BOOL)charon_isFinished;
@end

@interface NSURLSessionTaskMetrics (CharonWriting)
- (instancetype)initCharonWithTransactions:(NSArray<NSURLSessionTaskTransactionMetrics *> *)transactions start:(NSDate *)start end:(NSDate *)end;
@end
