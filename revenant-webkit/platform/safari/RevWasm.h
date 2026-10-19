#import <Foundation/Foundation.h>
@class WebView;
@class WebFrame;

@interface RevWasm : NSObject
+ (void)installInWebView:(WebView *)webView forFrame:(WebFrame *)frame;
@end
