#import <Foundation/Foundation.h>

/* The attributed formatting of iOS 15.0: five members over an NSAttributedString format.

   The format is an attributed string and not an NSString, which is the whole difference from the 2001
   API this sits beside: a conversion can stand inside a run of its own attributes, and those attributes
   are what the substituted text is drawn with. What the system's own Foundation does, measured by
   tests/backports/host/attributed15/run.sh, where the port's five members sit beside the system's in one
   process and every case compares:

     the format's own attributes at a conversion are MERGED with the argument's, the argument winning
     where the two name one key, and a literal takes the attributes of the format at its OWN place, so a
     coloured run keeps its colour and the substituted text beside it has none;
     NSAttributedStringFormattingInsertArgumentAttributesWithoutMerging keeps the argument's alone and
     drops the format's;
     NSAttributedStringFormattingApplyReplacementIndexAttribute puts NSReplacementIndexAttributeName on
     each substituted run, numbered by the ARGUMENT the conversion stands for - so one argument written
     twice by "%1$@" is numbered 1 both times, "%3$@ %1$@ %2$@" is numbered 3, 1, 2, and a width taken
     from the list with "%*" is an argument of its own and pushes the conversion's own number along
     ("[%*.*f]" of 8, 2 and 3.14159 puts 3 on the eight characters the value occupies);
     the text a %@ is replaced with is an attributed argument's own string, anything else's -description,
     and a nil one's "(null)";
     a '%' that opens no conversion is consumed and leaves nothing: "100%% %@ %q" answers "100% v ", a
     trailing '%' and a bare '%' answer without it, and "a % b" answers "a  b" - the flags and the width
     before a character that is no conversion go with it.

   Three rules of the format language itself are answered here, all measured against the system:
   a positional conversion "%1$@", which the system answers by taking its argument from the position it
   names ("%2$@ then %1$@" answers "two then one", "%1$d apples and %1$d oranges" answers "3 apples and
   3 oranges" off one argument); a width and a precision written '*', which are arguments of their own
   read just before the conversion's, and a negative one of those is the '-' flag with its magnitude
   ("[%*d]" of -6 and 42 answers "[42]", "[%.*f]" of -2 and 3.14159 answers "[3,14159]"); and one
   argument list read whole, which is what makes the first two possible at all - the list is read once,
   into the argument each conversion stands for, and every conversion then reads its own slot out of it.

   And the one that is not in the header: the two families differ in the locale they format numbers with,
   and so do the two spellings of the initialiser. Measured, over de_DE, fr_FR, the current locale and
   nil:

     -initWithFormat:options:locale:, ...        CANONICAL - de_DE, fr_FR, nil and the current locale
                                                   all answer "1234.5 | 1234 | 2.500000"
     -initWithFormat:options:locale:arguments:   LOCALIZED - nil answers the canonical string and
                                                   everything else answers "1.234,5 | 1.234 | 2,500000"
     +localizedAttributedStringWithFormat:       LOCALIZED with [NSLocale currentLocale], which the two
                                                   class methods hand themselves

   So the locale an explicit variadic initialiser is given does not reach the arithmetic, the one the
   va_list form is given does, and a nil there is what answers the canonical string. The comment in the
   header says the va_list form takes the canonical spelling for nil and the localized one otherwise, and
   that is what this answers; the comment does not say the same of the variadic form, which is canonical
   whatever locale it is handed, and that is measured above.

   One object for this release and no other. The scan below is its own and not the one in
   NSString+ValidatedFormat.m: that one validates a format and refuses a specifier it cannot honour, this
   one walks a format to substitute into it and to know which attributes each conversion stands in, and a
   15.0 object may not call a C function a 16.0 one defines - the file that defines it is left out of
   every band below 16.0, so the call would be undefined there and nowhere else. */

typedef struct {
    unichar flags[8];
    NSUInteger flagLength;
    NSUInteger width;         /* NSNotFound when the format wrote none */
    NSUInteger precision;     /* NSNotFound when the format wrote none */
    int length;               /* 'h', 'l', 'z', 'j', 't', 'q', or 0 */
    unichar conversion;
    NSUInteger start;         /* the '%' of this conversion */
    NSUInteger end;           /* one past the last character the conversion took */
    NSUInteger argument;      /* the index a "n$" names, or 0 when the conversion is not positional */
    NSUInteger widthSlot;     /* the argument a '*' width is, or 0 */
    NSUInteger precisionSlot; /* the argument a '*' precision is, or 0 */
    NSUInteger slot;          /* the argument this conversion stands for, 1-based */
} CharonConversion;

