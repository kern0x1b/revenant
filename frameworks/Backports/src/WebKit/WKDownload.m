#if defined(REVENANT_HOST_BUILD)
#define WKDownload WKDownloadRevenant
#endif

#import <WebKit/WebKit.h>

// The engine never hands a navigation or response to WebKit's download path, so no WKDownload is created.
// The class is complete for a download a caller holds: cancelling it reports no resume data, as this engine
// cannot resume anything.
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
