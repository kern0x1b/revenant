#import "RevenantAVCapture.h"

@implementation AVCaptureDeviceDiscoverySession {
@private
    NSArray *_deviceTypes;
    NSString *_mediaType;
    AVCaptureDevicePosition _position;
    NSArray *_devices;
}

@dynamic supportedMultiCamDeviceSets;

REVENANT_AVFOUNDATION_UNAVAILABLE_INIT

+ (instancetype)discoverySessionWithDeviceTypes:(NSArray *)deviceTypes mediaType:(NSString *)mediaType position:(AVCaptureDevicePosition)position
{
    return [[self alloc] initRevenantWithDeviceTypes:deviceTypes mediaType:mediaType position:position];
}

- (instancetype)initRevenantWithDeviceTypes:(NSArray *)deviceTypes mediaType:(NSString *)mediaType position:(AVCaptureDevicePosition)position
{
    if ((self = [super init])) {
        _deviceTypes = [deviceTypes copy];
        _mediaType = mediaType;
        _position = position;
        _devices = revenant_capture_devices(deviceTypes, mediaType, position);
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
                       : [type isEqualToString:REVENANT_DUAL_CAMERA_TYPE] ? @"DualCamera"
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
