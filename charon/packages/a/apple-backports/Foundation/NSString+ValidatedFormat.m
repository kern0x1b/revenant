#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, CharonFormatKind) {
    CharonFormatNone,
    CharonFormatObject,
    CharonFormatInteger,
    CharonFormatWideCharacter,
    CharonFormatLongInteger,
    CharonFormatFloating,
    CharonFormatLongFloating,
    CharonFormatCString,
    CharonFormatWideString,
    CharonFormatPascalString,
    CharonFormatPointer,
    CharonFormatCount,
    CharonFormatIncomplete,
};

typedef NS_ENUM(NSUInteger, CharonFormatLength) {
    CharonFormatLengthPlain,
    CharonFormatLengthLong,
    CharonFormatLengthLongLong,
};

typedef NS_ENUM(NSUInteger, CharonFormatSize) {
    CharonFormatSizeDefault,
    CharonFormatSizeByte,
    CharonFormatSizeShort,
    CharonFormatSizeLong,
    CharonFormatSizeLongLong,
    CharonFormatSizeLongDouble,
};

typedef struct {
    CharonFormatKind kind;
    CharonFormatLength length;
    NSInteger main, width, precision;
    BOOL external;
    NSUInteger start, end;
    unichar plain[128];
    NSUInteger plainLength;
    CharonFormatSize size;
} CharonFormatSpec;

static BOOL charon_format_satisfies(CharonFormatKind wanted, CharonFormatKind allowed)
{
    if (wanted == allowed)
        return YES;
    switch (wanted) {
        case CharonFormatWideCharacter:
            return allowed == CharonFormatInteger;
        case CharonFormatPointer:
            return allowed == CharonFormatObject || allowed == CharonFormatInteger || allowed == CharonFormatCString
                || allowed == CharonFormatWideString || allowed == CharonFormatPascalString;
        case CharonFormatCString:
            return allowed == CharonFormatPointer || allowed == CharonFormatPascalString;
        case CharonFormatPascalString:
            return allowed == CharonFormatPointer || allowed == CharonFormatCString;
        case CharonFormatWideString:
            return allowed == CharonFormatPointer;
        default:
            return NO;
    }
}

