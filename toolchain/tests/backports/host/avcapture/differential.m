#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

extern AVCaptureDeviceType const CharonHostAVCaptureDeviceTypeBuiltInMicrophone;
extern AVCaptureDeviceType const CharonHostAVCaptureDeviceTypeBuiltInWideAngleCamera;
extern AVCaptureDeviceType const CharonHostAVCaptureDeviceTypeBuiltInTelephotoCamera;
extern AVCaptureDeviceType const CharonHostAVCaptureDeviceTypeBuiltInDualCamera;

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static NSString *ids(NSArray *devices)
{
    NSMutableArray *names = [NSMutableArray array];
    for (AVCaptureDevice *device in devices)
        [names addObject:device.localizedName];
    return [NSString stringWithFormat:@"[%@]", [names componentsJoinedByString:@", "]];
}

static NSArray *(*discover)(id, SEL, NSArray *, NSString *, AVCaptureDevicePosition) = (NSArray * (*)(id, SEL, NSArray *, NSString *, AVCaptureDevicePosition))objc_msgSend;

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        Class ours = NSClassFromString(@"CharonHostAVCaptureDeviceDiscoverySession");
        NSDictionary *system_types = @{@"mic": AVCaptureDeviceTypeBuiltInMicrophone, @"wide": AVCaptureDeviceTypeBuiltInWideAngleCamera,
                                       @"tele": AVCaptureDeviceTypeBuiltInTelephotoCamera};
        NSDictionary *our_types = @{@"mic": CharonHostAVCaptureDeviceTypeBuiltInMicrophone, @"wide": CharonHostAVCaptureDeviceTypeBuiltInWideAngleCamera,
                                    @"tele": CharonHostAVCaptureDeviceTypeBuiltInTelephotoCamera};
        compare(@"the wide angle constant", AVCaptureDeviceTypeBuiltInWideAngleCamera, CharonHostAVCaptureDeviceTypeBuiltInWideAngleCamera);
        compare(@"the telephoto constant", AVCaptureDeviceTypeBuiltInTelephotoCamera, CharonHostAVCaptureDeviceTypeBuiltInTelephotoCamera);

        for (AVCaptureDevice *device in [AVCaptureDevice devices]) {
            BOOL video = [device hasMediaType:AVMediaTypeVideo];
            if (!video)
                continue;
            NSString *system_kind = [device.deviceType isEqual:AVCaptureDeviceTypeBuiltInWideAngleCamera] ? @"wide"
                                  : [device.deviceType isEqual:AVCaptureDeviceTypeBuiltInMicrophone] ? @"mic" : device.deviceType;
            NSString *ours_type = ((NSString * (*)(id, SEL))objc_msgSend)(device, NSSelectorFromString(@"charonHost_deviceType"));
            NSString *ours_kind = [ours_type isEqual:CharonHostAVCaptureDeviceTypeBuiltInWideAngleCamera] ? @"wide"
                                : [ours_type isEqual:CharonHostAVCaptureDeviceTypeBuiltInMicrophone] ? @"mic" : ours_type;
            compare([NSString stringWithFormat:@"the type of %@ (video %d)", device.localizedName, video], system_kind, ours_kind);
        }

        NSArray *lists = @[@[@"wide"], @[@"mic"], @[@"tele"], @[@"wide", @"mic"], @[@"mic", @"wide"], @[@"tele", @"wide", @"mic"], @[]];
        NSArray *media = @[[NSNull null], AVMediaTypeVideo, AVMediaTypeAudio, AVMediaTypeMuxed];
        for (NSArray *kinds in lists) {
            NSMutableArray *system_list = [NSMutableArray array], *our_list = [NSMutableArray array];
            for (NSString *kind in kinds) {
                [system_list addObject:system_types[kind]];
                [our_list addObject:our_types[kind]];
            }
            for (id type in media) {
                NSString *mediaType = [type isKindOfClass:[NSNull class]] ? nil : type;
                for (AVCaptureDevicePosition position = 0; position <= 2; position++) {
                    NSString *label = [NSString stringWithFormat:@"types %@, media %@, position %ld", [kinds componentsJoinedByString:@"+"], mediaType ?: @"any", (long)position];
                    AVCaptureDeviceDiscoverySession *system = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:system_list mediaType:mediaType position:position];
                    id backport = ((id (*)(id, SEL, NSArray *, NSString *, AVCaptureDevicePosition))objc_msgSend)(ours, NSSelectorFromString(@"discoverySessionWithDeviceTypes:mediaType:position:"), our_list, mediaType, position);
                    compare(label, ids(system.devices), ids(((NSArray * (*)(id, SEL))objc_msgSend)(backport, @selector(devices))));
                }
            }
        }

        AVCaptureDeviceDiscoverySession *system = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInMicrophone]
                                                                                                          mediaType:nil position:AVCaptureDevicePositionUnspecified];
        id backport = ((id (*)(id, SEL, NSArray *, NSString *, AVCaptureDevicePosition))objc_msgSend)(ours, NSSelectorFromString(@"discoverySessionWithDeviceTypes:mediaType:position:"),
                                                                                                        @[CharonHostAVCaptureDeviceTypeBuiltInWideAngleCamera, CharonHostAVCaptureDeviceTypeBuiltInMicrophone], nil, AVCaptureDevicePositionUnspecified);
        NSString *(^scrub)(NSString *) = ^NSString *(NSString *text) {
            text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
            NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
            return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
        };
        compare(@"the description", scrub(system.description), scrub([backport description]));
        AVCaptureDeviceDiscoverySession *front = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInTelephotoCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        id backportFront = ((id (*)(id, SEL, NSArray *, NSString *, AVCaptureDevicePosition))objc_msgSend)(ours, NSSelectorFromString(@"discoverySessionWithDeviceTypes:mediaType:position:"), @[CharonHostAVCaptureDeviceTypeBuiltInTelephotoCamera], AVMediaTypeVideo, AVCaptureDevicePositionFront);
        compare(@"the description with a media type and a position", scrub(front.description), scrub([backportFront description]));

        for (NSString *kind in @[@"wide", @"tele"]) {
            for (id type in media) {
                NSString *mediaType = [type isKindOfClass:[NSNull class]] ? nil : type;
                AVCaptureDevice *system_default = [AVCaptureDevice defaultDeviceWithDeviceType:system_types[kind] mediaType:mediaType position:AVCaptureDevicePositionUnspecified];
                AVCaptureDevice *our_default = ((id (*)(id, SEL, NSString *, NSString *, AVCaptureDevicePosition))objc_msgSend)([AVCaptureDevice class],
                    NSSelectorFromString(@"charonHost_defaultDeviceWithDeviceType:mediaType:position:"), our_types[kind], mediaType, AVCaptureDevicePositionUnspecified);
                compare([NSString stringWithFormat:@"the default device of %@, media %@", kind, mediaType ?: @"any"], system_default.localizedName ?: @"nil", our_default.localizedName ?: @"nil");
            }
        }
        NSString *(^raised)(void (^)(void)) = ^NSString *(void (^block)(void)) {
            @try {
                block();
            } @catch (NSException *exception) {
                NSString *reason = exception.reason;
                NSRange tail = [reason rangeOfString:@"] "];
                return [NSString stringWithFormat:@"%@: %@%@", exception.name, [reason hasPrefix:@"*** +["] ? @"*** +[..] " : @"", tail.location == NSNotFound ? reason : [reason substringFromIndex:NSMaxRange(tail)]];
            }
            return @"nothing";
        };
        compare(@"a nil device type", raised(^{ [AVCaptureDevice defaultDeviceWithDeviceType:nil mediaType:AVMediaTypeVideo position:0]; }),
                raised(^{ ((void (*)(id, SEL, NSString *, NSString *, AVCaptureDevicePosition))objc_msgSend)([AVCaptureDevice class],
                    NSSelectorFromString(@"charonHost_defaultDeviceWithDeviceType:mediaType:position:"), nil, AVMediaTypeVideo, 0); }));
        printf("%d checks, %d failures\n", checks, failures);
        return failures;
    }
}
