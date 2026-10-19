#import <Speech/Speech.h>

// The recognizer of iOS 10. No recognizer runs on this device, so no locale is one it can recognize: supportedLocales is
// empty, and a recognizer for any locale is not made, which is the answer the host gives for a locale it does not support
// (tests/backports/host/speech-data, case 10). Nothing here opens the microphone or sends audio anywhere.
//
// The host answers an authorization status of NotDetermined for an application with no usage description, and it ends
// the process when that application asks for authorization, before the handler runs (case 12). Ending the process is not
// an answer an application can act on, and a handler never called leaves it waiting forever. The port answers the request
// once, on a global queue (the header does not promise the main queue), with Restricted: the header's word
// for a device that does not let the application recognize speech. The status reads Restricted from then on, and
// NotDetermined before it, which is the host's answer (case 8). Restricted is the coordinator's decision, not a host
// measurement (facts/Speech/recognizer.md).
static int requested;

@implementation SFSpeechRecognizer

// The instance properties are declared in the header but not carried: no recognizer instance exists on this device, so
// nothing answers them. @dynamic stops the compiler from synthesizing accessors, which would answer the zeros of ivars the
// host never shows; a caller that asks reaches an unrecognized selector (facts/Speech/recognizer.md).
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
    // The locale is not one of supportedLocales, which is empty here, so no recognizer is made for it.
    return nil;
}

@end
