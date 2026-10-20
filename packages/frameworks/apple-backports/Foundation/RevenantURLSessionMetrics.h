#import <Foundation/Foundation.h>

@interface NSURLSessionTaskTransactionMetrics (RevenantNotes)
- (void)revenant_noteBytesSent:(int64_t)sent
              beforeEncoding:(int64_t)before
                     received:(int64_t)received;
- (void)revenant_noteInterfaceFlags:(BOOL)cellular
                         expensive:(BOOL)expensive
                       constrained:(BOOL)constrained
                             proxy:(BOOL)proxy;
- (void)revenant_noteConnectionReused:(BOOL)reused;
@end

@interface NSURLSessionTaskTransactionMetrics (RevenantSocket)
- (void)revenant_noteSocketLocalAddress:(NSString *)address port:(NSNumber *)port
                        remoteAddress:(NSString *)remote remotePort:(NSNumber *)remotePort
                    tlsProtocolVersion:(NSNumber *)version cipherSuite:(NSNumber *)cipher;
@end

@interface NSURLSessionTaskTransactionMetrics (RevenantWriting)
- (instancetype)initRevenantWithRequest:(NSURLRequest *)request fetchType:(NSURLSessionTaskMetricsResourceFetchType)fetchType;
- (void)revenant_receivedResponse:(NSURLResponse *)response;
- (void)revenant_finished;
- (BOOL)revenant_isFinished;
@end

@interface NSURLSessionTaskMetrics (RevenantWriting)
- (instancetype)initRevenantWithTransactions:(NSArray<NSURLSessionTaskTransactionMetrics *> *)transactions start:(NSDate *)start end:(NSDate *)end;
@end
