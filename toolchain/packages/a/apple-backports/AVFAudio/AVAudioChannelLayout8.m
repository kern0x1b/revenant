#import "CharonAVFAudio.h"

@implementation AVAudioChannelLayout {
    AudioChannelLayoutTag _charon_tag;
    AudioChannelLayout *_charon_layout;
    NSUInteger _charon_length;
}

- (instancetype)initWithLayoutTag:(AudioChannelLayoutTag)layoutTag
{
    if (layoutTag == kAudioChannelLayoutTag_UseChannelDescriptions || layoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
        return nil;
    }
    AudioChannelLayout layout;
    memset(&layout, 0, sizeof(layout));
    layout.mChannelLayoutTag = layoutTag;
    return [self initWithLayout:&layout];
}

- (instancetype)initWithLayout:(const AudioChannelLayout *)layout
{
    if (layout == NULL) {
        return nil;
    }
    self = [super init];
    AudioChannelLayoutTag tag = layout->mChannelLayoutTag;
    if (tag == kAudioChannelLayoutTag_UseChannelDescriptions) {
        AudioChannelLayoutTag specific = CharonTagForChannelCount(layout->mNumberChannelDescriptions);
        if (specific != kAudioChannelLayoutTag_UseChannelDescriptions) {
            tag = specific;
        }
    }
    if (tag == kAudioChannelLayoutTag_UseChannelBitmap) {
        NSUInteger channels = (NSUInteger)__builtin_popcount(layout->mChannelBitmap);
        AudioChannelLayoutTag specific = CharonTagForChannelCount(channels);
        if (specific != kAudioChannelLayoutTag_UseChannelBitmap) {
            tag = specific;
        }
    }
    _charon_tag = tag;
    _charon_length = sizeof(AudioChannelLayout) + (layout->mNumberChannelDescriptions > 0 ? (layout->mNumberChannelDescriptions - 1) * sizeof(AudioChannelDescription) : 0);
    _charon_layout = calloc(1, _charon_length);
    if (!_charon_layout) {
        abort();
    }
    _charon_layout->mChannelLayoutTag = tag;
    if (layout->mNumberChannelDescriptions > 0) {
        _charon_layout->mNumberChannelDescriptions = layout->mNumberChannelDescriptions;
        memcpy(_charon_layout->mChannelDescriptions, layout->mChannelDescriptions,
               layout->mNumberChannelDescriptions * sizeof(AudioChannelDescription));
    } else {
        _charon_layout->mChannelBitmap = layout->mChannelBitmap;
    }
    return self;
}

- (void)dealloc
{
    free(_charon_layout);
}

+ (instancetype)layoutWithLayoutTag:(AudioChannelLayoutTag)layoutTag
{
    return [[self alloc] initWithLayoutTag:layoutTag];
}

+ (instancetype)layoutWithLayout:(const AudioChannelLayout *)layout
{
    return [[self alloc] initWithLayout:layout];
}

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[AVAudioChannelLayout class]]) {
        return NO;
    }
    AVAudioChannelLayout *other = object;
    if (_charon_tag != other->_charon_tag) {
        return NO;
    }
    if (_charon_layout->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
        return _charon_layout->mChannelBitmap == other->_charon_layout->mChannelBitmap;
    }
    if (_charon_layout->mNumberChannelDescriptions != other->_charon_layout->mNumberChannelDescriptions) {
        return NO;
    }
    return memcmp(_charon_layout->mChannelDescriptions, other->_charon_layout->mChannelDescriptions,
                  _charon_layout->mNumberChannelDescriptions * sizeof(AudioChannelDescription)) == 0;
}

- (AudioChannelLayoutTag)layoutTag
{
    return _charon_tag;
}

- (const AudioChannelLayout *)layout
{
    return _charon_layout;
}

- (AVAudioChannelCount)channelCount
{
    if (_charon_layout->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
        return (AVAudioChannelCount)__builtin_popcount(_charon_layout->mChannelBitmap);
    }
    if (_charon_layout->mNumberChannelDescriptions > 0) {
        return _charon_layout->mNumberChannelDescriptions;
    }
    NSUInteger channels = CharonChannelsForLayoutTag(_charon_tag);
    return (AVAudioChannelCount)(channels != 0 ? channels : (_charon_tag & 0x0000FFFF));
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_charon_tag forKey:@"tag"];
    [coder encodeInteger:(NSInteger)self.channelCount forKey:@"channels"];
    UInt32 descriptions = _charon_layout->mNumberChannelDescriptions;
    [coder encodeInteger:(NSInteger)descriptions forKey:@"descriptions"];
    for (UInt32 index = 0; index < descriptions; index++) {
        NSString *key = [NSString stringWithFormat:@"%u", (unsigned)index];
        AudioChannelDescription description = _charon_layout->mChannelDescriptions[index];
        [coder encodeInteger:(NSInteger)description.mChannelLabel forKey:[key stringByAppendingString:@".label"]];
        [coder encodeInteger:(NSInteger)description.mChannelFlags forKey:[key stringByAppendingString:@".flags"]];
        [coder encodeInteger:(NSInteger)description.mChannelFlags forKey:[key stringByAppendingString:@".spatial"]];
    }
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    AudioChannelLayoutTag tag = (AudioChannelLayoutTag)[coder decodeIntegerForKey:@"tag"];
    if (tag == 0) {
        return nil;
    }
    return [self initWithLayoutTag:tag];
}

@end
