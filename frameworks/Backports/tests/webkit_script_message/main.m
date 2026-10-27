#import <Foundation/Foundation.h>

#ifdef WEBKIT_MESSAGE_ORACLE
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#else
#import <JavaScriptCore/JavaScriptCore.h>
#import "RevenantScriptCodec.h"

@interface WKWindowFeaturesRevenant : NSObject
+ (instancetype)revenant_featuresWithString:(NSString *)string;
@property (nonatomic, readonly) NSNumber *menuBarVisibility;
@property (nonatomic, readonly) NSNumber *statusBarVisibility;
@property (nonatomic, readonly) NSNumber *toolbarsVisibility;
@property (nonatomic, readonly) NSNumber *allowsResizing;
@property (nonatomic, readonly) NSNumber *x;
@property (nonatomic, readonly) NSNumber *y;
@property (nonatomic, readonly) NSNumber *width;
@property (nonatomic, readonly) NSNumber *height;
@end
#endif

static NSString *const Samples[] = {
    @"1",
    @"'text'",
    @"true",
    @"false",
    @"null",
    @"[1, 'a', null, true]",
    @"{a: 1, b: {c: [true, false]}}",
    @"new Date(86400000)",
    @"NaN",
    @"Infinity",
    @"-Infinity",
    @"-0",
    @"'h\\u00e9llo \\u2713 & ?#%20 \"q\" \\\\'",
    @"{k: undefined, z: 2}",
    @"[undefined, 1]",
    @"[]",
    @"({})",
};
static const NSUInteger SampleCount = sizeof(Samples) / sizeof(Samples[0]);

static NSString *const PopupCall = @"window.open('http://example.invalid/popup?x=1','pop','width=320,height=240,left=10,top=20,resizable=no,menubar=no,status=yes,toolbar=no');";
static const NSUInteger WindowCount = 2;

static NSString *Dump(id value)
{
    if (!value)
        return @"nil";
    if (value == [NSNull null])
        return @"null";
    if ([value isKindOfClass:[NSString class]])
        return [NSString stringWithFormat:@"string(%@)", value];
    if ([value isKindOfClass:[NSNumber class]]) {
        if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID())
            return [value boolValue] ? @"true" : @"false";
        double number = [value doubleValue];
        if (isnan(number))
            return @"nan";
        if (number == 0 && signbit(number))
            return @"-0";
        return [NSString stringWithFormat:@"number(%.17g)", number];
    }
    if ([value isKindOfClass:[NSDate class]])
        return [NSString stringWithFormat:@"date(%lld)", llround([value timeIntervalSince1970] * 1000)];
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id item in value)
            [items addObject:Dump(item)];
        return [NSString stringWithFormat:@"[%@]", [items componentsJoinedByString:@", "]];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *key in [[value allKeys] sortedArrayUsingSelector:@selector(compare:)])
            [items addObject:[NSString stringWithFormat:@"%@: %@", key, Dump(value[key])]];
        return [NSString stringWithFormat:@"{%@}", [items componentsJoinedByString:@", "]];
    }
    return [NSString stringWithFormat:@"other(%@)", [value class]];
}

static NSString *Features(NSNumber *width, NSNumber *height, NSNumber *x, NSNumber *y, NSNumber *menubar, NSNumber *status, NSNumber *toolbar, NSNumber *resizable)
{
    return [NSString stringWithFormat:@"window open features: width=%@ height=%@ x=%@ y=%@ menubar=%@ status=%@ toolbar=%@ resizable=%@",
            width.stringValue ?: @"nil", height.stringValue ?: @"nil", x.stringValue ?: @"nil", y.stringValue ?: @"nil",
            menubar.stringValue ?: @"nil", status.stringValue ?: @"nil", toolbar.stringValue ?: @"nil", resizable.stringValue ?: @"nil"];
}

#ifdef WEBKIT_MESSAGE_ORACLE

@interface MessageRecorder : NSObject <WKScriptMessageHandler, WKUIDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *lines;
@property (nonatomic, strong) NSMutableArray<NSString *> *windows;
@end

