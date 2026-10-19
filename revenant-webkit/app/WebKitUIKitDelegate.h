#import <Foundation/Foundation.h>
#import <WebKitLegacy/WebFrame.h>
#import <WebKitLegacy/WebView.h>
#import <WebKitLegacy/WAKView.h>
#import <WebKitLegacy/DOM.h>

@protocol WebKitRootLayerHandler <NSObject>
- (void)attachRootLayer:(id)rootLayer;
- (void)contentsSizeChanged:(NSValue *)boxedSize;
@end

@interface WebKitUIKitDelegate : NSObject
@property (nonatomic, assign) id<WebKitRootLayerHandler> handler;
@end
