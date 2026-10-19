#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>
#import <objc/message.h>

static AVAuthorizationStatus charon_media_status(NSString *mediaType, SEL caller, Class receiver)
{
    if ([mediaType isEqualToString:AVMediaTypeAudio])
        return AVAuthorizationStatusAuthorized;
    if (![mediaType isEqualToString:AVMediaTypeVideo]) {
        NSString *reason = [NSString stringWithFormat:@"*** +[%@ %@] The passed media type '%@' is not supported", NSStringFromClass(receiver), NSStringFromSelector(caller), mediaType];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
    }
    static dispatch_once_t once;
    static Class connection;
    static NSString *setting;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration", RTLD_LAZY);
        NSString *__unsafe_unretained *feature = handle ? (NSString *__unsafe_unretained *)dlsym(handle, "MCFeatureCameraAllowed") : NULL;
        connection = NSClassFromString(@"MCProfileConnection");
        setting = feature ? *feature : nil;
    });
    if (connection && setting) {
        id shared = ((id (*)(id, SEL))objc_msgSend)(connection, sel_registerName("sharedConnection"));
        SEL effective = sel_registerName("effectiveBoolValueForSetting:");
        if ([shared respondsToSelector:effective] && ((int (*)(id, SEL, id))objc_msgSend)(shared, effective, setting) == 2)
            return AVAuthorizationStatusRestricted;
    }
    return AVAuthorizationStatusAuthorized;
}

@implementation AVCaptureDevice (CharonAuthorization)

+ (AVAuthorizationStatus)authorizationStatusForMediaType:(NSString *)mediaType
{
    return charon_media_status(mediaType, _cmd, self);
}

+ (void)requestAccessForMediaType:(NSString *)mediaType completionHandler:(void (^)(BOOL granted))handler
{
    AVAuthorizationStatus status = charon_media_status(mediaType, _cmd, self);
    void (^kept)(BOOL) = [handler copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (kept)
            kept(status == AVAuthorizationStatusAuthorized);
    });
}

@end
