#import <WebKit/WebKit.h>
#import "webkit-cases.h"

static void spin(NSTimeInterval seconds)
{
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static BOOL spin_until(NSTimeInterval seconds, BOOL (^condition)(void))
{
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!condition() && end.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    return condition();
}

static NSString *text_at(id value, int depth);
static NSString *text(id value)
{
    return text_at(value, 0);
}

static NSString *text_at(id value, int depth)
{
    if (depth > 6)
        return @"deep";
    if (value == nil)
        return @"nil";
    if ([value isKindOfClass:[NSNull class]])
        return @"null";
    if ([value isKindOfClass:[NSString class]])
        return [NSString stringWithFormat:@"\"%@\"", value];
    if ([value isKindOfClass:[NSNumber class]]) {
        const char *type = [value objCType];
        if (type[0] == 'c' || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID())
            return [value boolValue] ? @"true" : @"false";
        return [NSString stringWithFormat:@"%g", [value doubleValue]];
    }
    if ([value isKindOfClass:[NSDate class]])
        return [NSString stringWithFormat:@"date %.0f", [value timeIntervalSince1970]];
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id item in value)
            [parts addObject:text_at(item, depth + 1)];
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@","]];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (NSString *key in [[value allKeys] sortedArrayUsingSelector:@selector(compare:)])
            [parts addObject:[NSString stringWithFormat:@"%@:%@", key, text_at(value[key], depth + 1)]];
        return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@","]];
    }
    return [NSString stringWithFormat:@"<%@>", NSStringFromClass([value class])];
}

static NSString *state(WKWebView *view)
{
    return [NSString stringWithFormat:@"url=%@ title=%@ loading=%d back=%d forward=%d", view.URL.absoluteString ?: @"nil", view.title ?: @"nil", view.loading, view.canGoBack, view.canGoForward];
}

@interface WebKitWatcher : NSObject <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, copy) WKNavigationActionPolicy (^policy)(WKNavigationAction *action);
@property (nonatomic, strong) NSMutableArray<NSString *> *messages;
@property (nonatomic) NSTimeInterval delay;
@end

@implementation WebKitWatcher

- (instancetype)init
{
    self = [super init];
    _events = [NSMutableArray array];
    _messages = [NSMutableArray array];
    return self;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))handler
{
    WKNavigationActionPolicy decision = self.policy ? self.policy(action) : WKNavigationActionPolicyAllow;
    [self.events addObject:[NSString stringWithFormat:@"decide type=%ld main=%d url=%@ -> %ld", (long)action.navigationType, action.targetFrame.isMainFrame, action.request.URL.absoluteString, (long)decision]];
    if (self.delay > 0)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ handler(decision); });
    else
        handler(decision);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [self.events addObject:[NSString stringWithFormat:@"start %@", state(webView)]];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    [self.events addObject:[NSString stringWithFormat:@"commit %@", state(webView)]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self.events addObject:[NSString stringWithFormat:@"finish %@ progress=%.1f", state(webView), webView.estimatedProgress]];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self.events addObject:[NSString stringWithFormat:@"fail %@/%ld", error.domain, (long)error.code]];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self.events addObject:[NSString stringWithFormat:@"failProvisional %@/%ld", error.domain, (long)error.code]];
}

- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message
{
    [self.messages addObject:[NSString stringWithFormat:@"%@ main=%d body=%@", message.name, message.frameInfo.mainFrame, text(message.body)]];
}

@end

@interface WebKitObserver : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *changes;
@end

@implementation WebKitObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!self.changes)
        self.changes = [NSMutableArray array];
    if ([keyPath isEqualToString:@"estimatedProgress"])
        return;
    id value = change[NSKeyValueChangeNewKey];
    BOOL flag = [@[@"loading", @"canGoBack", @"canGoForward"] containsObject:keyPath];
    NSString *entry = [NSString stringWithFormat:@"%@=%@", keyPath, flag ? ([value boolValue] ? @"true" : @"false") : text(value)];
    if (![self.changes.lastObject isEqualToString:entry])
        [self.changes addObject:entry];
}

