#if defined(REVENANT_HOST_BUILD)
#define WKDownload WKDownloadRevenant
#endif

#import <WebKit/WebKit.h>

@implementation WKDownload {
    __weak id<WKDownloadDelegate> _delegate;
}

- (NSURLRequest *)originalRequest
{
    return nil;
}

- (WKWebView *)webView
{
    return nil;
}

- (id<WKDownloadDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<WKDownloadDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)isUserInitiated
{
    return NO;
}

- (WKFrameInfo *)originatingFrame
{
    return nil;
}

- (NSProgress *)progress
{
    return nil;
}

- (void)cancel:(void (^)(NSData *resumeData))completionHandler
{
    if (completionHandler) {
        completionHandler(nil);
    }
}

@end
