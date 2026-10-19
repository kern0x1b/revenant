#import <AVFAudio/AVSpeechSynthesis.h>
#include <dlfcn.h>

// AVSpeechSynthesisVoice answers from the release's own voice listing, read from VoiceServices (measured on
// 6.1.3 in tests/backports/host/avf-speech/voices/probe.m, facts/AVFoundation/AVSpeech.md): VSSpeechSynthesizer's
// +availableLanguageCodes (36 codes on 6.1.3) and +availableVoicesForLanguageCode: (one voice name per code). No
// voice is typed in here. VoiceServices is not linked into a process by default, so it is loaded by path, and the
// class is looked up by name: the port carries no dependency on a private framework's class.

// The two class methods of VSSpeechSynthesizer the listing uses. Declared by name here; the class is never named
// in a message as a symbol, so nothing strong-imports it.
@protocol CharonVoiceServicesListing <NSObject>
+ (NSArray *)availableLanguageCodes;
+ (NSArray *)availableVoicesForLanguageCode:(NSString *)languageCode;
@end

static NSString *const CharonVoiceServicesPath = @"/System/Library/PrivateFrameworks/VoiceServices.framework/VoiceServices";

// The identifiers the host gives its voices, for the 22 of the 6.1.3 voices the host answers under the same name: the
// host's voiceWithLanguage: with the release's code gives a voice with the release's name, and its identifier is
// taken (measured on the host, facts/AVFoundation/AVSpeech.md, the identifier; checked by voice-checks.m). Keyed by
// "<code> <name>" as the release lists them. The host's identifiers drop the hyphen of a name ("Ting-Ting" is
// "Tingting"), so the key is not the identifier.
static NSDictionary *CharonHostIdentifiers(void)
{
    static NSDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
        @"cs-CZ Zuzana": @"com.apple.voice.super-compact.cs-CZ.Zuzana",
        @"de-DE Anna": @"com.apple.voice.super-compact.de-DE.Anna",
        @"en-AU Karen": @"com.apple.voice.super-compact.en-AU.Karen",
        @"en-GB Daniel": @"com.apple.voice.super-compact.en-GB.Daniel",
        @"en-IE Moira": @"com.apple.voice.super-compact.en-IE.Moira",
        @"en-US Samantha": @"com.apple.voice.compact.en-US.Samantha",
        @"en-ZA Tessa": @"com.apple.voice.super-compact.en-ZA.Tessa",
        @"es-ES Monica": @"com.apple.voice.super-compact.es-ES.Monica",
        @"es-MX Paulina": @"com.apple.voice.super-compact.es-MX.Paulina",
        @"fr-FR Thomas": @"com.apple.voice.super-compact.fr-FR.Thomas",
        @"hi-IN Lekha": @"com.apple.voice.super-compact.hi-IN.Lekha",
        @"id-ID Damayanti": @"com.apple.voice.super-compact.id-ID.Damayanti",
        @"ja-JP Kyoko": @"com.apple.voice.super-compact.ja-JP.Kyoko",
        @"ko-KR Yuna": @"com.apple.voice.super-compact.ko-KR.Yuna",
        @"nl-BE Ellen": @"com.apple.voice.super-compact.nl-BE.Ellen",
        @"nl-NL Xander": @"com.apple.voice.super-compact.nl-NL.Xander",
        @"pt-PT Joana": @"com.apple.voice.super-compact.pt-PT.Joana",
        @"ru-RU Milena": @"com.apple.voice.super-compact.ru-RU.Milena",
        @"sk-SK Laura": @"com.apple.voice.super-compact.sk-SK.Laura",
        @"sv-SE Alva": @"com.apple.voice.super-compact.sv-SE.Alva",
        @"zh-CN Ting-Ting": @"com.apple.voice.super-compact.zh-CN.Tingting",
        @"zh-HK Sin-Ji": @"com.apple.voice.super-compact.zh-HK.Sinji",
        };
    });
    return table;
}

// The primary language of a BCP-47 tag: "en" for "en-US", "zh" for "zh-Hans-CN".
static NSString *CharonPrimaryLanguage(NSString *tag)
{
    NSRange dash = [tag rangeOfString:@"-"];
    return dash.location == NSNotFound ? tag : [tag substringToIndex:dash.location];
}

// The VoiceServices class, loaded on first use. Private helpers are functions, not methods: a method on this class
// would be a selector the release does not have, and the gate refuses it.
static Class<CharonVoiceServicesListing> CharonListingClass(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dlopen([CharonVoiceServicesPath UTF8String], RTLD_LAZY);
    });
    return (Class<CharonVoiceServicesListing>)NSClassFromString(@"VSSpeechSynthesizer");
}

