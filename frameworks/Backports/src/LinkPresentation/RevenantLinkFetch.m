#import "RevenantLinkPresentation.h"

@implementation RevenantLinkFetch {
    NSURLRequest *_request;
    NSURLConnection *_connection;
    NSMutableData *_data;
    NSURLResponse *_response;
    void (^_completion)(NSData *, NSURLResponse *, NSError *);
}

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if ((self = [super init])) {
        _request = [request copy];
    }
    return self;
}

- (void)startWithCompletion:(void (^)(NSData *, NSURLResponse *, NSError *))completion
{
    _completion = [completion copy];
    _data = [NSMutableData data];
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self startImmediately:YES];
}

- (void)cancel
{
    [_connection cancel];
    [self finishWithData:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
}

- (void)finishWithData:(NSData *)data error:(NSError *)error
{
    void (^completion)(NSData *, NSURLResponse *, NSError *) = _completion;
    _completion = nil;
    _connection = nil;
    if (completion) {
        completion(data, _response, error);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _response = response;
    [_data setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self finishWithData:_data error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self finishWithData:nil error:error];
}

@end
