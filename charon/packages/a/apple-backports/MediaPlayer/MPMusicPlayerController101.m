// -[MPMusicPlayerController prepareToPlayWithCompletionHandler:], the 10.1 member, and nothing else.
//
// MPMusicPlayerController.h at SDK 26.2 is the whole contract, quoted:
//
//   - (void)prepareToPlayWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler MP_API(ios(10.1), tvos(14.0));
//
// and the release's own, measured in the 6.1.3 cache:
//
//   -[MPMusicPlayerController prepareToPlay]
//
// iOS 6.1.3 has the void-returning `-prepareToPlay` and not this one. The port bridges them.
//
// THE SHAPE DIFFERENCE, which is the only thing this has to get right. Apple's takes a handler and
// reports the queue's failure through it; the release's returns nothing, so the port cannot report a
// failure it is never told about. It answers the handler with **nil**, which is Apple's own spelling of
// success - `NSError *_Nullable` - and not a fabricated error object. A caller that only checks for nil,
// which is what Apple's documentation tells callers to do, gets the answer it gets on a working queue.
//
// That honesty has a cost and it is stated rather than hidden: on a queue the release fails to prepare,
// this answers nil where Apple's would answer an error. There is no public way to learn that on this
// release - `-[MPMusicPlayerController playbackState]` is the release's own answer to a different question,
// and reading it to synthesise an error would be inventing a failure Apple's own accessor never reports.
// So the port reports what it is told, which is nothing, and that means nil.
//
// MEASURED, read with tools/mach32_methods.py from the armv7 cache of 6.1.3 (MediaPlayer image at
// 0x31fe3000):
//   - MPMusicPlayerController has 64 own instance methods and 5 own class methods; `-prepareToPlay` is among
//     the 64 and `prepareToPlayWithCompletionHandler:` is not among them.
//   - all 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS and none extends
//     MPMusicPlayerController, so nothing here clobbers a release method and nothing in the release clobbers
//     this one. -aSelectorNoFrameworkHas is absent as the control.
//   - `prepareToPlayWithCompletionHandler:` is on NO line of the release's whole-cache selector list (113981
//     distinct names), so no class anywhere in 6.1.3 declares it.
//
// THE CALL IS THE RELEASE'S OWN, by message and not by symbol: `-prepareToPlay` is called through
// `objc_msgSend` with the selector registered by name, which is the idiom this file's siblings in
// MPRemoteCommandCenter71.m already use and the only one available - the release's selector is in the
// runtime's table, so the call resolves on the device.
//
// One object per release, per band()'s own rule: this file holds the 10.1 member. The 9.3 and 8.0 siblings
// that belong to the same class, and the 10.3 queue-descriptor ones, are objects of their own.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif
#import <objc/message.h>

#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The SDK's own declaration is not available to the stand-in build, so the contract is restated for it -
// read from MPMusicPlayerController.h above, not invented for the check to pass - together with the one
// release accessor it bridges, so the check can see the bridge happen rather than trust that it does.
@interface MPMusicPlayerController : NSObject
- (void)prepareToPlay;
@end
@interface MPMusicPlayerController (Charon101)
- (void)prepareToPlayWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler;
@end
#endif

// A CATEGORY on a class the release owns, not an @implementation of it - written as a bare
// `@implementation MPMusicPlayerController` it would claim the release's 64 instance and 5 class methods.
@implementation MPMusicPlayerController (Charon101)

- (void)prepareToPlayWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler {
    // The release's own accessor, by selector: the release's -prepareToPlay is in the runtime's table on
    // the device, so registering the name and messaging it is what reaches the release's method rather
    // than a symbol this object file cannot link against. objc_msgSend is used directly because ARC
    // forbids sending through a typed pointer whose type is not the method's own.
    ((void (*)(id, SEL))objc_msgSend)(self, sel_registerName("prepareToPlay"));

    if (completionHandler) {
        // nil is Apple's spelling of success for `NSError *_Nullable`, and the release's -prepareToPlay
        // returns void, so there is no failure it reported and none this may invent.
        completionHandler(nil);
    }
}

@end