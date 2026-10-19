//
//  CharonBraille.m
//  Accessibility
//
//  Unified English Braille, grade 1, written from the published standard: the letters, the capital
//  sign, the number sign with a-j standing for 1-0, and the punctuation below. The tables here are
//  this package's own, in dot numbers, and every cell is the Unicode braille pattern those dots
//  are (U+2800 + the dot bitmask, dot 1 the lowest bit) - so the output is the braille itself, not
//  a code for it and not the input handed back.
//
//  liblouis is the implementation of this standard everyone uses, and it is LGPL: read it and do
//  not copy it, and it is not here. What is here is the standard's table, written out.
//
//  A character the table does not cover becomes a space cell and is counted, and the count is
//  readable through -charon_unmappedCount, because the alternative - the input handed back - is the
//  thing this replaces.
//
//  A braille table is a provider's dot patterns and the one the system's AXBrailleTable describes
//  is the one the system installs, which this release does not. That is why the table classes
//  answer empty and a translator is built with a table an application gives it: the translation
//  below is this port's own.
//

#import <Foundation/Foundation.h>
#ifndef CHARON_BRAILLE_ONLY
#import <Accessibility/Accessibility.h>
#endif
#import <ctype.h>
#import <stdint.h>

#import "CharonBraille.h"
#import "../../../c/charon-coding/files/CharonCoding.h"

#pragma mark - The standard's tables

// The letters: each is the cell the grade-1 alphabet gives it, in order a to z.
static const uint16_t charon_ueb_letters[26] = {
    0x01, 0x03, 0x09, 0x19, 0x11, 0x0B, 0x1B, 0x13,   // a b c d e f g h
    0x0A, 0x1A, 0x05, 0x07, 0x0D, 0x1D, 0x15, 0x0F,   // i j k l m n o p
    0x1F, 0x17, 0x0E, 0x1E, 0x25, 0x27, 0x3A, 0x2D,   // q r s t u v w x
    0x3D, 0x35,                                       // y z
};

static const uint16_t charon_ueb_capital = 0x20;  // dot 6, before the letter it capitalises
static const uint16_t charon_ueb_number = 0x3C;   // dots 3, 4, 5, 6: after it a-j are 1-0

// Dots 5 and 6, U+2830: the grade-1 indicator. A letter a-j straight after a digit would be read
// as a digit, so the standard writes this before it - without it, "1a" and "12" would be the same
// six cells.
static const uint16_t charon_ueb_grade1 = 0x30;

// A dot pattern is not yet a character: the braille block starts at U+2800 and a cell's code is
// that base plus its dot bitmask, dot 1 the lowest bit. Every cell goes through here, so a table
// written in dot numbers and the string an application reads are the same thing.
#define CHARON_UEB_BASE 0x2800
static unichar charon_ueb_pattern(uint16_t mask)
{
    return (unichar)(CHARON_UEB_BASE + mask);
}

enum {
    CharonBrailleSpace = 0x00,
    CharonBrailleComma = 0x02,        // ,
    CharonBrailleSemicolon = 0x06,    // ;
    CharonBrailleColon = 0x12,        // :
    CharonBraillePeriod = 0x32,       // .
    CharonBrailleExclamation = 0x16,  // !
    CharonBrailleQuestion = 0x26,     // ? and, in the standard, the opening double quote
    CharonBrailleApostrophe = 0x04,   // '
    CharonBrailleHyphen = 0x24,       // -
    CharonBraillePair = 0x17,         // ( ) and * - one cell for all three
    CharonBrailleSlash = 0x2F,        // /
};

// The punctuation the table covers. The standard writes several of these with one cell, and two
// characters share a cell; the table says so rather than the code inventing a second one.
static const struct { unichar character; uint16_t cell; } charon_ueb_punctuation[] = {
    { ',', CharonBrailleComma },
    { ';', CharonBrailleSemicolon },
    { ':', CharonBrailleColon },
    { '.', CharonBraillePeriod },
    { '!', CharonBrailleExclamation },
    { '?', CharonBrailleQuestion },
    { '\'', CharonBrailleApostrophe },
    { '-', CharonBrailleHyphen },
    { '(', CharonBraillePair },
    { ')', CharonBraillePair },
    { '*', CharonBraillePair },
    { '/', CharonBrailleSlash },
    { '"', CharonBrailleQuestion },
};

