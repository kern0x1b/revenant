#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

extern void revenant_web_bind_scheme(NSString *scheme, id<WKURLSchemeHandler> handler, WKWebView *webView);

@interface RevenantWebURLProtocol : NSURLProtocol

@end
