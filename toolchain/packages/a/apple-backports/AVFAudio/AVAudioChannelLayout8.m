#import "RevenantAVFAudio.h"

@implementation AVAudioChannelLayout {
    AudioChannelLayoutTag _revenant_tag;
    AudioChannelLayout *_revenant_layout;
    NSUInteger _revenant_length;
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
        AudioChannelLayoutTag specific = RevenantTagForChannelCount(layout->mNumberChannelDescriptions);
        if (specific != kAudioChannelLayoutTag_UseChannelDescriptions) {
            tag = specific;
        }
    }
    if (tag == kAudioChannelLayoutTag_UseChannelBitmap) {
        NSUInteger channels = (NSUInteger)__builtin_popcount(layout->mChannelBitmap);
        AudioChannelLayoutTag specific = RevenantTagForChannelCount(channels);
        if (specific != kAudioChannelLayoutTag_UseChannelBitmap) {
            tag = specific;
        }
    }
    _revenant_tag = tag;
    _revenant_length = sizeof(AudioChannelLayout) + (layout->mNumberChannelDescriptions > 0 ? (layout->mNumberChannelDescriptions - 1) * sizeof(AudioChannelDescription) : 0);
    _revenant_layout = calloc(1, _revenant_length);
    if (!_revenant_layout) {
        abort();
    }
    _revenant_layout->mChannelLayoutTag = tag;
    if (layout->mNumberChannelDescriptions > 0) {
        _revenant_layout->mNumberChannelDescriptions = layout->mNumberChannelDescriptions;
        memcpy(_revenant_layout->mChannelDescriptions, layout->mChannelDescriptions,
               layout->mNumberChannelDescriptions * sizeof(AudioChannelDescription));
    } else {
        _revenant_layout->mChannelBitmap = layout->mChannelBitmap;
    }
    return self;
}

- (void)dealloc
{
    free(_revenant_layout);
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
    if (_revenant_tag != other->_revenant_tag) {
        return NO;
    }
    if (_revenant_layout->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
        return _revenant_layout->mChannelBitmap == other->_revenant_layout->mChannelBitmap;
    }
    if (_revenant_layout->mNumberChannelDescriptions != other->_revenant_layout->mNumberChannelDescriptions) {
        return NO;
    }
    return memcmp(_revenant_layout->mChannelDescriptions, other->_revenant_layout->mChannelDescriptions,
                  _revenant_layout->mNumberChannelDescriptions * sizeof(AudioChannelDescription)) == 0;
}

- (AudioChannelLayoutTag)layoutTag
{
    return _revenant_tag;
}

- (const AudioChannelLayout *)layout
{
    return _revenant_layout;
}

- (AVAudioChannelCount)channelCount
{
    if (_revenant_layout->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
        return (AVAudioChannelCount)__builtin_popcount(_revenant_layout->mChannelBitmap);
    }
    if (_revenant_layout->mNumberChannelDescriptions > 0) {
        return _revenant_layout->mNumberChannelDescriptions;
    }
    NSUInteger channels = RevenantChannelsForLayoutTag(_revenant_tag);
    return (AVAudioChannelCount)(channels != 0 ? channels : (_revenant_tag & 0x0000FFFF));
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_revenant_tag forKey:@"tag"];
    [coder encodeInteger:(NSInteger)self.channelCount forKey:@"channels"];
    UInt32 descriptions = _revenant_layout->mNumberChannelDescriptions;
    [coder encodeInteger:(NSInteger)descriptions forKey:@"descriptions"];
    for (UInt32 index = 0; index < descriptions; index++) {
        NSString *key = [NSString stringWithFormat:@"%u", (unsigned)index];
        AudioChannelDescription description = _revenant_layout->mChannelDescriptions[index];
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
