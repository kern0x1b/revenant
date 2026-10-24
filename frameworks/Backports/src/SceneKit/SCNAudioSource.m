#import "RevenantSCNAudio.h"

static NSMutableDictionary<NSString *, SCNAudioSource *> *RevenantSCNAudioSources;

@implementation SCNAudioSource
{
    NSURL *_url;
    NSData *_data;
    BOOL _positional;
    float _volume;
    float _rate;
    BOOL _loops;
    BOOL _shouldStream;
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
    copy->_loops = _loops;
    copy->_shouldStream = _shouldStream;
    return copy;
}

@end
