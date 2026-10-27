#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <pthread.h>
#import <sys/socket.h>
#import <unistd.h>

static int Listener;
static NSMutableArray<NSString *> *Lines;

static void Log(NSString *line)
{
    [Lines addObject:line];
    printf("%s\n", line.UTF8String);
}

static NSData *Attachment(void)
{
    NSMutableData *body = [NSMutableData dataWithLength:1000];
    uint8_t *bytes = body.mutableBytes;
    for (NSUInteger index = 0; index < body.length; index++)
        bytes[index] = (uint8_t)(index * 3);
    return body;
}

static void Reply(int client, NSString *head, NSData *body)
{
    NSData *data = [head dataUsingEncoding:NSASCIIStringEncoding];
    write(client, data.bytes, data.length);
    write(client, body.bytes, body.length);
}

static void *Serve(void *argument)
{
    for (;;) {
        int client = accept(Listener, NULL, NULL);
        if (client < 0)
            continue;
        char buffer[2048];
        ssize_t count = read(client, buffer, sizeof buffer - 1);
        if (count > 0) {
            buffer[count] = 0;
            if (strstr(buffer, "GET /file.bin ")) {
                Reply(client, @"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"file.bin\"\r\nContent-Length: 1000\r\nConnection: close\r\n\r\n", Attachment());
            } else {
                NSData *page = [@"<html><body>page</body></html>" dataUsingEncoding:NSUTF8StringEncoding];
                Reply(client, [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n", (unsigned long)page.length], page);
            }
        }
        close(client);
    }
    return NULL;
}

static int StartServer(void)
{
    Listener = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    bind(Listener, (struct sockaddr *)&address, sizeof address);
    socklen_t length = sizeof address;
    getsockname(Listener, (struct sockaddr *)&address, &length);
    listen(Listener, 8);
    pthread_t thread;
    pthread_create(&thread, NULL, Serve, NULL);
    pthread_detach(thread);
    return ntohs(address.sin_port);
}

@interface Recorder : NSObject <WKNavigationDelegate, WKDownloadDelegate>
@property (nonatomic) BOOL finished;
@property (nonatomic, strong) NSURL *destination;
@end

@implementation Recorder

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    Log([NSString stringWithFormat:@"decide response %@", navigationResponse.response.URL.lastPathComponent]);
    decisionHandler(WKNavigationResponsePolicyDownload);
}

- (void)webView:(WKWebView *)webView navigationResponse:(WKNavigationResponse *)navigationResponse didBecomeDownload:(WKDownload *)download
{
    Log(@"became download");
    download.delegate = self;
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    Log(@"start provisional");
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    Log(@"commit");
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    Log(@"finish navigation");
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    Log([NSString stringWithFormat:@"fail provisional %@ %ld", error.domain, (long)error.code]);
    self.finished = YES;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    Log([NSString stringWithFormat:@"fail navigation %@ %ld", error.domain, (long)error.code]);
    self.finished = YES;
}

- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response suggestedFilename:(NSString *)suggestedFilename completionHandler:(void (^)(NSURL *))completionHandler
{
    Log([NSString stringWithFormat:@"download destination %@", suggestedFilename]);
    completionHandler(self.destination);
}

- (void)downloadDidFinish:(WKDownload *)download
{
    Log(@"download finished");
    self.finished = YES;
}

- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(NSData *)resumeData
{
    Log([NSString stringWithFormat:@"download failed %@ %ld", error.domain, (long)error.code]);
    self.finished = YES;
}

@end

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        Lines = [NSMutableArray array];
        int port = StartServer();
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-navigation-oracle"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        NSURL *destination = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"file.bin"]];
        [[NSFileManager defaultManager] removeItemAtURL:destination error:NULL];

        Recorder *recorder = [[Recorder alloc] init];
        recorder.destination = destination;
        WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480) configuration:[[WKWebViewConfiguration alloc] init]];
        webView.navigationDelegate = recorder;
        NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/file.bin", port]];
        [webView loadRequest:[NSURLRequest requestWithURL:URL]];

        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:20];
        while (!recorder.finished && [deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        NSData *written = [NSData dataWithContentsOfURL:destination];
        Log([NSString stringWithFormat:@"file bytes %lu", (unsigned long)written.length]);
    }
    return 0;
}
