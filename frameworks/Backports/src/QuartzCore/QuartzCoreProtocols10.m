#import <Foundation/Foundation.h>

@class CAAnimation, CALayer;
@protocol CAAction;
typedef struct CGContext *CGContextRef;

@protocol CAAnimationDelegate <NSObject>
@optional
- (void)animationDidStart:(CAAnimation *)anim;
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag;
@end

@protocol CALayerDelegate <NSObject>
@optional
- (void)displayLayer:(CALayer *)layer;
- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx;
- (void)layerWillDraw:(CALayer *)layer;
- (void)layoutSublayersOfLayer:(CALayer *)layer;
- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event;
@end

__attribute__((used)) static void revenantEmitProtocols(void)
{
    (void)@protocol(CAAnimationDelegate);
    (void)@protocol(CALayerDelegate);
}
