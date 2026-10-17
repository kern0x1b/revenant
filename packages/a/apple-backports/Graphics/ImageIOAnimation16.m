// CGAnimateImageAtURLWithBlock and CGAnimateImageDataWithBlock: the animation pair, over the release's own
// CGImageSource, which is what decodes and indexes the frames.
//
// WHICH RELEASE THIS OBJECT IS: 16.0, and it is a new object of a family GraphicsBackports already has
// twenty-eight objects of. tools/cache-index/first-rung.lua over the 50 held rungs puts
// _CGAnimateImageAtURLWithBlock, _CGAnimateImageDataWithBlock and the three kCGImageAnimation... names at
// 16.0 and on no rung below it, which is what makes this a 16.0-band object and not a 13.0 one: the SDK
// annotates the pair 13.0, and the ladder the answer comes from has no rung between 13.0 and 16.0. It is not
// a split of anything already carried - nothing else in the tree defines either function.
//
// WHAT IT DOES, AND EVERY PART OF IT MEASURED ON THE HOST'S OWN ImageIO on 2026-10-03
// (tests/backports/host/imageio-animate/, which builds this object and the host's ImageIO into two
// programs and compares them case by case):
//
//   * THE FUNCTION RETURNS BEFORE THE FIRST FRAME IS DRAWN, unless there is only one frame. Measured: for
//     a two- and a three-frame file the host answers 0 with no call at all and the first call arrives within
//     a millisecond of that return, while a ONE-frame file has its frame drawn inside the call and a loop
//     count of three still draws it once. So the animation is a timer on the main run loop and not a loop
//     here: the header describes the block as called on the main queue, at intervals set by the delay
//     time of each image.
//   * THE FRAME ORDER IS THE FILE'S, and it wraps: index 0, 1, 2, 0, 1, ... for a three-frame file, and the
//     block is handed the frame the release's own CGImageSourceCreateImageAtIndex decodes at that index
//     (the harness compares the pixels, not only the index).
//   * EACH FRAME IS GIVEN ITS OWN DELAY, read out of that frame's own {GIF} dictionary: a file whose
//     frames declare 0.1, 0.3 and 0.5 seconds is drawn with gaps of 0.104, 0.301 and 0.507 measured. The
//     delay that decides is kCGImagePropertyGIFDelayTime and not kCGImagePropertyGIFUnclampedDelayTime: a
//     file written with a delay of 0.005 answers DelayTime 0.1 and UnclampedDelayTime 0.01 and is drawn at
//     0.104. A frame with no delay at all answers 0.1, which is ImageIO's own default and needs nothing
//     here to invent it.
//   * IT LOOPS FOREVER unless kCGImageAnimationLoopCount says otherwise: one loop of a three-frame file is
//     exactly three calls and two loops are exactly six. The GIF dictionary's own kCGImagePropertyGIFLoopCount
//     is NOT read - a file that says "loop forever" and a file that says "one loop" both animate forever
//     when no option is given (measured, both).
//   * kCGImageAnimationStartIndex is read: 1 on a three-frame file draws 1, 2, 0, 1. A negative index draws
//     from 0, which is what the host does.
//   * kCGImageAnimationDelayTime IS READ OUT AND NOT USED, because the host ignores it: a file whose frames
//     declare 0.1, 0.3 and 0.5 is drawn at 0.104/0.301/0.507 with the option set to 0.02 and at the same
//     0.104/0.301/0.507 with it set to 2.0 (measured, both, with the option's own value printed). The
//     frame's own delay wins, so this follows the host rather than the header's sentence about the option.
//   * *stop ENDS THE ANIMATION: set on the second of three calls, the third never comes.
//   * THE STATUS: 0 for a GIF, including a one-frame one, which is drawn once. -22141
//     (kCGImageAnimationStatus_CorruptInputImage) for a source that is not an animation - a PNG, a JPEG and
//     a THREE-FRAME TIFF all answer it with no call at all, so a frame count is not what decides it and
//     the {GIF} dictionary of the first frame is. -50 (paramErr) for a NULL url or NULL data. A NULL block
//     answers 0 and the block is never called, which is this: the block is drawn once per frame and there
//     is nothing to call.
//
// THE ONE PLACE THE PORT DOES NOT COPY THE HOST: a kCGImageAnimationStartIndex at or past the frame count.
// The host answers 0 and then TRAPS (SIGTRAP, exit 133, measured on this Mac for index 2 on a two-frame
// file and for index 9) when its first frame is read. A trap is not a behaviour to carry, so this object
// answers 0 and calls nothing, which is the same status with the block never running; the harness declares
// that one case and says why in known-differences.txt.
//
// WHAT THIS CANNOT DO, and says so here rather than in a commit: an APNG. The header names GIF and APNG as
// the supported formats, and a release whose ImageIO carries no APNG decoder cannot decode one, so the frame
// this object draws is whatever the release's own source hands back. The status for a file the release
// cannot read is the -22141 above.

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

