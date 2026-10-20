#import <Foundation/Foundation.h>
#ifndef REVENANT_BRAILLE_ONLY
#import <Accessibility/Accessibility.h>
#endif
#import <ctype.h>
#import <stdint.h>

#import "RevenantBraille.h"
#import "../../../c/revenant-coding/files/RevenantCoding.h"

#pragma mark - The standard's tables

static const uint16_t revenant_ueb_letters[26] = {
    0x01, 0x03, 0x09, 0x19, 0x11, 0x0B, 0x1B, 0x13,
    0x0A, 0x1A, 0x05, 0x07, 0x0D, 0x1D, 0x15, 0x0F,
    0x1F, 0x17, 0x0E, 0x1E, 0x25, 0x27, 0x3A, 0x2D,
    0x3D, 0x35,
};

static const uint16_t revenant_ueb_capital = 0x20;
static const uint16_t revenant_ueb_number = 0x3C;

static const uint16_t revenant_ueb_grade1 = 0x30;

#define REVENANT_UEB_BASE 0x2800
static unichar revenant_ueb_pattern(uint16_t mask)
{
    return (unichar)(REVENANT_UEB_BASE + mask);
}

enum {
    RevenantBrailleSpace = 0x00,
    RevenantBrailleComma = 0x02,
    RevenantBrailleSemicolon = 0x06,
    RevenantBrailleColon = 0x12,
    RevenantBraillePeriod = 0x32,
    RevenantBrailleExclamation = 0x16,
    RevenantBrailleQuestion = 0x26,
    RevenantBrailleApostrophe = 0x04,
    RevenantBrailleHyphen = 0x24,
    RevenantBraillePair = 0x17,
    RevenantBrailleSlash = 0x2F,
};

static const struct { unichar character; uint16_t cell; } revenant_ueb_punctuation[] = {
    { ',', RevenantBrailleComma },
    { ';', RevenantBrailleSemicolon },
    { ':', RevenantBrailleColon },
    { '.', RevenantBraillePeriod },
    { '!', RevenantBrailleExclamation },
    { '?', RevenantBrailleQuestion },
    { '\'', RevenantBrailleApostrophe },
    { '-', RevenantBrailleHyphen },
    { '(', RevenantBraillePair },
    { ')', RevenantBraillePair },
    { '*', RevenantBraillePair },
    { '/', RevenantBrailleSlash },
    { '"', RevenantBrailleQuestion },
};

static const unsigned revenant_ueb_punctuation_count =
    sizeof(revenant_ueb_punctuation) / sizeof(revenant_ueb_punctuation[0]);

static uint16_t revenant_ueb_cell(unichar character, BOOL *covered)
{
    *covered = YES;
    if (character >= 'a' && character <= 'z') {
        return revenant_ueb_letters[character - 'a'];
    }
    if (character >= 'A' && character <= 'Z') {
        return revenant_ueb_letters[character - 'A'];
    }
    for (unsigned index = 0; index < revenant_ueb_punctuation_count; index++) {
        if (revenant_ueb_punctuation[index].character == character) {
            return revenant_ueb_punctuation[index].cell;
        }
    }
    *covered = NO;
    return RevenantBrailleSpace;
}

static BOOL revenant_ueb_run_starts(unichar character, NSString *text, NSUInteger index)
{
    (void)character;
    NSUInteger next = index + 1;
    if (next >= [text length]) {
        return NO;
    }
    unichar following = [text characterAtIndex:next];
    return following >= 'A' && following <= 'Z';
}

#pragma mark - AXBrailleTable

@implementation AXBrailleTable {
    NSString *_identifier;
    NSString *_localizedName;
    NSString *_providerIdentifier;
    NSString *_localizedProviderName;
    NSString *_language;
    NSSet<NSLocale *> *_locales;
    BOOL _isEightDot;
}

@synthesize identifier = _identifier;
@synthesize localizedName = _localizedName;
@synthesize providerIdentifier = _providerIdentifier;
@synthesize localizedProviderName = _localizedProviderName;
@synthesize language = _language;
@synthesize locales = _locales;
@synthesize isEightDot = _isEightDot;

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (!identifier) {
        return nil;
    }
    if ((self = [super init])) {
        _identifier = [identifier copy];
    }
    return self;
}

