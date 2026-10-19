#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>

@interface revenant_host_AVSpeechSynthesisVoice : NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSString *language;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) AVSpeechSynthesisVoiceQuality quality;
+ (NSArray *)speechVoices;
+ (NSString *)currentLanguageCode;
+ (revenant_host_AVSpeechSynthesisVoice *)voiceWithLanguage:(NSString *)languageCode;
+ (revenant_host_AVSpeechSynthesisVoice *)voiceWithIdentifier:(NSString *)identifier;
@end

@interface VSSpeechSynthesizer : NSObject
+ (NSArray *)availableLanguageCodes;
+ (NSArray *)availableVoicesForLanguageCode:(NSString *)code;
@end

@implementation VSSpeechSynthesizer
+ (NSDictionary *)listing
{
    return @{
        @"ar-SA": @"Maged", @"cs-CZ": @"Zuzana", @"da-DK": @"Ida", @"de-DE": @"Anna",
        @"el-GR": @"Alexandros", @"en-AU": @"Karen", @"en-GB": @"Daniel", @"en-IE": @"Moira",
        @"en-US": @"Samantha", @"en-ZA": @"Tessa", @"es-ES": @"Monica", @"es-MX": @"Paulina",
        @"fi-FI": @"Mikko", @"fr-CA": @"Julie", @"fr-FR": @"Thomas", @"hi-IN": @"Lekha",
        @"hu-HU": @"Eszter", @"id-ID": @"Damayanti", @"it-IT": @"Silvia", @"ja-JP": @"Kyoko",
        @"ko-KR": @"Yuna", @"nl-BE": @"Ellen", @"nl-NL": @"Xander", @"no-NO": @"Stine",
        @"pl-PL": @"Agata", @"pt-BR": @"Raquel", @"pt-PT": @"Joana", @"ro-RO": @"Simona",
        @"ru-RU": @"Milena", @"sk-SK": @"Laura", @"sv-SE": @"Alva", @"th-TH": @"Narisa",
        @"tr-TR": @"Aylin", @"zh-CN": @"Ting-Ting", @"zh-HK": @"Sin-Ji", @"zh-TW": @"Ya-Ling",
    };
}
+ (NSArray *)availableLanguageCodes
{
    return [[self listing].allKeys sortedArrayUsingSelector:@selector(compare:)];
}
+ (NSArray *)availableVoicesForLanguageCode:(NSString *)code
{
    NSString *name = [self listing][code];
    return name ? @[name] : @[];
}
@end

static int checks = 0;
static int failures = 0;

static void verdict(const char *what, BOOL held)
{
    checks++;
    if (!held) failures++;
    printf("%s %s\n", held ? "ok  " : "FAIL", what);
}

static void divergence(const char *what, BOOL pinned)
{
    checks++;
    if (!pinned) failures++;
    printf("%s divergence: %s\n", pinned ? "ok  " : "FAIL", what);
}

static NSString *fold(NSString *s)
{
    NSString *plain = [s stringByFoldingWithOptions:NSDiacriticInsensitiveSearch | NSCaseInsensitiveSearch locale:nil];
    return [[plain componentsSeparatedByString:@"-"] componentsJoinedByString:@""];
}

