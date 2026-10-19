#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <ctype.h>
#include <errno.h>
#include <math.h>
#include <stdlib.h>

static NSStringEncoding CharonJSONDetectEncoding(NSData *data, NSUInteger *bomLength)
{
    const unsigned char *b = (const unsigned char *)data.bytes;
    NSUInteger n = data.length;
    *bomLength = 0;
    if (n >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) { *bomLength = 3; return NSUTF8StringEncoding; }
    if (n >= 2 && b[0] == 0xFE && b[1] == 0xFF) { *bomLength = 2; return NSUTF16BigEndianStringEncoding; }
    if (n >= 2 && b[0] == 0xFF && b[1] == 0xFE) { *bomLength = 2; return NSUTF16LittleEndianStringEncoding; }
    if (n >= 4 && b[0] == 0x00 && b[1] == 0x00 && b[2] == 0xFE && b[3] == 0xFF) { *bomLength = 4; return NSUTF32BigEndianStringEncoding; }
    if (n >= 4) {
        BOOL z0 = b[0] == 0, z1 = b[1] == 0, z2 = b[2] == 0, z3 = b[3] == 0;
        if (z0 && z1 && z2 && !z3) return NSUTF32BigEndianStringEncoding;
        if (!z0 && z1 && z2 && z3) return NSUTF32LittleEndianStringEncoding;
        if (z0 && !z1 && z2 && !z3) return NSUTF16BigEndianStringEncoding;
        if (!z0 && z1 && !z2 && z3) return NSUTF16LittleEndianStringEncoding;
    } else if (n >= 2) {
        if (b[0] == 0 && b[1] != 0) return NSUTF16BigEndianStringEncoding;
        if (b[0] != 0 && b[1] == 0) return NSUTF16LittleEndianStringEncoding;
    }
    return NSUTF8StringEncoding;
}

static NSError *CharonJSONError(NSString *reason, NSUInteger line, NSUInteger column, NSUInteger index)
{
    NSString *debug = [NSString stringWithFormat:@"%@ around line %lu, column %lu.", reason, (unsigned long)line, (unsigned long)column];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError
                            userInfo:@{NSDebugDescriptionErrorKey: debug, @"NSJSONSerializationErrorIndex": @(index)}];
}

static NSError *CharonJSONEmptyDataError(void)
{
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError
                            userInfo:@{NSDebugDescriptionErrorKey: @"Unable to parse empty data."}];
}

static const NSUInteger CharonJSONMaximumDepth = 512;

static const NSUInteger CharonJSONJSON5Allowed = 1UL << 3;
static const NSUInteger CharonJSONTopLevelDictionaryAssumed = 1UL << 4;

@interface CharonJSONReader : NSObject
@property (nonatomic) const unichar *buffer;
@property (nonatomic) NSUInteger length;
@property (nonatomic) NSUInteger position;
@property (nonatomic) NSUInteger line;
@property (nonatomic) NSUInteger lineStart;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) NSUInteger startOfValue;
@property (nonatomic) NSUInteger lastDelimiter;
@property (nonatomic) NSUInteger stringStart;
@property (nonatomic) BOOL endsWithSpace;
@property (nonatomic) BOOL inBody;
@property (nonatomic) NSJSONReadingOptions options;
@property (nonatomic) BOOL assumedTopLevel;
@property (nonatomic) BOOL unterminatedComment;
@property (nonatomic, strong) NSError *error;
@end

@implementation CharonJSONReader
@synthesize buffer = _buffer, length = _length, position = _position, line = _line, lineStart = _lineStart,
            depth = _depth, startOfValue = _startOfValue, lastDelimiter = _lastDelimiter, stringStart = _stringStart,
            endsWithSpace = _endsWithSpace,
            inBody = _inBody, options = _options, assumedTopLevel = _assumedTopLevel,
            unterminatedComment = _unterminatedComment, error = _error;

- (BOOL)json5 { return (self.options & CharonJSONJSON5Allowed) != 0; }

- (unichar)peek { return self.position < self.length ? self.buffer[self.position] : 0; }

- (unichar)peekAt:(NSUInteger)offset
{
    return self.position + offset < self.length ? self.buffer[self.position + offset] : 0;
}

- (unichar)peekAfterSpace:(NSUInteger)offset
{
    NSUInteger at = self.position + offset;
    while (at < self.length) {
        unichar c = self.buffer[at];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') { at++; continue; }
        return c;
    }
    return 0;
}