/* The type C promotes each conversion's argument to, which is also how it comes off the list. The kind
   is read off the conversion and the length modifier together, so the union member a conversion reads
   below is the member its kind wrote: one place decides, and the two cannot disagree. */
typedef enum {
    CharonArgumentNone = 0,
    CharonArgumentInt,
    CharonArgumentUnsigned,
    CharonArgumentLong,
    CharonArgumentUnsignedLong,
    CharonArgumentLongLong,
    CharonArgumentUnsignedLongLong,
    CharonArgumentPtrDiff,
    CharonArgumentSize,
    CharonArgumentIntMax,
    CharonArgumentUIntMax,
    CharonArgumentDouble,
    CharonArgumentLongDouble,
    CharonArgumentCharPointer,
    CharonArgumentVoidPointer,
    CharonArgumentObject,
} CharonArgumentKind;

typedef struct {
    CharonArgumentKind kind;
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
        void *object;         /* an id off the list, held unretained for the length of the call */
    } value;
} CharonFormatArgument;

static BOOL CharonFlag(unichar c)
{
    return c == '-' || c == '+' || c == ' ' || c == '#' || c == '0' || c == '\'';
}

static BOOL CharonLength(unichar c)
{
    return c == 'h' || c == 'l' || c == 'z' || c == 'j' || c == 't' || c == 'q';
}

static BOOL CharonUses(unichar c)
{
    return c != 0 && strchr("diouxXeEfFgGaAcCsSpn@", c) != NULL;
}

/* One conversion, starting at its '%', with where the scan stopped left in the struct. A '%' whose last
   character is not one is consumed whole and emits nothing, which is the measured answer, so the caller
   never has to look at a character the scan already passed. The two walks both consume what this one
   consumed, which is what a conversion character of zero says: that character was read and it stands
   for nothing. There is no answer here beyond the struct - a '%' that opens no conversion is a
   conversion as far as both walks are concerned. */
