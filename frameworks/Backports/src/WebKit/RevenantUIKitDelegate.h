#import <Foundation/Foundation.h>

@protocol RevenantRootLayerHandler <NSObject>
- (void)attachRootLayer:(id)rootLayer;
- (void)contentsSizeChanged:(NSValue *)boxedSize;
@end

@interface RevenantUIKitDelegate : NSObject
@property (nonatomic, weak) id<RevenantRootLayerHandler> handler;
@end
