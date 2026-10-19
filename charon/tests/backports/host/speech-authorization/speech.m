#import <Foundation/Foundation.h>
#import <Speech/Speech.h>

int main(void)
{
    @autoreleasepool {
        printf("authorizationStatus: %ld\n", (long)[SFSpeechRecognizer authorizationStatus]);
        SFSpeechRecognizer *r = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
        printf("en-US recognizer: %s\n", r ? "non-nil" : "nil");
        if (r) {
            printf("available: %d\n", r.isAvailable);
            printf("supportsOnDeviceRecognition: %d\n", r.supportsOnDeviceRecognition);
            printf("locale: %s\n", r.locale.localeIdentifier.UTF8String);
            printf("delegate: %s\n", r.delegate ? "set" : "nil");
            printf("queue: %s\n", r.queue ? "set" : "nil");
        }
    }
    return 0;
}
