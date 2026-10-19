#import "CharonAVFAudio.h"

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