static BOOL charon_format_word(unichar character)
{
    return (character >= '0' && character <= '9') || (character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z')
        || character == '_';
}

static void charon_format_keep(CharonFormatSpec *spec, unichar character)
{
    if (spec->plainLength < sizeof spec->plain / sizeof spec->plain[0])
        spec->plain[spec->plainLength++] = character;
}

static NSUInteger charon_format_incomplete(CharonFormatSpec *spec, NSUInteger index)
{
    spec->kind = CharonFormatIncomplete;
    spec->end = index;
    return index;
}

static NSUInteger charon_format_parse(NSString *format, NSUInteger index, CharonFormatSpec *spec)
{
    NSUInteger length = format.length;
    BOOL seenSharp = NO, seenBracket = NO, keyed = NO, longDouble = NO;
    *spec = (CharonFormatSpec){CharonFormatNone, CharonFormatLengthPlain, -1, -1, -1, NO, index - 1, index, {'%'}, 1};
    for (;;) {
        if (index >= length)
            return charon_format_incomplete(spec, index);
        unichar character = [format characterAtIndex:index++];
        spec->end = index;
        if (keyed) {
            charon_format_keep(spec, character);
            if (!charon_format_word(character)) {
                if (character == '@') {
                    spec->kind = CharonFormatObject;
                    spec->external = YES;
                    return index;
                }
                if (character != ']')
                    keyed = NO;
            }
            continue;
        }
    again:
        switch (character) {
            case '#':
                seenSharp = YES;
                charon_format_keep(spec, character);
                break;
            case '[':
                charon_format_keep(spec, character);
                if (!seenBracket) {
                    seenBracket = YES;
                    keyed = YES;
                }
                break;
            case ' ': case '-': case '+': case '0':
                charon_format_keep(spec, character);
                break;
            case 'h':
                charon_format_keep(spec, character);
                if (index < length && [format characterAtIndex:index] == 'h') {
                    charon_format_keep(spec, 'h');
                    index++;
                    spec->end = index;
                    spec->size = CharonFormatSizeByte;
                } else {
                    spec->size = CharonFormatSizeShort;
                }
                break;
            case 'l':
                charon_format_keep(spec, character);
                if (index < length && [format characterAtIndex:index] == 'l') {
                    charon_format_keep(spec, 'l');
                    index++;
                    spec->end = index;
                    spec->length = CharonFormatLengthLongLong;
                    spec->size = CharonFormatSizeLongLong;
                } else {
                    spec->length = CharonFormatLengthLong;
                    spec->size = CharonFormatSizeLong;
                }
                break;
            case 'q': case 'j':
                charon_format_keep(spec, character);
                spec->length = CharonFormatLengthLongLong;
                spec->size = CharonFormatSizeLongLong;
                break;
            case 'z': case 't':
                charon_format_keep(spec, character);
                spec->length = CharonFormatLengthLong;
                spec->size = CharonFormatSizeLong;
                break;
            case 'L':
                charon_format_keep(spec, character);
                longDouble = YES;
                spec->size = CharonFormatSizeLongDouble;
                break;
            case 'c':
                charon_format_keep(spec, character);
                spec->kind = CharonFormatInteger;
                spec->length = CharonFormatLengthPlain;
                spec->size = CharonFormatSizeByte;
                return index;
            case 'D': case 'd': case 'i': case 'U': case 'u': case 'O': case 'o': case 'x': case 'X':
                charon_format_keep(spec, character);
                spec->kind = longDouble ? CharonFormatLongInteger : CharonFormatInteger;
                if (longDouble)
                    spec->length = CharonFormatLengthLongLong;
                return index;
            case 'f': case 'F': case 'g': case 'G': case 'e': case 'E': case 'a': case 'A':
                charon_format_keep(spec, character);
                spec->kind = longDouble ? CharonFormatLongFloating : CharonFormatFloating;
                return index;
            case 'n':
                charon_format_keep(spec, character);
                spec->kind = CharonFormatCount;
                return index;
            case 'p':
                charon_format_keep(spec, character);
                spec->kind = CharonFormatPointer;
                return index;
            case 's':
                charon_format_keep(spec, character);
                spec->kind = CharonFormatCString;
                return index;
            case 'S':
                charon_format_keep(spec, character);
                spec->kind = CharonFormatWideString;
                return index;
            case 'C':
                charon_format_keep(spec, character);
                spec->kind = CharonFormatWideCharacter;
                return index;
            case 'P':
                charon_format_keep(spec, character);
                spec->kind = CharonFormatPascalString;
                return index;
            case '@':
                charon_format_keep(spec, character);
                if (seenSharp) {
                    seenSharp = NO;
                    keyed = YES;
                    break;
                }
                spec->kind = CharonFormatObject;
                return index;
            case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9': {
                NSInteger number = 0;
                unichar digits[24];
                NSUInteger count = 0;
                do {
                    number = number * 10 + (character - '0');
                    if (count < sizeof digits / sizeof digits[0])
                        digits[count++] = character;
                    if (index >= length)
                        return charon_format_incomplete(spec, index);
                    character = [format characterAtIndex:index++];
                    spec->end = index;
                } while (character >= '0' && character <= '9');
                if (character == '$') {
                    if (spec->precision == -2)
                        spec->precision = number - 1;
                    else if (spec->width == -2)
                        spec->width = number - 1;
                    else
                        spec->main = number - 1;
                    break;
                }
                for (NSUInteger digit = 0; digit < count; digit++)
                    charon_format_keep(spec, digits[digit]);
                goto again;
            }
            case '*':
                charon_format_keep(spec, character);
                spec->width = -2;
                break;
            case '.':
                charon_format_keep(spec, character);
                if (index >= length)
                    return charon_format_incomplete(spec, index);
                character = [format characterAtIndex:index++];
                spec->end = index;
                if (character == '*') {
                    charon_format_keep(spec, character);
                    spec->precision = -2;
                    break;
                }
                goto again;
            default:
                return index;
        }
    }
}

typedef void (^CharonFormatVisitor)(CharonFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot);

