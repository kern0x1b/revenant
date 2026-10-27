#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

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