static BOOL same_voice(revenant_host_AVSpeechSynthesisVoice *p, AVSpeechSynthesisVoice *h)
{
    if (p == nil || h == nil) return p == nil && h == nil;
    AVSpeechSynthesisVoice *answer = [AVSpeechSynthesisVoice voiceWithLanguage:p.language];
    return [fold(p.name) isEqualToString:fold(h.name)] && [answer.identifier isEqualToString:h.identifier];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *expectedCurrent = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"en-US";

        verdict("control: host currentLanguageCode is the variant's", [[AVSpeechSynthesisVoice currentLanguageCode] isEqualToString:expectedCurrent]);
        verdict("control: host voiceWithIdentifier answers a known identifier",
                [AVSpeechSynthesisVoice voiceWithIdentifier:@"com.apple.voice.compact.en-US.Samantha"].name.length > 0);

        NSArray *portVoices = [revenant_host_AVSpeechSynthesisVoice speechVoices];
        verdict("listing: the port lists 36 voices (the release's codes)", portVoices.count == 36);
        BOOL allDefault = YES;
        for (revenant_host_AVSpeechSynthesisVoice *p in portVoices) allDefault &= p.quality == AVSpeechSynthesisVoiceQualityDefault;
        verdict("listing: every port voice is the default quality", allDefault);
        BOOL hostAllDefault = YES;
        for (AVSpeechSynthesisVoice *h in [AVSpeechSynthesisVoice speechVoices]) hostAllDefault &= h.quality == AVSpeechSynthesisVoiceQualityDefault;
        verdict("listing: every host voice is the default quality (the port's quality matches)", hostAllDefault);

        int hostAnswers = 0, hostAnswersSame = 0;
        for (revenant_host_AVSpeechSynthesisVoice *p in portVoices) {
            AVSpeechSynthesisVoice *h = [AVSpeechSynthesisVoice voiceWithIdentifier:p.identifier];
            if (h) {
                hostAnswers++;
                if (same_voice(p, h)) hostAnswersSame++;
            }
        }
        verdict("identifiers: the host answers 22 of the 36 port identifiers", hostAnswers == 22);
        verdict("identifiers: each host answer is the same language and voice", hostAnswers == hostAnswersSame);

        int found = 0;
        for (revenant_host_AVSpeechSynthesisVoice *p in portVoices) {
            if ([[revenant_host_AVSpeechSynthesisVoice voiceWithIdentifier:p.identifier].identifier isEqualToString:p.identifier]) found++;
        }
        verdict("voiceWithIdentifier: each port identifier finds its own voice", found == 36);
        verdict("voiceWithIdentifier: an unknown identifier is nil (host and port)",
                [AVSpeechSynthesisVoice voiceWithIdentifier:@"com.example.none"] == nil &&
                [revenant_host_AVSpeechSynthesisVoice voiceWithIdentifier:@"com.example.none"] == nil);
        verdict("voiceWithIdentifier: nil is nil (host and port)",
                [AVSpeechSynthesisVoice voiceWithIdentifier:nil] == nil && [revenant_host_AVSpeechSynthesisVoice voiceWithIdentifier:nil] == nil);
        verdict("voiceWithIdentifier: the release has no AVSpeechSynthesisVoiceIdentifierAlex value (host and port nil)",
                [AVSpeechSynthesisVoice voiceWithIdentifier:AVSpeechSynthesisVoiceIdentifierAlex] == nil &&
                [revenant_host_AVSpeechSynthesisVoice voiceWithIdentifier:AVSpeechSynthesisVoiceIdentifierAlex] == nil);

        NSArray *questions = @[[NSNull null], @"", @"en", @"en-NZ", @"en-US", @"en-GB", @"fr", @"fr-BE", @"fr-FR",
                               @"de", @"zh", @"zh-Hans", @"zh-CN", @"ar", @"ar-SA", @"xx-YY"];
        for (id q in questions) {
            NSString *code = [q isKindOfClass:[NSString class]] ? q : nil;
            AVSpeechSynthesisVoice *h = [AVSpeechSynthesisVoice voiceWithLanguage:code];
            revenant_host_AVSpeechSynthesisVoice *p = [revenant_host_AVSpeechSynthesisVoice voiceWithLanguage:code];
            char what[160];
            snprintf(what, sizeof what, "voiceWithLanguage:%s host %s port %s", code ? [code UTF8String] : "nil",
                     h ? [h.language UTF8String] : "nil", p ? [p.language UTF8String] : "nil");
            if ([h.language isEqualToString:@"ar-001"] || (code && [code hasPrefix:@"ar"])) {
                divergence(what, [h.language isEqualToString:@"ar-001"] && [p.language isEqualToString:@"ar-SA"]);
            } else {
                verdict(what, same_voice(p, h) || ((h == nil) == (p == nil) && (p == nil || [p.language isEqualToString:h.language])));
            }
        }

        NSString *hostCurrent = [AVSpeechSynthesisVoice currentLanguageCode];
        NSString *portCurrent = [revenant_host_AVSpeechSynthesisVoice currentLanguageCode];
        char what[160];
        snprintf(what, sizeof what, "currentLanguageCode host %s port %s", [hostCurrent UTF8String], [portCurrent UTF8String]);
        if ([hostCurrent isEqualToString:@"cmn-CN"]) {
            divergence(what, [portCurrent isEqualToString:@"zh-CN"]);
        } else if ([hostCurrent isEqualToString:@"ar-001"]) {
            divergence(what, [portCurrent isEqualToString:@"ar-SA"]);
        } else {
            verdict(what, [hostCurrent isEqualToString:portCurrent]);
        }

        revenant_host_AVSpeechSynthesisVoice *sample = [revenant_host_AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:sample];
        NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:archive error:nil];
        u.requiresSecureCoding = YES;
        revenant_host_AVSpeechSynthesisVoice *back = [u decodeObjectOfClass:[revenant_host_AVSpeechSynthesisVoice class] forKey:NSKeyedArchiveRootObjectKey];
        verdict("secure decode of a port voice yields a voice", back != nil);
        verdict("secure decode keeps the language, identifier, name and quality",
                back != nil && [back.language isEqualToString:sample.language] &&
                [back.identifier isEqualToString:sample.identifier] && [back.name isEqualToString:sample.name] &&
                back.quality == sample.quality);
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
