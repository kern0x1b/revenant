/* speech.m - the host's answers for the speech recognizer's state before any permission is asked: the authorization status
 * (read, never requested, so no prompt), and whether the en-US recognizer is available, supports on-device recognition,
 * and what its delegate and queue are. The supported-locale count is left out: it changes with the OS release.
 * facts/Speech/Authorization.md has the reading. */
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