+ (NSSet<NSLocale *> *)supportedLocales
{
    return [NSSet set];
}

+ (AXBrailleTable *)defaultTableForLocale:(NSLocale *)locale
{
    return nil;
}

+ (NSSet<AXBrailleTable *> *)tablesForLocale:(NSLocale *)locale
{
    return [NSSet set];
}

+ (NSSet<AXBrailleTable *> *)languageAgnosticTables
{
    return [NSSet set];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
    if ((self = [[[self class] alloc] initWithIdentifier:identifier])) {
        revenant_intents_decode(self, coder);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    AXBrailleTable *copy = [[[self class] allocWithZone:zone] initWithIdentifier:_identifier];
    copy->_localizedName = _localizedName;
    copy->_providerIdentifier = _providerIdentifier;
    copy->_localizedProviderName = _localizedProviderName;
    copy->_language = _language;
    copy->_locales = _locales;
    copy->_isEightDot = _isEightDot;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AXBrailleTable %@ %@>", _identifier, _localizedName];
}

@end

#pragma mark - AXBrailleTranslationResult

@implementation AXBrailleTranslationResult {
    NSString *_resultString;
    NSArray<NSNumber *> *_locationMap;
    NSUInteger _unmapped;
}

@synthesize resultString = _resultString;
@synthesize locationMap = _locationMap;

- (NSUInteger)revenant_unmappedCount
{
    return _unmapped;
}

- (instancetype)revenant_withResultString:(NSString *)resultString
                                locations:(NSArray<NSNumber *> *)locations
{
    return [self revenant_withResultString:resultString locations:locations unmapped:0];
}

- (instancetype)revenant_withResultString:(NSString *)resultString
                                locations:(NSArray<NSNumber *> *)locations
                                 unmapped:(NSUInteger)unmapped
{
    AXBrailleTranslationResult *result = [[AXBrailleTranslationResult alloc] init];
    result->_resultString = [resultString copy];
    result->_locationMap = [locations copy];
    result->_unmapped = unmapped;
    return result;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        revenant_intents_decode(self, coder);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[AXBrailleTranslationResult alloc] revenant_withResultString:_resultString
                                                              locations:_locationMap
                                                               unmapped:_unmapped];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AXBrailleTranslationResult %@ %lu cell(s), %lu unmapped>",
            _resultString, (unsigned long)[_locationMap count], (unsigned long)_unmapped];
}

@end

#pragma mark - AXBrailleTranslator

@implementation AXBrailleTranslator {
    AXBrailleTable *_brailleTable;
}

- (instancetype)initWithBrailleTable:(AXBrailleTable *)brailleTable
{
    if ((self = [super init])) {
        _brailleTable = brailleTable;
    }
    return self;
}

