#import <Foundation/Foundation.h>

static NSRange charon_sentence_range(NSString *string, NSUInteger index)
{
    NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeTokenType] options:0];
    tagger.string = string;
    return [tagger sentenceRangeForRange:NSMakeRange(index, 0)];
}

static NSString *charon_first_tag(NSString *string, NSRange range, NSLinguisticTagScheme scheme)
{
    NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[scheme] options:0];
    tagger.string = string;
    __block NSString *found = nil;
    [tagger enumerateTagsInRange:range scheme:scheme options:NSLinguisticTaggerOmitWhitespace | NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitOther usingBlock:^(NSLinguisticTag tag, NSRange tokenRange, NSRange sentenceRange, BOOL *stop) {
        if (tag) {
            found = tag;
            *stop = YES;
        }
    }];
    return found;
}

static NSString *charon_dominant_tag(NSString *string, NSLinguisticTagScheme scheme)
{
    NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[scheme] options:0];
    tagger.string = string;
    NSMutableDictionary *weights = [NSMutableDictionary dictionary];
    NSMutableArray *order = [NSMutableArray array];
    [tagger enumerateTagsInRange:NSMakeRange(0, string.length) scheme:scheme options:NSLinguisticTaggerOmitWhitespace | NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitOther usingBlock:^(NSLinguisticTag tag, NSRange tokenRange, NSRange sentenceRange, BOOL *stop) {
        if (!tag)
            return;
        if (!weights[tag])
            [order addObject:tag];
        weights[tag] = @([weights[tag] unsignedIntegerValue] + 1);
    }];
    NSString *best = nil;
    for (NSString *tag in order)
        if (!best || [weights[tag] unsignedIntegerValue] > [weights[best] unsignedIntegerValue])
            best = tag;
    return best;
}

static void charon_raise(SEL selector)
{
    [NSException raise:NSRangeException format:@"*** -[NSLinguisticTagger %@]: Range or index out of bounds", NSStringFromSelector(selector)];
}

static NSRange charon_unit_range(NSLinguisticTagger *self, NSUInteger index, NSLinguisticTaggerUnit unit)
{
    NSString *string = self.string;
    switch (unit) {
    case NSLinguisticTaggerUnitSentence:
        return charon_sentence_range(string, index);
    case NSLinguisticTaggerUnitParagraph:
        return [string paragraphRangeForRange:NSMakeRange(index, 0)];
    case NSLinguisticTaggerUnitDocument:
        return NSMakeRange(0, string.length);
    default: {
        NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeTokenType] options:0];
        tagger.string = string;
        NSRange token = NSMakeRange(NSNotFound, 0);
        [tagger tagAtIndex:index scheme:NSLinguisticTagSchemeTokenType tokenRange:&token sentenceRange:NULL];
        return token;
    }
    }
}

static NSLinguisticTagger *charon_tagger(NSString *string, NSLinguisticTagScheme scheme, NSOrthography *orthography)
{
    NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[scheme] options:0];
    tagger.string = string;
    if (orthography)
        [tagger setOrthography:orthography range:NSMakeRange(0, string.length)];
    return tagger;
}

@implementation NSLinguisticTagger (CharonUnits)

- (NSRange)tokenRangeAtIndex:(NSUInteger)charIndex unit:(NSLinguisticTaggerUnit)unit
{
    if (!self.string || charIndex >= self.string.length)
        charon_raise(_cmd);
    return charon_unit_range(self, charIndex, unit);
}

- (void)enumerateTagsInRange:(NSRange)range unit:(NSLinguisticTaggerUnit)unit scheme:(NSLinguisticTagScheme)scheme options:(NSLinguisticTaggerOptions)options usingBlock:(void (NS_NOESCAPE ^)(NSLinguisticTag tag, NSRange tokenRange, BOOL *stop))block
{
    NSString *string = self.string;
    if (!string || NSMaxRange(range) > string.length)
        charon_raise(_cmd);
    if (unit == NSLinguisticTaggerUnitWord) {
        __block BOOL stopped = NO;
        [self enumerateTagsInRange:range scheme:scheme options:options usingBlock:^(NSLinguisticTag tag, NSRange tokenRange, NSRange sentenceRange, BOOL *stop) {
            if (stopped) {
                *stop = YES;
                return;
            }
            block(tag, tokenRange, &stopped);
            if (stopped)
                *stop = YES;
        }];
        return;
    }
    if (![scheme isEqual:NSLinguisticTagSchemeLanguage] && ![scheme isEqual:NSLinguisticTagSchemeScript])
        return;
    NSUInteger index = range.location;
    BOOL stop = NO;
    while (!stop && index < NSMaxRange(range)) {
        NSRange token = charon_unit_range(self, index, unit);
        if (token.length == 0)
            break;
        block(charon_first_tag(string, token, scheme), token, &stop);
        index = NSMaxRange(token);
    }
}

