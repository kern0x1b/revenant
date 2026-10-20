#import "RevenantSpriteKit.h"
#include <objc/runtime.h>

@interface RevenantSKWeakReference : NSObject
@property (nonatomic, weak) id object;
@end

@implementation RevenantSKWeakReference

@synthesize object = _object;

@end

static const void *RevenantSKDelegateKey = &RevenantSKDelegateKey;

@implementation SKScene (RevenantSpriteKitScene8)

- (id<SKSceneDelegate>)delegate
{
    return ((RevenantSKWeakReference *)objc_getAssociatedObject(self, RevenantSKDelegateKey)).object;
}

- (void)setDelegate:(id<SKSceneDelegate>)delegate
{
    RevenantSKWeakReference *reference = [[RevenantSKWeakReference alloc] init];
    reference.object = delegate;
    objc_setAssociatedObject(self, RevenantSKDelegateKey, reference, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)didApplyConstraints
{
}

- (void)didFinishUpdate
{
}

@end
