#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

static NSString *const Early = @"window.early = 'set-by-start';";

static NSString *const Page = @"<!DOCTYPE html><html><head><title>page</title><script>var seen = window.early;</script></head><body>café</body></html>";

@interface Starts : NSObject <WKScriptMessageHandler>
@property (nonatomic) NSUInteger count;
@end

@implementation Starts

- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message
{
    self.count++;
}

@end

@interface Finished : NSObject <WKNavigationDelegate>
@property (nonatomic) BOOL done;
@end

@implementation Finished

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    self.done = YES;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    self.done = YES;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    self.done = YES;
}

@end

static WKWebView *web;
static Starts *starts;
static Finished *finished;

static void Spin(NSTimeInterval seconds, BOOL (^condition)(void))
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ((!condition || !condition()) && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static NSUInteger Load(void (^perform)(WKWebView *view))
{
    NSUInteger before = starts.count;
    finished.done = NO;
    perform(web);
    Spin(20, ^BOOL{ return finished.done; });
    Spin(0.3, nil);
    return starts.count - before;
}

static NSString *Seen(void)
{
    __block NSString *value = @"undefined";
    __block BOOL answered = NO;
    [web evaluateJavaScript:@"typeof seen === 'undefined' ? 'undefined' : String(seen)" completionHandler:^(id result, NSError *error) {
        value = [result isKindOfClass:[NSString class]] ? result : @"undefined";
        answered = YES;
    }];
    Spin(10, ^BOOL{ return answered; });
    return value;
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        starts = [[Starts alloc] init];
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        [configuration.userContentController addScriptMessageHandler:starts name:@"start"];
        NSString *source = [Early stringByAppendingString:@" window.webkit.messageHandlers.start.postMessage(0);"];
        [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:source injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
        web = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480) configuration:configuration];
        finished = [[Finished alloc] init];
        web.navigationDelegate = finished;

        Load(^(WKWebView *view) { [view loadHTMLString:Page baseURL:nil]; });
        printf("loadHTMLString page saw: %s\n", Seen().UTF8String);

        Load(^(WKWebView *view) {
            [view loadData:[Page dataUsingEncoding:NSISOLatin1StringEncoding] MIMEType:@"text/html" characterEncodingName:@"iso-8859-1" baseURL:nil];
        });
        printf("loadData page saw: %s\n", Seen().UTF8String);

        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-document-start-oracle"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        NSURL *pageA = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"a.html"]];
        NSURL *pageB = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"b.html"]];
        [Page writeToURL:pageA atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        [[Page stringByReplacingOccurrencesOfString:@"page" withString:@"other"] writeToURL:pageB atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        Load(^(WKWebView *view) { [view loadFileURL:pageA allowingReadAccessToURL:[NSURL fileURLWithPath:directory]]; });
        printf("loadFileURL page saw: %s\n", Seen().UTF8String);

        NSUInteger reloaded = Load(^(WKWebView *view) { [view reload]; });
        printf("reload starts: %lu\n", (unsigned long)reloaded);

        Load(^(WKWebView *view) { [view loadFileURL:pageB allowingReadAccessToURL:[NSURL fileURLWithPath:directory]]; });
        NSUInteger back = Load(^(WKWebView *view) { [view goBack]; });
        printf("goBack starts: %lu\n", (unsigned long)back);
        printf("goBack page saw: %s\n", Seen().UTF8String);
    }
    return 0;
}
