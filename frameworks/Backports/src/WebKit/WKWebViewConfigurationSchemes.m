#import "RevenantWebKit.h"
#import "RevenantURLSchemes.h"
#import <objc/runtime.h>

static char RevenantSchemeHandlersKey;

@implementation WKWebViewConfiguration (RevenantURLSchemes)

- (void)setURLSchemeHandler:(id<WKURLSchemeHandler>)urlSchemeHandler forURLScheme:(NSString *)urlScheme
{
    NSMutableDictionary *handlers = objc_getAssociatedObject(self, &RevenantSchemeHandlersKey);
    if (!handlers) {
        handlers = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &RevenantSchemeHandlersKey, handlers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSString *key = urlScheme.lowercaseString;
    if (urlSchemeHandler) {
        handlers[key] = urlSchemeHandler;
    } else {
        [handlers removeObjectForKey:key];
    }
    revenant_web_bind_scheme(key, urlSchemeHandler, nil);
}

- (id<WKURLSchemeHandler>)urlSchemeHandlerForURLScheme:(NSString *)urlScheme
{
    return ((NSMutableDictionary *)objc_getAssociatedObject(self, &RevenantSchemeHandlersKey))[urlScheme.lowercaseString];
}

- (void)revenant_bindURLSchemeHandlersToWebView:(WKWebView *)webView
{
    [(NSDictionary *)objc_getAssociatedObject(self, &RevenantSchemeHandlersKey) enumerateKeysAndObjectsUsingBlock:^(NSString *scheme, id<WKURLSchemeHandler> handler, BOOL *stop) {
        revenant_web_bind_scheme(scheme, handler, webView);
    }];
}

@end
