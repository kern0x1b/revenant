#import "CharonAVCapture.h"

@implementation AVCaptureDeviceDiscoverySession {
@private
    NSArray *_deviceTypes;
    NSString *_mediaType;
    AVCaptureDevicePosition _position;
    NSArray *_devices;
}

@dynamic supportedMultiCamDeviceSets;

// The -init of the class, which its own header closes with AV_INIT_UNAVAILABLE. Apple's class implements it -
// its own instance method list carries -init at 10.0.1 and at 16.0, where the metaclass never carries +new - and
// what it answers is nil without raising (measured on the host, and read out of the held caches; the reasoning,
// the two header line numbers and the measurements are on the macro itself, in CharonAVCapture.h - named
// there and not here, because a plant on this file replaces that name and a second copy of it in a comment
// would be the copy it replaced).
//
// +new is deliberately NOT defined here: Apple's class does not implement it and every class inherits
// +[NSObject new], so a definition would put a selector in the port's metadata where Apple's class has none and
// answer the caller exactly what NSObject's already answers. That inherited +new reaches this -init, which is why
// +new on this class answers nil as well - the release's answer for both.
CHARON_AVFOUNDATION_UNAVAILABLE_INIT

+ (instancetype)discoverySessionWithDeviceTypes:(NSArray *)deviceTypes mediaType:(NSString *)mediaType position:(AVCaptureDevicePosition)position
{
    return [[self alloc] initCharonWithDeviceTypes:deviceTypes mediaType:mediaType position:position];
}

- (instancetype)initCharonWithDeviceTypes:(NSArray *)deviceTypes mediaType:(NSString *)mediaType position:(AVCaptureDevicePosition)position
{
    if ((self = [super init])) {
        _deviceTypes = [deviceTypes copy];
        _mediaType = mediaType;
        _position = position;
        _devices = charon_capture_devices(deviceTypes, mediaType, position);
    }
    return self;
}

- (NSArray *)devices
{
    return _devices;
}

- (NSString *)description
{
    NSMutableString *types = [NSMutableString string];
    for (NSString *type in _deviceTypes) {
        NSString *name = [type isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera] ? @"WideAngleCamera"
                       : [type isEqualToString:AVCaptureDeviceTypeBuiltInTelephotoCamera] ? @"TelephotoCamera"
                       : [type isEqualToString:CHARON_DUAL_CAMERA_TYPE] ? @"DualCamera"
                       : [type isEqualToString:AVCaptureDeviceTypeBuiltInMicrophone] ? @"Microphone" : type;
        if (types.length)
            [types appendString:@", "];
        [types appendFormat:@"%@", name];
    }
    NSString *position = _position == AVCaptureDevicePositionUnspecified ? @"Unspecified" : _position == AVCaptureDevicePositionBack ? @"Back"
                       : _position == AVCaptureDevicePositionFront ? @"Front" : @"<Unknown>";
    return [NSString stringWithFormat:@"<%@: %p device types: [%@], media type: %@, position: %@>", NSStringFromClass([self class]), self, types,
                                      _mediaType ?: @"Any", position];
}

@end
