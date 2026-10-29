#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <pthread.h>
#import <sys/socket.h>
#import <unistd.h>

static NSString *const OpenerPage =
    @"<html><body><script>\n"
    @"var h=window.webkit.messageHandlers.h;\n"
    @"function line(name,ok){h.postMessage(name+': '+(ok?1:0));}\n"
    @"window.addEventListener('message',function(e){line('popup message reaches opener with source',e.source===window.__w&&e.data==='from popup'&&e.origin===location.origin);});\n"
    @"var popup=location.origin+'/popup.html?x=1';\n"
    @"window.__w=window.open(popup,'pop','width=320,height=240,left=10,top=20,resizable=no,menubar=no,status=yes,toolbar=no');\n"
    @"line('window open accepted is an object',typeof window.__w==='object'&&window.__w!==null);\n"
    @"line('window location starts at about:blank',window.__w.location.href==='about:blank');\n"
    @"line('window open refused is null',window.open(location.origin+'/refused.html','refused')===null);\n"
    @"window.__check=function(){line('window location is the URL after load',window.__w.location.href===popup);};\n"
    @"window.__finish=function(){window.__w.close();line('window closed after close() is true',window.__w.closed===true);};\n"
    @"</script></body></html>";

static NSString *const PopupPage =
    @"<html><body><script>\n"
    @"var h=window.webkit.messageHandlers.h;\n"
    @"function line(name,ok){h.postMessage(name+': '+(ok?1:0));}\n"
    @"window.received=[];\n"
    @"window.addEventListener('message',function(e){window.received.push(e.data);"
    @"if(e.data==='hello'){line('window message from opener has its source',e.source===window.opener&&e.origin===location.origin);}});\n"
    @"line('window opener is an object',typeof window.opener==='object'&&window.opener!==null);\n"
    @"line('window opener href is the opener URL',window.opener.location.href===location.origin+'/opener.html');\n"
    @"line('window opener starts open',window.opener.closed===false);\n"
    @"window.opener.postMessage('from popup',location.origin);\n"
    @"window.webkit.messageHandlers.r.postMessage('ready');\n"
    @"</script></body></html>";

static int Listener;

static void Reply(int client, NSString *status, NSString *body)
{
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString *head = [NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: text/html\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n", status, (unsigned long)data.length];
    NSData *headData = [head dataUsingEncoding:NSASCIIStringEncoding];
    write(client, headData.bytes, headData.length);
    write(client, data.bytes, data.length);
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
            if (strstr(buffer, "GET /opener.html "))
                Reply(client, @"200 OK", OpenerPage);
            else if (strstr(buffer, "GET /popup.html?"))
                Reply(client, @"200 OK", PopupPage);
            else
                Reply(client, @"404 Not Found", @"");
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

static void Log(NSString *line)
{
    printf("%s\n", line.UTF8String);
}

@interface WindowRecorder : NSObject <WKScriptMessageHandler, WKUIDelegate>
@property (nonatomic, strong) WKWebView *opener;
@property (nonatomic, strong) WKWebView *popup;
@property (nonatomic) BOOL done;
@end

@implementation WindowRecorder

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"r"]) {
        [self popupReady];
        return;
    }
    Log([NSString stringWithFormat:@"%@", message.body]);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    if ([navigationAction.request.URL.path isEqualToString:@"/refused.html"])
        return nil;
    self.popup = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 240) configuration:configuration];
    return self.popup;
}

- (void)popupReady
{
    [self.opener evaluateJavaScript:@"window.__w.postMessage('hello',location.origin);window.__w.postMessage('dropped','http://example.invalid');" completionHandler:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.popup evaluateJavaScript:@"window.received.indexOf('hello')>=0&&window.received.indexOf('dropped')<0" completionHandler:^(id result, NSError *error) {
            Log([NSString stringWithFormat:@"window postMessage other origin is dropped: %d", [result boolValue]]);
            [self.opener evaluateJavaScript:@"window.__check();window.__finish();" completionHandler:^(id finished, NSError *failed) {
                self.done = YES;
            }];
        }];
    });
}

@end

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        int port = StartServer();
        WindowRecorder *recorder = [[WindowRecorder alloc] init];
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
        [configuration.userContentController addScriptMessageHandler:recorder name:@"h"];
        [configuration.userContentController addScriptMessageHandler:recorder name:@"r"];
        WKWebView *opener = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480) configuration:configuration];
        opener.UIDelegate = recorder;
        recorder.opener = opener;
        NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/opener.html", port]];
        [opener loadRequest:[NSURLRequest requestWithURL:URL]];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30];
        while (!recorder.done && [deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        return recorder.done ? 0 : 1;
    }
}
