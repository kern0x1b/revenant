#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char charon_url_asset_initialization_options_key;

@implementation AVComposition (CharonAVFoundationURLAssetInitializationOptions)

- (NSDictionary *)URLAssetInitializationOptions
{
    return objc_getAssociatedObject(self, &charon_url_asset_initialization_options_key);
}

- (void)setURLAssetInitializationOptions:(NSDictionary *)URLAssetInitializationOptions
{
    objc_setAssociatedObject(self, &charon_url_asset_initialization_options_key,
                             [URLAssetInitializationOptions copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation AVMutableComposition (CharonAVFoundationURLAssetInitializationOptions)

+ (instancetype)compositionWithURLAssetInitializationOptions:(NSDictionary *)options
{
    AVMutableComposition *composition = [self composition];
    composition.URLAssetInitializationOptions = options;
    return composition;
}

@end