@end

static WKWebView *make(UIView *container, WebKitWatcher *watcher, WKWebViewConfiguration *configuration)
{
    WKWebView *view = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) configuration:configuration ?: [[WKWebViewConfiguration alloc] init]];
    view.navigationDelegate = watcher;
    [container addSubview:view];
    return view;
}

static NSString *html(NSString *title, NSString *body)
{
    return [NSString stringWithFormat:@"<html><head><title>%@</title></head><body>%@</body></html>", title, body];
}

static NSString *joined(NSArray *events)
{
    return events.count ? [events componentsJoinedByString:@" | "] : @"none";
}

static NSString *evaluate(WKWebView *view, NSString *script)
{
    __block NSString *result = nil;
    [view evaluateJavaScript:script completionHandler:^(id value, NSError *error) {
        result = error ? [NSString stringWithFormat:@"error %@/%ld", error.domain, (long)error.code] : text(value);
    }];
    spin_until(3, ^BOOL { return result != nil; });
    return result ?: @"no answer";
}

void webkit_run(UIView *container, WebKitRecorder record)
{
    NSURL *base = [NSURL URLWithString:@"https://charon.invalid/base"];

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        record(@"new.state", state(view));
        record(@"new.progress", [NSString stringWithFormat:@"%.1f", view.estimatedProgress]);
        record(@"new.secure", [NSString stringWithFormat:@"%d", view.hasOnlySecureContent]);
        record(@"new.navigationDelegate", view.navigationDelegate == watcher ? @"set" : @"other");
        record(@"new.UIDelegate", view.UIDelegate ? @"set" : @"nil");
        record(@"new.gestures", [NSString stringWithFormat:@"%d", view.allowsBackForwardNavigationGestures]);
        record(@"new.userAgent", view.customUserAgent ? @"set" : @"nil");
        record(@"new.scrollView", NSStringFromClass([view.scrollView class]));
        record(@"new.backList", [NSString stringWithFormat:@"%lu %lu", (unsigned long)view.backForwardList.backList.count, (unsigned long)view.backForwardList.forwardList.count]);
        record(@"new.currentItem", view.backForwardList.currentItem ? @"item" : @"nil");
        WKWebViewConfiguration *configuration = view.configuration;
        record(@"config.preferences", [NSString stringWithFormat:@"js=%d windows=%d minfont=%.0f", configuration.preferences.javaScriptEnabled, configuration.preferences.javaScriptCanOpenWindowsAutomatically, configuration.preferences.minimumFontSize]);
        record(@"config.media", [NSString stringWithFormat:@"airplay=%d", configuration.allowsAirPlayForMediaPlayback]);
        record(@"config.identity", view.configuration == view.configuration ? @"same" : @"copy");
        record(@"config.controller", configuration.userContentController ? @"present" : @"nil");
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        WKNavigation *navigation = [view loadHTMLString:html(@"T1", @"hello") baseURL:base];
        record(@"html.navigation", navigation ? @"object" : @"nil");
        record(@"html.afterCall", state(view));
        spin_until(5, ^BOOL { return watcher.events.count >= 3; });
        spin(0.5);
        record(@"html.events", joined(watcher.events));
        record(@"html.state", state(view));
        record(@"html.navigationEqual", [navigation isKindOfClass:[WKNavigation class]] ? @"WKNavigation" : @"other");
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        [view loadHTMLString:html(@"T1", @"hello") baseURL:base];
        spin_until(5, ^BOOL { return !view.loading && view.title.length; });
        spin(0.3);
        for (NSString *script in @[@"1+2", @"'a'", @"true", @"null", @"undefined", @"[1,'x',{a:2}]", @"({a:1,b:[2]})", @"document.title",
                                   @"throw new Error('boom')", @"(function(){return function(){}})()", @"new Date(86400000)", @"NaN", @"1.5", @"0", @"false",
                                   @"''", @"[]", @"({})", @"var q = 5", @"document.body.innerHTML", @"[undefined, null]", @"({u: undefined})", @"[new Date(0)]",
                                   @"1/0", @"'a\\u2028b'", @"'\\u00e9\\ud83d\\ude00'", @"this === window", @"({a:{b:{c:[1,2,3]}}})", @"12345678901234567890", @"-0", @"var c = {}; c.c = c; c", @"[function(){}]", @"({f: function(){}})", @"new Object(5)", @"(function(){ return arguments; })(1, 2)"])
            record([NSString stringWithFormat:@"js %@", script], evaluate(view, script));
        record(@"js.noHandler", ({ __block NSString *out = @"unset"; [view evaluateJavaScript:@"1" completionHandler:nil]; out = @"ok"; out; }));
        [view removeFromSuperview];
    }

    {
        NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"webkit-cases"];
        [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
        [html(@"A", @"<a id=l href='b.html'>b</a><a id=m href='c.html#frag'>c</a>") writeToFile:[folder stringByAppendingPathComponent:@"a.html"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        [html(@"B", @"page b") writeToFile:[folder stringByAppendingPathComponent:@"b.html"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        [html(@"C", @"page c") writeToFile:[folder stringByAppendingPathComponent:@"c.html"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSURL *root = [NSURL fileURLWithPath:folder isDirectory:YES];
        NSURL *a = [root URLByAppendingPathComponent:@"a.html"];
        NSURL *b = [root URLByAppendingPathComponent:@"b.html"];
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        NSString *(^scrub)(NSString *) = ^NSString *(NSString *line) { return [[line stringByReplacingOccurrencesOfString:@"file://localhost/" withString:@"file:///"] stringByReplacingOccurrencesOfString:folder withString:@"$"]; };
        void (^settle)(void) = ^{
            spin_until(5, ^BOOL { return watcher.events.count >= 3 && !view.loading; });
            spin(0.5);
        };
        [view loadFileURL:a allowingReadAccessToURL:root];
        settle();
        record(@"history.first", scrub(joined(watcher.events)));
        [watcher.events removeAllObjects];
        [view loadFileURL:b allowingReadAccessToURL:root];
        settle();
        record(@"history.second", scrub(joined(watcher.events)));
        record(@"history.list", scrub([NSString stringWithFormat:@"back=%lu forward=%lu current=%@ backItem=%@", (unsigned long)view.backForwardList.backList.count, (unsigned long)view.backForwardList.forwardList.count, view.backForwardList.currentItem.URL.absoluteString, view.backForwardList.backItem.URL.absoluteString]));
        [watcher.events removeAllObjects];
        [view goBack];
        settle();
        record(@"history.back", scrub(joined(watcher.events)));
        record(@"history.backList", scrub([NSString stringWithFormat:@"back=%lu forward=%lu current=%@", (unsigned long)view.backForwardList.backList.count, (unsigned long)view.backForwardList.forwardList.count, view.backForwardList.currentItem.URL.absoluteString]));
        [watcher.events removeAllObjects];
        [view goForward];
        settle();
        record(@"history.forward", scrub(joined(watcher.events)));
        [watcher.events removeAllObjects];
        [view goBack];
        settle();
        [watcher.events removeAllObjects];
        evaluate(view, @"var e = document.createEvent('MouseEvents'); e.initEvent('click', true, true); document.getElementById('l').dispatchEvent(e); 1");
        settle();
        record(@"history.click", scrub(joined(watcher.events)));
        [watcher.events removeAllObjects];
        [view reload];
        settle();
        record(@"history.reload", scrub(joined(watcher.events)));
        [watcher.events removeAllObjects];
        evaluate(view, @"location.hash = 'z'; 1");
        spin(1);
        record(@"history.fragment", scrub([NSString stringWithFormat:@"%@ || %@", joined(watcher.events), state(view)]));
        [watcher.events removeAllObjects];
        [view stopLoading];
        record(@"history.stop", joined(watcher.events));
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        watcher.policy = ^WKNavigationActionPolicy(WKNavigationAction *action) {
            return [action.request.URL.scheme isEqualToString:@"charon-cancel"] ? WKNavigationActionPolicyCancel : WKNavigationActionPolicyAllow;
        };
        WKWebView *view = make(container, watcher, nil);
        [view loadHTMLString:html(@"T1", @"<a id=l href='charon-cancel://x'>x</a>") baseURL:base];
        spin_until(5, ^BOOL { return !view.loading && view.title.length; });
        spin(0.3);
        [watcher.events removeAllObjects];
        evaluate(view, @"location.href = 'charon-cancel://x'; 1");
        spin(1);
        record(@"cancel.events", joined(watcher.events));
        record(@"cancel.state", state(view));
        [watcher.events removeAllObjects];
        evaluate(view, @"var e = document.createEvent('MouseEvents'); e.initEvent('click', true, true); document.getElementById('l').dispatchEvent(e); 1");
        spin(1);
        record(@"cancel.click", joined(watcher.events));
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        [view loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"charon-none://x/y"]]];
        spin_until(5, ^BOOL { return watcher.events.count >= 3; });
        spin(0.5);
        record(@"bad.events", joined(watcher.events));
        record(@"bad.state", state(view));
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        [view loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"data:text/html,%3Ctitle%3ED%3C/title%3Ehi"]]];
        spin_until(5, ^BOOL { return watcher.events.count >= 4; });
        spin(0.5);
        record(@"data.events", joined(watcher.events));
        record(@"data.state", state(view));
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        WebKitObserver *observer = [[WebKitObserver alloc] init];
        NSArray *keys = @[@"title", @"URL", @"loading", @"canGoBack", @"canGoForward", @"estimatedProgress"];
        for (NSString *key in keys)
            [view addObserver:observer forKeyPath:key options:NSKeyValueObservingOptionNew context:NULL];
        [view loadHTMLString:html(@"T2", @"hello") baseURL:base];
        spin_until(5, ^BOOL { return !view.loading && view.title.length; });
        spin(0.5);
        evaluate(view, @"document.title = 'T3'; 1");
        spin(0.5);
        record(@"kvo.changes", joined(observer.changes));
        for (NSString *key in keys)
            [view removeObserver:observer forKeyPath:key];
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        [configuration.userContentController addScriptMessageHandler:watcher name:@"h"];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:@"document.body.setAttribute('x', 'ran')" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [configuration.userContentController addUserScript:script];
        WKWebView *view = make(container, watcher, configuration);
        [view loadHTMLString:html(@"T1", @"<p>x</p>") baseURL:base];
        spin_until(5, ^BOOL { return !view.loading && view.title.length; });
        spin(0.5);
        record(@"script.ran", evaluate(view, @"document.body.getAttribute('x')"));
        record(@"script.hasHandlers", evaluate(view, @"typeof window.webkit.messageHandlers.h.postMessage"));
        for (NSString *body in @[@"'text'", @"42", @"({a:1,b:[2,3],c:null})", @"[1,'x']", @"true", @"null", @"1.5"])
            evaluate(view, [NSString stringWithFormat:@"window.webkit.messageHandlers.h.postMessage(%@); 1", body]);
        spin(1);
        record(@"message.received", joined(watcher.messages));
        record(@"message.unknown", evaluate(view, @"(function(){ try { window.webkit.messageHandlers.nope.postMessage(1); return 'no throw'; } catch (e) { return 'threw'; } })()"));
        record(@"message.count", [NSString stringWithFormat:@"%lu", (unsigned long)watcher.messages.count]);
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        record(@"early.js", evaluate(view, @"1 + 1"));
        record(@"early.title", evaluate(view, @"document.title"));
        [view loadHTMLString:html(@"T5", @"x") baseURL:nil];
        spin_until(5, ^BOOL { return watcher.events.count >= 3; });
        spin(0.5);
        record(@"nilbase.events", joined(watcher.events));
        record(@"nilbase.state", state(view));
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebView *view = make(container, watcher, nil);
        [view loadData:[html(@"T6", @"data") dataUsingEncoding:NSUTF8StringEncoding] MIMEType:@"text/html" characterEncodingName:@"utf-8" baseURL:base];
        spin_until(5, ^BOOL { return watcher.events.count >= 3; });
        spin(0.5);
        record(@"loaddata.events", joined(watcher.events));
        record(@"loaddata.title", evaluate(view, @"document.title"));
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        [configuration.userContentController addScriptMessageHandler:watcher name:@"dup"];
        NSString *raised = @"none";
        @try {
            [configuration.userContentController addScriptMessageHandler:watcher name:@"dup"];
        } @catch (NSException *exception) {
            raised = exception.name;
        }
        record(@"handler.duplicate", raised);
        [configuration.userContentController removeScriptMessageHandlerForName:@"dup"];
        [configuration.userContentController addScriptMessageHandler:watcher name:@"dup"];
        [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:@"1" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO]];
        record(@"scripts.count", [NSString stringWithFormat:@"%lu", (unsigned long)configuration.userContentController.userScripts.count]);
        [configuration.userContentController removeAllUserScripts];
        record(@"scripts.removed", [NSString stringWithFormat:@"%lu", (unsigned long)configuration.userContentController.userScripts.count]);
        WKWebView *view = make(container, watcher, configuration);
        record(@"config.sameController", view.configuration.userContentController == configuration.userContentController ? @"same" : @"different");
        record(@"config.samePreferences", view.configuration.preferences == configuration.preferences ? @"same" : @"different");
        [view loadHTMLString:html(@"T7", @"x") baseURL:base];
        spin_until(5, ^BOOL { return !view.loading; });
        spin(0.5);
        evaluate(view, @"window.webkit.messageHandlers.dup.postMessage('one'); 1");
        spin(0.5);
        [configuration.userContentController removeScriptMessageHandlerForName:@"dup"];
        record(@"handler.afterRemove", evaluate(view, @"typeof window.webkit.messageHandlers.dup"));
        record(@"handler.messages", joined(watcher.messages));
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        watcher.policy = ^WKNavigationActionPolicy(WKNavigationAction *action) { return WKNavigationActionPolicyAllow; };
        WKWebView *view = make(container, watcher, nil);
        NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"webkit-cases"];
        [html(@"F", @"<iframe id=f src='c.html'></iframe>") writeToFile:[folder stringByAppendingPathComponent:@"f.html"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSURL *root = [NSURL fileURLWithPath:folder isDirectory:YES];
        [view loadFileURL:[root URLByAppendingPathComponent:@"f.html"] allowingReadAccessToURL:root];
        spin_until(5, ^BOOL { return !view.loading; });
        spin(1);
        NSString *joinedEvents = [[[joined(watcher.events) stringByReplacingOccurrencesOfString:@"file://localhost/" withString:@"file:///"] stringByReplacingOccurrencesOfString:folder withString:@"$"] copy];
        record(@"iframe.events", joinedEvents);
        [view removeFromSuperview];
    }

    {
        WebKitWatcher *watcher = [[WebKitWatcher alloc] init];
        watcher.delay = 0.3;
        WKWebView *view = make(container, watcher, nil);
        [view loadHTMLString:html(@"T8", @"x") baseURL:base];
        record(@"async.afterCall", state(view));
        spin_until(5, ^BOOL { return watcher.events.count >= 4; });
        spin(0.5);
        record(@"async.allow", joined(watcher.events));
        record(@"async.state", state(view));
        [watcher.events removeAllObjects];
        watcher.policy = ^WKNavigationActionPolicy(WKNavigationAction *action) { return WKNavigationActionPolicyCancel; };
        [view loadHTMLString:html(@"T9", @"y") baseURL:[NSURL URLWithString:@"https://charon.invalid/second"]];
        spin(1.5);
        record(@"async.cancel", joined(watcher.events));
        record(@"async.cancelState", state(view));
        [view removeFromSuperview];
    }
}
