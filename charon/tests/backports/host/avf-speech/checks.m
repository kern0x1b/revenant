// checks.m -- AVSpeechUtterance and its three rate constants: the host's own class against the port's, in one
// binary (run.sh). Compiled plain, every bare name is Apple's. The port's two objects are compiled with each
// name renamed to a charon_host_ spelling and linked beside this file, so the prefixed names below are the
// port's own. Every line compares the two answers to the same question; nothing here is a typed expectation
// except the one control at the top, which asks the host what its own default rate is.
//
// Output: "ok" and "FAIL" lines, a "divergence" line for the one measured difference, and checks=N failures=M.

#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>
#include <math.h>

@interface charon_host_AVSpeechUtterance : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)speechUtteranceWithString:(NSString *)string;
- (instancetype)initWithString:(NSString *)string;
@property (nonatomic, readonly) NSString *speechString;
@property (nonatomic, retain) id voice;
@property (nonatomic) float rate;
@property (nonatomic) float pitchMultiplier;
@property (nonatomic) float volume;
@property (nonatomic) NSTimeInterval preUtteranceDelay;
@property (nonatomic) NSTimeInterval postUtteranceDelay;
@end

extern const float charon_host_AVSpeechUtteranceMinimumSpeechRate;
extern const float charon_host_AVSpeechUtteranceMaximumSpeechRate;
extern const float charon_host_AVSpeechUtteranceDefaultSpeechRate;

static int checks = 0;
static int failures = 0;

static void verdict(const char *what, BOOL held)
{
    checks++;
    if (!held) failures++;
    printf("%s %s\n", held ? "ok  " : "FAIL", what);
}

static BOOL same_f(float a, float b) { return (isnan(a) && isnan(b)) || a == b; }
static BOOL same_d(double a, double b) { return (isnan(a) && isnan(b)) || a == b; }

// Compares one utterance's whole state, host against port, under a label.
static void compare_state(const char *label, AVSpeechUtterance *h, charon_host_AVSpeechUtterance *p)
{
    char what[256];
    snprintf(what, sizeof what, "%s rate %g vs %g", label, h.rate, p.rate);
    verdict(what, same_f(h.rate, p.rate));
    snprintf(what, sizeof what, "%s pitchMultiplier %g vs %g", label, h.pitchMultiplier, p.pitchMultiplier);
    verdict(what, same_f(h.pitchMultiplier, p.pitchMultiplier));
    snprintf(what, sizeof what, "%s volume %g vs %g", label, h.volume, p.volume);
    verdict(what, same_f(h.volume, p.volume));
    snprintf(what, sizeof what, "%s preUtteranceDelay %g vs %g", label, h.preUtteranceDelay, p.preUtteranceDelay);
    verdict(what, same_d(h.preUtteranceDelay, p.preUtteranceDelay));
    snprintf(what, sizeof what, "%s postUtteranceDelay %g vs %g", label, h.postUtteranceDelay, p.postUtteranceDelay);
    verdict(what, same_d(h.postUtteranceDelay, p.postUtteranceDelay));
    snprintf(what, sizeof what, "%s voice identity", label);
    verdict(what, h.voice == nil ? p.voice == nil : p.voice != nil);
    snprintf(what, sizeof what, "%s speechString", label);
    verdict(what, (h.speechString == nil) == (p.speechString == nil) &&
                  (h.speechString == nil || [h.speechString isEqualToString:p.speechString]));
}

