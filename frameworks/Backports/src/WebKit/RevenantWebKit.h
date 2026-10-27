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

@protocol WKScriptMessageHandler <NSObject>
@required
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message;
@end

@protocol WKUIDelegate <NSObject>
@optional
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures;
- (void)webView:(WKWebView *)webView runOpenPanelWithParameters:(WKOpenPanelParameters *)parameters initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSArray<NSURL *> *URLs))completionHandler;
- (void)webView:(WKWebView *)webView contextMenuConfigurationForElement:(WKContextMenuElementInfo *)elementInfo completionHandler:(void (^)(UIContextMenuConfiguration *configuration))completionHandler;
@end

@protocol WKDownloadDelegate <NSObject>
@required
- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response suggestedFilename:(NSString *)suggestedFilename completionHandler:(void (^)(NSURL *destination))completionHandler;
@optional
- (void)download:(WKDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler;
- (void)downloadDidFinish:(WKDownload *)download;
- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(NSData *)resumeData;
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
