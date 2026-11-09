#import <AVFoundation/AVFoundation.h>
#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        revenant_check((session.allowHapticsAndSystemSoundsDuringRecording == NO) != revenant_negative, "system sounds and haptics are not allowed during recording by default", @"");
        NSError *error = nil;
        BOOL set = [session setAllowHapticsAndSystemSoundsDuringRecording:YES error:&error];
        revenant_check((set && error == nil && session.allowHapticsAndSystemSoundsDuringRecording == YES) != revenant_negative, "allowing them is accepted and read back", error.description ?: @"");
        set = [session setAllowHapticsAndSystemSoundsDuringRecording:NO error:&error];
        revenant_check((set && error == nil && session.allowHapticsAndSystemSoundsDuringRecording == NO) != revenant_negative, "disallowing them is accepted and read back", error.description ?: @"");
    }
    return revenant_finish();
}