int main(void)
{
    @autoreleasepool {
        // Control: the probe reads Apple's own constant. If this disagrees, the probe is not reading the host.
        verdict("control: host default rate is 0.5", AVSpeechUtteranceDefaultSpeechRate == 0.5f);

        // The three constants, each a float. Host against port.
        verdict("constant minimum rate", AVSpeechUtteranceMinimumSpeechRate == charon_host_AVSpeechUtteranceMinimumSpeechRate);
        verdict("constant maximum rate", AVSpeechUtteranceMaximumSpeechRate == charon_host_AVSpeechUtteranceMaximumSpeechRate);
        verdict("constant default rate", AVSpeechUtteranceDefaultSpeechRate == charon_host_AVSpeechUtteranceDefaultSpeechRate);

        // Defaults of the factory and of -initWithString:, host against port.
        AVSpeechUtterance *h = [AVSpeechUtterance speechUtteranceWithString:@"hello"];
        charon_host_AVSpeechUtterance *p = [charon_host_AVSpeechUtterance speechUtteranceWithString:@"hello"];
        compare_state("factory", h, p);
        verdict("factory default rate is the default constant", h.rate == AVSpeechUtteranceDefaultSpeechRate);

        // Later-release properties the port does not carry: the port must not answer them. The host does (it is a
        // later system), so these are port-only assertions; a silent getter here would be a fake.
        verdict("port does not answer attributedSpeechString (iOS 10)",
                ![charon_host_AVSpeechUtterance instancesRespondToSelector:@selector(attributedSpeechString)]);
        verdict("port does not answer prefersAssistiveTechnologySettings (iOS 14)",
                ![charon_host_AVSpeechUtterance instancesRespondToSelector:@selector(prefersAssistiveTechnologySettings)] &&
                ![charon_host_AVSpeechUtterance instancesRespondToSelector:@selector(setPrefersAssistiveTechnologySettings:)]);
        verdict("host answers attributedSpeechString (control for the port-only check above)",
                [AVSpeechUtterance instancesRespondToSelector:@selector(attributedSpeechString)]);

        // A plain -init leaves every number at zero, on both.
        AVSpeechUtterance *hi = [[AVSpeechUtterance alloc] init];
        charon_host_AVSpeechUtterance *pi = [[charon_host_AVSpeechUtterance alloc] init];
        compare_state("plain init", hi, pi);

        // A nil string, which both accept.
        AVSpeechUtterance *hn = [[AVSpeechUtterance alloc] initWithString:nil];
        charon_host_AVSpeechUtterance *pn = [[charon_host_AVSpeechUtterance alloc] initWithString:nil];
        compare_state("nil string", hn, pn);

        // Setters, each over the same inputs on both. Read back what each object holds.
        float rates[] = {-1, -0.0f, 0, 0.25f, 0.5f, 1, 1.5f, 2, INFINITY, NAN};
        for (size_t i = 0; i < sizeof rates / sizeof rates[0]; i++) {
            h.rate = rates[i]; p.rate = rates[i];
            char what[128];
            snprintf(what, sizeof what, "rate set %g", rates[i]);
            verdict(what, same_f(h.rate, p.rate));
        }
        float pitches[] = {-1, 0, 0.25f, 0.49f, 0.5f, 0.51f, 1, 2, 3, NAN, INFINITY};
        for (size_t i = 0; i < sizeof pitches / sizeof pitches[0]; i++) {
            h.pitchMultiplier = pitches[i]; p.pitchMultiplier = pitches[i];
            char what[128];
            snprintf(what, sizeof what, "pitchMultiplier set %g", pitches[i]);
            verdict(what, same_f(h.pitchMultiplier, p.pitchMultiplier));
        }
        float volumes[] = {-1, -0.0f, 0, 0.5f, 1, 2, NAN, INFINITY};
        for (size_t i = 0; i < sizeof volumes / sizeof volumes[0]; i++) {
            h.volume = volumes[i]; p.volume = volumes[i];
            char what[128];
            snprintf(what, sizeof what, "volume set %g", volumes[i]);
            verdict(what, same_f(h.volume, p.volume));
        }
        double delays[] = {-1, 0, 1.5, 1e9, NAN};
        for (size_t i = 0; i < sizeof delays / sizeof delays[0]; i++) {
            h.preUtteranceDelay = delays[i]; p.preUtteranceDelay = delays[i];
            h.postUtteranceDelay = delays[i]; p.postUtteranceDelay = delays[i];
            char what[128];
            snprintf(what, sizeof what, "delays set %g", delays[i]);
            verdict(what, same_d(h.preUtteranceDelay, p.preUtteranceDelay) && same_d(h.postUtteranceDelay, p.postUtteranceDelay));
        }

        // Voice: the same object is handed to both and read back as that object.
        NSObject *voice = [NSObject new];
        h.voice = voice; p.voice = voice;
        verdict("voice retained by host", h.voice == voice);
        verdict("voice retained by port", p.voice == voice);
        h.voice = nil; p.voice = nil;
        verdict("voice nil on both", h.voice == nil && p.voice == nil);

        // The string is retained, not copied: a later append shows through, on both.
        NSMutableString *ms = [NSMutableString stringWithString:@"abc"];
        AVSpeechUtterance *hm = [AVSpeechUtterance speechUtteranceWithString:ms];
        charon_host_AVSpeechUtterance *pm = [charon_host_AVSpeechUtterance speechUtteranceWithString:ms];
        [ms appendString:@"def"];
        verdict("host string retained, not copied", [hm.speechString isEqualToString:@"abcdef"]);
        verdict("port string retained, not copied", [pm.speechString isEqualToString:@"abcdef"]);

        // Copy: a new object that carries every number, the string and the voice.
        h.rate = 0.75f; p.rate = 0.75f;
        h.pitchMultiplier = 1.5f; p.pitchMultiplier = 1.5f;
        h.volume = 0.25f; p.volume = 0.25f;
        h.preUtteranceDelay = 1.25; p.preUtteranceDelay = 1.25;
        h.postUtteranceDelay = 2.5; p.postUtteranceDelay = 2.5;
        h.voice = voice; p.voice = voice;
        AVSpeechUtterance *hc = [h copy];
        charon_host_AVSpeechUtterance *pc = [p copy];
        verdict("host copy is a new object", hc != h);
        verdict("port copy is a new object", pc != p);
        compare_state("copy", hc, pc);
        verdict("host copy keeps the voice object", hc.voice == voice);
        verdict("port copy keeps the voice object", pc.voice == voice);

        // Secure coding: both declare it, and both round-trip the numbers through a secure decode.
        verdict("host supports secure coding", [AVSpeechUtterance supportsSecureCoding]);
        verdict("port supports secure coding", [charon_host_AVSpeechUtterance supportsSecureCoding]);
        // An archivable voice: a plain NSObject is not one, and the host's encoder raises on it.
        AVSpeechSynthesisVoice *sv = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
        h.voice = sv; p.voice = sv;
        NSData *hd = [NSKeyedArchiver archivedDataWithRootObject:h];
        NSData *pd = [NSKeyedArchiver archivedDataWithRootObject:p];
        NSKeyedUnarchiver *hu = [[NSKeyedUnarchiver alloc] initForReadingFromData:hd error:nil];
        hu.requiresSecureCoding = YES;
        AVSpeechUtterance *hr = [hu decodeObjectOfClass:[AVSpeechUtterance class] forKey:NSKeyedArchiveRootObjectKey];
        NSKeyedUnarchiver *pu = [[NSKeyedUnarchiver alloc] initForReadingFromData:pd error:nil];
        pu.requiresSecureCoding = YES;
        charon_host_AVSpeechUtterance *pr = [pu decodeObjectOfClass:[charon_host_AVSpeechUtterance class] forKey:NSKeyedArchiveRootObjectKey];
        verdict("host secure decode yields an utterance", hr != nil);
        verdict("port secure decode yields an utterance", pr != nil);
        verdict("secure decode rate", hr != nil && pr != nil && same_f(hr.rate, pr.rate));
        verdict("secure decode pitchMultiplier", hr != nil && pr != nil && same_f(hr.pitchMultiplier, pr.pitchMultiplier));
        verdict("secure decode volume", hr != nil && pr != nil && same_f(hr.volume, pr.volume));
        verdict("secure decode preUtteranceDelay", hr != nil && pr != nil && same_d(hr.preUtteranceDelay, pr.preUtteranceDelay));
        verdict("secure decode postUtteranceDelay", hr != nil && pr != nil && same_d(hr.postUtteranceDelay, pr.postUtteranceDelay));
        verdict("secure decode voice identifier", hr != nil && pr != nil &&
                [hr.voice.identifier isEqualToString:[pr.voice valueForKey:@"identifier"]]);

        // The one measured difference. The host's own archive holds speechString as $null (plutil on the
        // archive), so its decode returns nil; the port encodes and keeps the string. Pinned as a divergence:
        // if the host ever keeps the string, this line goes red and the facts file has to be read again.
        verdict("divergence: host decodes speechString as nil (archive holds $null)", hr != nil && hr.speechString == nil);
        verdict("divergence: port decodes speechString as the encoded string", pr != nil && [pr.speechString isEqualToString:@"hello"]);
        printf("divergence: speechString on secure decode: host=%s port=%s\n",
               hr.speechString ? "kept" : "nil", pr.speechString ? "kept" : "nil");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
