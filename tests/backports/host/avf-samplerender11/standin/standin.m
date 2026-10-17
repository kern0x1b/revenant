//  standin.m - the RELEASE side of tests/backports/host/avf-samplerender11, and as little of it as the
//  link needs.
//
//  On this Mac none of these three names is that name: the real AVFoundation carries the whole later
//  surface of both classes, so linking the port's objects against it would answer every question from
//  Apple's code instead of the port's. This file therefore provides the two symbols of the release the
//  port's own objects reference and that no other object in the link defines - AVFoundationErrorDomain,
//  which the release exports from 4.0 (tools/cache-index/first-rung.lua _AVFoundationErrorDomain answers
//  4.0), and nothing else.
//
//  It implements no member of either class and none of the protocol, and that is the whole contract: if the
//  port's objects were not in this link, -timebase, -addRenderer:, -enqueueSampleBuffer: and the rest would
//  raise, which is a louder failure than a wrong answer.
#import <AVFoundation/AVFoundation.h>

NSString *const AVFoundationErrorDomain = @"AVFoundationErrorDomain";

// +[NSValue valueWithCMTime:] and -[NSValue CMTimeValue], which the boundary times of
// -addBoundaryTimeObserverForTimes: are boxed in and which the port's own objects read back. This Mac
// declares them in AVFoundation's own headers and implements them in the framework, so the host half gets
// them from -framework AVFoundation and this file stands in for the same pair on the release's side; the
// release has carried both since 4.0 (tools/cache-index/first-rung.lua valueWithCMTime: and CMTimeValue both
// answer 4.0) and the port already uses them in AVCaptureDevice+ActiveFrameDuration.m.
@implementation NSValue (CharonStandinCMTime)

+ (NSValue *)valueWithCMTime:(CMTime)time
{
    return [NSValue valueWithBytes:&time objCType:@encode(CMTime)];
}

- (CMTime)CMTimeValue
{
    CMTime time;
    [self getValue:&time];
    return time;
}

@end