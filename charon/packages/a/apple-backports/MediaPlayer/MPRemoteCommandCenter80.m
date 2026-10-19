#import <MediaPlayer/MediaPlayer.h>

// Split from MPRemoteCommandCenter71.m by introduced release, per band()'s own rule: this file
// holds the classes the registry declares "introduced": "8.0" - MPChangeRepeatModeCommand and
// MPChangeShuffleModeCommand. MPChangePlaybackPositionCommandEvent, the third of them, is in
// MPChangePlaybackPositionCommandEvent80.m, with the host check that holds it: two definitions of one
// class are a duplicate symbol at the link (the gate found it).
// See MPRemoteCommandCenter71.m for the bridge and the classes that fire for real; nothing here
// is ever messaged by this port's own event bridge, since iOS 6's UIEventTypeRemoteControl has no
// repeat-mode, shuffle-mode or scrubbing subtype - these are real, addressable command/event
// objects with real storage, not fabricated ones.

@implementation MPChangeShuffleModeCommand
@synthesize currentShuffleType = _currentShuffleType;
@end

@implementation MPChangeRepeatModeCommand
@synthesize currentRepeatType = _currentRepeatType;
@end