- (unichar)peekAfterSpaceAndComments:(NSUInteger)offset
{
    NSUInteger at = self.position + offset;
    if (!self.json5)
        return [self peekAfterSpace:offset];
    for (;;) {
        while (at < self.length) {
            unichar c = self.buffer[at];
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') { at++; continue; }
            break;
        }
        if (at + 1 >= self.length || self.buffer[at] != '/')
            return at < self.length ? self.buffer[at] : 0;
        if (self.buffer[at + 1] == '/') {
            while (at < self.length && self.buffer[at] != '\n')
                at++;
            if (at >= self.length) {
                if (!self.inBody)
                    [self fail:@"Unexpected end of file" at:self.length];
                return 0;
            }
            continue;
        }
        if (self.buffer[at + 1] == '*') {
            NSUInteger scan = at + 2;
            while (scan + 1 < self.length && !(self.buffer[scan] == '*' && self.buffer[scan + 1] == '/'))
                scan++;
            if (scan + 1 >= self.length) {
                if (!self.inBody)
                    [self fail:@"Unterminated block comment" at:self.length];
                return 0;
            }
            at = scan + 2;
            continue;
        }
        return self.buffer[at];
    }
}

- (void)fail:(NSString *)reason
{
    [self fail:reason at:self.position];
}

- (void)fail:(NSString *)reason at:(NSUInteger)index
{
    if (self.error)
        return;
    self.error = CharonJSONError(reason, self.line, index - self.lineStart, index);
}

- (void)failAtEndOfTextWantingValue:(BOOL)wantsValue
{
    if (self.error)
        return;
    if (self.unterminatedComment) {
        [self fail:@"Unterminated block comment" at:self.length];
    } else if (wantsValue && !self.endsWithSpace) {
        [self fail:@"Unexpected end of file during JSON parse." at:self.lastDelimiter];
    } else {
        [self fail:@"Unexpected end of file" at:self.length];
    }
}

- (void)advance
{
    if (self.buffer[self.position] == '\n') {
        self.line += 1;
        self.lineStart = self.position + 1;
    }
    self.position += 1;
}

- (void)skipWhitespaceAndComments
{
    self.endsWithSpace = NO;
    while (self.position < self.length && !self.error) {
        unichar c = [self peek];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            self.endsWithSpace = YES;
            [self advance];
        } else if (self.json5 && c == '/' && [self peekAt:1] == '/') {
            while (self.position < self.length && [self peek] != '\n')
                [self advance];
        } else if (self.json5 && c == '/' && [self peekAt:1] == '*') {
            [self advance]; [self advance];
            while (self.position + 1 < self.length && !([self peek] == '*' && [self peekAt:1] == '/'))
                [self advance];
            if (self.position + 1 >= self.length) {
                self.unterminatedComment = YES;
                self.position = self.length;
                return;
            }
            [self advance]; [self advance];
        } else {
            return;
        }
    }
}

- (id)parseValue
{
    [self skipWhitespaceAndComments];
    if (self.error)
        return nil;
    if (self.position >= self.length) {
        if (self.depth == 0 && !self.unterminatedComment)
            [self fail:@"JSON text did not have any content" at:self.length];
        else
            [self failAtEndOfTextWantingValue:YES];
        return nil;
    }
    self.startOfValue = self.position;
    unichar c = [self peek];
    if (c == '{') return [self parseObject];
    if (c == '[') return [self parseArray];
    if (c == '"') return [self parseString];
    if (self.json5 && c == '\'') return [self parseQuotedString:'\''];
    if (c == '-' || (c >= '0' && c <= '9') || (self.json5 && (c == '+' || c == '.'))) return [self parseNumber];
    if (c == 't' || c == 'f' || c == 'n') {
        NSString *word = c == 't' ? @"true" : (c == 'f' ? @"false" : @"null");
        if ([self literal:word])
            return c == 'n' ? (id)[NSNull null] : [NSNumber numberWithBool:c == 't'];
        if (self.depth == 0)
            [self fail:@"Unexpected end of file during JSON parse." at:self.startOfValue];
        else
            [self fail:[NSString stringWithFormat:@"Something looked like a '%@' but wasn't", word] at:self.startOfValue];
        return nil;
    }
    if (self.json5 && c == 'N') {
        if ([self matchesWord:@"NaN"]) {
            [self literal:@"NaN"];
            double notANumber = NAN;
            return @(notANumber);
        }
        BOOL only = self.position + 1 == self.length;
        [self fail:(only ? @"Partial NaN around character %lu (EoF)." : @"Invalid NaN around character %lu (EoF).")
                 at:self.startOfValue];
        return nil;
    }
    if (self.json5 && [self literal:@"NaN"]) {
        double notANumber = NAN;
        return @(notANumber);
    }
    if (self.json5 && [self literal:@"Infinity"]) {
        double infinite = INFINITY;
        return @(infinite);
    }
    [self fail:@"Invalid value" at:self.startOfValue];
    return nil;
}

