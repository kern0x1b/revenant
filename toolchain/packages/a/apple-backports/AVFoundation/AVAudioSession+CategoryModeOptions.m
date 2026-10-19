#import <AVFoundation/AVFoundation.h>

@implementation AVAudioSession (CharonCategoryModeOptions)

- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError
{
    BOOL categoryOK = [self setCategory:category withOptions:options error:outError];
    if (!categoryOK)
        return NO;

    AVAudioSessionCategoryOptions dropped = options & ~self.categoryOptions;
    if (dropped != 0) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"AVAudioSession.setCategory:mode:options:error: is kept and only partly applied on iOS 6: option bits 0x%lx were accepted without error and then silently dropped by the release's own -setCategory:withOptions:error: - measured against categoryOptions readback, not assumed",
                  (unsigned long)dropped);
        });
    }

    NSError *modeError = nil;
    BOOL modeOK = [self setMode:mode error:&modeError];
    if (!modeOK && outError)
        *outError = modeError;
    return modeOK;
}

@end
