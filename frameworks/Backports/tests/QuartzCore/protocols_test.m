#import "../Foundation/check.h"
#import <objc/runtime.h>

@interface RevenantAnimationProbe : NSObject
@end

@implementation RevenantAnimationProbe
@end

static BOOL revenant_optional(Protocol *protocol, SEL selector)
{
    return protocol && protocol_getMethodDescription(protocol, selector, NO, YES).name != NULL;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Protocol *animation = objc_getProtocol("CAAnimationDelegate");
    Protocol *layer = objc_getProtocol("CALayerDelegate");
    revenant_check(animation != NULL, "CAAnimationDelegate is registered", @"objc_getProtocol returns nil");
    revenant_check(layer != NULL, "CALayerDelegate is registered", @"objc_getProtocol returns nil");
    Class probe = [RevenantAnimationProbe class];
    class_addProtocol(probe, animation);
    class_addProtocol(probe, layer);
    revenant_check(class_conformsToProtocol(probe, animation), "a class conforms to CAAnimationDelegate", @"no conformance");
    revenant_check(class_conformsToProtocol(probe, layer), "a class conforms to CALayerDelegate", @"no conformance");
    revenant_check(revenant_optional(animation, @selector(animationDidStart:)), "animationDidStart: is an optional method", @"missing");
    revenant_check(revenant_optional(animation, revenant_negative ? @selector(animationDidFinish:) : @selector(animationDidStop:finished:)), "animationDidStop:finished: is an optional method", @"missing");
    revenant_check(revenant_optional(layer, @selector(displayLayer:)), "displayLayer: is an optional method", @"missing");
    revenant_check(revenant_optional(layer, @selector(drawLayer:inContext:)), "drawLayer:inContext: is an optional method", @"missing");
    revenant_check(revenant_optional(layer, @selector(layerWillDraw:)), "layerWillDraw: is an optional method", @"missing");
    revenant_check(revenant_optional(layer, @selector(layoutSublayersOfLayer:)), "layoutSublayersOfLayer: is an optional method", @"missing");
    revenant_check(revenant_optional(layer, @selector(actionForLayer:forKey:)), "actionForLayer:forKey: is an optional method", @"missing");
    return revenant_finish();
}
