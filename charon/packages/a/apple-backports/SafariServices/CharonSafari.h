#import <SafariServices/SafariServices.h>

@protocol CharonWebView <NSObject>
@property (nonatomic, assign) id delegate;
@property (nonatomic) BOOL scalesPageToFit;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)stopLoading;
@end

@interface CharonSafariPage : UIViewController
- (instancetype)initWithURL:(NSURL *)URL;
@property (nonatomic, readonly) NSURL *initialURL;
@property (nonatomic, weak) id<SFSafariViewControllerDelegate> delegate;
@property (nonatomic, weak) UIViewController *owner;
@property (nonatomic, strong) UIColor *preferredBarTintColor;
@property (nonatomic, strong) UIColor *preferredControlTintColor;
@property (nonatomic) SFSafariViewControllerDismissButtonStyle dismissButtonStyle;
@property (nonatomic, copy) BOOL (^callbackMatcher)(NSURL *URL);
@property (nonatomic, copy) void (^callback)(NSURL *URL);
@end

@interface SFAuthenticationSession ()
@property (nonatomic, weak) UIWindow *charon_presentationWindow;
@end
