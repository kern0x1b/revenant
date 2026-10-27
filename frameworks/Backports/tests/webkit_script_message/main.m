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
    @"var setTimeout=function(){};";

static NSURL *Bridged(JSContext *context, NSString *expression, NSUInteger before)
{
    [context evaluateScript:[NSString stringWithFormat:@"window.webkit.messageHandlers.h.postMessage(%@);", expression]];
    JSValue *count = [context evaluateScript:@"frames.length"];
    if (count.toUInt32 != before + 1)
        return nil;
    NSString *source = [[context evaluateScript:@"frames[frames.length - 1]"] toString];
    return [NSURL URLWithString:source];
}

static JSContext *Shimmed(void)
{
    JSContext *context = [[JSContext alloc] init];
    [context evaluateScript:Stubs];
    [context evaluateScript:[NSString stringWithFormat:RevenantShim, RevenantEncoder, @"[\"h\"]", Nonce]];
    return context;
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
    NSDictionary *message = RevenantCodecBridgeMessage(URL, Nonce);
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
#endif
    }
    return 0;
}