@implementation MessageRecorder

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    [self.lines addObject:[NSString stringWithFormat:@"%@ main: %d", Dump(message.body), message.frameInfo.isMainFrame]];
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    [self.windows addObject:[NSString stringWithFormat:@"window open url: %@", navigationAction.request.URL.absoluteString]];
    [self.windows addObject:Features(windowFeatures.width, windowFeatures.height, windowFeatures.x, windowFeatures.y,
                                     windowFeatures.menuBarVisibility, windowFeatures.statusBarVisibility,
                                     windowFeatures.toolbarsVisibility, windowFeatures.allowsResizing)];
    return nil;
}

@end

static NSArray<NSString *> *OracleLines(void)
{
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    MessageRecorder *recorder = [[MessageRecorder alloc] init];
    recorder.lines = [NSMutableArray array];
    recorder.windows = [NSMutableArray array];
    [configuration.userContentController addScriptMessageHandler:recorder name:@"h"];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480) configuration:configuration];
    webView.UIDelegate = recorder;
    NSMutableString *script = [NSMutableString string];
    for (NSUInteger index = 0; index < SampleCount; index++)
        [script appendFormat:@"window.webkit.messageHandlers.h.postMessage(%@);\n", Samples[index]];
    [script appendFormat:@"%@\n", PopupCall];
    NSString *html = [NSString stringWithFormat:@"<html><body><script>\n%@</script></body></html>", script];
    [webView loadHTMLString:html baseURL:nil];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:20];
    while ((recorder.lines.count < SampleCount || recorder.windows.count < WindowCount) && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return [recorder.lines arrayByAddingObjectsFromArray:recorder.windows];
}

#else

static NSString *const Nonce = @"nonce-under-test";

static NSString *const Stubs =
    @"var window=this; window.top=window;"
    @"var frames=[];"
    @"var document={documentElement:{appendChild:function(frame){frames.push(frame.src);}},"
    @"getElementsByTagName:function(){return [];},"
    @"createElement:function(tag){return {style:{},parentNode:null};}};"
    @"var setTimeout=function(){};"
    @"var location={protocol:'http:',host:'example.invalid'};"
    @"var syncAnswer='1';"
    @"function XMLHttpRequest(){this.status=0;this.responseText='';}"
    @"XMLHttpRequest.prototype.open=function(method,url){this.url=url;};"
    @"XMLHttpRequest.prototype.send=function(){frames.push(this.url);this.status=200;this.responseText=syncAnswer;};"
    @"var events=[];document.createEvent=function(){return {initMessageEvent:function(type,bubbles,cancelable,data,origin,lastEventId,source){this.type=type;this.data=data;this.origin=origin;this.source=source;}};};"
    @"window.dispatchEvent=function(event){events.push(event);};";

static NSURL *Bridged(JSContext *context, NSString *expression, NSUInteger before)
{
    [context evaluateScript:[NSString stringWithFormat:@"window.webkit.messageHandlers.h.postMessage(%@);", expression]];
    JSValue *count = [context evaluateScript:@"frames.length"];
    if (count.toUInt32 != before + 1)
        return nil;
    NSString *source = [[context evaluateScript:@"frames[frames.length - 1]"] toString];
    return [NSURL URLWithString:source];
}

static JSContext *ShimmedWithOpener(NSString *opener)
{
    JSContext *context = [[JSContext alloc] init];
    [context evaluateScript:Stubs];
    [context evaluateScript:[NSString stringWithFormat:RevenantShim, RevenantEncoder, @"[\"h\"]", Nonce, opener]];
    return context;
}

static JSContext *Shimmed(void)
{
    return ShimmedWithOpener(@"null");
}

static NSDictionary *Envelope(NSURL *URL)
{
    if ([URL.scheme isEqualToString:RevenantWebKitBridgeScheme])
        return RevenantCodecBridgeMessage(URL, Nonce);
    BOOL valid = NO;
    NSDictionary *message = RevenantCodecParsed([URL.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], &valid);
    return valid && [message[@"k"] isEqual:Nonce] ? message : nil;
}

