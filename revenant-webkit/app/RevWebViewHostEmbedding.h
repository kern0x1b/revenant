#import <UIKit/UIKit.h>
@class WebView;

@protocol RevWebViewHostDelegate <NSObject>
@optional
- (void)webViewHost:(id)host didStartLoadWithURLString:(NSString *)urlString;
- (void)webViewHost:(id)host didUpdateProgress:(double)progress;
- (void)webViewHost:(id)host didUpdateTitle:(NSString *)title;
- (void)webViewHost:(id)host didUpdateURLString:(NSString *)urlString canGoBack:(BOOL)canGoBack canGoForward:(BOOL)canGoForward;
- (void)webViewHost:(id)host didFinishLoadWithURLString:(NSString *)urlString canGoBack:(BOOL)canGoBack canGoForward:(BOOL)canGoForward;
- (void)webViewHost:(id)host didFailLoadWithError:(NSError *)error;
- (void)webViewHost:(id)host didScrollToOffsetY:(CGFloat)offsetY tracking:(BOOL)tracking;
@end

@protocol RevWebViewHostControlling <NSObject>
- (void)setHostDelegate:(id<RevWebViewHostDelegate>)delegate;
- (id<RevWebViewHostDelegate>)hostDelegate;
- (void)setEmbeddedContentFrame:(CGRect)frame;
- (void)setStartURLString:(NSString *)urlString;
- (void)loadURLString:(NSString *)urlString;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)stopLoading;
- (WebView *)webView;
@end