- (AXBrailleTranslationResult *)translatePrintText:(NSString *)printText
{
    NSMutableString *cells = [NSMutableString stringWithCapacity:[printText length] * 2];
    NSMutableArray<NSNumber *> *map = [NSMutableArray arrayWithCapacity:[printText length]];
    NSUInteger unmapped = 0, capitals = 0;
    BOOL inNumbers = NO;
    NSUInteger index = 0, count = [printText length];
    while (index < count) {
        unichar character = [printText characterAtIndex:index];
        if (character == ' ' || character == '\n' || character == '\t') {
            [cells appendString:[NSString stringWithFormat:@"%C", revenant_ueb_pattern(RevenantBrailleSpace)]];
            [map addObject:@(index)];
            capitals = 0;
            inNumbers = NO;
            index++;
            continue;
        }
        if (character >= '0' && character <= '9') {
            if (!inNumbers) {
                [cells appendString:[NSString stringWithFormat:@"%C", revenant_ueb_pattern(revenant_ueb_number)]];
                [map addObject:@(index)];
                inNumbers = YES;
            }
            uint16_t digit = character == '0' ? revenant_ueb_letters[9]
                                              : revenant_ueb_letters[character - '1'];
            [cells appendString:[NSString stringWithFormat:@"%C", revenant_ueb_pattern(digit)]];
            [map addObject:@(index)];
            capitals = 0;
            index++;
            continue;
        }
        if (character >= 'A' && character <= 'Z') {
            inNumbers = NO;
            if (capitals == 0) {
                BOOL run = revenant_ueb_run_starts(character, printText, index);
                for (unsigned added = 0; added < (run ? 2 : 1); added++) {
                    [cells appendString:[NSString stringWithFormat:@"%C",
                                         revenant_ueb_pattern(revenant_ueb_capital)]];
                    [map addObject:@(index)];
                }
            }
            capitals++;
            [cells appendString:[NSString stringWithFormat:@"%C",
                                 revenant_ueb_pattern(revenant_ueb_letters[character - 'A'])]];
            [map addObject:@(index)];
            index++;
            continue;
        }
        capitals = 0;
        if (inNumbers && character >= 'a' && character <= 'j') {
            [cells appendString:[NSString stringWithFormat:@"%C", revenant_ueb_pattern(revenant_ueb_grade1)]];
            [map addObject:@(index)];
            inNumbers = NO;
        }
        BOOL covered = NO;
        uint16_t cell = revenant_ueb_cell(character, &covered);
        if (!covered) {
            unmapped++;
        }
        [cells appendString:[NSString stringWithFormat:@"%C", revenant_ueb_pattern(cell)]];
        [map addObject:@(index)];
        index++;
    }
    return [[AXBrailleTranslationResult alloc] revenant_withResultString:cells
                                                               locations:map
                                                                unmapped:unmapped];
}

- (AXBrailleTranslationResult *)backTranslateBraille:(NSString *)braille
{
    NSMutableString *text = [NSMutableString stringWithCapacity:[braille length]];
    NSMutableArray<NSNumber *> *map = [NSMutableArray arrayWithCapacity:[braille length]];
    NSUInteger unmapped = 0, capitals = 0, index = 0, count = [braille length];
    BOOL inNumbers = NO;
    while (index < count) {
        unichar pattern = [braille characterAtIndex:index];
        if (pattern < REVENANT_UEB_BASE || pattern > REVENANT_UEB_BASE + 0xFF) {
            unmapped++;
            index++;
            continue;
        }
        uint16_t cell = (uint16_t)(pattern - REVENANT_UEB_BASE);
        if (cell == RevenantBrailleSpace) {
            [text appendString:@" "];
            [map addObject:@(index)];
            index++;
            continue;
        }
        if (cell == revenant_ueb_capital) {
            capitals++;
            index++;
            continue;
        }
        if (inNumbers && cell != revenant_ueb_letters[0] && cell != revenant_ueb_number) {
        }
        if (cell == revenant_ueb_number) {
            inNumbers = YES;
            index++;
            continue;
        }
        unichar character = 0;
        if (inNumbers) {
            for (unsigned digit = 0; digit < 10; digit++) {
                if (revenant_ueb_letters[digit] == cell) {
                    character = (unichar)(digit == 9 ? '0' : '1' + digit);
                    break;
                }
            }
        }
        if (character == 0) {
            for (unsigned letter = 0; letter < 26; letter++) {
                if (revenant_ueb_letters[letter] == cell) {
                    character = (unichar)('a' + letter);
                    break;
                }
            }
        }
        if (character == 0) {
            for (unsigned entry = 0; entry < revenant_ueb_punctuation_count; entry++) {
                if (revenant_ueb_punctuation[entry].cell == cell) {
                    character = revenant_ueb_punctuation[entry].character;
                    break;
                }
            }
        }
        if (character == 0) {
            unmapped++;
            index++;
            continue;
        }
        if (capitals > 0) {
            character = (unichar)toupper(character);
            capitals = 0;
        }
        [text appendFormat:@"%C", character];
        [map addObject:@(index)];
        index++;
    }
    return [[AXBrailleTranslationResult alloc] revenant_withResultString:text
                                                               locations:map
                                                                unmapped:unmapped];
}

@end