- (BOOL)literal:(NSString *)word
{
    NSUInteger n = word.length;
    if (self.position + n > self.length)
        return NO;
    for (NSUInteger i = 0; i < n; i++)
        if (self.buffer[self.position + i] != [word characterAtIndex:i])
            return NO;
    for (NSUInteger i = 0; i < n; i++)
        [self advance];
    return YES;
}

- (id)finishedContainer:(id)container
{
    return (self.options & NSJSONReadingMutableContainers) ? container : [container copy];
}

- (id)parseObject
{
    BOOL body = self.inBody;
    self.inBody = NO;
    NSUInteger counted = self.depth;
    BOOL empty = !body && [self peekAfterSpaceAndComments:1] == '}';
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if (empty) {
        [self advance];
        [self skipWhitespaceAndComments];
        [self advance];
        return [self finishedContainer:dict];
    }
    if (++self.depth > CharonJSONMaximumDepth) {
        [self fail:@"Too many nested arrays or dictionaries"];
        return nil;
    }
    if (!body) {
        self.lastDelimiter = self.position;
        [self advance];
    }
    BOOL hadMember = NO;
    for (;;) {
        [self skipWhitespaceAndComments];
        if (self.error) { self.depth = counted; return nil; }
        if (self.position >= self.length) {
            if (body) break;
            [self failAtEndOfTextWantingValue:!hadMember];
            self.depth = counted;
            return nil;
        }
        unichar k = [self peek];
        NSUInteger keyStart = self.position;
        NSString *key;
        if (k == '"') {
            key = [self parseString];
        } else if (self.json5 && k == '\'') {
            key = [self parseQuotedString:'\''];
        } else if (self.json5 && (k == '_' || k == '$' || (k >= 'a' && k <= 'z') || (k >= 'A' && k <= 'Z'))) {
            key = [self parseIdentifier];
        } else {
            [self fail:(self.json5 ? @"Disallowed first character in JSON5 object key" : @"No string key for value in object")];
            self.depth = counted;
            return nil;
        }
        if (self.error) { self.depth = counted; return nil; }
        [self skipWhitespaceAndComments];
        if (self.error) { self.depth = counted; return nil; }
        BOOL quotedKey = (k == '"' || k == '\'');
        if (self.position >= self.length || [self peek] != ':') {
            if (self.position >= self.length && !quotedKey)
                [self fail:@"Unterminated string" at:keyStart];
            else if (self.position >= self.length)
                [self failAtEndOfTextWantingValue:NO];
            else
                [self fail:@"No value for key in object"];
            self.depth = counted;
            return nil;
        }
        self.lastDelimiter = self.position;
        [self advance];
        id value = [self parseValue];
        if (self.error) { self.depth = counted; return nil; }
        if ((self.options & NSJSONReadingMutableContainers) || [dict objectForKey:key] == nil)
            dict[key] = value;
        hadMember = YES;
        [self skipWhitespaceAndComments];
        if (self.error) { self.depth = counted; return nil; }
        if (self.position >= self.length) {
            if (body) break;
            [self failAtEndOfTextWantingValue:NO];
            self.depth = counted;
            return nil;
        }
        unichar c = [self peek];
        if (c == ',') {
            self.lastDelimiter = self.position;
            [self advance];
            [self skipWhitespaceAndComments];
            if (!self.error && [self peek] == '}') { [self advance]; break; }
            continue;
        }
        if (c == '}') { [self advance]; break; }
        [self fail:@"Badly formed object"];
        self.depth = counted;
        return nil;
    }
    self.depth = counted;
    return [self finishedContainer:dict];
}

