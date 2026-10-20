#import <Foundation/Foundation.h>

typedef struct {
    unichar flags[8];
    NSUInteger flagLength;
    NSUInteger width;
    NSUInteger precision;
    int length;
    unichar conversion;
    NSUInteger start;
    NSUInteger end;
    NSUInteger argument;
    NSUInteger widthSlot;
    NSUInteger precisionSlot;
    NSUInteger slot;
} RevenantConversion;

typedef enum {
    RevenantArgumentNone = 0,
    RevenantArgumentInt,
    RevenantArgumentUnsigned,
    RevenantArgumentLong,
    RevenantArgumentUnsignedLong,
    RevenantArgumentLongLong,
    RevenantArgumentUnsignedLongLong,
    RevenantArgumentPtrDiff,
    RevenantArgumentSize,
    RevenantArgumentIntMax,
    RevenantArgumentUIntMax,
    RevenantArgumentDouble,
    RevenantArgumentLongDouble,
    RevenantArgumentCharPointer,
    RevenantArgumentVoidPointer,
    RevenantArgumentObject,
} RevenantArgumentKind;

typedef struct {
    RevenantArgumentKind kind;
    union {
        int i;
        unsigned u;
        long l;
        unsigned long ul;
        long long ll;
        unsigned long long ull;
        ptrdiff_t z;
        size_t zs;
        intmax_t j;
        uintmax_t ju;
        double d;
        long double ld;
        char *cs;
        void *vp;
        void *object;
    } value;
} RevenantFormatArgument;

static BOOL RevenantFlag(unichar c)
{
    return c == '-' || c == '+' || c == ' ' || c == '#' || c == '0' || c == '\'';
}

static BOOL RevenantLength(unichar c)
{
    return c == 'h' || c == 'l' || c == 'z' || c == 'j' || c == 't' || c == 'q';
}

static BOOL RevenantUses(unichar c)
{
    return c != 0 && strchr("diouxXeEfFgGaAcCsSpn@", c) != NULL;
}

static void RevenantConversionAt(NSString *format, NSUInteger percent, RevenantConversion *out)
{
    NSUInteger length = format.length, index = percent + 1, digits;
    memset(out, 0, sizeof *out);
    out->width = NSNotFound;
    out->precision = NSNotFound;
    out->start = percent;
    if (index >= length) {
        out->end = percent + 1;
        return;
    }
    if ([format characterAtIndex:index] == '%') {
        out->conversion = '%';
        out->end = index + 1;
        return;
    }
    {
        NSUInteger start = index;
        digits = 0;
        while (index < length && [format characterAtIndex:index] >= '0' && [format characterAtIndex:index] <= '9')
            digits = digits * 10 + (NSUInteger)([format characterAtIndex:index++] - '0');
        if (digits > 0 && index < length && [format characterAtIndex:index] == '$') {
            out->argument = digits;
            index++;
        } else {
            index = start;
        }
    }
    while (index < length && RevenantFlag([format characterAtIndex:index]) && out->flagLength < sizeof out->flags / sizeof *out->flags)
        out->flags[out->flagLength++] = [format characterAtIndex:index++];
    if (index < length && [format characterAtIndex:index] == '*') {
        out->widthSlot = NSUIntegerMax;
        index++;
    } else {
        BOOL wrote = NO;
        digits = 0;
        while (index < length && [format characterAtIndex:index] >= '0' && [format characterAtIndex:index] <= '9') {
            digits = digits * 10 + (NSUInteger)([format characterAtIndex:index++] - '0');
            wrote = YES;
        }
        if (wrote)
            out->width = digits;
    }
    if (index < length && [format characterAtIndex:index] == '.') {
        index++;
        if (index < length && [format characterAtIndex:index] == '*') {
            out->precisionSlot = NSUIntegerMax;
            index++;
        } else {
            digits = 0;
            while (index < length && [format characterAtIndex:index] >= '0' && [format characterAtIndex:index] <= '9')
                digits = digits * 10 + (NSUInteger)([format characterAtIndex:index++] - '0');
            out->precision = digits;
        }
    }
    while (index < length && RevenantLength([format characterAtIndex:index])) {
        if ([format characterAtIndex:index] == 'l' && index + 1 < length && [format characterAtIndex:index + 1] == 'l') {
            out->length = 'q';
            index += 2;
            continue;
        }
        out->length = (int)[format characterAtIndex:index];
        index++;
    }
    if (index < length && RevenantUses([format characterAtIndex:index])) {
        out->conversion = [format characterAtIndex:index];
        out->end = index + 1;
        return;
    }
    if (index >= length)
        out->end = length;
    else if (index + 1 == length && index == percent + 1)
        out->end = length;
    else
        out->end = percent + 1;
}

