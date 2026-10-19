#import <AVKit/AVKit.h>
#import <Foundation/Foundation.h>

int main(void)
{
    @autoreleasepool {
        NSArray<AVPlaybackSpeed *> *speeds = [AVPlaybackSpeed systemDefaultSpeeds];
        printf("locale: %s\n", [[NSLocale currentLocale].localeIdentifier UTF8String]);
        printf("count: %lu\n", (unsigned long)speeds.count);
        for (AVPlaybackSpeed *speed in speeds) {
            printf("speed: rate=%.6g name=%s numeric=%s\n",
                   (double)speed.rate,
                   speed.localizedName.UTF8String,
                   speed.localizedNumericName.UTF8String);
        }
        AVPlaybackSpeed *made = [[AVPlaybackSpeed alloc] initWithRate:1.75f localizedName:@"port probe"];
        printf("made: rate=%.6g name=%s numeric=%s\n",
               (double)made.rate,
               made.localizedName.UTF8String,
               made.localizedNumericName.UTF8String ? made.localizedNumericName.UTF8String : "(nil)");
    }
    return 0;
}
