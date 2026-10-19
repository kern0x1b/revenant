// SpriteKitScene8.m - SKScene's delegate and its two update hooks of iOS 8, carried for the releases that have no
// SpriteKit at all.
//
// The delegate is weak, as the SDK declares it. A category cannot add storage, so the reference is held by an
// associated object that holds the delegate weakly, and the scene's own object (SpriteKitScene7.m) is not changed by
// this release's members. The two hooks are called by the view once each frame, after the constraints and before the
// frame is finished; the view calls them only when the scene answers the selector, since the release below 8 has none.
#import "CharonSpriteKit.h"
#include <objc/runtime.h>

// A weak reference, held by an associated object so the scene does not own its delegate.
@interface CharonSKWeakReference : NSObject
@property (nonatomic, weak) id object;
@end

@implementation CharonSKWeakReference

@synthesize object = _object;

@end

static const void *CharonSKDelegateKey = &CharonSKDelegateKey;

@implementation SKScene (CharonSpriteKitScene8)

- (id<SKSceneDelegate>)delegate
{
    return ((CharonSKWeakReference *)objc_getAssociatedObject(self, CharonSKDelegateKey)).object;
}

- (void)setDelegate:(id<SKSceneDelegate>)delegate
{
    CharonSKWeakReference *reference = [[CharonSKWeakReference alloc] init];
    reference.object = delegate;
    objc_setAssociatedObject(self, CharonSKDelegateKey, reference, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)didApplyConstraints
{
}

- (void)didFinishUpdate
{
}

@end
