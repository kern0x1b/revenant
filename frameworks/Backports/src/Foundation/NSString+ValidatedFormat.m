#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, RevenantFormatKind) {
    RevenantFormatNone,
    RevenantFormatObject,
    RevenantFormatInteger,
    RevenantFormatWideCharacter,
    RevenantFormatLongInteger,
    RevenantFormatFloating,
    RevenantFormatLongFloating,
    RevenantFormatCString,
    RevenantFormatWideString,
    RevenantFormatPascalString,
    RevenantFormatPointer,
    RevenantFormatCount,
    RevenantFormatIncomplete,
};

typedef NS_ENUM(NSUInteger, RevenantFormatLength) {
    RevenantFormatLengthPlain,
    RevenantFormatLengthLong,
    RevenantFormatLengthLongLong,
};

typedef NS_ENUM(NSUInteger, RevenantFormatSize) {
    RevenantFormatSizeDefault,
    RevenantFormatSizeByte,
    RevenantFormatSizeShort,
    RevenantFormatSizeLong,
    RevenantFormatSizeLongLong,
    RevenantFormatSizeLongDouble,
};

typedef struct {
    RevenantFormatKind kind;
    RevenantFormatLength length;
    NSInteger main, width, precision;
    BOOL external;
    NSUInteger start, end;
    unichar plain[128];
    NSUInteger plainLength;
    RevenantFormatSize size;
} RevenantFormatSpec;

static BOOL revenant_format_satisfies(RevenantFormatKind wanted, RevenantFormatKind allowed)
{
    if (wanted == allowed)
        return YES;
    switch (wanted) {
        case RevenantFormatWideCharacter:
            return allowed == RevenantFormatInteger;
        case RevenantFormatPointer:
            return allowed == RevenantFormatObject || allowed == RevenantFormatInteger || allowed == RevenantFormatCString
                || allowed == RevenantFormatWideString || allowed == RevenantFormatPascalString;
        case RevenantFormatCString:
            return allowed == RevenantFormatPointer || allowed == RevenantFormatPascalString;
        case RevenantFormatPascalString:
            return allowed == RevenantFormatPointer || allowed == RevenantFormatCString;
        case RevenantFormatWideString:
            return allowed == RevenantFormatPointer;
        default:
            return NO;
    }
}