static void charon_format_walk(NSString *format, BOOL validating, void (^text)(NSRange range), CharonFormatVisitor visit)
{
    NSUInteger length = format.length, next = 0, index = 0, chunk = 0;
    while (index < length) {
        if ([format characterAtIndex:index] != '%') {
            index++;
            continue;
        }
        if (text && index > chunk)
            text(NSMakeRange(chunk, index - chunk));
        CharonFormatSpec spec;
        index = charon_format_parse(format, index + 1, &spec);
        chunk = index;
        if (spec.kind == CharonFormatNone || (spec.external && !validating)) {
            visit(&spec, NSNotFound, NSNotFound, NSNotFound);
            continue;
        }
        if (spec.kind == CharonFormatIncomplete) {
            visit(&spec, validating ? (spec.main >= 0 ? (NSUInteger)spec.main : next++) : NSNotFound, NSNotFound, NSNotFound);
            continue;
        }
        NSUInteger widthSlot = NSNotFound, precisionSlot = NSNotFound;
        if (spec.width == -2)
            widthSlot = next++;
        else if (spec.width >= 0)
            widthSlot = (NSUInteger)spec.width;
        if (spec.precision == -2)
            precisionSlot = next++;
        else if (spec.precision >= 0)
            precisionSlot = (NSUInteger)spec.precision;
        visit(&spec, spec.main >= 0 ? (NSUInteger)spec.main : next++, widthSlot, precisionSlot);
    }
    if (text && length > chunk)
        text(NSMakeRange(chunk, length - chunk));
}

static void charon_format_take(NSMutableArray *slots, NSUInteger slot, CharonFormatKind kind, CharonFormatLength length)
{
    if (slot == NSNotFound)
        return;
    while (slots.count <= slot)
        [slots addObject:[NSMutableArray array]];
    [slots[slot] addObject:@[@(kind), @(length)]];
}

static NSArray *charon_format_slots(NSString *format, BOOL validating)
{
    NSMutableArray *slots = [NSMutableArray array];
    charon_format_walk(format, validating, nil, ^(CharonFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot) {
        charon_format_take(slots, widthSlot, CharonFormatInteger, CharonFormatLengthPlain);
        charon_format_take(slots, precisionSlot, CharonFormatInteger, CharonFormatLengthPlain);
        charon_format_take(slots, slot, spec->kind, spec->length);
    });
    return slots;
}

static BOOL charon_format_allowed(NSString *format, NSString *valid)
{
    NSArray *wanted = charon_format_slots(format, YES), *allowed = charon_format_slots(valid, YES);
    if (wanted.count > allowed.count)
        return NO;
    for (NSUInteger index = 0; index < wanted.count; index++) {
        NSArray *offered = allowed[index];
        for (NSArray *kind in wanted[index])
            if (!offered.count || !charon_format_satisfies([kind[0] unsignedIntegerValue], [offered[0][0] unsignedIntegerValue]))
                return NO;
    }
    return YES;
}

typedef struct {
    long long integer;
    long double floating;
} CharonFormatValue;

static CharonFormatValue charon_format_read(NSArray *described, va_list *arguments)
{
    CharonFormatValue value = {0, 0};
    CharonFormatKind kind = described.count ? [described[0][0] unsignedIntegerValue] : CharonFormatPointer;
    CharonFormatLength length = described.count ? [described[0][1] unsignedIntegerValue] : CharonFormatLengthPlain;
    switch (kind) {
        case CharonFormatInteger:
        case CharonFormatWideCharacter:
        case CharonFormatLongInteger:
            if (length == CharonFormatLengthLongLong)
                value.integer = va_arg(*arguments, long long);
            else if (length == CharonFormatLengthLong)
                value.integer = va_arg(*arguments, long);
            else
                value.integer = va_arg(*arguments, int);
            break;
        case CharonFormatFloating:
            value.floating = va_arg(*arguments, double);
            break;
        case CharonFormatLongFloating:
            value.floating = va_arg(*arguments, long double);
            break;
        default:
            value.integer = (long long)(intptr_t)va_arg(*arguments, void *);
            break;
    }
    return value;
}

#define CHARON_FORMAT_ONE(value) \
    (stars == 0 ? [[NSString alloc] initWithFormat:plain locale:locale, value] \
     : stars == 1 ? [[NSString alloc] initWithFormat:plain locale:locale, first, value] \
     : [[NSString alloc] initWithFormat:plain locale:locale, first, second, value])

#define CHARON_FORMAT_C(value) \
    (stars == 0 ? snprintf(buffer, size, raw, value) \
     : stars == 1 ? snprintf(buffer, size, raw, first, value) \
     : snprintf(buffer, size, raw, first, second, value))

static BOOL charon_format_wide(CharonFormatSpec *spec)
{
    return spec->size == CharonFormatSizeLongLong || (spec->size == CharonFormatSizeLong && sizeof(long) == sizeof(long long));
}

static long long charon_format_sized(CharonFormatSize size, long long value)
{
    switch (size) {
        case CharonFormatSizeByte:
            return (int8_t)value;
        case CharonFormatSizeShort:
            return (int16_t)value;
        case CharonFormatSizeLong:
            return (long)value;
        case CharonFormatSizeLongLong:
            return value;
        default:
            return (int32_t)value;
    }
}