- (id)parseArray
{
    NSUInteger counted = self.depth;
    BOOL empty = [self peekAfterSpaceAndComments:1] == ']';
    NSMutableArray *array = [NSMutableArray new];
    if (empty) {
        [self advance];
        [self skipWhitespaceAndComments];
        [self advance];
        return [self finishedContainer:array];
    }
    if (++self.depth > CharonJSONMaximumDepth) {
        [self fail:@"Too many nested arrays or dictionaries"];
        return nil;
    }
    self.lastDelimiter = self.position;
    [self advance];
    for (;;) {
        id value = [self parseValue];
        if (self.error) { self.depth = counted; return nil; }
        [array addObject:value];
        [self skipWhitespaceAndComments];
        if (self.error) { self.depth = counted; return nil; }
        if (self.position >= self.length) {
            [self failAtEndOfTextWantingValue:NO];
            self.depth = counted;
            return nil;
        }
        unichar c = [self peek];
        if (c == ',') {
            self.lastDelimiter = self.position;
            [self advance];
            [self skipWhitespaceAndComments];
            if (!self.error && [self peek] == ']') { [self advance]; break; }
            continue;
        }
        if (c == ']') { [self advance]; break; }
        [self fail:@"Badly formed array"];
        self.depth = counted;
        return nil;
    }
    self.depth = counted;
    return [self finishedContainer:array];
}

- (NSString *)parseIdentifier
{
    NSUInteger start = self.position;
    [self advance];
    for (;;) {
        unichar c = [self peek];
        if (c == '_' || c == '$' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))
            [self advance];
        else
            break;
    }
    return [NSString stringWithCharacters:self.buffer + start length:self.position - start];
}

- (NSString *)parseString { return [self parseQuotedString:'"']; }

- (NSString *)parseQuotedString:(unichar)quote
{
    NSUInteger opening = self.position;
    self.stringStart = opening;
    [self advance];
    NSMutableString *out = [NSMutableString new];
    for (;;) {
        if (self.position >= self.length) { [self fail:@"Unterminated string" at:opening]; return nil; }
        unichar c = self.buffer[self.position];
        if (c == quote) { [self advance]; return out; }
        if (c < 0x20) { [self fail:@"Unescaped control character" at:self.position]; return nil; }
        if (c != '\\') { [out appendFormat:@"%C", c]; [self advance]; continue; }
        NSUInteger escape = self.position;
        [self advance];
        if (self.position >= self.length) { [self fail:@"Unterminated string" at:opening]; return nil; }
        unichar e = self.buffer[self.position];
        switch (e) {
            case '"': [out appendString:@"\""]; [self advance]; break;
            case '\'': if (!self.json5) { [self fail:@"Invalid escape sequence" at:escape]; return nil; }
                       [out appendString:@"'"]; [self advance]; break;
            case '\\': [out appendString:@"\\"]; [self advance]; break;
            case '/': [out appendString:@"/"]; [self advance]; break;
            case 'b': [out appendFormat:@"%C", (unichar)0x08]; [self advance]; break;
            case 'f': [out appendFormat:@"%C", (unichar)0x0C]; [self advance]; break;
            case 'n': [out appendString:@"\n"]; [self advance]; break;
            case 'r': [out appendString:@"\r"]; [self advance]; break;
            case 't': [out appendString:@"\t"]; [self advance]; break;
            case '0': if (!self.json5) { [self fail:@"Invalid escape sequence" at:escape]; return nil; }
                       [self fail:@"Unsupported escaped null" at:escape]; return nil;
            case '\n':
                if (!self.json5) { [self fail:@"Invalid escape sequence" at:escape]; return nil; }
                [self advance];
                [out appendString:@"\n"];
                break;
            case '\r': {
                if (!self.json5) {
                    if (self.position + 1 >= self.length || self.buffer[self.position + 1] != '\n') {
                        [self fail:@"Invalid escape sequence" at:escape];
                        return nil;
                    }
                    [self advance];
                    break;
                }
                [self advance];
                [out appendString:@"\n"];
                if (self.position < self.length && self.buffer[self.position] == '\n') {
                    [self advance];
                    if (self.position < self.length && self.buffer[self.position] == '"')
                        [out appendString:@"\n"];
                    else if (self.json5 && self.position < self.length && self.buffer[self.position] == '\'')
                        [out appendString:@"\n"];
                }
                break;
            }
            case 'x': {
                if (!self.json5) { [self fail:@"Invalid escape sequence" at:escape]; return nil; }
                [self advance];
                int high = 0;
                for (int i = 0; i < 2; i++) {
                    int digit = [self hexDigit:[self peek]];
                    if (digit < 0) { [self fail:@"Invalid escape sequence" at:escape]; return nil; }
                    high = high * 16 + digit;
                    [self advance];
                }
                if (high == 0 && self.json5) { [self fail:@"Unsupported escaped (hex) null" at:escape]; return nil; }
                [out appendFormat:@"%C", (unichar)high];
                break;
            }
            case 'u': {
                [self advance];
                unichar u1 = [self readHex4];
                if (self.error) return nil;
                if (u1 == 0 && self.json5) { [self fail:@"Unsupported escaped (unicode) null" at:self.stringStart]; return nil; }
                if (u1 >= 0xD800 && u1 <= 0xDBFF) {
                    if (self.position + 1 >= self.length || self.buffer[self.position] != '\\' || self.buffer[self.position + 1] != 'u') {
                        [self fail:@"Unexpected end of file during string parse (expected low-surrogate code point but did not find one)." at:escape];
                        return nil;
                    }
                    [self advance]; [self advance];
                    unichar u2 = [self readHex4];
                    if (self.error) return nil;
                    if (u2 < 0xDC00 || u2 > 0xDFFF) { [self fail:@"Invalid \\u escape" at:escape]; return nil; }
                    [out appendFormat:@"%C%C", u1, u2];
                } else if (u1 >= 0xDC00 && u1 <= 0xDFFF) {
                    [self fail:@"Unable to convert hex escape sequence (no high character) to UTF8-encoded character." at:escape];
                    return nil;
                } else {
                    [out appendFormat:@"%C", u1];
                }
                break;
            }
            default:
                [self fail:@"Invalid escape sequence" at:escape];
                return nil;
        }
    }
}

