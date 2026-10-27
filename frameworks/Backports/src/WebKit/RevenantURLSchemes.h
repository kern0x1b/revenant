#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

// The scheme callbacks and the task a handler receives. The engine loads a scheme through an NSURLProtocol
// scoped to the web view (RevenantWebURLProtocol), so these describe the handler's side of that route.
@protocol WKURLSchemeTask <NSObject>
@property (nonatomic, readonly, copy) NSURLRequest *request;
- (void)didReceiveResponse:(NSURLResponse *)response;
- (void)didReceiveData:(NSData *)data;
- (void)didFinish;
- (void)didFailWithError:(NSError *)error;
@end

@protocol WKURLSchemeHandler <NSObject>
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask;
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask;
@end

extern void revenant_web_bind_scheme(NSString *scheme, id<WKURLSchemeHandler> handler, WKWebView *webView);

@interface RevenantWebURLProtocol : NSURLProtocol

@end