static int charon_format_print(CharonFormatSpec *spec, const char *raw, char *buffer, size_t size, int first, int second, NSUInteger stars,
                               CharonFormatValue value)
{
    switch (spec->kind) {
        case CharonFormatFloating:
            return CHARON_FORMAT_C((double)value.floating);
        case CharonFormatLongFloating:
            return CHARON_FORMAT_C((long double)value.floating);
        case CharonFormatPointer:
            return CHARON_FORMAT_C((void *)(intptr_t)value.integer);
        case CharonFormatLongInteger:
            return CHARON_FORMAT_C((long long)(int32_t)value.integer);
        default:
            if (charon_format_wide(spec))
                return CHARON_FORMAT_C(value.integer);
            return CHARON_FORMAT_C((long)(int32_t)value.integer);
    }
}

static NSData *charon_format_number(CharonFormatSpec *spec, int first, int second, NSUInteger stars, CharonFormatValue value)
{
    char raw[sizeof spec->plain / sizeof spec->plain[0] + 1], buffer[512];
    for (NSUInteger index = 0; index < spec->plainLength; index++)
        raw[index] = spec->plain[index] < 0x80 ? (char)spec->plain[index] : '?';
    raw[spec->plainLength] = 0;
    int written = charon_format_print(spec, raw, buffer, sizeof buffer, first, second, stars, value);
    if (written < 0)
        return [NSData data];
    if ((size_t)written < sizeof buffer)
        return [NSData dataWithBytes:buffer length:strlen(buffer)];
    NSMutableData *large = [NSMutableData dataWithLength:(NSUInteger)written + 1];
    if (charon_format_print(spec, raw, large.mutableBytes, large.length, first, second, stars, value) < 0)
        return [NSData data];
    return [NSData dataWithBytes:large.bytes length:strlen(large.bytes)];
}

static id charon_format_one(CharonFormatSpec *spec, id locale, int first, int second, NSUInteger stars, CharonFormatValue value)
{
    NSString *plain = [NSString stringWithCharacters:spec->plain length:spec->plainLength];
    BOOL number = spec->kind == CharonFormatInteger || spec->kind == CharonFormatLongInteger || spec->kind == CharonFormatFloating
               || spec->kind == CharonFormatLongFloating || spec->kind == CharonFormatPointer;
    BOOL character = spec->kind == CharonFormatInteger && spec->plain[spec->plainLength - 1] == 'c';
    if (number && (!locale || character))
        return charon_format_number(spec, first, second, stars, value);
    switch (spec->kind) {
        case CharonFormatObject:
            return CHARON_FORMAT_ONE((__bridge id)(void *)(intptr_t)value.integer);
        case CharonFormatInteger:
            if (charon_format_wide(spec))
                return CHARON_FORMAT_ONE(value.integer);
            return CHARON_FORMAT_ONE((long)(int32_t)value.integer);
        case CharonFormatWideCharacter:
            return CHARON_FORMAT_ONE((int)value.integer);
        case CharonFormatLongInteger:
            return CHARON_FORMAT_ONE((long long)(int32_t)value.integer);
        case CharonFormatFloating:
            return CHARON_FORMAT_ONE((double)value.floating);
        case CharonFormatLongFloating:
            return CHARON_FORMAT_ONE((long double)value.floating);
        case CharonFormatCount:
            return @"";
        default:
            return CHARON_FORMAT_ONE((void *)(intptr_t)value.integer);
    }
}

