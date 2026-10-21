#import <AVFAudio/AVSpeechSynthesis.h>
#include <dlfcn.h>

@protocol RevenantVoiceServicesListing <NSObject>
+ (NSArray *)availableLanguageCodes;
+ (NSArray *)availableVoicesForLanguageCode:(NSString *)languageCode;
@end

static NSString *const RevenantVoiceServicesPath = @"/System/Library/PrivateFrameworks/VoiceServices.framework/VoiceServices";

static NSDictionary *RevenantHostIdentifiers(void)
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

static NSString *RevenantPrimaryLanguage(NSString *tag)
{
    NSRange dash = [tag rangeOfString:@"-"];
    return dash.location == NSNotFound ? tag : [tag substringToIndex:dash.location];
}

static Class<RevenantVoiceServicesListing> RevenantListingClass(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dlopen([RevenantVoiceServicesPath UTF8String], RTLD_LAZY);
    });
    return (Class<RevenantVoiceServicesListing>)NSClassFromString(@"VSSpeechSynthesizer");
}

static NSString *RevenantIdentifierForVoice(NSString *language, NSString *name)
{
    NSString *measured = RevenantHostIdentifiers()[[NSString stringWithFormat:@"%@ %@", language, name]];
    return measured ?: [NSString stringWithFormat:@"com.apple.voice.super-compact.%@.%@", language,
                        [name stringByReplacingOccurrencesOfString:@"-" withString:@""]];
}

@implementation AVSpeechSynthesisVoice {
    NSString *_language;
    NSString *_identifier;
    NSString *_name;
    AVSpeechSynthesisVoiceQuality _quality;
}

@dynamic gender;
@dynamic audioFileSettings;

+ (NSArray<AVSpeechSynthesisVoice *> *)speechVoices
{
    Class<RevenantVoiceServicesListing> listing = RevenantListingClass();
    NSMutableArray *voices = [NSMutableArray array];
    if (!listing) return voices;
    for (NSString *code in [listing availableLanguageCodes]) {
        for (NSString *name in [listing availableVoicesForLanguageCode:code]) {
            AVSpeechSynthesisVoice *voice = [[self alloc] init];
            voice->_language = [code copy];
            voice->_name = [name copy];
            voice->_identifier = RevenantIdentifierForVoice(code, name);
            voice->_quality = AVSpeechSynthesisVoiceQualityDefault;
            [voices addObject:voice];
        }
    }
    return voices;
}

+ (NSString *)currentLanguageCode
{
    NSString *tag = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    if ([tag rangeOfString:@"-"].location == NSNotFound) {
        NSString *region = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        if (region) tag = [tag stringByAppendingFormat:@"-%@", region];
    }
    NSArray *codes = [RevenantListingClass() availableLanguageCodes];
    if ([codes containsObject:tag]) return tag;
    for (NSString *code in codes) {
        if ([RevenantPrimaryLanguage(code) isEqualToString:RevenantPrimaryLanguage(tag)]) return code;
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
    NSString *primary = RevenantPrimaryLanguage(code);
    NSString *current = [self currentLanguageCode];
    if ([RevenantPrimaryLanguage(current) isEqualToString:primary]) {
        for (AVSpeechSynthesisVoice *voice in voices) {
            if ([voice->_language isEqualToString:current]) return voice;
        }
    }
    for (AVSpeechSynthesisVoice *voice in voices) {
        if ([RevenantPrimaryLanguage(voice->_language) isEqualToString:primary]) return voice;
    }
    return nil;
}

+ (AVSpeechSynthesisVoice *)voiceWithIdentifier:(NSString *)identifier
{
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
