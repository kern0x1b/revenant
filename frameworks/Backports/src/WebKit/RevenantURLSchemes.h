#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

// WKURLSchemeHandler and WKURLSchemeTask come from the SDK's WebKit headers, which <WebKit/WebKit.h> imports above.

extern void revenant_web_bind_scheme(NSString *scheme, id<WKURLSchemeHandler> handler, WKWebView *webView);

@interface RevenantWebURLProtocol : NSURLProtocol

@end