static const unsigned charon_ueb_punctuation_count =
    sizeof(charon_ueb_punctuation) / sizeof(charon_ueb_punctuation[0]);

// The cell for a character, and whether the tables had one at all. A space is a real cell (an
// empty pattern) *and* the answer for a character the standard's grade-1 tables do not carry, so
// the two are told apart by the second value rather than by the cell.
static uint16_t charon_ueb_cell(unichar character, BOOL *covered)
{
    *covered = YES;
    if (character >= 'a' && character <= 'z') {
        return charon_ueb_letters[character - 'a'];
    }
    if (character >= 'A' && character <= 'Z') {
        return charon_ueb_letters[character - 'A'];
    }
    for (unsigned index = 0; index < charon_ueb_punctuation_count; index++) {
        if (charon_ueb_punctuation[index].character == character) {
            return charon_ueb_punctuation[index].cell;
        }
    }
    *covered = NO;
    return CharonBrailleSpace;
}

// Whether this capital begins a run of capitals, which is what the standard marks with the sign
// written twice. **Only consecutive capitals**: in "AbC" the A is a capital on its own, because the
// b after it is a lower-case letter, so the sign is written once. Looking further ahead for
// another capital is what made "AbC" come out as a run.
static BOOL charon_ueb_run_starts(unichar character, NSString *text, NSUInteger index)
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
    // The locales a table exists for are the providers' data, one table per provider per locale,
    // and none of it is on this release. An empty set is the answer, and it is what makes
    // +defaultTableForLocale: and the two other sets answer nothing rather than something invented.
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
        charon_intents_decode(self, coder);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
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

- (NSUInteger)charon_unmappedCount
{
    return _unmapped;
}

- (instancetype)charon_withResultString:(NSString *)resultString
                                locations:(NSArray<NSNumber *> *)locations
{
    return [self charon_withResultString:resultString locations:locations unmapped:0];
}

- (instancetype)charon_withResultString:(NSString *)resultString
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
        charon_intents_decode(self, coder);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[AXBrailleTranslationResult alloc] charon_withResultString:_resultString
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
    // Print text to braille, the standard's way round:
    //   * a capital letter is the capital sign and then the letter, and a run of capitals takes the
    //     sign twice before the first of them;
    //   * a digit is the number sign and then a-j for 1-0, and the sign is written again for a
    //     run of digits that anything else breaks;
    //   * everything else is the cell the table gives the character, and a character the table does
    //     not cover is a space, counted so the caller can see the translation was not total.
    NSMutableString *cells = [NSMutableString stringWithCapacity:[printText length] * 2];
    NSMutableArray<NSNumber *> *map = [NSMutableArray arrayWithCapacity:[printText length]];
    NSUInteger unmapped = 0, capitals = 0;
    BOOL inNumbers = NO;
    NSUInteger index = 0, count = [printText length];
    while (index < count) {
        unichar character = [printText characterAtIndex:index];
        if (character == ' ' || character == '\n' || character == '\t') {
            [cells appendString:[NSString stringWithFormat:@"%C", charon_ueb_pattern(CharonBrailleSpace)]];
            [map addObject:@(index)];
            capitals = 0;
            inNumbers = NO;
            index++;
            continue;
        }
        if (character >= '0' && character <= '9') {
            if (!inNumbers) {
                [cells appendString:[NSString stringWithFormat:@"%C", charon_ueb_pattern(charon_ueb_number)]];
                [map addObject:@(index)];
                inNumbers = YES;
            }
            // 1-9 are a-i and 0 is j: the number sign is what tells the reader which it is.
            uint16_t digit = character == '0' ? charon_ueb_letters[9]
                                              : charon_ueb_letters[character - '1'];
            [cells appendString:[NSString stringWithFormat:@"%C", charon_ueb_pattern(digit)]];
            [map addObject:@(index)];
            capitals = 0;
            // inNumbers stays: the number sign holds for the whole run of digits, and it is
            // written again only when something else breaks the run.
            index++;
            continue;
        }
        if (character >= 'A' && character <= 'Z') {
            inNumbers = NO;
            // One capital sign for a capital letter on its own; the sign **twice** once before a
            // run of capitals, which is the standard's word marker - not once per letter of the
            // run, which would read as a run of single capitals.
            if (capitals == 0) {
                BOOL run = charon_ueb_run_starts(character, printText, index);
                for (unsigned added = 0; added < (run ? 2 : 1); added++) {
                    [cells appendString:[NSString stringWithFormat:@"%C",
                                         charon_ueb_pattern(charon_ueb_capital)]];
                    [map addObject:@(index)];
                }
            }
            capitals++;
            [cells appendString:[NSString stringWithFormat:@"%C",
                                 charon_ueb_pattern(charon_ueb_letters[character - 'A'])]];
            [map addObject:@(index)];
            index++;
            continue;
        }
        capitals = 0;
        if (inNumbers && character >= 'a' && character <= 'j') {
            // The letter is one of a-j and the number sign is still in force, so the cell would
            // read as a digit: the standard puts the grade-1 indicator before it.
            [cells appendString:[NSString stringWithFormat:@"%C", charon_ueb_pattern(charon_ueb_grade1)]];
            [map addObject:@(index)];
            inNumbers = NO;
        }
        BOOL covered = NO;
        uint16_t cell = charon_ueb_cell(character, &covered);
        if (!covered) {
            unmapped++;
        }
        [cells appendString:[NSString stringWithFormat:@"%C", charon_ueb_pattern(cell)]];
        [map addObject:@(index)];
        index++;
    }
    return [[AXBrailleTranslationResult alloc] charon_withResultString:cells
                                                               locations:map
                                                                unmapped:unmapped];
}

