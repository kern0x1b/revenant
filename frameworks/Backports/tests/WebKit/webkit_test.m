#import "../Foundation/check.h"
#import <WebKit/WebKit.h>
#import "../../src/WebKit/RevenantURLSchemes.h"

@interface RevenantRecordingClient : NSObject <NSURLProtocolClient>

@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic) BOOL finished;
@property (nonatomic, strong) NSError *error;

@end

@implementation RevenantRecordingClient

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveResponse:(NSURLResponse *)response cacheStoragePolicy:(NSURLCacheStoragePolicy)policy
{
    self.response = response;
}

- (void)URLProtocol:(NSURLProtocol *)protocol didLoadData:(NSData *)data
{
    if (!self.data) {
        self.data = [NSMutableData data];
    }
    [self.data appendData:data];
}

- (void)URLProtocolDidFinishLoading:(NSURLProtocol *)protocol
{
    self.finished = YES;
}

- (void)URLProtocol:(NSURLProtocol *)protocol didFailWithError:(NSError *)error
{
    self.error = error;
}

- (void)URLProtocol:(NSURLProtocol *)protocol wasRedirectedToRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
}

- (void)URLProtocol:(NSURLProtocol *)protocol cachedResponseIsValid:(NSCachedURLResponse *)cachedResponse
{
}

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
}

- (void)URLProtocol:(NSURLProtocol *)protocol didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
}

@end

@interface RevenantSchemeHandler : NSObject <WKURLSchemeHandler>

@property (nonatomic) NSUInteger starts;
@property (nonatomic) NSUInteger stops;

@end

@implementation RevenantSchemeHandler

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask
{
    self.starts++;
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:urlSchemeTask.request.URL MIMEType:@"text/plain" expectedContentLength:5 textEncodingName:@"utf-8"];
    [urlSchemeTask didReceiveResponse:response];
    [urlSchemeTask didReceiveData:[@"hello" dataUsingEncoding:NSUTF8StringEncoding]];
    [urlSchemeTask didFinish];
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask
{
    self.stops++;
}

@end

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class snapshotClass = NSClassFromString(@"WKSnapshotConfigurationRevenant");
    revenant_check((snapshotClass != Nil) != revenant_negative, "WKSnapshotConfiguration implementation is present", NSStringFromClass(snapshotClass));
    if (!snapshotClass) {
        return revenant_finish();
    }

    WKSnapshotConfiguration *hostConfiguration = [[WKSnapshotConfiguration alloc] init];
    id configuration = [[snapshotClass alloc] init];
    revenant_check(CGRectEqualToRect(hostConfiguration.rect, [configuration rect]), "default rect matches host", NSStringFromRect([configuration rect]));
    revenant_check(hostConfiguration.snapshotWidth == [configuration snapshotWidth], "default snapshot width matches host", [NSString stringWithFormat:@"%@", [configuration snapshotWidth]]);
    revenant_check(hostConfiguration.afterScreenUpdates == [configuration afterScreenUpdates], "default afterScreenUpdates matches host", [NSString stringWithFormat:@"%d", [configuration afterScreenUpdates]]);

    hostConfiguration.rect = CGRectMake(1, 2, 3, 4);
    hostConfiguration.snapshotWidth = @320;
    hostConfiguration.afterScreenUpdates = NO;
    [configuration setRect:CGRectMake(1, 2, 3, 4)];
    [configuration setSnapshotWidth:@320];
    [configuration setAfterScreenUpdates:NO];
    id copy = [configuration copy];
    revenant_check(CGRectEqualToRect(hostConfiguration.rect, [copy rect]), "copied rect matches host", NSStringFromRect([copy rect]));
    revenant_check([[copy snapshotWidth] isEqual:hostConfiguration.snapshotWidth], "copied snapshot width matches host", [NSString stringWithFormat:@"%@", [copy snapshotWidth]]);
    revenant_check([copy afterScreenUpdates] == hostConfiguration.afterScreenUpdates, "copied afterScreenUpdates matches host", @"differs");
    revenant_check([copy class] == snapshotClass && copy != configuration, "copy is a new instance of the same class", NSStringFromClass([copy class]));

    Class protocolClass = [RevenantWebURLProtocol class];
    NSURL *custom = [NSURL URLWithString:@"revtest://host/page"];
    NSURL *web = [NSURL URLWithString:@"https://example.com/page"];
    revenant_check(![protocolClass canInitWithRequest:[NSURLRequest requestWithURL:custom]], "no scheme handler bound: custom scheme is not intercepted", @"intercepted");
    RevenantSchemeHandler *handler = [[RevenantSchemeHandler alloc] init];
    revenant_web_bind_scheme(@"RevTest", handler, nil);
    revenant_check([protocolClass canInitWithRequest:[NSURLRequest requestWithURL:custom]], "bound scheme is intercepted case-insensitively", @"not intercepted");
    revenant_check(![protocolClass canInitWithRequest:[NSURLRequest requestWithURL:web]], "unbound scheme is not intercepted", @"intercepted");

    RevenantRecordingClient *client = [[RevenantRecordingClient alloc] init];
    NSURLProtocol *protocol = [[protocolClass alloc] initWithRequest:[NSURLRequest requestWithURL:custom] cachedResponse:nil client:client];
    [protocol startLoading];
    revenant_check(handler.starts == 1, "handler receives the start of the task", [NSString stringWithFormat:@"%lu", (unsigned long)handler.starts]);
    revenant_check(client.response != nil && [client.response.URL isEqual:custom], "response reaches the URL loading client", [client.response.URL absoluteString]);
    revenant_check([[[NSString alloc] initWithData:client.data encoding:NSUTF8StringEncoding] isEqualToString:@"hello"], "body reaches the URL loading client", [[NSString alloc] initWithData:client.data encoding:NSUTF8StringEncoding]);
    revenant_check(client.finished && client.error == nil, "task finish reaches the URL loading client", client.error.description ?: @"not finished");
    [protocol stopLoading];
    revenant_check(handler.stops == 0, "stop after finish does not reach the handler", [NSString stringWithFormat:@"%lu", (unsigned long)handler.stops]);

    return revenant_finish();
}
