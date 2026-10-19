// The HOST's own answers for the five value-object members, measured once and printed, so the port's
// answers have something to be equal to.
//
// This is the only part of this harness that touches the host, and it exists because the other part
// cannot: SRKeyboardMetrics, SRSpeechMetrics and SRFaceMetrics are all API_UNAVAILABLE(macos) in the
// host's SDK, so a typed call cannot name them and the port's CharonSensorKit.h cannot be compiled
// against that SDK at all. What the host does answer is this, and it is worth writing down:
//
//   - both counts answer 0 for all ten SRKeyboardMetricsSentimentCategory cases,
//   - both speech properties answer nil for a metrics object with no session,
//   - and -[SRSensorReader init] RAISES NSInternalInconsistencyException with the message
//     "Use initWithSensor:", which is Apple's own text. The port raises it too, and all eighteen
//     classes whose headers close the pair are measured and held in tests/backports/host/unavailable-init.
//
// The interfaces are written here rather than imported because the imported ones are unavailable, and
// the receiver comes from objc_getClass for the same reason. performSelector: is NOT used for the
// counts: it carries an NSInteger return as garbage, which measured as ten lines of "(nil)" here before
// the declarations were written out, and a garbage number read as zero would have agreed with the port
// for the wrong reason.
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

    // The ten cases of SRKeyboardMetricsSentimentCategory, SRKeyboardMetrics.h:283 to :292.
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