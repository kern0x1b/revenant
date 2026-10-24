#import "RevenantSCNAudio.h"
#import "RevenantSCNSoundEngine.h"

static NSMutableDictionary<NSString *, SCNAudioSource *> *RevenantSCNAudioSources;

@implementation SCNAudioSource
{
    NSURL *_url;
    NSData *_data;
    BOOL _positional;
    float _volume;
    float _rate;
    float _reverbBlend;
    BOOL _loops;
    BOOL _shouldStream;
    unsigned int _monoBuffer;
    unsigned int _stereoBuffer;
    double _sampleRate;
    unsigned long long _frames;
}

- (instancetype)initWithURL:(NSURL *)url
{
    if (url == nil) {
        return nil;
    }
    if ((self = [super init])) {
        _url = [url copy];
        _positional = YES;
        _volume = 1;
        _rate = 1;
    }
    return self;
}

- (instancetype)initWithFileNamed:(NSString *)name
{
    NSString *extension = [name pathExtension];
    NSURL *url = [[NSBundle mainBundle] URLForResource:[name stringByDeletingPathExtension]
                                         withExtension:extension.length ? extension : nil];
    return url ? [self initWithURL:url] : nil;
}

+ (instancetype)audioSourceNamed:(NSString *)fileName
{
    if (RevenantSCNAudioSources == nil) {
        RevenantSCNAudioSources = [NSMutableDictionary dictionary];
    }
    SCNAudioSource *source = RevenantSCNAudioSources[fileName];
    if (source == nil) {
        source = [[self alloc] initWithFileNamed:fileName];
        if (source) {
            RevenantSCNAudioSources[fileName] = source;
        }
    }
    return source;
}

- (void)dealloc
{
    if ([RevenantSCNSoundEngine isActive]) {
        [RevenantSCNSoundEngine deleteBuffer:_monoBuffer];
        [RevenantSCNSoundEngine deleteBuffer:_stereoBuffer];
    }
}

- (BOOL)isPositional
{
    return _positional;
}

- (void)setPositional:(BOOL)positional
{
    _positional = positional;
}

- (float)volume
{
    return _volume;
}

- (void)setVolume:(float)volume
{
    _volume = volume;
}

- (float)rate
{
    return _rate;
}

- (void)setRate:(float)rate
{
    _rate = rate;
}

- (float)reverbBlend
{
    return _reverbBlend;
}

- (void)setReverbBlend:(float)reverbBlend
{
    _reverbBlend = reverbBlend;
}

- (BOOL)loops
{
    return _loops;
}

- (void)setLoops:(BOOL)loops
{
    _loops = loops;
}

- (BOOL)shouldStream
{
    return _shouldStream;
}

- (void)setShouldStream:(BOOL)shouldStream
{
    _shouldStream = shouldStream;
}

- (void)load
{
    if (!_shouldStream && _data == nil && _url) {
        _data = [NSData dataWithContentsOfURL:_url];
    }
}

- (unsigned int)revenantBufferForSpatial:(BOOL)spatial
{
    unsigned int *slot = spatial ? &_monoBuffer : &_stereoBuffer;
    if (*slot == 0) {
        [RevenantSCNSoundEngine prepare];
        double sampleRate = 0;
        unsigned long long frames = 0;
        NSData *pcm = [RevenantSCNSoundEngine decodeURL:_url channels:spatial ? 1 : 2 sampleRate:&sampleRate frames:&frames];
        if (pcm == nil) {
            [NSException raise:NSInvalidArgumentException format:@"SCNAudioSource: %@ cannot be decoded", _url];
        }
        *slot = [RevenantSCNSoundEngine newBuffer:pcm channels:spatial ? 1 : 2 sampleRate:sampleRate];
        _sampleRate = sampleRate;
        _frames = frames;
    }
    return *slot;
}

- (double)revenantDuration
{
    if (_sampleRate <= 0) {
        [self revenantBufferForSpatial:YES];
    }
    return _sampleRate > 0 ? (double)_frames / _sampleRate : 0;
}

- (NSURL *)revenantURL
{
    return _url;
}

- (NSData *)revenantData
{
    [self load];
    return _data;
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNAudioSource *copy = [[[self class] allocWithZone:zone] initWithURL:_url];
    copy->_data = _data;
    copy->_positional = _positional;
    copy->_volume = _volume;
    copy->_rate = _rate;
    copy->_reverbBlend = _reverbBlend;
    copy->_loops = _loops;
    copy->_shouldStream = _shouldStream;
    return copy;
}

@end