- (BOOL)matchesWord:(NSString *)word
{
    NSUInteger n = word.length;
    if (self.position + n > self.length)
        return NO;
    for (NSUInteger i = 0; i < n; i++)
        if (self.buffer[self.position + i] != [word characterAtIndex:i])
            return NO;
    return YES;
}

- (int)hexDigit:(unichar)c
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return 10 + c - 'a';
    if (c >= 'A' && c <= 'F') return 10 + c - 'A';
    return -1;
}

- (unichar)readHex4
{
    unichar value = 0;
    for (int i = 0; i < 4; i++) {
        if (self.position + i >= self.length) { [self fail:@"Unterminated string" at:self.stringStart]; return 0; }
        unichar c = self.buffer[self.position + i];
        if (c == '"' || c == '\'') { [self fail:@"Unterminated string" at:self.stringStart]; return 0; }
        int digit = [self hexDigit:c];
        if (digit < 0) { [self fail:@"Invalid hex digit in unicode escape sequence" at:self.position + i]; return 0; }
        value = (unichar)(value * 16 + digit);
    }
    self.position += 4;
    return value;
}

- (id)parseNumber
{
    NSUInteger numberStart = self.position;
    BOOL negative = NO;
    if ([self peek] == '-') { negative = YES; [self advance]; }
    else if (self.json5 && [self peek] == '+') { [self advance]; }
    BOOL digit = [self peek] >= '0' && [self peek] <= '9';
    BOOL dot = self.json5 && [self peek] == '.';
    if (!digit && !dot) {
        if (self.json5 && [self matchesWord:@"Infinity"]) {
            [self literal:@"Infinity"];
            double infinite = negative ? -INFINITY : INFINITY;
            return @(infinite);
        }
        if (negative) { [self fail:@"Number with minus sign but no digits" at:self.position]; return nil; }
        [self fail:@"Malformed number" at:self.position];
        return nil;
    }
    if (self.json5 && [self peek] == '0' && ([self peekAt:1] == 'x' || [self peekAt:1] == 'X')) {
        [self advance]; [self advance];
        NSUInteger hexStart = self.position;
        while (self.position < self.length && isxdigit(self.buffer[self.position]))
            [self advance];
        if (self.position == hexStart) { [self fail:@"Hex number without next digit" at:self.position]; return nil; }
        NSString *hex = [NSString stringWithCharacters:self.buffer + hexStart length:self.position - hexStart];
        unsigned long long v = strtoull(hex.UTF8String, NULL, 16);
        return @(negative ? -(long long)v : (long long)v);
    }
    NSUInteger intDigits = 0;
    BOOL leadingDot = NO;
    if (self.json5 && [self peek] == '.') {
        leadingDot = YES;
    } else if ([self peek] == '0') {
        [self advance];
        if ([self peek] >= '0' && [self peek] <= '9') { [self fail:@"Number with leading zero" at:self.position]; return nil; }
    } else if ([self peek] >= '1' && [self peek] <= '9') {
        while ([self peek] >= '0' && [self peek] <= '9') { intDigits++; [self advance]; }
    } else {
        [self fail:@"Invalid number" at:self.position];
        return nil;
    }
    BOOL isFractional = NO;
    NSUInteger fracDigits = 0;
    if (leadingDot || [self peek] == '.') {
        [self advance];
        NSUInteger before = self.position;
        while ([self peek] >= '0' && [self peek] <= '9') { fracDigits++; [self advance]; }
        isFractional = leadingDot || fracDigits > 0;
        if (self.position == before && !self.json5) {
            [self fail:@"Number with decimal point but no additional digits" at:self.position];
            return nil;
        }
    }
    if ([self peek] == 'e' || [self peek] == 'E') {
        isFractional = YES;
        [self advance];
        BOOL signed_ = NO;
        if ([self peek] == '+' || [self peek] == '-') { signed_ = YES; [self advance]; }
        NSUInteger digits = 0, value = 0;
        while ([self peek] >= '0' && [self peek] <= '9') { digits++; value = value * 10 + ([self peek] - '0'); [self advance]; }
        if (digits == 0) {
            [self fail:(signed_ ? @"Number with '+' or '-' but no additional digits" : @"Number with 'e' but no additional digits")
                     at:self.position];
            return nil;
        }
        if (digits >= 5 || (digits == 4 && signed_)) { [self fail:@"Number wound up as NaN" at:numberStart]; return nil; }
    }
    BOOL trailingDot = fracDigits == 0 && self.position > numberStart && self.buffer[self.position - 1] == '.';
    NSUInteger literalEnd = trailingDot ? self.position - 1 : self.position;
    NSString *literal = [NSString stringWithCharacters:self.buffer + numberStart length:literalEnd - numberStart];
    if (!isFractional) {
        const char *cstr = literal.UTF8String;
        errno = 0;
        char *end = NULL;
        long long ll = strtoll(cstr, &end, 10);
        if (errno == 0 && end && *end == 0)
            return @(ll);
        errno = 0;
        end = NULL;
        unsigned long long ull = strtoull(cstr, &end, 10);
        if (!negative && errno == 0 && end && *end == 0)
            return @(ull);
        return [NSDecimalNumber decimalNumberWithString:literal locale:nil];
    }
    NSUInteger significant = intDigits + fracDigits;
    if (significant > 17)
        return [NSDecimalNumber decimalNumberWithString:literal locale:nil];
    double v = strtod(literal.UTF8String, NULL);
    if (v == INFINITY) { [self fail:@"Number wound up as NaN" at:numberStart]; return nil; }
    return @(v);
}

