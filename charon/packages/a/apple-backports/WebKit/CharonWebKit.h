#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

extern NSString *const CharonWebKitBridgeScheme;

@protocol CharonWebKitScriptHost <NSObject>
- (void)charon_scriptsDidChange;
@end

@interface WKUserContentController (CharonWebKit)
- (NSArray<WKUserScript *> *)charon_scripts;
- (NSArray<NSString *> *)charon_handlerNames;
- (id<WKScriptMessageHandler>)charon_handlerNamed:(NSString *)name;
- (void)charon_attach:(id<CharonWebKitScriptHost>)host;
@end

@interface WKNavigation (CharonWebKit)
@property (nonatomic, copy) NSURLRequest *charon_request;
@end

@interface WKFrameInfo (CharonWebKit)
+ (instancetype)charon_frameWithMainFrame:(BOOL)mainFrame request:(NSURLRequest *)request;
@end

@interface WKNavigationAction (CharonWebKit)
+ (instancetype)charon_actionWithRequest:(NSURLRequest *)request type:(WKNavigationType)type mainFrame:(BOOL)mainFrame;
@end

@interface WKScriptMessage (CharonWebKit)
+ (instancetype)charon_messageWithBody:(id)body name:(NSString *)name webView:(WKWebView *)webView mainFrame:(BOOL)mainFrame;
@end

@interface WKBackForwardListItem (CharonWebKit)
+ (instancetype)charon_itemWithURL:(NSURL *)url title:(NSString *)title;
@property (nonatomic, copy) NSString *charon_title;
@end

@interface WKBackForwardList (CharonWebKit)
- (void)charon_setItems:(NSArray<WKBackForwardListItem *> *)items index:(NSInteger)index;
@end
