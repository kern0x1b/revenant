#import "CharonURLSessionMetrics.h"

#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation NSURLSessionTaskTransactionMetrics {
@private
    NSURLRequest *_request;
    NSURLResponse *_response;
    NSDate *_fetchStartDate;
    NSDate *_requestStartDate;
    NSDate *_requestEndDate;
    NSDate *_responseStartDate;
    NSDate *_responseEndDate;
    NSString *_networkProtocolName;
    NSURLSessionTaskMetricsResourceFetchType _resourceFetchType;
    BOOL _finished;
}

@dynamic countOfRequestHeaderBytesSent, countOfRequestBodyBytesSent, countOfRequestBodyBytesBeforeEncoding, countOfResponseHeaderBytesReceived, countOfResponseBodyBytesReceived,
    countOfResponseBodyBytesAfterDecoding, localAddress, localPort, remoteAddress, remotePort, negotiatedTLSProtocolVersion, negotiatedTLSCipherSuite, cellular, expensive, constrained,
    multipath, domainResolutionProtocol;

- (instancetype)initCharonWithRequest:(NSURLRequest *)request fetchType:(NSURLSessionTaskMetricsResourceFetchType)fetchType
{
    if ((self = [super init])) {
        _request = [request copy];
        _resourceFetchType = fetchType;
        _fetchStartDate = [NSDate date];
    }
    return self;
}

- (void)charon_receivedResponse:(NSURLResponse *)response
{
    if (_response || _finished)
        return;
    NSDate *now = [NSDate date];
    _response = [response copy];
    _requestStartDate = _fetchStartDate;
    _requestEndDate = now;
    _responseStartDate = now;
    NSString *scheme = _request.URL.scheme.lowercaseString;
    if (_resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad && ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]))
        _networkProtocolName = @"http/1.1";
}

- (void)charon_finished
{
    if (_finished)
        return;
    _finished = YES;
    if (_response)
        _responseEndDate = [NSDate date];
}

- (BOOL)charon_isFinished
{
    return _finished;
}

- (NSURLRequest *)request { return _request; }
- (NSURLResponse *)response { return _response; }
- (NSDate *)fetchStartDate { return _fetchStartDate; }
- (NSDate *)domainLookupStartDate { return nil; }
- (NSDate *)domainLookupEndDate { return nil; }
- (NSDate *)connectStartDate { return nil; }
- (NSDate *)secureConnectionStartDate { return nil; }
- (NSDate *)secureConnectionEndDate { return nil; }
- (NSDate *)connectEndDate { return nil; }
- (NSDate *)requestStartDate { return _requestStartDate; }
- (NSDate *)requestEndDate { return _requestEndDate; }
- (NSDate *)responseStartDate { return _responseStartDate; }
- (NSDate *)responseEndDate { return _responseEndDate; }
- (NSString *)networkProtocolName { return _networkProtocolName; }
- (BOOL)isProxyConnection { return NO; }
- (BOOL)isReusedConnection { return NO; }
- (NSURLSessionTaskMetricsResourceFetchType)resourceFetchType { return _resourceFetchType; }

@end

@implementation NSURLSessionTaskMetrics {
@private
    NSArray *_transactionMetrics;
    NSDateInterval *_taskInterval;
}

- (instancetype)initCharonWithTransactions:(NSArray<NSURLSessionTaskTransactionMetrics *> *)transactions start:(NSDate *)start end:(NSDate *)end
{
    if ((self = [super init])) {
        _transactionMetrics = [transactions copy];
        _taskInterval = [[NSDateInterval alloc] initWithStartDate:start endDate:end];
    }
    return self;
}

- (NSArray<NSURLSessionTaskTransactionMetrics *> *)transactionMetrics
{
    return _transactionMetrics;
}

- (NSDateInterval *)taskInterval
{
    return _taskInterval;
}

- (NSUInteger)redirectCount
{
    return _transactionMetrics.count ? _transactionMetrics.count - 1 : 0;
}

@end
