#import "RevenantImageAsset.h"
#import "RevenantWeak.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantImageAssetKey;

void revenant_image_set_asset(UIImage *image, UIImageAsset *asset)
{
    revenant_weak_set(image, &RevenantImageAssetKey, asset);
}

@implementation UIImage (RevenantAsset8)

- (UIImageAsset *)imageAsset
{
    return revenant_weak_get(self, &RevenantImageAssetKey);
}

@end