@end

static id CharonJSONParse(NSData *data, NSJSONReadingOptions opt, NSError **error)
{
    if (data.length == 0) {
        if ((opt & CharonJSONTopLevelDictionaryAssumed) != 0)
            return [NSDictionary dictionary];
        if (error) *error = CharonJSONEmptyDataError();
        return nil;
    }
    NSUInteger bom = 0;
    NSStringEncoding encoding = CharonJSONDetectEncoding(data, &bom);
    NSData *body = bom > 0 ? [data subdataWithRange:NSMakeRange(bom, data.length - bom)] : data;
    NSString *string = [[NSString alloc] initWithData:body encoding:encoding];
    if (!string) {
        if (error) *error = CharonJSONError(@"Unable to convert data to string", 1, 1, 1);
        return nil;
    }
    NSUInteger length = string.length;
    unichar *buffer = length > 0 ? malloc(length * sizeof(unichar)) : NULL;
    if (length > 0)
        [string getCharacters:buffer range:NSMakeRange(0, length)];
    CharonJSONReader *reader = [CharonJSONReader new];
    reader.buffer = buffer;
    reader.length = length;
    reader.line = 1;
    reader.options = opt;
    reader.assumedTopLevel = (opt & CharonJSONTopLevelDictionaryAssumed) != 0;
    id result = nil;
    [reader skipWhitespaceAndComments];
    if (!reader.error) {
        if (reader.assumedTopLevel && (reader.position >= reader.length || reader.buffer[reader.position] != '{')) {
            reader.inBody = YES;
            result = [reader parseObject];
        } else {
            BOOL fragmentsOK = (opt & NSJSONReadingFragmentsAllowed) != 0;
            if (!fragmentsOK && reader.position < reader.length && reader.buffer[reader.position] != '{' && reader.buffer[reader.position] != '[') {
                [reader fail:@"JSON text did not start with array or object and option to allow fragments not set." at:reader.position];
            } else {
                result = [reader parseValue];
            }
        }
    }
    if (!reader.error && result) {
        [reader skipWhitespaceAndComments];
        if (reader.position < reader.length)
            [reader fail:@"Garbage at end" at:reader.position];
    }
    free(buffer);
    if (reader.error) {
        if (error) *error = reader.error;
        return nil;
    }
    return result;
}