- (NSLinguisticTag)tagAtIndex:(NSUInteger)charIndex unit:(NSLinguisticTaggerUnit)unit scheme:(NSLinguisticTagScheme)scheme tokenRange:(NSRangePointer)tokenRange
{
    NSString *string = self.string;
    if (!string || charIndex >= string.length)
        charon_raise(_cmd);
    if (unit == NSLinguisticTaggerUnitWord)
        return [self tagAtIndex:charIndex scheme:scheme tokenRange:tokenRange sentenceRange:NULL];
    NSRange token = charon_unit_range(self, charIndex, unit);
    if (tokenRange)
        *tokenRange = token;
    if (![scheme isEqual:NSLinguisticTagSchemeLanguage] && ![scheme isEqual:NSLinguisticTagSchemeScript])
        return nil;
    return charon_first_tag(string, token, scheme);
}

- (NSArray<NSLinguisticTag> *)tagsInRange:(NSRange)range unit:(NSLinguisticTaggerUnit)unit scheme:(NSLinguisticTagScheme)scheme options:(NSLinguisticTaggerOptions)options tokenRanges:(NSArray<NSValue *> **)tokenRanges
{
    NSMutableArray *tags = [NSMutableArray array], *ranges = [NSMutableArray array];
    [self enumerateTagsInRange:range unit:unit scheme:scheme options:options usingBlock:^(NSLinguisticTag tag, NSRange tokenRange, BOOL *stop) {
        [tags addObject:tag ?: (id)[NSNull null]];
        [ranges addObject:[NSValue valueWithRange:tokenRange]];
    }];
    if (tokenRanges)
        *tokenRanges = ranges;
    return tags;
}

+ (NSArray<NSLinguisticTagScheme> *)availableTagSchemesForUnit:(NSLinguisticTaggerUnit)unit language:(NSString *)language
{
    if (unit == NSLinguisticTaggerUnitWord)
        return [self availableTagSchemesForLanguage:language];
    return @[NSLinguisticTagSchemeLanguage, NSLinguisticTagSchemeScript];
}

- (NSString *)dominantLanguage
{
    NSString *string = self.string;
    if (!string.length)
        return nil;
    return charon_dominant_tag(string, NSLinguisticTagSchemeLanguage);
}

+ (NSString *)dominantLanguageForString:(NSString *)string
{
    if (!string.length)
        return nil;
    return charon_dominant_tag(string, NSLinguisticTagSchemeLanguage);
}

+ (NSLinguisticTag)tagForString:(NSString *)string atIndex:(NSUInteger)charIndex unit:(NSLinguisticTaggerUnit)unit scheme:(NSLinguisticTagScheme)scheme orthography:(NSOrthography *)orthography tokenRange:(NSRangePointer)tokenRange
{
    return [charon_tagger(string, scheme, orthography) tagAtIndex:charIndex unit:unit scheme:scheme tokenRange:tokenRange];
}

+ (NSArray<NSLinguisticTag> *)tagsForString:(NSString *)string range:(NSRange)range unit:(NSLinguisticTaggerUnit)unit scheme:(NSLinguisticTagScheme)scheme options:(NSLinguisticTaggerOptions)options orthography:(NSOrthography *)orthography tokenRanges:(NSArray<NSValue *> **)tokenRanges
{
    return [charon_tagger(string, scheme, orthography) tagsInRange:range unit:unit scheme:scheme options:options tokenRanges:tokenRanges];
}

+ (void)enumerateTagsForString:(NSString *)string range:(NSRange)range unit:(NSLinguisticTaggerUnit)unit scheme:(NSLinguisticTagScheme)scheme options:(NSLinguisticTaggerOptions)options orthography:(NSOrthography *)orthography usingBlock:(void (NS_NOESCAPE ^)(NSLinguisticTag tag, NSRange tokenRange, BOOL *stop))block
{
    [charon_tagger(string, scheme, orthography) enumerateTagsInRange:range unit:unit scheme:scheme options:options usingBlock:block];
}

@end
