#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>
#include <string.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: avchannellayout-probe null|tag0|unknown|stereo\n");
            return 2;
        }
        const char *name = argv[1];
        AudioChannelLayout layout;
        memset(&layout, 0, sizeof(layout));
        const AudioChannelLayout *input = &layout;
        if (strcmp(name, "null") == 0) {
            input = NULL;
        } else if (strcmp(name, "tag0") == 0) {
            layout.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions;
        } else if (strcmp(name, "unknown") == 0) {
            layout.mChannelLayoutTag = 0xFFFF0003;
        } else if (strcmp(name, "stereo") == 0) {
            layout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        } else {
            fprintf(stderr, "unknown input: %s\n", name);
            return 2;
        }

        AVAudioChannelLayout *result = nil;
        NSString *exception = @"none";
        AudioChannelLayoutTag tag = 0;
        AVAudioChannelCount channels = 0;
        BOOL answered = NO;
        @try {
            result = [[AVAudioChannelLayout alloc] initWithLayout:input];
            if (result != nil) {
                answered = YES;
                tag = result.layoutTag;
                channels = result.channelCount;
            }
        } @catch (NSException *e) {
            exception = e.name;
        }

        if (answered) {
            printf("%s\tobject\t%s\t0x%08x\t%u\t%s\n", name, NSStringFromClass([result class]).UTF8String,
                   (unsigned)tag, (unsigned)channels, exception.UTF8String);
        } else {
            printf("%s\tnil\t-\t-\t-\t%s\n", name, exception.UTF8String);
        }
    }
    return 0;
}