static BOOL CharonJSONValidValue(id obj, BOOL topLevel)
{
    if (obj == nil)
        return NO;
    if ([obj isKindOfClass:[NSNull class]])
        return !topLevel;
    if ([obj isKindOfClass:[NSNumber class]]) {
        if (topLevel)
            return NO;
        if (CFGetTypeID((CFTypeRef)obj) == CFBooleanGetTypeID())
            return YES;
        const char *type = ((NSNumber *)obj).objCType;
        if (strcmp(type, @encode(double)) == 0 || strcmp(type, @encode(float)) == 0) {
            double v = ((NSNumber *)obj).doubleValue;
            return !isnan(v) && !isinf(v);
        }
        return YES;
    }
    if ([obj isKindOfClass:[NSString class]])
        return !topLevel;
    if ([obj isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)obj)
            if (!CharonJSONValidValue(item, NO))
                return NO;
        return YES;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = obj;
        for (id key in dict) {
            if (![key isKindOfClass:[NSString class]] || !CharonJSONValidValue(dict[key], NO))
                return NO;
        }
        return YES;
    }
    return NO;
}

static void CharonJSONWriteString(NSString *s, NSMutableString *out, NSJSONWritingOptions opt)
{
    BOOL escapeSlashes = !(opt & NSJSONWritingWithoutEscapingSlashes);
    [out appendString:@"\""];
    NSUInteger len = s.length;
    if (len > 0) {
        unichar *buf = malloc(len * sizeof(unichar));
        [s getCharacters:buf range:NSMakeRange(0, len)];
        for (NSUInteger i = 0; i < len; i++) {
            unichar c = buf[i];
            switch (c) {
                case '"': [out appendString:@"\\\""]; break;
                case '\\': [out appendString:@"\\\\"]; break;
                case '\n': [out appendString:@"\\n"]; break;
                case '\r': [out appendString:@"\\r"]; break;
                case '\t': [out appendString:@"\\t"]; break;
                case 0x08: [out appendString:@"\\b"]; break;
                case 0x0C: [out appendString:@"\\f"]; break;
                case '/': if (escapeSlashes) [out appendString:@"\\/"]; else [out appendFormat:@"%C", c]; break;
                default:
                    if (c < 0x20)
                        [out appendFormat:@"\\u%04x", c];
                    else
                        [out appendFormat:@"%C", c];
            }
        }
        free(buf);
    }
    [out appendString:@"\""];
}

static void CharonJSONWriteNumber(NSNumber *n, NSMutableString *out)
{
    if (CFGetTypeID((CFTypeRef)n) == CFBooleanGetTypeID()) {
        [out appendString:n.boolValue ? @"true" : @"false"];
        return;
    }
    if ([n isKindOfClass:[NSDecimalNumber class]]) {
        [out appendString:[n descriptionWithLocale:nil]];
        return;
    }
    const char *type = n.objCType;
    if (strcmp(type, @encode(double)) == 0 || strcmp(type, @encode(float)) == 0) {
        double v = n.doubleValue;
        char buf[64];
        snprintf(buf, sizeof buf, "%.17g", v);
        [out appendFormat:@"%s", buf];
        return;
    }
    if (strcmp(type, @encode(unsigned long long)) == 0 || strcmp(type, @encode(unsigned long)) == 0) {
        [out appendFormat:@"%llu", n.unsignedLongLongValue];
        return;
    }
    [out appendFormat:@"%lld", n.longLongValue];
}