static void CharonConversionAt(NSString *format, NSUInteger percent, CharonConversion *out)
{
    NSUInteger length = format.length, index = percent + 1, digits;
    memset(out, 0, sizeof *out);
    out->width = NSNotFound;
    out->precision = NSNotFound;
    out->start = percent;
    if (index >= length) {
        out->end = percent + 1;         /* a trailing '%' is consumed and emits nothing */
        return;
    }
    if ([format characterAtIndex:index] == '%') {
        out->conversion = '%';
        out->end = index + 1;
        return;
    }
    /* The digits a conversion may open with are its argument's index when a '$' follows them and the
       width otherwise, which is C's rule and the system's: "%2$@ then %1$@" answers "two then one" and
       "%10d" answers a ten-wide number, and "%1 b" opens no conversion at all. A width after an index
       is a width of its own: "%1$10d" is a ten-wide number standing for the first argument. The run is
       put back where it started when no '$' follows, so the width below reads it as the width. */
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
    while (index < length && CharonFlag([format characterAtIndex:index]) && out->flagLength < sizeof out->flags / sizeof *out->flags)
        out->flags[out->flagLength++] = [format characterAtIndex:index++];
    if (index < length && [format characterAtIndex:index] == '*') {
        out->widthSlot = NSUIntegerMax;     /* the slot is a count, fixed by the scan below */
        index++;                             /* a width taken from the argument list */
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
    while (index < length && CharonLength([format characterAtIndex:index])) {
        if ([format characterAtIndex:index] == 'l' && index + 1 < length && [format characterAtIndex:index + 1] == 'l') {
            out->length = 'q';
            index += 2;
            continue;
        }
        out->length = (int)[format characterAtIndex:index];
        index++;
    }
    if (index < length && CharonUses([format characterAtIndex:index])) {
        out->conversion = [format characterAtIndex:index];
        out->end = index + 1;
        return;
    }
    /* A '%' that opens no conversion is consumed together with the flags, the width and the length the
       scan read, and the character that is not a conversion is text again - unless it is the last
       character of the format and the scan read nothing, which is the whole of it: "a % b" answers
       "a  b" and "a %1 b" answers "a 1 b" with the space and the "1" kept, "x %q y" answers "x q y",
       and "%q", "%0", "%-" and the "%q" at the end of "100%% %@ %q" answer nothing at all (all
       measured). The conversion character stays zero, which is how the second walk is told to skip
       what this one consumed. */
    if (index >= length)
        out->end = length;
    else if (index + 1 == length && index == percent + 1)
        out->end = length;
    else
        out->end = percent + 1;
}

/* The type the argument of this conversion comes off the list as. */
static CharonArgumentKind CharonKind(CharonConversion spec)
{
    switch (spec.conversion) {
    case 'd': case 'i': case 'c':
        switch (spec.length) {
        case 'l': return CharonArgumentLong;
        case 'q': return CharonArgumentLongLong;
        case 'z': return CharonArgumentPtrDiff;
        case 't': return CharonArgumentPtrDiff;
        case 'j': return CharonArgumentIntMax;
        default: return CharonArgumentInt;
        }
    case 'u': case 'o': case 'x': case 'X':
        switch (spec.length) {
        case 'l': return CharonArgumentUnsignedLong;
        case 'q': return CharonArgumentUnsignedLongLong;
        case 'z': return CharonArgumentSize;
        case 't': return CharonArgumentUIntMax;
        case 'j': return CharonArgumentUIntMax;
        default: return CharonArgumentUnsigned;
        }
    case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A':
        return spec.length == 'L' ? CharonArgumentLongDouble : CharonArgumentDouble;
    case 's':
        return CharonArgumentCharPointer;
    case 'p':
        return CharonArgumentVoidPointer;
    case '@':
        return CharonArgumentObject;
    default:
        return CharonArgumentNone;
    }
}

/* One argument, off the list once. */
static CharonFormatArgument CharonRead(va_list *arguments, CharonArgumentKind kind)
{
    CharonFormatArgument argument;
    memset(&argument, 0, sizeof argument);
    argument.kind = kind;
    switch (kind) {
    case CharonArgumentInt: argument.value.i = va_arg(*arguments, int); break;
    case CharonArgumentUnsigned: argument.value.u = va_arg(*arguments, unsigned); break;
    case CharonArgumentLong: argument.value.l = va_arg(*arguments, long); break;
    case CharonArgumentUnsignedLong: argument.value.ul = va_arg(*arguments, unsigned long); break;
    case CharonArgumentLongLong: argument.value.ll = va_arg(*arguments, long long); break;
    case CharonArgumentUnsignedLongLong: argument.value.ull = va_arg(*arguments, unsigned long long); break;
    case CharonArgumentPtrDiff: argument.value.z = va_arg(*arguments, ptrdiff_t); break;
    case CharonArgumentSize: argument.value.zs = va_arg(*arguments, size_t); break;
    case CharonArgumentIntMax: argument.value.j = va_arg(*arguments, intmax_t); break;
    case CharonArgumentUIntMax: argument.value.ju = va_arg(*arguments, uintmax_t); break;
    case CharonArgumentDouble: argument.value.d = va_arg(*arguments, double); break;
    case CharonArgumentLongDouble: argument.value.ld = va_arg(*arguments, long double); break;
    case CharonArgumentCharPointer: argument.value.cs = va_arg(*arguments, char *); break;
    case CharonArgumentVoidPointer: argument.value.vp = va_arg(*arguments, void *); break;
    case CharonArgumentObject: {
        __unsafe_unretained id object = va_arg(*arguments, id);
        /* The list's argument belongs to the caller and lives for the whole call, which is what the
           object is used inside, so it is carried as the pointer it is rather than retained: a union
           with an __strong member in it cannot be a C type at all under ARC. */
        argument.value.object = (__bridge void *)object;
        break;
    }
    case CharonArgumentNone: break;
    }
    return argument;
}

/* The whole format, once, before anything is substituted: every conversion with its place in the format
   and the argument it stands for, and the argument each of those arguments arrives as. Two passes over
   one format and one argument list are what let one argument be substituted twice and what let a width
   be an argument of its own, and the count the list is read by is the largest number any conversion
   asked for - a "n$" reads the argument it names and leaves the list at least there, and a conversion
   that names none takes the next one.

   An index past the end of the format is taken as the format's own length, which is the bound this
   allocation carries: a conversion naming a thousand arguments is a program that reads past the end of
   its list, which is undefined on this side and on the system's, so no case compares it and the read
   stops where this object can still answer. */
static NSUInteger CharonScan(NSString *text, CharonConversion *conversions, CharonArgumentKind *kinds, NSUInteger *arguments)
{
    NSUInteger length = text.length, index = 0, found = 0, next = 1, bound = length + 1;
    CharonConversion spec;
    while (index < length) {
        if ([text characterAtIndex:index] != '%') {
            index++;
            continue;
        }
        CharonConversionAt(text, index, &spec);
        index = MAX(spec.end, index + 1);
        if (spec.conversion == 0 || spec.conversion == '%') {
            /* the first consumed nothing and the second is one character of result: neither stands for
               an argument, and both are recorded so that the walk below consumes what this consumed */
            conversions[found++] = spec;
            continue;
        }
        if (spec.widthSlot != 0) {
            spec.widthSlot = next;
            kinds[next++] = CharonArgumentInt;
        }
        if (spec.precisionSlot != 0) {
            spec.precisionSlot = next;
            kinds[next++] = CharonArgumentInt;
        }
        if (spec.argument) {
            if (spec.argument > bound)
                spec.argument = bound;
            if (spec.argument > next)
                next = spec.argument;
            spec.slot = spec.argument;
            kinds[spec.slot] = CharonKind(spec);
        } else {
            spec.slot = next < bound ? next : bound;
            kinds[spec.slot] = CharonKind(spec);
            if (next < bound)
                next++;
        }
        conversions[found++] = spec;
    }
    *arguments = next;
    return found;
}

/* The conversion on its own, for the release's own formatter: this one's flags, width, precision and
   length with this one's conversion character. The arithmetic and the grouping are then the system's,
   which is where they belong, and not a second implementation of them here. */
static NSString *CharonSpecifier(CharonConversion spec)
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

/* One argument, formatted on its own. The list a variadic member is given cannot be handed to the
   release's formatter twice: the second call reads the floating point register area as spent and answers
   0.00 where the first answered 1234.50 (measured, with %d and %.2f off one list). So each argument is
   formatted on its own through this - a fresh list of one, which the release's own formatter reads
   whole. */
static NSString *CharonApply(NSLocale *locale, NSString *specifier, ...)
{
    va_list arguments;
    va_start(arguments, specifier);
    NSString *formatted = [[NSString alloc] initWithFormat:specifier locale:locale arguments:arguments];
    va_end(arguments);
    return formatted;
}

/* The width and the precision a '*' wrote, in the form a specifier takes them. A negative one is a left
   justification, which the two families answer differently and both are measured for: the canonical one
   takes the magnitude with the '-' flag ("[%*d]" of -6 and 42 answers "[42    ]" through
   -initWithFormat:options:locale:arguments: with a nil locale), and the localized one takes no width at
   all ("[42]" through +localizedAttributedStringWithFormat:, for every width from -1 to -12). The port
   answers each of them as measured, which is why the locale is read here.

   A negative precision is no precision at all, which is C's rule and the canonical family's answer
   ("[%.*f]" of -8 and 3.14159 answers "[3.141590]" there). The localized family's answer is the value's
   own digits instead ("[3,14159]"), and that is the one shape this object does not carry: the shortest
   decimal that reads back as the same double is a search over the precisions, and a measurement is in
   facts/Foundation/AttributedStrings15.md with the command that takes it again.

   The slots are cleared, so a specifier built after this spells the width and the precision it read and
   not the two placeholders they came from. */
static void CharonApplyStars(CharonConversion *spec, NSLocale *locale, const CharonFormatArgument *arguments)
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

static NSString *CharonNumericArgument(CharonConversion spec, NSLocale *locale, CharonFormatArgument argument)
{
    NSString *specifier = CharonSpecifier(spec);
    switch (spec.conversion) {
    case 'd': case 'i':
        switch (spec.length) {
        case 'l': return CharonApply(locale, specifier, argument.value.l);
        case 'q': return CharonApply(locale, specifier, argument.value.ll);
        case 'z': return CharonApply(locale, specifier, (long)argument.value.z);
        case 't': return CharonApply(locale, specifier, (long)argument.value.z);
        case 'j': return CharonApply(locale, specifier, (long)argument.value.j);
        default: return CharonApply(locale, specifier, argument.value.i);
        }
    case 'u': case 'o': case 'x': case 'X':
        switch (spec.length) {
        case 'l': return CharonApply(locale, specifier, argument.value.ul);
        case 'q': return CharonApply(locale, specifier, argument.value.ull);
        case 'z': return CharonApply(locale, specifier, (unsigned long)argument.value.zs);
        case 't': return CharonApply(locale, specifier, (unsigned long)argument.value.ju);
        case 'j': return CharonApply(locale, specifier, (unsigned long)argument.value.ju);
        default: return CharonApply(locale, specifier, argument.value.u);
        }
    case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A':
        if (spec.length == 'L')
            return CharonApply(locale, specifier, argument.value.ld);
        return CharonApply(locale, specifier, argument.value.d);
    case 'c':
        return CharonApply(locale, specifier, argument.value.i);
    case 's':
        return CharonApply(locale, specifier, argument.value.cs);
    case 'p':
        return CharonApply(locale, specifier, argument.value.vp);
    default:
        return @"";
    }
}

/* The attributes one substituted range is drawn with: the format's own at the conversion, the
   argument's over the top, and the argument the conversion stands for when the options ask for it. */
static NSDictionary *CharonAttributes(NSDictionary *formatAttributes, NSDictionary *argumentAttributes,
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

static void CharonAppend(NSMutableAttributedString *result, NSString *text, NSDictionary *attributes)
{
    if (text.length)
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
}

static void CharonAppendText(NSMutableAttributedString *result, NSAttributedString *format, NSString *text, NSUInteger index)
{
    NSDictionary *attributes = [format attributesAtIndex:index effectiveRange:NULL] ?: [NSDictionary dictionary];
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
}

static void CharonAppendLiteral(NSMutableAttributedString *result, NSAttributedString *format, NSString *text,
                                NSUInteger start, NSUInteger end)
{
    /* Literal text takes the attributes of the format at its OWN place, so a coloured run of the format
       keeps its colour and the text after it does not: "pre %@ mid %@ post" with the colour over "%@ "
       answers a coloured "ARG" and a coloured " " and an uncoloured "mid ". One run per effective range,
       which is what the enumeration below asks the format for. */
    NSUInteger at = start;
    while (at < end) {
        NSRange effective;
        [format attributesAtIndex:at effectiveRange:&effective];
        NSUInteger stop = MIN(effective.location + effective.length, end);
        if (stop <= at)
            stop = at + 1;
        CharonAppendText(result, format, [text substringWithRange:NSMakeRange(at, stop - at)], at);
        at = stop;
    }
}

static NSAttributedString *CharonFormat(NSAttributedString *format, NSUInteger options, NSLocale *locale, va_list arguments)
{
    NSString *text;
    NSMutableAttributedString *result;
    NSMutableData *scanned, *kinds, *read;
    CharonConversion *conversions;
    CharonArgumentKind *argumentKinds;
    CharonFormatArgument *values;
    NSUInteger length, found, wanted, index;
    if (!format) {
        /* A nil format is the release's own refusal and keeps its own wording and its own class: the
           concrete class raises from -initWithString: ("NSConcreteAttributedString initWithString:: nil
           value", measured), and asking it there is what answers with that text rather than this
           object's own guess at it. The argument is nil on purpose, so the warning is silenced where
           the reason is written. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
        return [[NSAttributedString alloc] initWithString:nil];
#pragma clang diagnostic pop
    }
    text = [format string];
    length = text.length;
    /* One allocation each, sized by the format: a conversion cannot outnumber the characters that spell
       it, so both arrays are the format's own length long plus one and neither needs to grow. They are
       held in NSMutableData, so there is nothing to free on any way out of here. The kinds are written
       at the slot's own index, one-based, so the loop that reads the list walks them from one as well. */
    scanned = [NSMutableData dataWithLength:(length + 1) * sizeof(CharonConversion)];
    conversions = (CharonConversion *)[scanned mutableBytes];
    kinds = [NSMutableData dataWithLength:(length + 1) * sizeof(CharonArgumentKind)];
    argumentKinds = (CharonArgumentKind *)[kinds mutableBytes];
    wanted = 1;
    found = CharonScan(text, conversions, argumentKinds, &wanted);
    read = [NSMutableData dataWithLength:(wanted + 1) * sizeof(CharonFormatArgument)];
    values = (CharonFormatArgument *)[read mutableBytes];
    for (index = 0; index < wanted; index++)
        values[index] = CharonRead(&arguments, argumentKinds[index + 1]);
    result = [[NSMutableAttributedString alloc] init];
    index = 0;
    for (NSUInteger i = 0; i < found; i++) {
        CharonConversion spec = conversions[i];
        if (spec.start > index)
            CharonAppendLiteral(result, format, text, index, spec.start);
        if (spec.conversion == '%') {
            CharonAppendText(result, format, @"%", spec.start);
        } else if (spec.conversion == 0) {
            /* consumed by the scan and standing for no text, which is the measured answer of a '%'
               that opens no conversion */
        } else if (spec.conversion == '@') {
            id argument = (__bridge id)values[spec.slot - 1].value.object;
            NSDictionary *formatAttributes = [format attributesAtIndex:spec.start effectiveRange:NULL];
            if ([argument isKindOfClass:[NSAttributedString class]]) {
                NSAttributedString *attributed = argument;
                NSString *attributedText = [attributed string];
                [attributed enumerateAttributesInRange:NSMakeRange(0, attributed.length) options:0
                                             usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
                    CharonAppend(result, [attributedText substringWithRange:range],
                                 CharonAttributes(formatAttributes, attributes, options, spec.slot));
                }];
            } else {
                CharonAppend(result, argument ? [argument description] : @"(null)",
                             CharonAttributes(formatAttributes, nil, options, spec.slot));
            }
        } else {
            CharonApplyStars(&spec, locale, values);
            CharonAppend(result, CharonNumericArgument(spec, locale, values[spec.slot - 1]),
                         CharonAttributes([format attributesAtIndex:spec.start effectiveRange:NULL], nil, options, spec.slot));
        }
        index = spec.end;
    }
    if (index < text.length)
        CharonAppendLiteral(result, format, text, index, text.length);
    return result;
}

@implementation NSAttributedString (CharonAttributedFormat15)

- (instancetype)initWithFormat:(NSAttributedString *)format
                       options:(NSAttributedStringFormattingOptions)options
                        locale:(NSLocale *)locale
                     arguments:(va_list)arguments
{
    /* The locale the caller names reaches the arithmetic here and does not in the variadic initialiser
       below, which is the measured difference between the two spellings of one selector. */
    return [self initWithAttributedString:CharonFormat(format, options, locale, arguments)];
}

- (instancetype)initWithFormat:(NSAttributedString *)format
                       options:(NSAttributedStringFormattingOptions)options
                        locale:(NSLocale *)locale, ...
{
    va_list arguments;
    /* This one formats CANONICALLY whatever locale it is handed - de_DE, fr_FR, the current locale and
       nil all answer "1234.5 | 1234 | 2.500000" - so a nil is what it formats with, and handing the
       locale on would localise where the release does not. */
    (void)locale;
    va_start(arguments, locale);
    NSAttributedString *result = CharonFormat(format, options, nil, arguments);
    va_end(arguments);
    return [self initWithAttributedString:result];
}

+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format, ...
{
    va_list arguments;
    va_start(arguments, format);
    NSAttributedString *result = CharonFormat(format, 0, [NSLocale currentLocale], arguments);
    va_end(arguments);
    return result;
}

+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format
                                            options:(NSAttributedStringFormattingOptions)options, ...
{
    va_list arguments;
    va_start(arguments, options);
    NSAttributedString *result = CharonFormat(format, options, [NSLocale currentLocale], arguments);
    va_end(arguments);
    return result;
}

@end

@implementation NSMutableAttributedString (CharonAttributedFormat15)

- (void)appendLocalizedFormat:(NSAttributedString *)format, ...
{
    va_list arguments;
    va_start(arguments, format);
    NSAttributedString *result = CharonFormat(format, 0, [NSLocale currentLocale], arguments);
    va_end(arguments);
    [self appendAttributedString:result];
}

@end