// -50 is paramErr (MacTypes.h), which is what the host answers for a NULL url and for NULL data. It is
// written here because the OSStatus this file returns is not a CFError and the constant is not in ImageIO.
#define CHARON_ANIMATION_PARAM_ERR (-50)

// What the port carries and the release does not export below the band this object is for:
// Graphics/ImageIONames130.m holds all three (first exported by the 16.0 caches, the SDK says 13.0), and
// this object is compiled in every band that compiles that one, so the symbols resolve in every band.
extern CFStringRef const kCGImageAnimationStartIndex;
extern CFStringRef const kCGImageAnimationDelayTime;
extern CFStringRef const kCGImageAnimationLoopCount;

@interface CharonImageAnimation : NSObject
- (instancetype)initWithSource:(CGImageSourceRef)source block:(CGImageSourceAnimationBlock)block;
- (OSStatus)runWithOptions:(CFDictionaryRef)options;
@end

@implementation CharonImageAnimation {
@private
    CGImageSourceRef _source;
    CGImageSourceAnimationBlock _block;
    NSTimer *_timer;
    size_t _count;
    size_t _index;
    size_t _loops;      // 0 means forever, which is the host's own answer with no option
    size_t _loopsDone;
}

- (instancetype)initWithSource:(CGImageSourceRef)source block:(CGImageSourceAnimationBlock)block
{
    if ((self = [super init])) {
        // the source is held for as long as the animation runs and released when it stops, so a caller that
        // drops its own reference right after the call does not pull the frames out from under the timer
        _source = (CGImageSourceRef)CFRetain(source);
        _block = [block copy];
    }
    return self;
}

- (void)dealloc
{
    if (_source)
        CFRelease(_source);
}

// The delay the file gives the frame at `index`, in seconds. A frame with no delay of its own answers 0.1,
// which is the release's own default and not a number chosen here.
static double charon_frame_delay(CGImageSourceRef source, size_t index)
{
    NSDictionary *properties =
        (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, index, NULL);
    NSDictionary *gif = properties[(__bridge NSString *)kCGImagePropertyGIFDictionary];
    NSNumber *delay = gif[(__bridge NSString *)kCGImagePropertyGIFDelayTime];
    return delay ? [delay doubleValue] : 0.1;
}

// Why a source cannot be animated, or kCGImageAnimationStatus_CorruptInputImage when it can. A frame count
// is not the test: a three-frame TIFF and a one-frame PNG are both refused (measured), and a one-frame GIF
// is accepted, so what is asked is whether the first frame carries the dictionary a GIF's frames carry.
static BOOL charon_is_animation(CGImageSourceRef source)
{
    if (!source || CGImageSourceGetCount(source) == 0)
        return NO;
    NSDictionary *properties =
        (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSDictionary *gif = properties[(__bridge NSString *)kCGImagePropertyGIFDictionary];
    return [gif isKindOfClass:[NSDictionary class]];
}

// The frame at `index` and the delay the file gives it. A frame the release cannot decode ends the
// animation rather than being drawn as nothing, which is what the host does when it cannot read a frame.
- (void)drawFrameAtIndex:(size_t)index
{
    CGImageRef image = CGImageSourceCreateImageAtIndex(_source, index, NULL);
    double delay = charon_frame_delay(_source, index);
    if (!image) {
        [self stop];
        return;
    }
    bool stop = false;
    _block(index, image, &stop);
    CGImageRelease(image);
    if (stop) {
        [self stop];
        return;
    }
    _index = index + 1;
    if (_index >= _count) {
        _index = 0;
        _loopsDone++;
        if (_loops && _loopsDone >= _loops) {
            [self stop];
            return;
        }
    }
    [self armAfter:delay];
}

- (void)step:(NSTimer *)timer
{
    // This object is kept alive for the length of this call, and the reason is the last frame: -stop
    // invalidates the timer, the timer holds the only other reference to this object, and without this the
    // object could be freed while its own callback is still running.
    CharonImageAnimation *alive = self;
    [self drawFrameAtIndex:_index];
    (void)alive;
}

- (void)armAfter:(double)delay
{
    _timer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(step:) userInfo:nil repeats:NO];
    // the main run loop, because the header says the block is called on the main queue. A caller on another
    // thread therefore gets its block on the main thread, which is the documented place and not this thread.
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
}

