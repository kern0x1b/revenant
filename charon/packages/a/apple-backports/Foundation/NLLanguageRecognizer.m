#import <NaturalLanguage/NaturalLanguage.h>

static NSDictionary<NSString *, NSNumber *> *charon_word_shares(NSString *string)
{
    NSMutableDictionary *counts = [NSMutableDictionary dictionary];
    NLTokenizer *sentences = [[NLTokenizer alloc] initWithUnit:NLTokenUnitSentence];
    sentences.string = string;
    [sentences enumerateTokensInRange:NSMakeRange(0, string.length) usingBlock:^(NSRange sentence, NLTokenizerAttributes flags, BOOL *stop) {
        NSString *text = [string substringWithRange:sentence];
        NSUInteger letters = 0;
        for (NSUInteger index = 0; index < text.length; index++)
            letters += [[NSCharacterSet letterCharacterSet] characterIsMember:[text characterAtIndex:index]] ? 1 : 0;
        if (!letters)
            return;
        NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeLanguage] options:0];
        tagger.string = text;
        NSString *language = [tagger tagAtIndex:0 scheme:NSLinguisticTagSchemeLanguage tokenRange:NULL sentenceRange:NULL];
        if (language && ![language isEqualToString:NLLanguageUndetermined])
            counts[language] = @([counts[language] doubleValue] + letters);
    }];
    return counts;
}

@implementation NLLanguageRecognizer {
    NSMutableDictionary<NSString *, NSNumber *> *_weights;
    NSDictionary<NSString *, NSNumber *> *_hints;
    NSArray<NSString *> *_constraints;
}

+ (NLLanguage)dominantLanguageForString:(NSString *)string
{
    NLLanguageRecognizer *recognizer = [[NLLanguageRecognizer alloc] init];
    [recognizer processString:string];
    return recognizer.dominantLanguage;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _weights = [NSMutableDictionary dictionary];
        _hints = @{};
        _constraints = @[];
    }
    return self;
}

- (void)processString:(NSString *)string
{
    if (!string.length)
        return;
    [charon_word_shares(string) enumerateKeysAndObjectsUsingBlock:^(NSString *language, NSNumber *count, BOOL *stop) {
        self->_weights[language] = @([self->_weights[language] doubleValue] + count.doubleValue);
    }];
}

- (void)reset
{
    [_weights removeAllObjects];
}

- (NSDictionary<NLLanguage, NSNumber *> *)charon_scores
{
    NSMutableDictionary *scores = [NSMutableDictionary dictionary];
    double total = 0;
    for (NSString *language in _weights) {
        if (_constraints.count && ![_constraints containsObject:language])
            continue;
        double weight = _weights[language].doubleValue;
        if (_hints.count) {
            NSNumber *prior = _hints[language];
            weight *= prior ? prior.doubleValue : 0;
        }
        if (weight > 0) {
            scores[language] = @(weight);
            total += weight;
        }
    }
    if (total == 0 && _hints.count) {
        NSDictionary *hints = _hints;
        _hints = @{};
        NSDictionary *plain = [self charon_scores];
        _hints = hints;
        return plain;
    }
    NSMutableDictionary *shares = [NSMutableDictionary dictionaryWithCapacity:scores.count];
    for (NSString *language in scores)
        shares[language] = @([scores[language] doubleValue] / total);
    return shares;
}

- (NLLanguage)dominantLanguage
{
    NSDictionary *scores = [self charon_scores];
    NSString *best = nil;
    for (NSString *language in scores) {
        if (!best || [scores[language] doubleValue] > [scores[best] doubleValue] || ([scores[language] doubleValue] == [scores[best] doubleValue] && [language compare:best] == NSOrderedAscending))
            best = language;
    }
    return best;
}

- (NSDictionary<NLLanguage, NSNumber *> *)languageHypothesesWithMaximum:(NSUInteger)maxHypotheses
{
    NSDictionary *scores = [self charon_scores];
    if (!maxHypotheses || scores.count <= maxHypotheses)
        return scores;
    NSArray *ranked = [scores keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [b compare:a];
    }];
    NSMutableDictionary *top = [NSMutableDictionary dictionary];
    for (NSUInteger index = 0; index < maxHypotheses; index++)
        top[ranked[index]] = scores[ranked[index]];
    return top;
}

- (NSDictionary<NLLanguage, NSNumber *> *)languageHints
{
    return _hints;
}

- (void)setLanguageHints:(NSDictionary<NLLanguage, NSNumber *> *)languageHints
{
    _hints = [languageHints copy] ?: @{};
}

- (NSArray<NLLanguage> *)languageConstraints
{
    return _constraints;
}

- (void)setLanguageConstraints:(NSArray<NLLanguage> *)languageConstraints
{
    _constraints = [languageConstraints copy] ?: @[];
}

@end
