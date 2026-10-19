#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#import "check.h"

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static NSString *names(NSArray *devices)
{
    NSMutableArray *found = [NSMutableArray array];
    for (AVCaptureDevice *device in devices)
        [found addObject:device.localizedName];
    return [found componentsJoinedByString:@", "];
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of((__bridge const void *)[AVCaptureDeviceDiscoverySession class]), @"libAVFoundationBackports.dylib",
                    "AVCaptureDeviceDiscoverySession comes from the backports library");
        CHECK_EQUAL(image_of((const void *)[AVCaptureDevice methodForSelector:@selector(defaultDeviceWithDeviceType:mediaType:position:)]),
                    @"libAVFoundationBackports.dylib", "and +defaultDeviceWithDeviceType:mediaType:position:");
        CHECK(AVCaptureDeviceTypeBuiltInMicrophone && [AVCaptureDeviceTypeBuiltInMicrophone isEqual:@"AVCaptureDeviceTypeBuiltInMicrophone"]
              && [AVCaptureDeviceTypeBuiltInWideAngleCamera isEqual:@"AVCaptureDeviceTypeBuiltInWideAngleCamera"]
              && [AVCaptureDeviceTypeBuiltInTelephotoCamera isEqual:@"AVCaptureDeviceTypeBuiltInTelephotoCamera"]
              && [AVCaptureDeviceTypeBuiltInDualCamera isEqual:@"AVCaptureDeviceTypeBuiltInDualCamera"],
              "the four device types have the strings read off iOS 10.3.4");

        NSArray *video = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        NSArray *audio = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
        printf("this device has %lu cameras (%s) and %lu microphones (%s)\n", (unsigned long)video.count, names(video).UTF8String,
               (unsigned long)audio.count, names(audio).UTF8String);
        CHECK(video.count > 0 && audio.count > 0, "the device has a camera and a microphone");

        BOOL typed = YES;
        for (AVCaptureDevice *device in video)
            typed = typed && [device.deviceType isEqual:AVCaptureDeviceTypeBuiltInWideAngleCamera];
        for (AVCaptureDevice *device in audio)
            typed = typed && [device.deviceType isEqual:AVCaptureDeviceTypeBuiltInMicrophone];
        CHECK(typed, "every camera is the wide angle camera and every microphone the built-in one");

        NSArray *wide = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
        AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:wide mediaType:nil position:AVCaptureDevicePositionUnspecified];
        NSArray *ordered = [session.devices sortedArrayUsingComparator:^NSComparisonResult(AVCaptureDevice *a, AVCaptureDevice *b) {
            return a.position < b.position ? NSOrderedAscending : a.position > b.position ? NSOrderedDescending : NSOrderedSame;
        }];
        BOOL sameCount = session.devices.count == video.count, inOrder = [session.devices isEqualToArray:ordered];
        CHECK(sameCount && inOrder, "a search for the wide angle camera finds every camera, back before front");
        for (AVCaptureDevicePosition position = AVCaptureDevicePositionBack; position <= AVCaptureDevicePositionFront; position++) {
            NSArray *expected = [video filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AVCaptureDevice *device, NSDictionary *bindings) {
                return device.position == position;
            }]];
            NSArray *found = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:wide mediaType:AVMediaTypeVideo position:position].devices;
            CHECK([found isEqualToArray:expected], ([[NSString stringWithFormat:@"a search for position %ld finds only the cameras there: %@", (long)position, names(found)] UTF8String]));
        }
        CHECK(([AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInTelephotoCamera, AVCaptureDeviceTypeBuiltInDualCamera]
                                                                       mediaType:nil position:AVCaptureDevicePositionUnspecified].devices.count == 0),
              "a search for the telephoto or the dual camera finds nothing, as there are none");
        CHECK(([AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[] mediaType:nil position:AVCaptureDevicePositionUnspecified].devices.count == 0
              && [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:nil mediaType:nil position:AVCaptureDevicePositionUnspecified].devices.count == 0),
              "and so does one for no types at all");
        CHECK(([AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:wide mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified].devices.count == 0
              && [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:wide mediaType:AVMediaTypeMuxed position:AVCaptureDevicePositionUnspecified].devices.count == 0),
              "a camera is not found for the audio or the muxed media type");
        AVCaptureDeviceDiscoverySession *microphone = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio
                                                                                                             position:AVCaptureDevicePositionUnspecified];
        CHECK([microphone.devices isEqualToArray:audio], "a search for the built-in microphone finds the microphone");

        NSArray *both = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone, AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                                mediaType:nil position:AVCaptureDevicePositionUnspecified].devices;
        NSArray *other = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInMicrophone]
                                                                                mediaType:nil position:AVCaptureDevicePositionUnspecified].devices;
        CHECK(both.count == video.count + audio.count && [[both firstObject] hasMediaType:AVMediaTypeAudio] && [[other firstObject] hasMediaType:AVMediaTypeVideo],
              "the devices come in the order of the types given");

        AVCaptureDevice *front = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        AVCaptureDevice *any = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:nil position:AVCaptureDevicePositionUnspecified];
        CHECK(front && front.position == AVCaptureDevicePositionFront && any == [session.devices firstObject],
              "the default device is the first that fits: the front camera for the front, the back camera for any");
        CHECK([AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInTelephotoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack] == nil,
              "and there is none for a type the device does not have");
        CHECK_EQUAL(raised(^{ [AVCaptureDevice defaultDeviceWithDeviceType:nil mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack]; }),
                    @"NSInvalidArgumentException: *** +[AVCaptureDevice defaultDeviceWithDeviceType:mediaType:position:] The deviceType cannot be nil",
                    "a nil device type raises with the text of the release");

        NSString *description = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInMicrophone]
                                                                                        mediaType:nil position:AVCaptureDevicePositionFront].description;
        CHECK([description hasSuffix:@" device types: [WideAngleCamera, Microphone], media type: Any, position: Front>"], "the description reads as the release's does");

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
