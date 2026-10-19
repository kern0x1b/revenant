#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const char charon_waits_to_minimize_stalling_key;
static const char charon_color_primaries_key;
static const char charon_color_ycbcr_matrix_key;
static const char charon_color_transfer_function_key;

@implementation AVPlayer (CharonAVFoundationPlayAtRate)

- (void)playImmediatelyAtRate:(float)rate
{
    [self setRate:rate];
}

@end

@implementation AVPlayer (CharonAVFoundationWaitsToMinimizeStalling)

- (BOOL)automaticallyWaitsToMinimizeStalling
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_waits_to_minimize_stalling_key);
    return stored ? stored.boolValue : YES;
}

- (void)setAutomaticallyWaitsToMinimizeStalling:(BOOL)automaticallyWaitsToMinimizeStalling
{
    objc_setAssociatedObject(self, &charon_waits_to_minimize_stalling_key,
                             @(automaticallyWaitsToMinimizeStalling), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static NSString *charon_avf_pixel_buffer_attribute(NSString *key)
{
    static NSDictionary *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @{@"PixelFormat": (__bridge id)kCVPixelBufferPixelFormatTypeKey,
                 @"Width": AVVideoWidthKey,
                 @"Height": AVVideoHeightKey,
                 @"IOSurface": (__bridge id)kCVPixelBufferIOSurfacePropertiesKey};
    });
    return keys[key];
}

@implementation AVPlayerItemVideoOutput (CharonAVFoundationOutputSettings)

- (instancetype)initWithOutputSettings:(NSDictionary *)outputSettings
{
    NSMutableDictionary *attributes = nil;
    for (NSString *name in @[@"PixelFormat", @"Width", @"Height", @"IOSurface"]) {
        id value = outputSettings[charon_avf_pixel_buffer_attribute(name)];
        if (!value)
            continue;
        if (!attributes)
            attributes = [NSMutableDictionary dictionary];
        attributes[charon_avf_pixel_buffer_attribute(name)] = value;
    }
    return [self initWithPixelBufferAttributes:attributes];
}

@end

@implementation AVVideoComposition (CharonAVFoundationColorProperties)

- (NSString *)colorPrimaries
{
    return objc_getAssociatedObject(self, &charon_color_primaries_key);
}

- (void)setColorPrimaries:(NSString *)colorPrimaries
{
    objc_setAssociatedObject(self, &charon_color_primaries_key, [colorPrimaries copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)colorYCbCrMatrix
{
    return objc_getAssociatedObject(self, &charon_color_ycbcr_matrix_key);
}

- (void)setColorYCbCrMatrix:(NSString *)colorYCbCrMatrix
{
    objc_setAssociatedObject(self, &charon_color_ycbcr_matrix_key, [colorYCbCrMatrix copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)colorTransferFunction
{
    return objc_getAssociatedObject(self, &charon_color_transfer_function_key);
}

- (void)setColorTransferFunction:(NSString *)colorTransferFunction
{
    objc_setAssociatedObject(self, &charon_color_transfer_function_key, [colorTransferFunction copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