static NSString *charon_format_render(NSString *format, NSString *valid, id locale, va_list arguments)
{
    NSArray *wanted = charon_format_slots(format, NO), *described = charon_format_slots(valid, NO);
    NSUInteger count = wanted.count;
    CharonFormatValue *values = (CharonFormatValue *)calloc(count ? count : 1, sizeof(CharonFormatValue));
    va_list walk;
    va_copy(walk, arguments);
    for (NSUInteger slot = 0; slot < count; slot++)
        values[slot] = charon_format_read(slot < described.count ? described[slot] : @[], &walk);
    va_end(walk);
    NSInteger *sizes = (NSInteger *)calloc(count ? count : 1, sizeof(NSInteger));
    charon_format_walk(format, NO, nil, ^(CharonFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot) {
        if (slot != NSNotFound && slot < count) {
            if (spec->kind == CharonFormatInteger || spec->kind == CharonFormatLongInteger)
                sizes[slot] = 1 + spec->size;
            else if (spec->kind == CharonFormatWideCharacter)
                sizes[slot] = 1 + CharonFormatSizeShort;
            else
                sizes[slot] = 0;
        }
        if (widthSlot != NSNotFound && widthSlot < count)
            sizes[widthSlot] = 1 + CharonFormatSizeDefault;
        if (precisionSlot != NSNotFound && precisionSlot < count)
            sizes[precisionSlot] = 1 + CharonFormatSizeDefault;
    });
    for (NSUInteger slot = 0; slot < count; slot++)
        if (sizes[slot])
            values[slot].integer = charon_format_sized((CharonFormatSize)(sizes[slot] - 1), values[slot].integer);
    free(sizes);
    NSMutableString *made = [NSMutableString string];
    NSMutableIndexSet *bytes = [NSMutableIndexSet indexSet];
    charon_format_walk(format, NO, ^(NSRange range) {
        [made appendString:[format substringWithRange:range]];
    }, ^(CharonFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot) {
        if (spec->external) {
            [made appendString:[format substringWithRange:NSMakeRange(spec->start, spec->end - spec->start)]];
            return;
        }
        if (spec->kind == CharonFormatNone) {
            [made appendString:[format substringWithRange:NSMakeRange(spec->start + 1, spec->end - spec->start - 1)]];
            return;
        }
        if (slot == NSNotFound)
            return;
        NSUInteger stars = 0;
        int first = 0, second = 0;
        if (widthSlot != NSNotFound) {
            first = (int)values[widthSlot].integer;
            stars++;
        }
        if (precisionSlot != NSNotFound) {
            if (stars)
                second = (int)values[precisionSlot].integer;
            else
                first = (int)values[precisionSlot].integer;
            stars++;
        }
        id piece = charon_format_one(spec, locale, first, second, stars, values[slot]);
        if ([piece isKindOfClass:[NSData class]]) {
            const uint8_t *raw = [piece bytes];
            for (NSUInteger index = 0; index < [piece length]; index++)
                if (raw[index] >= 0x80)
                    [bytes addIndex:made.length + index];
            piece = [[NSString alloc] initWithData:piece encoding:NSISOLatin1StringEncoding];
        }
        [made appendString:piece ?: @""];
    });
    free(values);
    BOOL wide = NO;
    for (NSUInteger index = 0; index < made.length && !wide; index++)
        wide = [made characterAtIndex:index] >= 0x80 && ![bytes containsIndex:index];
    if (wide) {
        NSStringEncoding system = CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
        [bytes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
            uint8_t byte = (uint8_t)[made characterAtIndex:index];
            NSString *decoded = [[NSString alloc] initWithBytes:&byte length:1 encoding:system];
            if (decoded.length == 1)
                [made replaceCharactersInRange:NSMakeRange(index, 1) withString:decoded];
        }];
    }
    return made;
}

static NSString *charon_validated_string(id receiver, SEL command, NSString *format, NSString *valid, id locale,
                                         va_list arguments, NSError **error)
{
    if (!format || !valid)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: nil argument", [receiver class], NSStringFromSelector(command)];
    if (!charon_format_allowed(format, valid)) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFormattingError
                                     userInfo:@{NSDebugDescriptionErrorKey: [NSString stringWithFormat:@"Format '%@' does not match expected '%@'", format, valid]}];
        return nil;
    }
    return [receiver initWithString:charon_format_render(format, valid, locale, arguments)];
}

@implementation NSString (CharonValidatedFormat)

- (instancetype)initWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                  error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    self = charon_validated_string(self, _cmd, format, validFormatSpecifiers, nil, arguments, error);
    va_end(arguments);
    return self;
}

- (instancetype)initWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                 locale:(id)locale error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    self = charon_validated_string(self, _cmd, format, validFormatSpecifiers, locale, arguments, error);
    va_end(arguments);
    return self;
}

- (instancetype)initWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                 locale:(id)locale arguments:(va_list)arguments error:(NSError **)error
{
    return charon_validated_string(self, _cmd, format, validFormatSpecifiers, locale, arguments, error);
}

+ (instancetype)stringWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                    error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    NSString *made = charon_validated_string([self alloc], _cmd, format, validFormatSpecifiers, nil, arguments, error);
    va_end(arguments);
    return made;
}

+ (instancetype)localizedStringWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                             error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    NSString *made = charon_validated_string([self alloc], _cmd, format, validFormatSpecifiers, [NSLocale currentLocale], arguments, error);
    va_end(arguments);
    return made;
}

@end