// The identifier of a voice: the host's where the host answers the voice under its language and name, else the host's
// pattern for a voice of its kind (facts/AVFoundation/AVSpeech.md, the identifier). Either way it is the host's form.
static NSString *CharonIdentifierForVoice(NSString *language, NSString *name)
{
    NSString *measured = CharonHostIdentifiers()[[NSString stringWithFormat:@"%@ %@", language, name]];
    return measured ?: [NSString stringWithFormat:@"com.apple.voice.super-compact.%@.%@", language,
                        [name stringByReplacingOccurrencesOfString:@"-" withString:@""]];
}

@implementation AVSpeechSynthesisVoice {
    NSString *_language;
    NSString *_identifier;
    NSString *_name;
    AVSpeechSynthesisVoiceQuality _quality;
}

// The SDK header also declares two later properties, and clang synthesises an ivar and accessors for any declared
// property this implementation leaves out. @dynamic says the port does not carry them, so the selectors are
// unrecognized, as they are on a release that lacks them.
@dynamic gender;             // iOS 13
@dynamic audioFileSettings;  // iOS 13

+ (NSArray<AVSpeechSynthesisVoice *> *)speechVoices
{
    Class<CharonVoiceServicesListing> listing = CharonListingClass();
    NSMutableArray *voices = [NSMutableArray array];
    if (!listing) return voices;
    for (NSString *code in [listing availableLanguageCodes]) {
        for (NSString *name in [listing availableVoicesForLanguageCode:code]) {
            AVSpeechSynthesisVoice *voice = [[self alloc] init];
            voice->_language = [code copy];
            voice->_name = [name copy];
            voice->_identifier = CharonIdentifierForVoice(code, name);
            // The listing carries one voice per language and no quality: each is the default quality, which is what
            // the host answers for every voice it lists (quality 1 for all 180).
            voice->_quality = AVSpeechSynthesisVoiceQualityDefault;
            [voices addObject:voice];
        }
    }
    return voices;
}

+ (NSString *)currentLanguageCode
{
    // The first preferred language, with its region taken from the locale when the tag has none: measured on the
    // host as the tag the process's language setting names (facts/AVFoundation/AVSpeech.md).
    NSString *tag = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    if ([tag rangeOfString:@"-"].location == NSNotFound) {
        NSString *region = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        if (region) tag = [tag stringByAppendingFormat:@"-%@", region];
    }
    NSArray *codes = [CharonListingClass() availableLanguageCodes];
    if ([codes containsObject:tag]) return tag;
    for (NSString *code in codes) {
        if ([CharonPrimaryLanguage(code) isEqualToString:CharonPrimaryLanguage(tag)]) return code;
    }
    return tag;
}

+ (AVSpeechSynthesisVoice *)voiceWithLanguage:(NSString *)languageCode
{
    NSString *code = languageCode ?: [self currentLanguageCode];
    NSArray *voices = [self speechVoices];
    for (AVSpeechSynthesisVoice *voice in voices) {
        if ([voice->_language isEqualToString:code]) return voice;
    }
    // A bare language, or a region the release does not list ("en-NZ"): the current language's voice when the current
    // language has that primary language, else the first voice of that language in the release's order. Measured on
    // the host: "en" is en-US under en-US and en-GB under en-GB, and "en" under de-DE is en-AU.
    NSString *primary = CharonPrimaryLanguage(code);
    NSString *current = [self currentLanguageCode];
    if ([CharonPrimaryLanguage(current) isEqualToString:primary]) {
        for (AVSpeechSynthesisVoice *voice in voices) {
            if ([voice->_language isEqualToString:current]) return voice;
        }
    }
    for (AVSpeechSynthesisVoice *voice in voices) {
        if ([CharonPrimaryLanguage(voice->_language) isEqualToString:primary]) return voice;
    }
    return nil;
}

+ (AVSpeechSynthesisVoice *)voiceWithIdentifier:(NSString *)identifier
{
    // The host compares identifiers without regard to case (measured: "com.apple.voice.super-compact.zh-HK.SinJi"
    // answers Sinji), so the port does too.
    if (!identifier) return nil;
    for (AVSpeechSynthesisVoice *voice in [self speechVoices]) {
        if ([voice->_identifier caseInsensitiveCompare:identifier] == NSOrderedSame) return voice;
    }
    return nil;
}

- (NSString *)language
{
    return _language;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSString *)name
{
    return _name;
}

- (AVSpeechSynthesisVoiceQuality)quality
{
    return _quality;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_language forKey:@"language"];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeInteger:_quality forKey:@"quality"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _language = [coder decodeObjectOfClass:[NSString class] forKey:@"language"];
        _identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _quality = [coder decodeIntegerForKey:@"quality"];
    }
    return self;
}

@end
