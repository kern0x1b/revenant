#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>

REVENANT_CASE(avfoundation_audio_session_hint)
{
    BOOL flip = (BOOL)negative;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    BOOL other = session.otherAudioPlaying;
    BOOL hint = session.secondaryAudioShouldBeSilencedHint;
    revenant_expect_true(@"the hint that iOS 8 added answers on iOS 6.1.3 and is the other-audio flag that iOS 6 has",
                         (hint == other) != flip, [NSString stringWithFormat:@"hint %d, other audio playing %d", hint, other]);
    revenant_expect_true(@"a session that is not playing has no other audio to silence it for",
                         (hint == NO) != flip, [NSString stringWithFormat:@"hint %d", hint]);
}