static void CharonJSONWriteValue(id obj, NSMutableString *out, NSJSONWritingOptions opt, NSUInteger depth)
{
    if (obj == nil || [obj isKindOfClass:[NSNull class]]) { [out appendString:@"null"]; return; }
    if ([obj isKindOfClass:[NSNumber class]]) {
        if ([obj isKindOfClass:[NSDecimalNumber class]]) {
            NSDecimal decimal = [obj decimalValue];
            if (NSDecimalIsNotANumber(&decimal))
                [NSException raise:NSInvalidArgumentException format:@"NaN number in JSON write"];
        } else if (CFGetTypeID((CFTypeRef)obj) != CFBooleanGetTypeID()) {
            const char *type = ((NSNumber *)obj).objCType;
            if (strcmp(type, @encode(double)) == 0 || strcmp(type, @encode(float)) == 0) {
                double v = ((NSNumber *)obj).doubleValue;
                if (isnan(v))
                    [NSException raise:NSInvalidArgumentException format:@"Invalid number value (NaN) in JSON write"];
                if (isinf(v))
                    [NSException raise:NSInvalidArgumentException format:@"Invalid number value (infinite) in JSON write"];
            }
        }
        CharonJSONWriteNumber(obj, out);
        return;
    }
    if ([obj isKindOfClass:[NSString class]]) { CharonJSONWriteString(obj, out, opt); return; }
    BOOL pretty = (opt & NSJSONWritingPrettyPrinted) != 0;
    NSString *indent = pretty ? [@"" stringByPaddingToLength:(depth + 1) * 2 withString:@" " startingAtIndex:0] : @"";
    NSString *closeIndent = pretty ? [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0] : @"";
    if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *array = obj;
        [out appendString:@"["];
        if (pretty) [out appendString:@"\n"];
        NSUInteger i = 0;
        for (id item in array) {
            [out appendString:indent];
            CharonJSONWriteValue(item, out, opt, depth + 1);
            if (++i < array.count) [out appendString:pretty ? @",\n" : @","];
        }
        if (pretty) {
            [out appendString:@"\n"];
            [out appendString:closeIndent];
        }
        [out appendString:@"]"];
        return;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = obj;
        NSArray *keys = dict.allKeys;
        for (id key in keys)
            if (![key isKindOfClass:[NSString class]])
                [NSException raise:NSInvalidArgumentException format:@"Invalid (non-string) key in JSON dictionary"];
        if ((opt & NSJSONWritingSortedKeys) != 0)
            keys = [keys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
        [out appendString:@"{"];
        if (pretty) [out appendString:@"\n"];
        NSUInteger i = 0;
        for (NSString *key in keys) {
            [out appendString:indent];
            CharonJSONWriteString(key, out, opt);
            [out appendString:pretty ? @" : " : @":"];
            CharonJSONWriteValue(dict[key], out, opt, depth + 1);
            if (++i < keys.count) [out appendString:pretty ? @",\n" : @","];
        }
        if (pretty) {
            [out appendString:@"\n"];
            [out appendString:closeIndent];
        }
        [out appendString:@"}"];
        return;
    }
    [NSException raise:NSInvalidArgumentException format:@"Invalid type in JSON write (%@)", NSStringFromClass([obj class])];
}

@implementation NSJSONSerialization

+ (BOOL)isValidJSONObject:(id)obj
{
    return CharonJSONValidValue(obj, YES);
}

+ (nullable NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error
{
    BOOL fragmentsOK = (opt & NSJSONWritingFragmentsAllowed) != 0;
    if (!fragmentsOK && ![obj isKindOfClass:[NSArray class]] && ![obj isKindOfClass:[NSDictionary class]])
        [NSException raise:NSInvalidArgumentException format:@"*** +[NSJSONSerialization dataWithJSONObject:options:error:]: Invalid top-level type in JSON write"];
    NSMutableString *out = [NSMutableString new];
    CharonJSONWriteValue(obj, out, opt, 0);
    return [out dataUsingEncoding:NSUTF8StringEncoding];
}

+ (nullable id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    if ((opt & CharonJSONTopLevelDictionaryAssumed) != 0 && (opt & NSJSONReadingFragmentsAllowed) != 0)
        [NSException raise:NSInvalidArgumentException
                    format:@"NSJSONReadingAssumeTopLevelDictionary and NSJSONReadingAllowFragments cannot be set at the same time"];
    return CharonJSONParse(data, opt, error);
}

+ (NSInteger)writeJSONObject:(id)obj toStream:(NSOutputStream *)stream options:(NSJSONWritingOptions)opt error:(NSError **)error
{
    NSData *data = [self dataWithJSONObject:obj options:opt error:error];
    if (!data)
        return 0;
    NSInteger total = 0;
    const uint8_t *bytes = data.bytes;
    NSInteger remaining = (NSInteger)data.length;
    while (remaining > 0) {
        NSInteger written = [stream write:bytes + total maxLength:(NSUInteger)remaining];
        if (written <= 0) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
            return -1;
        }
        total += written;
        remaining -= written;
    }
    return total;
}

+ (nullable id)JSONObjectWithStream:(NSInputStream *)stream options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    NSMutableData *data = [NSMutableData new];
    uint8_t buffer[4096];
    NSInteger read;
    while ((read = [stream read:buffer maxLength:sizeof(buffer)]) > 0)
        [data appendBytes:buffer length:(NSUInteger)read];
    return CharonJSONParse(data, opt, error);
}

@end