- (AXBrailleTranslationResult *)backTranslateBraille:(NSString *)braille
{
    // The other direction, over the same tables: a capital sign makes the letter after it
    // capital, and a number sign makes the a-j after it digits. A cell that is not in the tables
    // is skipped and counted, which is the honest reading of a cell this grade-1 alphabet does not
    // hold - the standard's eight-dot and user-defined cells among them.
    NSMutableString *text = [NSMutableString stringWithCapacity:[braille length]];
    NSMutableArray<NSNumber *> *map = [NSMutableArray arrayWithCapacity:[braille length]];
    NSUInteger unmapped = 0, capitals = 0, index = 0, count = [braille length];
    BOOL inNumbers = NO;
    while (index < count) {
        unichar pattern = [braille characterAtIndex:index];
        if (pattern < CHARON_UEB_BASE || pattern > CHARON_UEB_BASE + 0xFF) {
            // Not a cell of the braille block at all: counted, not guessed at.
            unmapped++;
            index++;
            continue;
        }
        uint16_t cell = (uint16_t)(pattern - CHARON_UEB_BASE);
        if (cell == CharonBrailleSpace) {
            [text appendString:@" "];
            [map addObject:@(index)];
            index++;
            continue;
        }
        if (cell == charon_ueb_capital) {
            capitals++;
            index++;
            continue;
        }
        if (inNumbers && cell != charon_ueb_letters[0] && cell != charon_ueb_number) {
            // handled below: a letter after the number sign is a digit only if it is a-j
        }
        if (cell == charon_ueb_number) {
            inNumbers = YES;
            index++;
            continue;
        }
        unichar character = 0;
        if (inNumbers) {
            // The number sign holds until a cell that is not one of a-j: a run of digits comes
            // back as a run of digits, and a letter after a break is a letter again.
            for (unsigned digit = 0; digit < 10; digit++) {
                if (charon_ueb_letters[digit] == cell) {
                    character = (unichar)(digit == 9 ? '0' : '1' + digit);
                    break;
                }
            }
        }
        if (character == 0) {
            for (unsigned letter = 0; letter < 26; letter++) {
                if (charon_ueb_letters[letter] == cell) {
                    character = (unichar)('a' + letter);
                    break;
                }
            }
        }
        if (character == 0) {
            for (unsigned entry = 0; entry < charon_ueb_punctuation_count; entry++) {
                if (charon_ueb_punctuation[entry].cell == cell) {
                    character = charon_ueb_punctuation[entry].character;
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
    return [[AXBrailleTranslationResult alloc] charon_withResultString:text
                                                               locations:map
                                                                unmapped:unmapped];
}

@end
