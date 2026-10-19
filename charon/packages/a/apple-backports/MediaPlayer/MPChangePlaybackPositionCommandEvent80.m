// MPChangePlaybackPositionCommandEvent, the 8.0 command event, and the one property its header declares.
//
// Carried, and for the same reason as the 9.0 event beside it: measured with tools/mach32_methods.py
// against the 6.1.3 cache, no class whose name holds 'CommandEvent' exists in any of its 236 classes and
// none of its 41 categories, with a nonsense selector absent as the control. A class the release does not
// have is new code and cannot shadow anything, so there is nothing native for it to be. `absent` is for a
// member whose answer needs hardware the device lacks, and none of this family needs any.
//
// It is new code over the base MPRemoteCommandCenter71.m already carries. The header line it
// implements, quoted:
//
//   @property (nonatomic, readonly) NSTimeInterval positionTime;
//
// at MP_API(ios(8.0)). The AST says the header declares exactly positionTime for this class, and the
// port declares exactly that and its setter, so a header member the port would not have is none.
//
// Readwrite in the port where the header has it readonly: an event the port builds has to be able to
// carry the position it is an event *about*. The accessor is written out rather than left to the
// synthesiser, so what a caller reads is the port's own code - without that, a mutation that removes
// the @synthesize changes the file and ARC synthesises the same property, and the check stays green with
// the bytes different.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPChangePlaybackPositionCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) NSTimeInterval positionTime;
@end
#else
// The SDK declares this class with its property readonly; the port's events have to be built carrying
// theirs, so it is made writable here, in an extension, and not declared a second time.
@interface MPChangePlaybackPositionCommandEvent ()
@property (nonatomic, assign, readwrite) NSTimeInterval positionTime;
@end
#endif

@implementation MPChangePlaybackPositionCommandEvent
@synthesize positionTime = _positionTime;

- (NSTimeInterval)positionTime {
    return _positionTime;
}

@end