static RevenantArgumentKind RevenantKind(RevenantConversion spec)
{
    switch (spec.conversion) {
    case 'd': case 'i': case 'c':
        switch (spec.length) {
        case 'l': return RevenantArgumentLong;
        case 'q': return RevenantArgumentLongLong;
        case 'z': return RevenantArgumentPtrDiff;
        case 't': return RevenantArgumentPtrDiff;
        case 'j': return RevenantArgumentIntMax;
        default: return RevenantArgumentInt;
        }
    case 'u': case 'o': case 'x': case 'X':
        switch (spec.length) {
        case 'l': return RevenantArgumentUnsignedLong;
        case 'q': return RevenantArgumentUnsignedLongLong;
        case 'z': return RevenantArgumentSize;
        case 't': return RevenantArgumentUIntMax;
        case 'j': return RevenantArgumentUIntMax;
        default: return RevenantArgumentUnsigned;
        }
    case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A':
        return spec.length == 'L' ? RevenantArgumentLongDouble : RevenantArgumentDouble;
    case 's':
        return RevenantArgumentCharPointer;
    case 'p':
        return RevenantArgumentVoidPointer;
    case '@':
        return RevenantArgumentObject;
    default:
        return RevenantArgumentNone;
    }
}

static RevenantFormatArgument RevenantRead(va_list *arguments, RevenantArgumentKind kind)
{
    RevenantFormatArgument argument;
    memset(&argument, 0, sizeof argument);
    argument.kind = kind;
    switch (kind) {
    case RevenantArgumentInt: argument.value.i = va_arg(*arguments, int); break;
    case RevenantArgumentUnsigned: argument.value.u = va_arg(*arguments, unsigned); break;
    case RevenantArgumentLong: argument.value.l = va_arg(*arguments, long); break;
    case RevenantArgumentUnsignedLong: argument.value.ul = va_arg(*arguments, unsigned long); break;
    case RevenantArgumentLongLong: argument.value.ll = va_arg(*arguments, long long); break;
    case RevenantArgumentUnsignedLongLong: argument.value.ull = va_arg(*arguments, unsigned long long); break;
    case RevenantArgumentPtrDiff: argument.value.z = va_arg(*arguments, ptrdiff_t); break;
    case RevenantArgumentSize: argument.value.zs = va_arg(*arguments, size_t); break;
    case RevenantArgumentIntMax: argument.value.j = va_arg(*arguments, intmax_t); break;
    case RevenantArgumentUIntMax: argument.value.ju = va_arg(*arguments, uintmax_t); break;
    case RevenantArgumentDouble: argument.value.d = va_arg(*arguments, double); break;
    case RevenantArgumentLongDouble: argument.value.ld = va_arg(*arguments, long double); break;
    case RevenantArgumentCharPointer: argument.value.cs = va_arg(*arguments, char *); break;
    case RevenantArgumentVoidPointer: argument.value.vp = va_arg(*arguments, void *); break;
    case RevenantArgumentObject: {
        __unsafe_unretained id object = va_arg(*arguments, id);
        argument.value.object = (__bridge void *)object;
        break;
    }
    case RevenantArgumentNone: break;
    }
    return argument;
}

static NSUInteger RevenantScan(NSString *text, RevenantConversion *conversions, RevenantArgumentKind *kinds, NSUInteger *arguments)
{
    NSUInteger length = text.length, index = 0, found = 0, next = 1, bound = length + 1;
    RevenantConversion spec;
    while (index < length) {
        if ([text characterAtIndex:index] != '%') {
            index++;
            continue;
        }
        RevenantConversionAt(text, index, &spec);
        index = MAX(spec.end, index + 1);
        if (spec.conversion == 0 || spec.conversion == '%') {
            conversions[found++] = spec;
            continue;
        }
        if (spec.widthSlot != 0) {
            spec.widthSlot = next;
            kinds[next++] = RevenantArgumentInt;
        }
        if (spec.precisionSlot != 0) {
            spec.precisionSlot = next;
            kinds[next++] = RevenantArgumentInt;
        }
        if (spec.argument) {
            if (spec.argument > bound)
                spec.argument = bound;
            if (spec.argument > next)
                next = spec.argument;
            spec.slot = spec.argument;
            kinds[spec.slot] = RevenantKind(spec);
        } else {
            spec.slot = next < bound ? next : bound;
            kinds[spec.slot] = RevenantKind(spec);
            if (next < bound)
                next++;
        }
        conversions[found++] = spec;
    }
    *arguments = next;
    return found;
}

static NSString *RevenantSpecifier(RevenantConversion spec)
{
    NSMutableString *text = [NSMutableString stringWithString:@"%"];
    for (NSUInteger i = 0; i < spec.flagLength; i++)
        [text appendFormat:@"%C", spec.flags[i]];
    if (spec.width != NSNotFound)
        [text appendFormat:@"%lu", (unsigned long)spec.width];
    if (spec.precision != NSNotFound)
        [text appendFormat:@".%lu", (unsigned long)spec.precision];
    if (spec.length)
        [text appendFormat:@"%C", (unichar)spec.length];
    [text appendFormat:@"%C", spec.conversion];
    return text;
}