static NSArray<NSString *> *BackportLines(void)
{
    JSContext *context = Shimmed();
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSUInteger index = 0; index < SampleCount; index++) {
        NSURL *URL = Bridged(context, Samples[index], index);
#ifdef WEBKIT_MESSAGE_NEGATIVE_CONTROL
        URL = [NSURL URLWithString:[URL.absoluteString substringToIndex:URL.absoluteString.length - 1]];
#endif
        NSDictionary *message = RevenantCodecBridgeMessage(URL, Nonce);
        BOOL valid = NO;
        id body = RevenantCodecMessageBody(message[@"b"], &valid);
        [lines addObject:[NSString stringWithFormat:@"%@ main: 1", Dump(body)]];
    }
    return lines;
}

static NSArray<NSString *> *BackportWindowLines(void)
{
    JSContext *context = Shimmed();
    [context evaluateScript:PopupCall];
    NSURL *URL = [NSURL URLWithString:[[context evaluateScript:@"frames[frames.length - 1]"] toString]];
    NSDictionary *message = Envelope(URL);
    BOOL valid = NO;
    NSDictionary *request = RevenantCodecMessageBody(message[@"b"], &valid);
    if (![message[@"w"] isEqual:@1] || !valid || ![request isKindOfClass:[NSDictionary class]])
        return @[@"window open envelope: missing"];
    WKWindowFeaturesRevenant *features = [WKWindowFeaturesRevenant revenant_featuresWithString:request[@"f"]];
    return @[
        [NSString stringWithFormat:@"window open url: %@", request[@"u"]],
        Features(features.width, features.height, features.x, features.y, features.menuBarVisibility,
                 features.statusBarVisibility, features.toolbarsVisibility, features.allowsResizing),
    ];
}

