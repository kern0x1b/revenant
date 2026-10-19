#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// iOS 9's AVFoundation on 6.1.3: two rows of the 27 that this slice carries, and they are one pair -
// the options a composition remembers for the asset it was made from, and the factory that sets them.
//
// AVComposition.URLAssetInitializationOptions carries the dictionary AVComposition.h documents for
// +[AVURLAsset URLAssetWithURL:options:], and 6.1.3's AVComposition carries -naturalSize, -duration and
// -tracks among its six own instance methods and no member for it, while 6.1.3's AVURLAsset carries
// -initWithURL:options: and +URLAssetWithURL:options: among its 37 own instance and 7 own class
// methods. So the value is carried on the composition and handed to the asset factory that understands
// it, which is the whole of what the two rows do.
//
// The other 25 rows are absent with the measurement in each row, and none of them is a forward this
// release could answer: see facts/AVFoundation/AVFoundation90.md.

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