static NSString *RevenantApply(NSLocale *locale, NSString *specifier, ...)
{
    va_list arguments;
    va_start(arguments, specifier);
    NSString *formatted = [[NSString alloc] initWithFormat:specifier locale:locale arguments:arguments];
    va_end(arguments);
    return formatted;
}

static void RevenantApplyStars(RevenantConversion *spec, NSLocale *locale, const RevenantFormatArgument *arguments)
{
    if (spec->widthSlot) {
        int width = arguments[spec->widthSlot - 1].value.i;
        if (width < 0) {
            if (locale) {
                spec->width = 0;
            } else {
                spec->width = (NSUInteger)(-width);
                if (spec->flagLength < sizeof spec->flags / sizeof *spec->flags)
                    spec->flags[spec->flagLength++] = '-';
            }
        } else {
            spec->width = (NSUInteger)width;
        }
        spec->widthSlot = 0;
    }
    if (spec->precisionSlot) {
        int precision = arguments[spec->precisionSlot - 1].value.i;
        spec->precision = precision < 0 ? NSNotFound : (NSUInteger)precision;
        spec->precisionSlot = 0;
    }
}

static NSString *RevenantNumericArgument(RevenantConversion spec, NSLocale *locale, RevenantFormatArgument argument)
{
    NSString *specifier = RevenantSpecifier(spec);
    switch (spec.conversion) {
    case 'd': case 'i':
        switch (spec.length) {
        case 'l': return RevenantApply(locale, specifier, argument.value.l);
        case 'q': return RevenantApply(locale, specifier, argument.value.ll);
        case 'z': return RevenantApply(locale, specifier, (long)argument.value.z);
        case 't': return RevenantApply(locale, specifier, (long)argument.value.z);
        case 'j': return RevenantApply(locale, specifier, (long)argument.value.j);
        default: return RevenantApply(locale, specifier, argument.value.i);
        }
    case 'u': case 'o': case 'x': case 'X':
        switch (spec.length) {
        case 'l': return RevenantApply(locale, specifier, argument.value.ul);
        case 'q': return RevenantApply(locale, specifier, argument.value.ull);
        case 'z': return RevenantApply(locale, specifier, (unsigned long)argument.value.zs);
        case 't': return RevenantApply(locale, specifier, (unsigned long)argument.value.ju);
        case 'j': return RevenantApply(locale, specifier, (unsigned long)argument.value.ju);
        default: return RevenantApply(locale, specifier, argument.value.u);
        }
    case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A':
        if (spec.length == 'L')
            return RevenantApply(locale, specifier, argument.value.ld);
        return RevenantApply(locale, specifier, argument.value.d);
    case 'c':
        return RevenantApply(locale, specifier, argument.value.i);
    case 's':
        return RevenantApply(locale, specifier, argument.value.cs);
    case 'p':
        return RevenantApply(locale, specifier, argument.value.vp);
    default:
        return @"";
    }
}

static NSDictionary *RevenantAttributes(NSDictionary *formatAttributes, NSDictionary *argumentAttributes,
                                      NSUInteger options, NSUInteger replacement)
{
    NSMutableDictionary *attributes;
    if (options & NSAttributedStringFormattingInsertArgumentAttributesWithoutMerging) {
        attributes = [NSMutableDictionary dictionaryWithDictionary:argumentAttributes ?: [NSDictionary dictionary]];
    } else {
        attributes = [NSMutableDictionary dictionaryWithDictionary:formatAttributes ?: [NSDictionary dictionary]];
        if (argumentAttributes)
            [attributes addEntriesFromDictionary:argumentAttributes];
    }
    if (options & NSAttributedStringFormattingApplyReplacementIndexAttribute)
        attributes[NSReplacementIndexAttributeName] = @(replacement);
    return attributes;
}

static void RevenantAppend(NSMutableAttributedString *result, NSString *text, NSDictionary *attributes)
{
    if (text.length)
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
}

static void RevenantAppendText(NSMutableAttributedString *result, NSAttributedString *format, NSString *text, NSUInteger index)
{
    NSDictionary *attributes = [format attributesAtIndex:index effectiveRange:NULL] ?: [NSDictionary dictionary];
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
}

static void RevenantAppendLiteral(NSMutableAttributedString *result, NSAttributedString *format, NSString *text,
                                NSUInteger start, NSUInteger end)
{
    NSUInteger at = start;
    while (at < end) {
        NSRange effective;
        [format attributesAtIndex:at effectiveRange:&effective];
        NSUInteger stop = MIN(effective.location + effective.length, end);
        if (stop <= at)
            stop = at + 1;
        RevenantAppendText(result, format, [text substringWithRange:NSMakeRange(at, stop - at)], at);
        at = stop;
    }
}

