#import "CharonAVFAudio.h"
#import "CharonAUAudioUnit.h"

// The channel count of a layout tag and the canonical tag of a channel count. The release is the
// authority for both - AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForTag) and
// kAudioFormatProperty_TagsForNumberOfChannels answer on iOS 6.1.3 - and this table is only the
// fallback for the tags the release's AudioFormat declines, so that AVAudioChannelLayout still
// answers for the layouts AVFAudio names itself.

typedef struct {
    AudioChannelLayoutTag tag;
    AVAudioChannelCount channels;
} CharonLayoutEntry;

static const CharonLayoutEntry CharonCanonicalLayouts[] = {
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

static const NSUInteger CharonCanonicalLayoutCount = sizeof(CharonCanonicalLayouts) / sizeof(*CharonCanonicalLayouts);

NSUInteger CharonChannelsForLayoutTag(AudioChannelLayoutTag tag)
{
    // The release decides first: kAudioFormatProperty_ChannelLayoutForTag takes the tag as its
    // specifier and answers the whole AudioChannelLayout, of which only mChannelLayoutTag and the
    // number of channels are read here. The struct has a variable-length tail, so the buffer is
    // asked for its size first and only then filled.
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
    for (NSUInteger index = 0; index < CharonCanonicalLayoutCount; index++) {
        if (CharonCanonicalLayouts[index].tag == tag) {
            return CharonCanonicalLayouts[index].channels;
        }
    }
    return 0;
}

AudioChannelLayoutTag CharonTagForChannelCount(AVAudioChannelCount channels)
{
    // kAudioFormatProperty_TagsForNumberOfChannels answers every tag the release holds for a count,
    // the canonical one first; the port takes the first, which is the tag
    // kAudioFormatProperty_TagForNumberOfChannels would have answered on its own.
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
    for (NSUInteger index = 0; index < CharonCanonicalLayoutCount; index++) {
        if (CharonCanonicalLayouts[index].channels == channels) {
            return CharonCanonicalLayouts[index].tag;
        }
    }
    return kAudioChannelLayoutTag_UseChannelDescriptions;
}

// CharonAUParameterImpl is declared in CharonAUAudioUnit.h and defined here, once. The @synthesize
// of every property is explicit because the class is one this package defines and the build treats an
// auto-synthesised property as an error; a helper file exports no API symbol of its own, and every name
// here is Charon-prefixed, so it exports none.
@implementation CharonAUParameterImpl
// Explicit synthesis for every one of them: this class is one the package defines rather than a
// release's, and the build compiles with -Werror=objc-missing-property-synthesis.
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


// The four characters of a name the channel-layout property publishes, as the tag. The property's value
// is an array of CFStrings and each is the name of a tag - "Mono", "Stereo", "Quadraphonic" - so the
// four characters of the name are the tag itself. A name the release does not use is zero, which is
// the tag for "none", and the caller leaves it out.
AudioChannelLayoutTag CharonTagFromName(NSString *name)
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