static BOOL revenant_format_word(unichar character)
{
    return (character >= '0' && character <= '9') || (character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z')
        || character == '_';
}

static void revenant_format_keep(RevenantFormatSpec *spec, unichar character)
{
    if (spec->plainLength < sizeof spec->plain / sizeof spec->plain[0])
        spec->plain[spec->plainLength++] = character;
}

static NSUInteger revenant_format_incomplete(RevenantFormatSpec *spec, NSUInteger index)
{
    spec->kind = RevenantFormatIncomplete;
    spec->end = index;
    return index;
}

static NSUInteger revenant_format_parse(NSString *format, NSUInteger index, RevenantFormatSpec *spec)
{
    NSUInteger length = format.length;
    BOOL seenSharp = NO, seenBracket = NO, keyed = NO, longDouble = NO;
    *spec = (RevenantFormatSpec){RevenantFormatNone, RevenantFormatLengthPlain, -1, -1, -1, NO, index - 1, index, {'%'}, 1};
    for (;;) {
        if (index >= length)
            return revenant_format_incomplete(spec, index);
        unichar character = [format characterAtIndex:index++];
        spec->end = index;
        if (keyed) {
            revenant_format_keep(spec, character);
            if (!revenant_format_word(character)) {
                if (character == '@') {
                    spec->kind = RevenantFormatObject;
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
                revenant_format_keep(spec, character);
                break;
            case '[':
                revenant_format_keep(spec, character);
                if (!seenBracket) {
                    seenBracket = YES;
                    keyed = YES;
                }
                break;
            case ' ': case '-': case '+': case '0':
                revenant_format_keep(spec, character);
                break;
            case 'h':
                revenant_format_keep(spec, character);
                if (index < length && [format characterAtIndex:index] == 'h') {
                    revenant_format_keep(spec, 'h');
                    index++;
                    spec->end = index;
                    spec->size = RevenantFormatSizeByte;
                } else {
                    spec->size = RevenantFormatSizeShort;
                }
                break;
            case 'l':
                revenant_format_keep(spec, character);
                if (index < length && [format characterAtIndex:index] == 'l') {
                    revenant_format_keep(spec, 'l');
                    index++;
                    spec->end = index;
                    spec->length = RevenantFormatLengthLongLong;
                    spec->size = RevenantFormatSizeLongLong;
                } else {
                    spec->length = RevenantFormatLengthLong;
                    spec->size = RevenantFormatSizeLong;
                }
                break;
            case 'q': case 'j':
                revenant_format_keep(spec, character);
                spec->length = RevenantFormatLengthLongLong;
                spec->size = RevenantFormatSizeLongLong;
                break;
            case 'z': case 't':
                revenant_format_keep(spec, character);
                spec->length = RevenantFormatLengthLong;
                spec->size = RevenantFormatSizeLong;
                break;
            case 'L':
                revenant_format_keep(spec, character);
                longDouble = YES;
                spec->size = RevenantFormatSizeLongDouble;
                break;
            case 'c':
                revenant_format_keep(spec, character);
                spec->kind = RevenantFormatInteger;
                spec->length = RevenantFormatLengthPlain;
                spec->size = RevenantFormatSizeByte;
                return index;
            case 'D': case 'd': case 'i': case 'U': case 'u': case 'O': case 'o': case 'x': case 'X':
                revenant_format_keep(spec, character);
                spec->kind = longDouble ? RevenantFormatLongInteger : RevenantFormatInteger;
                if (longDouble)
                    spec->length = RevenantFormatLengthLongLong;
                return index;
            case 'f': case 'F': case 'g': case 'G': case 'e': case 'E': case 'a': case 'A':
                revenant_format_keep(spec, character);
                spec->kind = longDouble ? RevenantFormatLongFloating : RevenantFormatFloating;
                return index;
            case 'n':
                revenant_format_keep(spec, character);
                spec->kind = RevenantFormatCount;
                return index;
            case 'p':
                revenant_format_keep(spec, character);
                spec->kind = RevenantFormatPointer;
                return index;
            case 's':
                revenant_format_keep(spec, character);
                spec->kind = RevenantFormatCString;
                return index;
            case 'S':
                revenant_format_keep(spec, character);
                spec->kind = RevenantFormatWideString;
                return index;
            case 'C':
                revenant_format_keep(spec, character);
                spec->kind = RevenantFormatWideCharacter;
                return index;
            case 'P':
                revenant_format_keep(spec, character);
                spec->kind = RevenantFormatPascalString;
                return index;
            case '@':
                revenant_format_keep(spec, character);
                if (seenSharp) {
                    seenSharp = NO;
                    keyed = YES;
                    break;
                }
                spec->kind = RevenantFormatObject;
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
                        return revenant_format_incomplete(spec, index);
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
                    revenant_format_keep(spec, digits[digit]);
                goto again;
            }
            case '*':
                revenant_format_keep(spec, character);
                spec->width = -2;
                break;
            case '.':
                revenant_format_keep(spec, character);
                if (index >= length)
                    return revenant_format_incomplete(spec, index);
                character = [format characterAtIndex:index++];
                spec->end = index;
                if (character == '*') {
                    revenant_format_keep(spec, character);
                    spec->precision = -2;
                    break;
                }
                goto again;
            default:
                return index;
        }
    }
}

typedef void (^RevenantFormatVisitor)(RevenantFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot);

static void revenant_format_walk(NSString *format, BOOL validating, void (^text)(NSRange range), RevenantFormatVisitor visit)
{
    NSUInteger length = format.length, next = 0, index = 0, chunk = 0;
    while (index < length) {
        if ([format characterAtIndex:index] != '%') {
            index++;
            continue;
        }
        if (text && index > chunk)
            text(NSMakeRange(chunk, index - chunk));
        RevenantFormatSpec spec;
        index = revenant_format_parse(format, index + 1, &spec);
        chunk = index;
        if (spec.kind == RevenantFormatNone || (spec.external && !validating)) {
            visit(&spec, NSNotFound, NSNotFound, NSNotFound);
            continue;
        }
        if (spec.kind == RevenantFormatIncomplete) {
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

static void revenant_format_take(NSMutableArray *slots, NSUInteger slot, RevenantFormatKind kind, RevenantFormatLength length)
{
    if (slot == NSNotFound)
        return;
    while (slots.count <= slot)
        [slots addObject:[NSMutableArray array]];
    [slots[slot] addObject:@[@(kind), @(length)]];
}

static NSArray *revenant_format_slots(NSString *format, BOOL validating)
{
    NSMutableArray *slots = [NSMutableArray array];
    revenant_format_walk(format, validating, nil, ^(RevenantFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot) {
        revenant_format_take(slots, widthSlot, RevenantFormatInteger, RevenantFormatLengthPlain);
        revenant_format_take(slots, precisionSlot, RevenantFormatInteger, RevenantFormatLengthPlain);
        revenant_format_take(slots, slot, spec->kind, spec->length);
    });
    return slots;
}

static BOOL revenant_format_allowed(NSString *format, NSString *valid)
{
    NSArray *wanted = revenant_format_slots(format, YES), *allowed = revenant_format_slots(valid, YES);
    if (wanted.count > allowed.count)
        return NO;
    for (NSUInteger index = 0; index < wanted.count; index++) {
        NSArray *offered = allowed[index];
        for (NSArray *kind in wanted[index])
            if (!offered.count || !revenant_format_satisfies([kind[0] unsignedIntegerValue], [offered[0][0] unsignedIntegerValue]))
                return NO;
    }
    return YES;
}

typedef struct {
    long long integer;
    long double floating;
} RevenantFormatValue;

static RevenantFormatValue revenant_format_read(NSArray *described, va_list *arguments)
{
    RevenantFormatValue value = {0, 0};
    RevenantFormatKind kind = described.count ? [described[0][0] unsignedIntegerValue] : RevenantFormatPointer;
    RevenantFormatLength length = described.count ? [described[0][1] unsignedIntegerValue] : RevenantFormatLengthPlain;
    switch (kind) {
        case RevenantFormatInteger:
        case RevenantFormatWideCharacter:
        case RevenantFormatLongInteger:
            if (length == RevenantFormatLengthLongLong)
                value.integer = va_arg(*arguments, long long);
            else if (length == RevenantFormatLengthLong)
                value.integer = va_arg(*arguments, long);
            else
                value.integer = va_arg(*arguments, int);
            break;
        case RevenantFormatFloating:
            value.floating = va_arg(*arguments, double);
            break;
        case RevenantFormatLongFloating:
            value.floating = va_arg(*arguments, long double);
            break;
        default:
            value.integer = (long long)(intptr_t)va_arg(*arguments, void *);
            break;
    }
    return value;
}

#define REVENANT_FORMAT_ONE(value) \
    (stars == 0 ? [[NSString alloc] initWithFormat:plain locale:locale, value] \
     : stars == 1 ? [[NSString alloc] initWithFormat:plain locale:locale, first, value] \
     : [[NSString alloc] initWithFormat:plain locale:locale, first, second, value])

#define REVENANT_FORMAT_C(value) \
    (stars == 0 ? snprintf(buffer, size, raw, value) \
     : stars == 1 ? snprintf(buffer, size, raw, first, value) \
     : snprintf(buffer, size, raw, first, second, value))

static BOOL revenant_format_wide(RevenantFormatSpec *spec)
{
    return spec->size == RevenantFormatSizeLongLong || (spec->size == RevenantFormatSizeLong && sizeof(long) == sizeof(long long));
}

static long long revenant_format_sized(RevenantFormatSize size, long long value)
{
    switch (size) {
        case RevenantFormatSizeByte:
            return (int8_t)value;
        case RevenantFormatSizeShort:
            return (int16_t)value;
        case RevenantFormatSizeLong:
            return (long)value;
        case RevenantFormatSizeLongLong:
            return value;
        default:
            return (int32_t)value;
    }
}

static int revenant_format_print(RevenantFormatSpec *spec, const char *raw, char *buffer, size_t size, int first, int second, NSUInteger stars,
                               RevenantFormatValue value)
{
    switch (spec->kind) {
        case RevenantFormatFloating:
            return REVENANT_FORMAT_C((double)value.floating);
        case RevenantFormatLongFloating:
            return REVENANT_FORMAT_C((long double)value.floating);
        case RevenantFormatPointer:
            return REVENANT_FORMAT_C((void *)(intptr_t)value.integer);
        case RevenantFormatLongInteger:
            return REVENANT_FORMAT_C((long long)(int32_t)value.integer);
        default:
            if (revenant_format_wide(spec))
                return REVENANT_FORMAT_C(value.integer);
            return REVENANT_FORMAT_C((long)(int32_t)value.integer);
    }
}

static NSData *revenant_format_number(RevenantFormatSpec *spec, int first, int second, NSUInteger stars, RevenantFormatValue value)
{
    char raw[sizeof spec->plain / sizeof spec->plain[0] + 1], buffer[512];
    for (NSUInteger index = 0; index < spec->plainLength; index++)
        raw[index] = spec->plain[index] < 0x80 ? (char)spec->plain[index] : '?';
    raw[spec->plainLength] = 0;
    int written = revenant_format_print(spec, raw, buffer, sizeof buffer, first, second, stars, value);
    if (written < 0)
        return [NSData data];
    if ((size_t)written < sizeof buffer)
        return [NSData dataWithBytes:buffer length:strlen(buffer)];
    NSMutableData *large = [NSMutableData dataWithLength:(NSUInteger)written + 1];
    if (revenant_format_print(spec, raw, large.mutableBytes, large.length, first, second, stars, value) < 0)
        return [NSData data];
    return [NSData dataWithBytes:large.bytes length:strlen(large.bytes)];
}

static id revenant_format_one(RevenantFormatSpec *spec, id locale, int first, int second, NSUInteger stars, RevenantFormatValue value)
{
    NSString *plain = [NSString stringWithCharacters:spec->plain length:spec->plainLength];
    BOOL number = spec->kind == RevenantFormatInteger || spec->kind == RevenantFormatLongInteger || spec->kind == RevenantFormatFloating
               || spec->kind == RevenantFormatLongFloating || spec->kind == RevenantFormatPointer;
    BOOL character = spec->kind == RevenantFormatInteger && spec->plain[spec->plainLength - 1] == 'c';
    if (number && (!locale || character))
        return revenant_format_number(spec, first, second, stars, value);
    switch (spec->kind) {
        case RevenantFormatObject:
            return REVENANT_FORMAT_ONE((__bridge id)(void *)(intptr_t)value.integer);
        case RevenantFormatInteger:
            if (revenant_format_wide(spec))
                return REVENANT_FORMAT_ONE(value.integer);
            return REVENANT_FORMAT_ONE((long)(int32_t)value.integer);
        case RevenantFormatWideCharacter:
            return REVENANT_FORMAT_ONE((int)value.integer);
        case RevenantFormatLongInteger:
            return REVENANT_FORMAT_ONE((long long)(int32_t)value.integer);
        case RevenantFormatFloating:
            return REVENANT_FORMAT_ONE((double)value.floating);
        case RevenantFormatLongFloating:
            return REVENANT_FORMAT_ONE((long double)value.floating);
        case RevenantFormatCount:
            return @"";
        default:
            return REVENANT_FORMAT_ONE((void *)(intptr_t)value.integer);
    }
}

static NSString *revenant_format_render(NSString *format, NSString *valid, id locale, va_list arguments)
{
    NSArray *wanted = revenant_format_slots(format, NO), *described = revenant_format_slots(valid, NO);
    NSUInteger count = wanted.count;
    RevenantFormatValue *values = (RevenantFormatValue *)calloc(count ? count : 1, sizeof(RevenantFormatValue));
    va_list walk;
    va_copy(walk, arguments);
    for (NSUInteger slot = 0; slot < count; slot++)
        values[slot] = revenant_format_read(slot < described.count ? described[slot] : @[], &walk);
    va_end(walk);
    NSInteger *sizes = (NSInteger *)calloc(count ? count : 1, sizeof(NSInteger));
    revenant_format_walk(format, NO, nil, ^(RevenantFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot) {
        if (slot != NSNotFound && slot < count) {
            if (spec->kind == RevenantFormatInteger || spec->kind == RevenantFormatLongInteger)
                sizes[slot] = 1 + spec->size;
            else if (spec->kind == RevenantFormatWideCharacter)
                sizes[slot] = 1 + RevenantFormatSizeShort;
            else
                sizes[slot] = 0;
        }
        if (widthSlot != NSNotFound && widthSlot < count)
            sizes[widthSlot] = 1 + RevenantFormatSizeDefault;
        if (precisionSlot != NSNotFound && precisionSlot < count)
            sizes[precisionSlot] = 1 + RevenantFormatSizeDefault;
    });
    for (NSUInteger slot = 0; slot < count; slot++)
        if (sizes[slot])
            values[slot].integer = revenant_format_sized((RevenantFormatSize)(sizes[slot] - 1), values[slot].integer);
    free(sizes);
    NSMutableString *made = [NSMutableString string];
    NSMutableIndexSet *bytes = [NSMutableIndexSet indexSet];
    revenant_format_walk(format, NO, ^(NSRange range) {
        [made appendString:[format substringWithRange:range]];
    }, ^(RevenantFormatSpec *spec, NSUInteger slot, NSUInteger widthSlot, NSUInteger precisionSlot) {
        if (spec->external) {
            [made appendString:[format substringWithRange:NSMakeRange(spec->start, spec->end - spec->start)]];
            return;
        }
        if (spec->kind == RevenantFormatNone) {
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
        id piece = revenant_format_one(spec, locale, first, second, stars, values[slot]);
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

static NSString *revenant_validated_string(id receiver, SEL command, NSString *format, NSString *valid, id locale,
                                         va_list arguments, NSError **error)
{
    if (!format || !valid)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: nil argument", [receiver class], NSStringFromSelector(command)];
    if (!revenant_format_allowed(format, valid)) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFormattingError
                                     userInfo:@{NSDebugDescriptionErrorKey: [NSString stringWithFormat:@"Format '%@' does not match expected '%@'", format, valid]}];
        return nil;
    }
    return [receiver initWithString:revenant_format_render(format, valid, locale, arguments)];
}

@implementation NSString (RevenantValidatedFormat)

- (instancetype)initWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                  error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    self = revenant_validated_string(self, _cmd, format, validFormatSpecifiers, nil, arguments, error);
    va_end(arguments);
    return self;
}

- (instancetype)initWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                 locale:(id)locale error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    self = revenant_validated_string(self, _cmd, format, validFormatSpecifiers, locale, arguments, error);
    va_end(arguments);
    return self;
}

- (instancetype)initWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                 locale:(id)locale arguments:(va_list)arguments error:(NSError **)error
{
    return revenant_validated_string(self, _cmd, format, validFormatSpecifiers, locale, arguments, error);
}

- (instancetype)initWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                              arguments:(va_list)arguments error:(NSError **)error
{
    return revenant_validated_string(self, _cmd, format, validFormatSpecifiers, nil, arguments, error);
}

+ (instancetype)stringWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                    error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    NSString *made = revenant_validated_string([self alloc], _cmd, format, validFormatSpecifiers, nil, arguments, error);
    va_end(arguments);
    return made;
}

+ (instancetype)localizedStringWithValidatedFormat:(NSString *)format validFormatSpecifiers:(NSString *)validFormatSpecifiers
                                             error:(NSError **)error, ...
{
    va_list arguments;
    va_start(arguments, error);
    NSString *made = revenant_validated_string([self alloc], _cmd, format, validFormatSpecifiers, [NSLocale currentLocale], arguments, error);
    va_end(arguments);
    return made;
}

@end
