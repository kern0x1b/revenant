#import "CharonSpriteKit.h"
#include <objc/runtime.h>

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
