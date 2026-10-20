#import "RevenantAVFAudio.h"
#import "RevenantAUAudioUnit.h"

typedef struct {
    AudioChannelLayoutTag tag;
    AVAudioChannelCount channels;
} RevenantLayoutEntry;

static const RevenantLayoutEntry RevenantCanonicalLayouts[] = {
    {kAudioChannelLayoutTag_Mono, 1},
    {kAudioChannelLayoutTag_Stereo, 2},
    {kAudioChannelLayoutTag_MatrixStereo, 2},
    {kAudioChannelLayoutTag_MidSide, 2},
    {kAudioChannelLayoutTag_XY, 2},
    {kAudioChannelLayoutTag_Binaural, 2},
    {kAudioChannelLayoutTag_Quadraphonic, 4},
    {kAudioChannelLayoutTag_Pentagonal, 5},
    {kAudioChannelLayoutTag_Hexagonal, 6},
    {kAudioChannelLayoutTag_Octagonal, 8},
    {kAudioChannelLayoutTag_Cube, 8},
    {kAudioChannelLayoutTag_Ambisonic_B_Format, 4},
    {kAudioChannelLayoutTag_MPEG_1_0, 2},
    {kAudioChannelLayoutTag_MPEG_2_0, 3},
    {kAudioChannelLayoutTag_MPEG_3_0_A, 4},
    {kAudioChannelLayoutTag_MPEG_3_0_B, 4},
    {kAudioChannelLayoutTag_MPEG_4_0_A, 5},
    {kAudioChannelLayoutTag_MPEG_4_0_B, 6},
    {kAudioChannelLayoutTag_MPEG_5_0_A, 5},
    {kAudioChannelLayoutTag_MPEG_5_0_B, 6},
};

static const NSUInteger RevenantCanonicalLayoutCount = sizeof(RevenantCanonicalLayouts) / sizeof(*RevenantCanonicalLayouts);

NSUInteger RevenantChannelsForLayoutTag(AudioChannelLayoutTag tag)
{
    UInt32 size = 0;
    if (AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForTag, sizeof(tag), &tag, &size, NULL) == noErr && size >= sizeof(AudioChannelLayout)) {
        AudioChannelLayout *layout = calloc(1, size);
        if (!layout) {
            return 0;
        }
        OSStatus status = AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForTag, sizeof(tag), &tag, &size, layout);
        UInt32 channels = status == noErr ? layout->mNumberChannelDescriptions : 0;
        if (status == noErr && layout->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
            channels = (UInt32)__builtin_popcount(layout->mChannelBitmap);
        }
        free(layout);
        if (channels > 0) {
            return channels;
        }
    }
    for (NSUInteger index = 0; index < RevenantCanonicalLayoutCount; index++) {
        if (RevenantCanonicalLayouts[index].tag == tag) {
            return RevenantCanonicalLayouts[index].channels;
        }
    }
    return 0;
}

AudioChannelLayoutTag RevenantTagForChannelCount(AVAudioChannelCount channels)
{
    UInt32 count = (UInt32)channels;
    UInt32 size = 0;
    if (AudioFormatGetProperty(kAudioFormatProperty_TagsForNumberOfChannels, sizeof(count), &count, &size, NULL) == noErr && size >= sizeof(AudioChannelLayoutTag)) {
        UInt32 count_of_tags = size / (UInt32)sizeof(AudioChannelLayoutTag);
        AudioChannelLayoutTag *tags = calloc(count_of_tags, sizeof(AudioChannelLayoutTag));
        if (!tags) {
            return kAudioChannelLayoutTag_UseChannelDescriptions;
        }
        OSStatus status = AudioFormatGetProperty(kAudioFormatProperty_TagsForNumberOfChannels, sizeof(count), &count, &size, tags);
        AudioChannelLayoutTag chosen = status == noErr && count_of_tags > 0 ? tags[0] : 0;
        free(tags);
        if (chosen != 0) {
            return chosen;
        }
    }
    for (NSUInteger index = 0; index < RevenantCanonicalLayoutCount; index++) {
        if (RevenantCanonicalLayouts[index].channels == channels) {
            return RevenantCanonicalLayouts[index].tag;
        }
    }
    return kAudioChannelLayoutTag_UseChannelDescriptions;
}

@implementation RevenantAUParameterImpl
@synthesize name = _name;
@synthesize identifier = _identifier;
@synthesize scope = _scope;
@synthesize element = _element;
@synthesize minValue = _minValue;
@synthesize maxValue = _maxValue;
@synthesize unit = _unit;
@synthesize flags = _flags;
@synthesize unitName = _unitName;
@synthesize valueStrings = _valueStrings;
@synthesize dependentParameters = _dependentParameters;
@synthesize owner = _owner;
@end


AudioChannelLayoutTag RevenantTagFromName(NSString *name)
{
    if (name.length < 4) {
        return kAudioChannelLayoutTag_UseChannelDescriptions;
    }
    const char *characters = name.UTF8String;
    if (characters == NULL) {
        return kAudioChannelLayoutTag_UseChannelDescriptions;
    }
    return (AudioChannelLayoutTag)(characters[0] | (characters[1] << 8) | (characters[2] << 16) | (characters[3] << 24));
}
