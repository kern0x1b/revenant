#import <MediaPlayer/MediaPlayer.h>

// Split from MPRemoteCommandCenter71.m by introduced release, per band()'s own rule: this file
// holds the one class the registry declares "introduced": "9.0" - MPChangePlaybackPositionCommand.
// See MPRemoteCommandCenter71.m for the bridge and the classes that fire for real; iOS 6's
// UIEventTypeRemoteControl has no scrubbing subtype, so this port's own bridge never messages it -
// a real, addressable MPRemoteCommand subclass an application can still set a handler on.

@implementation MPChangePlaybackPositionCommand
@end
