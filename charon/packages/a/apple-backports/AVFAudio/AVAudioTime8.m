#import "CharonAVFAudio.h"

// AVAudioTime over the AudioTimeStamp the release's own engine fills in, and over the host clock
// CoreAudio keeps: AudioGetCurrentHostTime and AudioGetHostClockFrequency are both exported by
// CoreAudio on the real armv7 cache of iOS 6.1.3, so a moment in time is a real measurement here and
// not a counter the port keeps for itself.
//
// The class is immutable, as the header says, and every answer is read out of the one AudioTimeStamp
// the instance holds - so +timeWithHostTime:, +timeWithSampleTime:atRate: and
// +timeWithAudioTimeStamp:sampleRate: differ only in which of the stamp's flags they set, which is
// what makes -extrapolateTimeFromAnchor: and -isHostTimeValid / -isSampleTimeValid agree with the
// header's description of them.

// The machine's clock, read once: mach_timebase_info is what AudioGetHostClockFrequency answers
// from, and the frequency in nanoseconds per tick is its denominator.
static struct mach_timebase_info CharonTimeBase(void)
{
    static struct mach_timebase_info base;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        base.numer = 0;
        base.denom = 0;
        mach_timebase_info(&base);
    });
    return base;
}

@implementation AVAudioTime {
    AudioTimeStamp _charon_stamp;
    double _charon_sampleRate;
}

- (instancetype)initWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(double)sampleRate
{
    if ((self = [super init])) {
        _charon_stamp = ts != NULL ? *ts : (AudioTimeStamp){0};
        _charon_sampleRate = sampleRate;
    }
    return self;
}

- (instancetype)initWithHostTime:(uint64_t)hostTime
{
    AudioTimeStamp stamp = {0};
    stamp.mFlags = kAudioTimeStampHostTimeValid;
    stamp.mHostTime = hostTime;
    return [self initWithAudioTimeStamp:&stamp sampleRate:0];
}

- (instancetype)initWithSampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate
{
    AudioTimeStamp stamp = {0};
    stamp.mFlags = kAudioTimeStampSampleTimeValid;
    stamp.mSampleTime = sampleTime;
    return [self initWithAudioTimeStamp:&stamp sampleRate:sampleRate];
}

- (instancetype)initWithHostTime:(uint64_t)hostTime sampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate
{
    AudioTimeStamp stamp = {0};
    stamp.mFlags = kAudioTimeStampHostTimeValid | kAudioTimeStampSampleTimeValid;
    stamp.mHostTime = hostTime;
    stamp.mSampleTime = sampleTime;
    return [self initWithAudioTimeStamp:&stamp sampleRate:sampleRate];
}

+ (instancetype)timeWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(double)sampleRate
{
    return [[self alloc] initWithAudioTimeStamp:ts sampleRate:sampleRate];
}

+ (instancetype)timeWithHostTime:(uint64_t)hostTime
{
    return [[self alloc] initWithHostTime:hostTime];
}

+ (instancetype)timeWithSampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate
{
    return [[self alloc] initWithSampleTime:sampleTime atRate:sampleRate];
}

+ (instancetype)timeWithHostTime:(uint64_t)hostTime sampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate
{
    return [[self alloc] initWithHostTime:hostTime sampleTime:sampleTime atRate:sampleRate];
}

// Seconds to host time, the conversion AudioFileSecondsToHostTime performs: seconds times the
// machine's clock frequency, and no rounding, so that the round trip through +secondsForHostTime:
// is the release's own and not the port's.
+ (uint64_t)hostTimeForSeconds:(NSTimeInterval)seconds
{
    struct mach_timebase_info base = CharonTimeBase();
    if (base.denom == 0) {
        return 0;
    }
    return (uint64_t)(seconds * (NSTimeInterval)base.denom / (NSTimeInterval)base.numer);
}

+ (NSTimeInterval)secondsForHostTime:(uint64_t)hostTime
{
    struct mach_timebase_info base = CharonTimeBase();
    if (base.denom == 0) {
        return 0;
    }
    return ((NSTimeInterval)hostTime * (NSTimeInterval)base.numer) / (NSTimeInterval)base.denom;
}

// The header's rule, taken literally: the anchor must have both a host time and a sample time, and
// the receiver a sample rate and at least one of the two times. The result is a copy of the
// receiver with the anchor's missing field filled in; the anchor's own host time is converted through
// the sample rate so the two agree, which is the conversion the engine's own timestamps make.
- (nullable AVAudioTime *)extrapolateTimeFromAnchor:(AVAudioTime *)anchorTime
{
    if (anchorTime == nil || _charon_sampleRate <= 0 || !anchorTime.hostTimeValid || !anchorTime.sampleTimeValid) {
        return nil;
    }
    if ((_charon_stamp.mFlags & (kAudioTimeStampHostTimeValid | kAudioTimeStampSampleTimeValid)) == 0) {
        return nil;
    }
    AudioTimeStamp stamp = _charon_stamp;
    const double rate = _charon_sampleRate;
    if ((_charon_stamp.mFlags & kAudioTimeStampHostTimeValid) && !(_charon_stamp.mFlags & kAudioTimeStampSampleTimeValid)) {
        double seconds = [[self class] secondsForHostTime:anchorTime.hostTime];
        stamp.mFlags |= kAudioTimeStampSampleTimeValid;
        stamp.mSampleTime = (AVAudioFramePosition)llround(seconds * rate) + anchorTime.sampleTime;
    } else if (!(_charon_stamp.mFlags & kAudioTimeStampHostTimeValid)) {
        stamp.mFlags |= kAudioTimeStampHostTimeValid;
        NSTimeInterval offset = ((double)stamp.mSampleTime - (double)anchorTime.sampleTime) / rate;
        stamp.mHostTime = (uint64_t)llround([[self class] hostTimeForSeconds:offset]) + anchorTime.hostTime;
    }
    return [[AVAudioTime alloc] initWithAudioTimeStamp:&stamp sampleRate:rate];
}

- (BOOL)isHostTimeValid
{
    return (_charon_stamp.mFlags & kAudioTimeStampHostTimeValid) != 0;
}

- (uint64_t)hostTime
{
    return _charon_stamp.mHostTime;
}

- (BOOL)isSampleTimeValid
{
    return (_charon_stamp.mFlags & kAudioTimeStampSampleTimeValid) != 0;
}

- (AVAudioFramePosition)sampleTime
{
    return _charon_stamp.mSampleTime;
}

- (double)sampleRate
{
    return _charon_sampleRate;
}

- (AudioTimeStamp)audioTimeStamp
{
    return _charon_stamp;
}

@end