- (void)stop
{
    [_timer invalidate];
    _timer = nil;
    _block = nil;
    if (_source) {
        CFRelease(_source);
        _source = NULL;
    }
}

- (OSStatus)runWithOptions:(CFDictionaryRef)options
{
    if (!charon_is_animation(_source))
        return kCGImageAnimationStatus_CorruptInputImage;
    _count = CGImageSourceGetCount(_source);

    NSDictionary *given = (__bridge NSDictionary *)options;
    NSNumber *start = given[(__bridge NSString *)kCGImageAnimationStartIndex];
    NSNumber *loops = given[(__bridge NSString *)kCGImageAnimationLoopCount];
    _index = start ? (size_t)MAX((long)0, [start integerValue]) : 0;
    _loops = loops ? (size_t)MAX((long)0, [loops integerValue]) : 0;
    _loopsDone = 0;

    // a start index at or past the last frame: the host traps here (measured) and this answers 0 with
    // nothing drawn, which is the status the host gives and without its crash
    if (_index >= _count)
        return 0;

    if (_count == 1) {
        // A ONE-FRAME ANIMATION IS PLAYED ONCE, AND INSIDE THIS CALL. Measured: the block runs before the
        // function returns, and a loop count of three still draws the one frame exactly once (the host
        // answers 0, one call, one second run loop), so a one-frame source is not a loop at all.
        _loops = 1;
        [self drawFrameAtIndex:_index];
        return 0;
    }

    // The first frame of a longer animation is drawn on the next turn of the run loop rather than inside
    // this call - measured, the host returns before the first frame of a two- or three-frame file and the
    // first call arrives within a millisecond of that return - and every later frame is drawn after the
    // delay the file gives the frame just drawn, which is the order of the gaps: 0.104, 0.301 and 0.507 for
    // a file whose frames declare 0.1, 0.3 and 0.5 seconds.
    [self armAfter:0];
    return 0;
}

@end

// The two functions are one object because one is the other's source: the URL form opens a file with the
// release's own CGImageSourceCreateWithURL and then runs the animation the data form would have run.
static OSStatus charon_animate(CGImageSourceRef source, CFDictionaryRef options, CGImageSourceAnimationBlock block)
{
    if (!source)
        return CHARON_ANIMATION_PARAM_ERR;
    if (!block) {
        CFRelease(source);
        return 0; // measured: 0, and no call; a NULL block cannot be called and the host does not object
    }
    // the animation object holds the source until it stops, and holds itself through the timer that targets
    // it, so nothing here has to keep a pointer the caller cannot see
    CharonImageAnimation *animation = [[CharonImageAnimation alloc] initWithSource:source block:block];
    CFRelease(source);
    return [animation runWithOptions:options];
}

OSStatus CGAnimateImageAtURLWithBlock(CFURLRef url, CFDictionaryRef options, CGImageSourceAnimationBlock block)
{
    if (!url)
        return CHARON_ANIMATION_PARAM_ERR;
    return charon_animate(CGImageSourceCreateWithURL(url, NULL), options, block);
}

OSStatus CGAnimateImageDataWithBlock(CFDataRef data, CFDictionaryRef options, CGImageSourceAnimationBlock block)
{
    if (!data)
        return CHARON_ANIMATION_PARAM_ERR;
    return charon_animate(CGImageSourceCreateWithData(data, NULL), options, block);
}