static NSURL *Forged(NSString *JSON)
{
    NSString *encoded = [JSON stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return [NSURL URLWithString:[@"revenant-wkbridge://m/" stringByAppendingString:encoded]];
}

static NSArray<NSString *> *BackportChecks(void)
{
    JSContext *context = Shimmed();
    NSDictionary *cycle = RevenantCodecBridgeMessage(Bridged(context, @"(function(){var o={n:1};o.self=o;return o;})()", 0), Nonce);
    BOOL valid = NO;
    id body = RevenantCodecMessageBody(cycle[@"b"], &valid);
    BOOL identical = [body isKindOfClass:[NSDictionary class]] && body[@"self"] == body;
    BOOL numberValid = YES, garbageValid = YES, taggedValid = YES;
    id number = RevenantCodecMessageBody(@5, &numberValid);
    id garbage = RevenantCodecMessageBody(@"{not json", &garbageValid);
    id tagged = RevenantCodecMessageBody(@"{\"$revenant\":5}", &taggedValid);
    BOOL foreign = RevenantCodecBridgeMessage([NSURL URLWithString:@"https://example.invalid/?n=h"], Nonce) == nil;
    BOOL forgedNonce = RevenantCodecBridgeMessage(Forged(@"{\"n\":\"h\",\"b\":\"1\",\"k\":\"forged\"}"), Nonce) == nil;
    BOOL missingNonce = RevenantCodecBridgeMessage(Forged(@"{\"n\":\"h\",\"b\":\"1\"}"), Nonce) == nil;
    NSMutableString *deep = [NSMutableString string];
    for (NSUInteger level = 0; level < 200; level++)
        [deep appendString:@"{\"$revenant\":\"a\",\"v\":["];
    [deep appendString:@"1"];
    for (NSUInteger level = 0; level < 200; level++)
        [deep appendString:@"]}"];
    BOOL deepValid = NO;
    id nested = RevenantCodecMessageBody(deep, &deepValid);
    NSUInteger depth = 0;
    for (id cursor = nested; [cursor isKindOfClass:[NSArray class]] && [cursor count]; cursor = [cursor firstObject])
        depth++;
    return @[
        [NSString stringWithFormat:@"cycle identical: %d", identical],
        [NSString stringWithFormat:@"refused non-string body: %d", !numberValid && number == nil],
        [NSString stringWithFormat:@"refused non-JSON body: %d", !garbageValid && garbage == nil],
        [NSString stringWithFormat:@"refused non-string tag: %d", taggedValid && tagged == nil],
        [NSString stringWithFormat:@"refused foreign URL: %d", foreign],
        [NSString stringWithFormat:@"refused forged nonce: %d", forgedNonce],
        [NSString stringWithFormat:@"refused missing nonce: %d", missingNonce],
        [NSString stringWithFormat:@"nesting capped: %d", deepValid && depth > 0 && depth <= 65],
    ];
}

static NSDictionary *LastFrame(JSContext *context)
{
    NSURL *URL = [NSURL URLWithString:[[context evaluateScript:@"frames[frames.length - 1]"] toString]];
    return Envelope(URL);
}

static NSArray<NSString *> *BackportProxyChecks(void)
{
    JSContext *context = Shimmed();
    [context evaluateScript:[NSString stringWithFormat:@"var __encode=%@;", RevenantEncoder]];
    [context evaluateScript:@"var w=window.open('http://example.invalid/popup?x=1','pop','width=320');"];
    NSDictionary *open = LastFrame(context);
    NSString *identifier = open[@"i"];
    BOOL valid = NO;
    NSDictionary *request = RevenantCodecMessageBody(open[@"b"], &valid);
    BOOL opened = [open[@"w"] isEqual:@1] && [identifier isKindOfClass:[NSString class]] && valid
        && [request[@"u"] isEqual:@"http://example.invalid/popup?x=1"] && [request[@"f"] isEqual:@"width=320"];
    BOOL object = [[context evaluateScript:@"typeof w === 'object' && w !== null"] toBool];
    BOOL starts = [[context evaluateScript:@"w.closed === false"] toBool];
    BOOL location = [[context evaluateScript:@"w.location.href === 'about:blank'"] toBool];
    NSUInteger beforeClose = [[context evaluateScript:@"frames.length"] toUInt32];
    [context evaluateScript:@"w.close(); w.close();"];
    NSUInteger afterClose = [[context evaluateScript:@"frames.length"] toUInt32];
    NSDictionary *close = LastFrame(context);
    BOOL closesOnce = afterClose == beforeClose + 1 && [close[@"w"] isEqual:@2] && [close[@"i"] isEqual:identifier];
    BOOL closed = [[context evaluateScript:@"w.closed === true"] toBool];
    [context evaluateScript:@"var v=window.open('http://example.invalid/second');"];
    NSString *second = LastFrame(context)[@"i"];
    context[@"__second"] = second;
    [context evaluateScript:@"v.postMessage({a:[1,'x']},'http://example.invalid');"];
    NSDictionary *post = LastFrame(context);
    BOOL posted = [post[@"w"] isEqual:@3] && [post[@"i"] isEqual:second] && [post[@"o"] isEqual:@"http://example.invalid"];
    [context evaluateScript:@"v.location.href='http://example.invalid/moved';"];
    NSDictionary *navigate = LastFrame(context);
    BOOL navigated = [navigate[@"w"] isEqual:@4] && [navigate[@"i"] isEqual:second] && [navigate[@"u"] isEqual:@"http://example.invalid/moved"];
    NSUInteger trips = 0;
    for (NSUInteger index = 0; index < SampleCount; index++) {
        [context evaluateScript:[NSString stringWithFormat:@"v.postMessage(%@, 'http://example.invalid');", Samples[index]]];
        context[@"__b"] = LastFrame(context)[@"b"];
        if ([[context evaluateScript:[NSString stringWithFormat:@"window['%@w']({m:__b,o:'http://example.invalid',t:'http://example.invalid'}); var __e=events[events.length-1]; __e.type === 'message' && __e.origin === 'http://example.invalid' && __encode(__e.data) === __b;", Nonce]] toBool])
            trips++;
    }
    [context evaluateScript:[NSString stringWithFormat:@"window['%@w']({i:__second,href:'http://example.invalid/from-native'});", Nonce]];
    BOOL moved = [[context evaluateScript:@"v.location.href === 'http://example.invalid/from-native'"] toBool];
    [context evaluateScript:@"var x=window.open('http://example.invalid/third');"];
    context[@"__third"] = LastFrame(context)[@"i"];
    [context evaluateScript:[NSString stringWithFormat:@"window['%@w']({i:__third,closed:true});", Nonce]];
    BOOL nativeClosed = [[context evaluateScript:@"x.closed === true"] toBool];
    NSUInteger beforeSelf = [[context evaluateScript:@"frames.length"] toUInt32];
    [context evaluateScript:@"window.close();"];
    BOOL selfClose = [[context evaluateScript:@"frames.length"] toUInt32] == beforeSelf + 1 && [LastFrame(context)[@"w"] isEqual:@5];
    [context evaluateScript:[NSString stringWithFormat:RevenantShim, RevenantEncoder, @"[\"h\"]", Nonce]];
    [context evaluateScript:[NSString stringWithFormat:@"window['%@w']({i:__second,href:'http://example.invalid/after-install'});", Nonce]];
    BOOL reinstalled = [[context evaluateScript:@"v.location.href === 'http://example.invalid/after-install'"] toBool];
    return @[
        [NSString stringWithFormat:@"window proxy open envelope: %d", opened],
        [NSString stringWithFormat:@"window proxy is an object: %d", object],
        [NSString stringWithFormat:@"window proxy starts open: %d", starts],
        [NSString stringWithFormat:@"window location starts at about:blank: %d", location],
        [NSString stringWithFormat:@"window proxy close posts once: %d", closesOnce],
        [NSString stringWithFormat:@"window closed after close() is true: %d", closed],
        [NSString stringWithFormat:@"window proxy postMessage posts origin: %d", posted],
        [NSString stringWithFormat:@"window proxy location set posts navigation: %d", navigated],
        [NSString stringWithFormat:@"window proxy message round trips: %d", trips == SampleCount],
        [NSString stringWithFormat:@"window proxy native update moves location: %d", moved],
        [NSString stringWithFormat:@"window proxy native update closes: %d", nativeClosed],
        [NSString stringWithFormat:@"window self close posts: %d", selfClose],
        [NSString stringWithFormat:@"window proxy survives a second install: %d", reinstalled],
    ];
}

static NSArray<NSString *> *BackportSyncChecks(void)
{
    JSContext *context = Shimmed();
    [context evaluateScript:@"syncAnswer='0';"];
    NSUInteger before = [[context evaluateScript:@"frames.length"] toUInt32];
    BOOL refused = [[context evaluateScript:@"window.open('http://example.invalid/refused') === null"] toBool];
    NSUInteger after = [[context evaluateScript:@"frames.length"] toUInt32];
    BOOL refusedSent = after == before + 1 && [LastFrame(context)[@"w"] isEqual:@1];
    [context evaluateScript:@"syncAnswer='1';"];
    BOOL accepted = [[context evaluateScript:@"typeof window.open('http://example.invalid/accepted') === 'object'"] toBool];
    return @[
        [NSString stringWithFormat:@"window open refused is null: %d", refused],
        [NSString stringWithFormat:@"window open refusal is sent synchronously: %d", refusedSent],
        [NSString stringWithFormat:@"window open accepted is an object: %d", accepted],
    ];
}

static NSArray<NSString *> *BackportOpenerChecks(void)
{
    JSContext *context = ShimmedWithOpener(@"{\"href\":\"http://example.invalid/opener\"}");
    BOOL object = [[context evaluateScript:@"typeof window.opener === 'object' && window.opener !== null"] toBool];
    BOOL href = [[context evaluateScript:@"window.opener.location.href === 'http://example.invalid/opener'"] toBool];
    BOOL open = [[context evaluateScript:@"window.opener.closed === false"] toBool];
    [context evaluateScript:@"window.opener.postMessage({a:[1,'x']},'http://example.invalid');"];
    NSDictionary *post = LastFrame(context);
    BOOL valid = NO;
    NSDictionary *body = RevenantCodecMessageBody(post[@"b"], &valid);
    BOOL posted = [post[@"w"] isEqual:@6] && [post[@"o"] isEqual:@"http://example.invalid"] && valid && [body[@"a"] count] == 2;
    [context evaluateScript:@"window.opener.location.href='http://example.invalid/next';"];
    NSDictionary *navigate = LastFrame(context);
    BOOL navigated = [navigate[@"w"] isEqual:@7] && [navigate[@"u"] isEqual:@"http://example.invalid/next"];
    [context evaluateScript:[NSString stringWithFormat:@"window['%@w']({opener:true,href:'http://example.invalid/moved'});", Nonce]];
    BOOL moved = [[context evaluateScript:@"window.opener.location.href === 'http://example.invalid/moved'"] toBool];
    [context evaluateScript:[NSString stringWithFormat:@"window['%@w']({m:'\"hello\"',o:'http://example.invalid',t:'http://example.invalid',s:'opener'});", Nonce]];
    BOOL delivered = [[context evaluateScript:@"var e=events[events.length-1]; e.type === 'message' && e.data === 'hello' && e.origin === 'http://example.invalid' && e.source === window.opener"] toBool];
    [context evaluateScript:@"syncAnswer='1';"];
    JSContext *popup = ShimmedWithOpener(@"null");
    BOOL noOpener = [[popup evaluateScript:@"window.opener === undefined"] toBool];
    return @[
        [NSString stringWithFormat:@"window opener is an object: %d", object],
        [NSString stringWithFormat:@"window opener href is the opener URL: %d", href],
        [NSString stringWithFormat:@"window opener starts open: %d", open],
        [NSString stringWithFormat:@"window opener postMessage posts origin: %d", posted],
        [NSString stringWithFormat:@"window opener location set posts navigation: %d", navigated],
        [NSString stringWithFormat:@"window opener native update moves location: %d", moved],
        [NSString stringWithFormat:@"window message from opener has its source: %d", delivered],
        [NSString stringWithFormat:@"window without opener has none: %d", noOpener],
    ];
}

static NSArray<NSString *> *BackportLoadChecks(void)
{
    JSContext *context = Shimmed();
    [context evaluateScript:@"var q=window.open('http://example.invalid/loaded');"];
    context[@"__loaded"] = LastFrame(context)[@"i"];
    [context evaluateScript:[NSString stringWithFormat:@"window['%@w']({i:__loaded,href:'http://example.invalid/loaded'});", Nonce]];
    BOOL loaded = [[context evaluateScript:@"q.location.href === 'http://example.invalid/loaded'"] toBool];
    return @[
        [NSString stringWithFormat:@"window location is the URL after load: %d", loaded],
    ];
}

static NSArray<NSString *> *BackportOriginChecks(void)
{
    NSString *popup = RevenantOriginOf([NSURL URLWithString:@"http://127.0.0.1:8080/popup.html?x=1"]);
    NSString *opener = RevenantOriginOf([NSURL URLWithString:@"http://127.0.0.1:8080/opener.html"]);
    JSContext *context = Shimmed();
    [context evaluateScript:@"var before=events.length;"];
    [context evaluateScript:[NSString stringWithFormat:@"window['%@w']({m:'\"x\"',o:'http://example.invalid',t:'http://other.invalid',s:'opener'});", Nonce]];
    BOOL pageDropped = [[context evaluateScript:@"events.length === before"] toBool];
    return @[
        [NSString stringWithFormat:@"window postMessage other origin is dropped: %d", !RevenantTargetAllows(@"http://example.invalid", opener, popup)],
        [NSString stringWithFormat:@"window postMessage matching origin is delivered: %d", RevenantTargetAllows(popup, opener, popup)],
        [NSString stringWithFormat:@"window origin drops default port: %d", [RevenantOriginOf([NSURL URLWithString:@"https://example.invalid:443/"]) isEqualToString:@"https://example.invalid"]],
        [NSString stringWithFormat:@"window message to other origin is dropped in the page: %d", pageDropped],
    ];
}

#endif

int main(int argc, const char *argv[])
{
    @autoreleasepool {
#ifdef WEBKIT_MESSAGE_ORACLE
        for (NSString *line in OracleLines())
            printf("%s\n", line.UTF8String);
#else
        for (NSString *line in BackportLines())
            printf("%s\n", line.UTF8String);
        for (NSString *line in BackportWindowLines())
            printf("%s\n", line.UTF8String);
        for (NSString *line in BackportChecks())
            printf("%s\n", line.UTF8String);
        for (NSString *line in BackportProxyChecks())
            printf("%s\n", line.UTF8String);
        for (NSString *line in BackportSyncChecks())
            printf("%s\n", line.UTF8String);
        for (NSString *line in BackportOpenerChecks())
            printf("%s\n", line.UTF8String);
        for (NSString *line in BackportLoadChecks())
            printf("%s\n", line.UTF8String);
        for (NSString *line in BackportOriginChecks())
            printf("%s\n", line.UTF8String);
#endif
    }
    return 0;
}
