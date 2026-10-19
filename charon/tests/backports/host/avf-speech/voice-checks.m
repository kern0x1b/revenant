// voice-checks.m -- AVSpeechSynthesisVoice: the host's own class against the port's, in one binary (run.sh).
//
// The host has no VoiceServices framework (dlopen finds none on this macOS), so the port's listing source is a stub
// VSSpeechSynthesizer class defined here. Its answers are the 6.1.3 listing as the guest probe read it on the 6.1.3
// image (voices/listing-6.1.3.txt, run.sh checks the stub against it): the release's own list is the port's input,
// and everything else the port answers is compared to the host's AVSpeechSynthesisVoice, which reads the host's list.
//
// Each line compares the two answers to the same question. A "divergence" line pins a difference that was measured
// (the release lists ar-SA and the host ar-001 for the same voice; a zh-Hans-CN locale is cmn-CN on the host and
// zh-CN in the port): it goes red if the host or the release changes its answer.
//
// argv[1] is the host's current language code for this run (run.sh gives one per locale variant), so the control
// below checks that the probe reads the host's setting and not a default.
//
// Output: "ok", "FAIL" and "divergence" lines, and checks=N failures=M.

#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>

@interface charon_host_AVSpeechSynthesisVoice : NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSString *language;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) AVSpeechSynthesisVoiceQuality quality;
+ (NSArray *)speechVoices;
+ (NSString *)currentLanguageCode;
+ (charon_host_AVSpeechSynthesisVoice *)voiceWithLanguage:(NSString *)languageCode;
+ (charon_host_AVSpeechSynthesisVoice *)voiceWithIdentifier:(NSString *)identifier;
@end

// The listing source the port finds by name. The 36 codes and one voice each, as the 6.1.3 probe listed them.
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

// The host's name for a voice compared with the release's: the host's names carry accents (an acute accent on Monica and Amelie) and the
// release's a hyphen (Ting-Ting), so both are folded to plain letters before the comparison.
static NSString *fold(NSString *s)
{
    NSString *plain = [s stringByFoldingWithOptions:NSDiacriticInsensitiveSearch | NSCaseInsensitiveSearch locale:nil];
    return [[plain componentsSeparatedByString:@"-"] componentsJoinedByString:@""];
}

