// probe.m -- the speech voices the release carries, read in the guest. It asks VoiceServices' own class
// (VSSpeechSynthesizer, found by name at run time: the probe is not linked against a private framework) for the
// voice list and the language codes, and lists the voice-shaped files on the image. It prints what the release
// answers; it chooses no voice and types no list. Every line starts with "probe:" so the run's log can be read.
#import <Foundation/Foundation.h>
#include <dlfcn.h>

// The three class methods the release answers, declared here by name and not by a private header; the class itself
// is looked up at run time.
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
        // VoiceServices is not linked into a process by default: load it, then look the class up by name.
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
        // The synthesizer voices the image carries: each clc_<language>_<voice>_cfg1.dat names one, so the names are
        // read from the file names (the language-only clc_<language>_cfg1.dat is the language, not a voice).
        NSString *tts = @"/System/Library/PrivateFrameworks/VoiceServices.framework/TTSResources";
        NSDirectoryEnumerator *walk = [files enumeratorAtPath:tts];
        NSString *path;
        while ((path = [walk nextObject])) {
            if ([[path lastPathComponent] hasPrefix:@"clc_"]) line([NSString stringWithFormat:@"clc %@", path]);
        }
    }
    return 0;
}
