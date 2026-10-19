#import <Speech/Speech.h>

static int requested;

@implementation SFSpeechRecognizer

@dynamic available, locale, supportsOnDeviceRecognition, delegate, defaultTaskHint, queue;

+ (NSSet<NSLocale *> *)supportedLocales
{
    return [NSSet set];
}

+ (SFSpeechRecognizerAuthorizationStatus)authorizationStatus
{
    if (__atomic_load_n(&requested, __ATOMIC_ACQUIRE))
        return SFSpeechRecognizerAuthorizationStatusRestricted;
    return SFSpeechRecognizerAuthorizationStatusNotDetermined;
}

+ (void)requestAuthorization:(void (^)(SFSpeechRecognizerAuthorizationStatus status))handler
{
    __atomic_store_n(&requested, 1, __ATOMIC_RELEASE);
    if (!handler)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handler(SFSpeechRecognizerAuthorizationStatusRestricted);
    });
}

- (nullable instancetype)init
{
    return [self initWithLocale:[NSLocale currentLocale]];
}

- (nullable instancetype)initWithLocale:(NSLocale *)locale
{
    return nil;
}

@end
