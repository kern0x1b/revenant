#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <stdio.h>

@interface HostSRKeyboardMetrics : NSObject
- (NSInteger)wordCountForSentimentCategory:(NSInteger)category;
- (NSInteger)emojiCountForSentimentCategory:(NSInteger)category;
@end

@interface HostSRSpeechMetrics : NSObject
- (id)speechRecognition;
- (id)soundClassification;
@end

@interface HostSRSensorReader : NSObject
- (instancetype)init;
@end

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    CFAllocatorRef control = *(CFAllocatorRef *)dlsym(
        dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY),
        "kCFAllocatorDefault");
    printf("CONTROL\tkCFAllocatorDefault\t%s\n",
           control == kCFAllocatorDefault ? "matches the host's own symbol" : "DIFFERS");

    void *lib = dlopen("/System/Library/Frameworks/SensorKit.framework/SensorKit", RTLD_LAZY);
    if (!lib) { printf("SKIP\tthe host has no SensorKit\n"); return 2; }

    HostSRKeyboardMetrics *k = [objc_getClass("SRKeyboardMetrics") alloc];
    if (!k) { printf("SKIP\tthe host declares no SRKeyboardMetrics\n"); return 2; }
    for (int category = 0; category < 10; category++)
        printf("COUNT\t%d\tword=%ld\temoji=%ld\n", category,
               (long)[k wordCountForSentimentCategory:category],
               (long)[k emojiCountForSentimentCategory:category]);

    HostSRSpeechMetrics *s = [objc_getClass("SRSpeechMetrics") alloc];
    if (s) {
        id recognition = [s speechRecognition];
        id classification = [s soundClassification];
        printf("PROPERTY\tspeechRecognition\t%s\n", recognition ? "not nil" : "nil");
        printf("PROPERTY\tsoundClassification\t%s\n", classification ? "not nil" : "nil");
    } else {
        printf("SKIP\tthe host declares no SRSpeechMetrics\n");
    }

    HostSRSensorReader *r = [objc_getClass("SRSensorReader") alloc];
    @try {
        id made = [r init];
        printf("INIT\t%s\n", made ? "returned an object" : "(nil)");
    } @catch (NSException *e) {
        printf("INIT\tRAISES %s: %s\n", [[e name] UTF8String], [[e reason] UTF8String]);
    }
    return 0;
}
