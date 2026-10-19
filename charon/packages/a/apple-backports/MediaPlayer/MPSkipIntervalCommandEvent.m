// MPSkipIntervalCommandEvent, the 7.1 command event, and the one property its header declares.
//
// Carried, and for the same reason as its siblings: measured with tools/mach32_methods.py against the
// 6.1.3 cache, no class whose name holds 'CommandEvent' exists in any of its 236 classes and none of its
// 41 categories, with a nonsense selector absent as the control. A class the release does not have is new
// code and cannot shadow anything, so there is nothing native for it to be. `absent` is for a member
// whose answer needs hardware the device lacks, and none of this family needs any.
//
// New code over the base MPRemoteCommandCenter71.m already carries. The header line it implements:
//
//   @property (nonatomic, readonly) NSTimeInterval interval;
//
// at MP_API(ios(7.1)). The AST says the header declares exactly interval for this class, and the
// port declares exactly that and its setter, so a header member the port would not have is none.
//
// Readwrite in the port where the header has it readonly: an event the port builds has to be able to
// carry the interval it is an event *about*. The accessor is written out rather than left to the
// synthesiser, so what a caller reads is the port's own code and mutating it changes what a caller reads
// rather than only the bytes.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPSkipIntervalCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) NSTimeInterval interval;
@end
#else
// The SDK declares this class with its property readonly; the port's events have to be built carrying
// theirs, so it is made writable here, in an extension, and not declared a second time.
@interface MPSkipIntervalCommandEvent ()
@property (nonatomic, assign, readwrite) NSTimeInterval interval;
@end
#endif

@implementation MPSkipIntervalCommandEvent
@synthesize interval = _interval;

- (NSTimeInterval)interval {
    return _interval;
}

@end