// The same voice: the same name, and the host's own answer for the port's language is that voice. (The host lists
// Sin-Ji under yue-HK and answers zh-HK with it, so the language alone does not identify the voice on the host.)
static BOOL same_voice(charon_host_AVSpeechSynthesisVoice *p, AVSpeechSynthesisVoice *h)
{
    if (p == nil || h == nil) return p == nil && h == nil;
    AVSpeechSynthesisVoice *answer = [AVSpeechSynthesisVoice voiceWithLanguage:p.language];
    return [fold(p.name) isEqualToString:fold(h.name)] && [answer.identifier isEqualToString:h.identifier];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *expectedCurrent = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"en-US";

        // Control: the probe reads the host's own current language, which run.sh sets per variant.
        verdict("control: host currentLanguageCode is the variant's", [[AVSpeechSynthesisVoice currentLanguageCode] isEqualToString:expectedCurrent]);
        verdict("control: host voiceWithIdentifier answers a known identifier",
                [AVSpeechSynthesisVoice voiceWithIdentifier:@"com.apple.voice.compact.en-US.Samantha"].name.length > 0);

        // Listing: the port reads every code of the stub listing, one voice each, default quality.
        NSArray *portVoices = [charon_host_AVSpeechSynthesisVoice speechVoices];
        verdict("listing: the port lists 36 voices (the release's codes)", portVoices.count == 36);
        BOOL allDefault = YES;
        for (charon_host_AVSpeechSynthesisVoice *p in portVoices) allDefault &= p.quality == AVSpeechSynthesisVoiceQualityDefault;
        verdict("listing: every port voice is the default quality", allDefault);
        BOOL hostAllDefault = YES;
        for (AVSpeechSynthesisVoice *h in [AVSpeechSynthesisVoice speechVoices]) hostAllDefault &= h.quality == AVSpeechSynthesisVoiceQualityDefault;
        verdict("listing: every host voice is the default quality (the port's quality matches)", hostAllDefault);

        // Identifiers: the host answers the voices it has under the same language and name; each such answer names the
        // same voice. The other voices get the host's pattern, which the host does not answer.
        int hostAnswers = 0, hostAnswersSame = 0;
        for (charon_host_AVSpeechSynthesisVoice *p in portVoices) {
            AVSpeechSynthesisVoice *h = [AVSpeechSynthesisVoice voiceWithIdentifier:p.identifier];
            if (h) {
                hostAnswers++;
                if (same_voice(p, h)) hostAnswersSame++;
            }
        }
        verdict("identifiers: the host answers 22 of the 36 port identifiers", hostAnswers == 22);
        verdict("identifiers: each host answer is the same language and voice", hostAnswers == hostAnswersSame);

        // voiceWithIdentifier: over the port's own identifiers, and the two answers that must be nil.
        int found = 0;
        for (charon_host_AVSpeechSynthesisVoice *p in portVoices) {
            if ([[charon_host_AVSpeechSynthesisVoice voiceWithIdentifier:p.identifier].identifier isEqualToString:p.identifier]) found++;
        }
        verdict("voiceWithIdentifier: each port identifier finds its own voice", found == 36);
        verdict("voiceWithIdentifier: an unknown identifier is nil (host and port)",
                [AVSpeechSynthesisVoice voiceWithIdentifier:@"com.example.none"] == nil &&
                [charon_host_AVSpeechSynthesisVoice voiceWithIdentifier:@"com.example.none"] == nil);
        verdict("voiceWithIdentifier: nil is nil (host and port)",
                [AVSpeechSynthesisVoice voiceWithIdentifier:nil] == nil && [charon_host_AVSpeechSynthesisVoice voiceWithIdentifier:nil] == nil);
        verdict("voiceWithIdentifier: the release has no AVSpeechSynthesisVoiceIdentifierAlex value (host and port nil)",
                [AVSpeechSynthesisVoice voiceWithIdentifier:AVSpeechSynthesisVoiceIdentifierAlex] == nil &&
                [charon_host_AVSpeechSynthesisVoice voiceWithIdentifier:AVSpeechSynthesisVoiceIdentifierAlex] == nil);

        // voiceWithLanguage: over the same questions, host against port. The language of the answer is compared.
        NSArray *questions = @[[NSNull null], @"", @"en", @"en-NZ", @"en-US", @"en-GB", @"fr", @"fr-BE", @"fr-FR",
                               @"de", @"zh", @"zh-Hans", @"zh-CN", @"ar", @"ar-SA", @"xx-YY"];
        for (id q in questions) {
            NSString *code = [q isKindOfClass:[NSString class]] ? q : nil;
            AVSpeechSynthesisVoice *h = [AVSpeechSynthesisVoice voiceWithLanguage:code];
            charon_host_AVSpeechSynthesisVoice *p = [charon_host_AVSpeechSynthesisVoice voiceWithLanguage:code];
            char what[160];
            snprintf(what, sizeof what, "voiceWithLanguage:%s host %s port %s", code ? [code UTF8String] : "nil",
                     h ? [h.language UTF8String] : "nil", p ? [p.language UTF8String] : "nil");
            // The release lists ar-SA; the host lists the same voice as ar-001 and has no ar-SA.
            if ([h.language isEqualToString:@"ar-001"] || (code && [code hasPrefix:@"ar"])) {
                divergence(what, [h.language isEqualToString:@"ar-001"] && [p.language isEqualToString:@"ar-SA"]);
            } else {
                verdict(what, same_voice(p, h) || ((h == nil) == (p == nil) && (p == nil || [p.language isEqualToString:h.language])));
            }
        }

        // currentLanguageCode: host against port, for this variant's setting.
        NSString *hostCurrent = [AVSpeechSynthesisVoice currentLanguageCode];
        NSString *portCurrent = [charon_host_AVSpeechSynthesisVoice currentLanguageCode];
        char what[160];
        snprintf(what, sizeof what, "currentLanguageCode host %s port %s", [hostCurrent UTF8String], [portCurrent UTF8String]);
        if ([hostCurrent isEqualToString:@"cmn-CN"]) {
            // zh-Hans-CN: the host's cmn-CN is not in the release's list; the port answers the release's zh-CN.
            divergence(what, [portCurrent isEqualToString:@"zh-CN"]);
        } else if ([hostCurrent isEqualToString:@"ar-001"]) {
            divergence(what, [portCurrent isEqualToString:@"ar-SA"]);
        } else {
            verdict(what, [hostCurrent isEqualToString:portCurrent]);
        }

        // Secure coding: the port's voice round-trips every field through a secure decode.
        charon_host_AVSpeechSynthesisVoice *sample = [charon_host_AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:sample];
        NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:archive error:nil];
        u.requiresSecureCoding = YES;
        charon_host_AVSpeechSynthesisVoice *back = [u decodeObjectOfClass:[charon_host_AVSpeechSynthesisVoice class] forKey:NSKeyedArchiveRootObjectKey];
        verdict("secure decode of a port voice yields a voice", back != nil);
        verdict("secure decode keeps the language, identifier, name and quality",
                back != nil && [back.language isEqualToString:sample.language] &&
                [back.identifier isEqualToString:sample.identifier] && [back.name isEqualToString:sample.name] &&
                back.quality == sample.quality);
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