static NSAttributedString *RevenantFormat(NSAttributedString *format, NSUInteger options, NSLocale *locale, va_list arguments)
{
    NSString *text;
    NSMutableAttributedString *result;
    NSMutableData *scanned, *kinds, *read;
    RevenantConversion *conversions;
    RevenantArgumentKind *argumentKinds;
    RevenantFormatArgument *values;
    NSUInteger length, found, wanted, index;
    if (!format) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
        return [[NSAttributedString alloc] initWithString:nil];
#pragma clang diagnostic pop
    }
    text = [format string];
    length = text.length;
    scanned = [NSMutableData dataWithLength:(length + 1) * sizeof(RevenantConversion)];
    conversions = (RevenantConversion *)[scanned mutableBytes];
    kinds = [NSMutableData dataWithLength:(length + 1) * sizeof(RevenantArgumentKind)];
    argumentKinds = (RevenantArgumentKind *)[kinds mutableBytes];
    wanted = 1;
    found = RevenantScan(text, conversions, argumentKinds, &wanted);
    read = [NSMutableData dataWithLength:(wanted + 1) * sizeof(RevenantFormatArgument)];
    values = (RevenantFormatArgument *)[read mutableBytes];
    for (index = 0; index < wanted; index++)
        values[index] = RevenantRead(&arguments, argumentKinds[index + 1]);
    result = [[NSMutableAttributedString alloc] init];
    index = 0;
    for (NSUInteger i = 0; i < found; i++) {
        RevenantConversion spec = conversions[i];
        if (spec.start > index)
            RevenantAppendLiteral(result, format, text, index, spec.start);
        if (spec.conversion == '%') {
            RevenantAppendText(result, format, @"%", spec.start);
        } else if (spec.conversion == 0) {
        } else if (spec.conversion == '@') {
            id argument = (__bridge id)values[spec.slot - 1].value.object;
            NSDictionary *formatAttributes = [format attributesAtIndex:spec.start effectiveRange:NULL];
            if ([argument isKindOfClass:[NSAttributedString class]]) {
                NSAttributedString *attributed = argument;
                NSString *attributedText = [attributed string];
                [attributed enumerateAttributesInRange:NSMakeRange(0, attributed.length) options:0
                                             usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
                    RevenantAppend(result, [attributedText substringWithRange:range],
                                 RevenantAttributes(formatAttributes, attributes, options, spec.slot));
                }];
            } else {
                RevenantAppend(result, argument ? [argument description] : @"(null)",
                             RevenantAttributes(formatAttributes, nil, options, spec.slot));
            }
        } else {
            RevenantApplyStars(&spec, locale, values);
            RevenantAppend(result, RevenantNumericArgument(spec, locale, values[spec.slot - 1]),
                         RevenantAttributes([format attributesAtIndex:spec.start effectiveRange:NULL], nil, options, spec.slot));
        }
        index = spec.end;
    }
    if (index < text.length)
        RevenantAppendLiteral(result, format, text, index, text.length);
    return result;
}

@implementation NSAttributedString (RevenantAttributedFormat15)

- (instancetype)initWithFormat:(NSAttributedString *)format
                       options:(NSAttributedStringFormattingOptions)options
                        locale:(NSLocale *)locale
                     arguments:(va_list)arguments
{
    return [self initWithAttributedString:RevenantFormat(format, options, locale, arguments)];
}

- (instancetype)initWithFormat:(NSAttributedString *)format
                       options:(NSAttributedStringFormattingOptions)options
                        locale:(NSLocale *)locale, ...
{
    va_list arguments;
    (void)locale;
    va_start(arguments, locale);
    NSAttributedString *result = RevenantFormat(format, options, nil, arguments);
    va_end(arguments);
    return [self initWithAttributedString:result];
}

+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format, ...
{
    va_list arguments;
    va_start(arguments, format);
    NSAttributedString *result = RevenantFormat(format, 0, [NSLocale currentLocale], arguments);
    va_end(arguments);
    return result;
}

+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format
                                            options:(NSAttributedStringFormattingOptions)options, ...
{
    va_list arguments;
    va_start(arguments, options);
    NSAttributedString *result = RevenantFormat(format, options, [NSLocale currentLocale], arguments);
    va_end(arguments);
    return result;
}

@end

@implementation NSMutableAttributedString (RevenantAttributedFormat15)

- (void)appendLocalizedFormat:(NSAttributedString *)format, ...
{
    va_list arguments;
    va_start(arguments, format);
    NSAttributedString *result = RevenantFormat(format, 0, [NSLocale currentLocale], arguments);
    va_end(arguments);
    [self appendAttributedString:result];
}

@end
