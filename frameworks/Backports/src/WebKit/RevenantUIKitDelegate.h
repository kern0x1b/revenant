#import <Foundation/Foundation.h>

// The engine's UIKit delegate: the callbacks that concern the screen, which the engine makes on its
// web thread and this forwards to the handler on the main thread. The engine calls every other
// callback without asking whether it is implemented, so they are all declared here and do nothing.
@protocol RevenantRootLayerHandler <NSObject>
- (void)attachRootLayer:(id)rootLayer;
- (void)contentsSizeChanged:(NSValue *)boxedSize;
@end

@interface RevenantUIKitDelegate : NSObject
@property (nonatomic, weak) id<RevenantRootLayerHandler> handler;
@end
