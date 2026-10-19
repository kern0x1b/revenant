#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// Every method below is one the 16.4 SDK declares on its own class and places at iOS 10, and the
// release this object is built for has no such member; the same diagnostic for that is what
// AVCaptureDevice+VideoZoom7.m:7 already carries.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// AVPlayerItemOutput.h:200 marks -initWithOutputSettings: as this class's designated initializer and
// AVPlayerItemOutput.h:179 marks -initWithPixelBufferAttributes: as one of the superclass's, so clang
// reads a category initializer that hands its argument to the pixel-buffer attributes as a chain it
// did not ask for. The mapping is the whole of the method: AVPlayerItemOutput.h:185 says the argument
// is the client requirements for output CVPixelBuffers "expressed using the constants in
// AVVideoSettings.h", and those constants are the pixel buffer attributes.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// iOS 10's AVFoundation on 6.1.3: the three of the 28 rows at 10.0 that 6.1.3 has the substrate for,
// and the seven value properties of the same 28 that it can carry but cannot apply.
//
//   -[AVPlayerItemVideoOutput initWithOutputSettings:]  the release's own
//     -initWithPixelBufferAttributes: (AVPlayerItemOutput.h:179) with the pixel buffer attributes read
//     out of the settings, which is what the SDK says the argument means (AVPlayerItemOutput.h:185,
//     "expressed using the constants in AVVideoSettings.h").
//   -[AVPlayer playImmediatelyAtRate:]                  the release's own -setRate: (AVPlayer.h), which
//     begins playback at the rate it is given; AVPlayer.h:307 says the method exists to make the rate
//     take effect and play what is buffered.
//   the six colour properties and AVPlayer.automaticallyWaitsToMinimizeStalling are inert: 6.1.3 takes
//     the colour of a composition from the track's own format description and takes the buffer wait
//     from its own -play, so nothing on this release reads either value.
//
// The rest of the 28 are absent with the measurement in each row, and the seven rows at 10.3 are the
// FairPlay content-key machinery, none of which class exists on this release. See
// facts/AVFoundation/AVFoundation100.md.

static const char charon_waits_to_minimize_stalling_key;
static const char charon_color_primaries_key;
static const char charon_color_ycbcr_matrix_key;
static const char charon_color_transfer_function_key;

@implementation AVPlayer (CharonAVFoundationPlayAtRate)

- (void)playImmediatelyAtRate:(float)rate
{
    // A non-zero rate on a player that is not playing begins playback at that rate, which is the
    // release's own documented behaviour of -setRate: and the whole of what this method asks for.
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

// The keys of AVVideoSettings.h that name a pixel buffer attribute, and the AVVideoSettings key each
// of them comes from. AVVideoWidthKey and AVVideoHeightKey read 4.0 and kCVPixelBufferPixelFormatTypeKey
// reads 3.0 in 6.1.3, so every symbol here is one the release exports.
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
    // No attribute the settings name: the release's own -initWithPixelBufferAttributes: with nil
    // attributes picks the pixel format for the item, which is what a caller that named none wants.
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