#import <Foundation/Foundation.h>
#include <dlfcn.h>

@interface NSObject (VoiceServicesListing)
+ (NSArray *)availableLanguageCodes;
+ (NSArray *)availableVoices;
+ (BOOL)isSystemSpeaking;
+ (NSArray *)availableVoicesForLanguageCode:(NSString *)code;
@end

static void line(NSString *text)
{
    printf("probe: %s\n", [text UTF8String]);
    fflush(stdout);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        void *voiceServices = dlopen("/System/Library/PrivateFrameworks/VoiceServices.framework/VoiceServices", RTLD_NOW);
        line([NSString stringWithFormat:@"VoiceServices %@", voiceServices ? @"loaded" : [NSString stringWithUTF8String:dlerror()]]);
        Class synthesizer = NSClassFromString(@"VSSpeechSynthesizer");
        line([NSString stringWithFormat:@"VSSpeechSynthesizer %@", synthesizer ? @"present" : @"absent"]);
        if (synthesizer) {
            for (NSString *name in @[@"availableLanguageCodes", @"availableVoices", @"isSystemSpeaking"]) {
                line([NSString stringWithFormat:@"+%@ responds %d", name,
                      [synthesizer respondsToSelector:NSSelectorFromString(name)]]);
            }
            NSArray *codes = [synthesizer availableLanguageCodes];
            line([NSString stringWithFormat:@"availableLanguageCodes (%lu)", (unsigned long)[codes count]]);
            for (id code in codes) {
                NSArray *named = [synthesizer availableVoicesForLanguageCode:code];
                line([NSString stringWithFormat:@"code %@ class %@ voices %@", code, NSStringFromClass([code class]), named]);
            }
            NSArray *voices = [synthesizer availableVoices];
            line([NSString stringWithFormat:@"availableVoices (%lu) %@", (unsigned long)[voices count], voices]);
            line([NSString stringWithFormat:@"isSystemSpeaking %d", [synthesizer isSystemSpeaking]]);
        }
        NSFileManager *files = [NSFileManager defaultManager];
        NSString *tts = @"/System/Library/PrivateFrameworks/VoiceServices.framework/TTSResources";
        NSDirectoryEnumerator *walk = [files enumeratorAtPath:tts];
        NSString *path;
        while ((path = [walk nextObject])) {
            if ([[path lastPathComponent] hasPrefix:@"clc_"]) line([NSString stringWithFormat:@"clc %@", path]);
        }
    }
    return 0;
}
