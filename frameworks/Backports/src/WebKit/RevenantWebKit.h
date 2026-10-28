#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

extern NSString *const RevenantWebKitBridgeScheme;

@protocol RevenantWebKitScriptHost <NSObject>
- (void)revenant_scriptsDidChange;
@end

@protocol WKNavigationDelegate <NSObject>
@optional
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler;
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;
@end

@interface WKUserContentController (RevenantWebKit)
- (NSArray<WKUserScript *> *)revenant_scripts;
- (NSArray<NSString *> *)revenant_handlerNames;
- (id<WKScriptMessageHandler>)revenant_handlerNamed:(NSString *)name;
- (void)revenant_attach:(id<RevenantWebKitScriptHost>)host;
@end

@interface WKNavigation (RevenantWebKit)
@property (nonatomic, copy) NSURLRequest *revenant_request;
@end

@interface WKFrameInfo (RevenantWebKit)
+ (instancetype)revenant_frameWithMainFrame:(BOOL)mainFrame request:(NSURLRequest *)request;
@end

@interface WKSecurityOrigin (RevenantWebKit)
+ (instancetype)revenant_originWithURL:(NSURL *)url;
@end

@interface WKNavigationAction (RevenantWebKit)
+ (instancetype)revenant_actionWithRequest:(NSURLRequest *)request type:(WKNavigationType)type mainFrame:(BOOL)mainFrame;
@end

@interface WKWebViewConfiguration (RevenantURLSchemes)
- (void)revenant_bindURLSchemeHandlersToWebView:(WKWebView *)webView;
@end

@interface WKScriptMessage (RevenantWebKit)
+ (instancetype)revenant_messageWithBody:(id)body name:(NSString *)name webView:(WKWebView *)webView mainFrame:(BOOL)mainFrame;
@end

@interface WKBackForwardListItem (RevenantWebKit)
+ (instancetype)revenant_itemWithURL:(NSURL *)url title:(NSString *)title;
@property (nonatomic, copy) NSString *revenant_title;
@end

@interface WKBackForwardList (RevenantWebKit)
- (void)revenant_setItems:(NSArray<WKBackForwardListItem *> *)items index:(NSInteger)index;
@end

@interface WKNavigationResponse (RevenantWebKit)
+ (WKNavigationResponsePolicy)revenant_policyAllowing:(BOOL)allowed;
@end
