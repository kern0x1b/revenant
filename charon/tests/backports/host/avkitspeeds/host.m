// host.m — what the system's own AVKit answers for AVPlaybackSpeed, so the port's copy is measured
// and not invented. Prints one line per speed and one summary line; the port's own values are read
// back the same way by check_records.py, which was deleted with no caller left.
//
// The three values per speed are the ones the port cannot reason its way to: the rate is a float the
// system chose, and the two names are localized strings. Nothing here is a stub and nothing is a
// constant we typed: every line is a value read out of the framework this links.
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
        // A speed the port also has to answer: the public initialiser's two arguments, echoed back.
        AVPlaybackSpeed *made = [[AVPlaybackSpeed alloc] initWithRate:1.75f localizedName:@"port probe"];
        printf("made: rate=%.6g name=%s numeric=%s\n",
               (double)made.rate,
               made.localizedName.UTF8String,
               made.localizedNumericName.UTF8String ? made.localizedNumericName.UTF8String : "(nil)");
    }
    return 0;
}
