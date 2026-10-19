#import "CharonPDFKit.h"

// PDFBorder as the header declares it: a value object with three settable members and the dictionary
// they are read out of.  A border in the format is two spellings in one annotation - the /Border ARRAY
// of PDF 1.7 Table 164, three numbers of which the host reads one, and the /BS DICTIONARY of Table 8.44,
// which carries the style and the dash pattern - and both are read into this object once, by the port's
// own initializer.  After that the object is the port's own state, and the three setters change it.
//
// Every rule below is measured on the host over fixtures whose dictionaries the harness writes, and each
// names the fixture that fixes it.

// The /BS /S name to PDFBorderStyle, and it is a TABLE and not an ordinal: the enum's five values are
// solid, dashed, beveled, inset, underline in the header's order, and the format's five names are
// /S /D /B /I /U in the same order, so reading the name as its position would fit.  All five are
// measured - bs-s, bs-d, bs-b, bs-i and bs-u each answer the value the enum names - and so is a name
// the format does not list: bs-q carries /S /Q and answers kPDFBorderStyleSolid, not an out-of-range
// value.  So an unknown name is solid, and that is measured rather than assumed.
static PDFBorderStyle charonBorderStyleForName(const char *name)
{
    if (name == NULL)
        return kPDFBorderStyleSolid;
    if (strcmp(name, "S") == 0)
        return kPDFBorderStyleSolid;
    if (strcmp(name, "D") == 0)
        return kPDFBorderStyleDashed;
    if (strcmp(name, "B") == 0)
        return kPDFBorderStyleBeveled;
    if (strcmp(name, "I") == 0)
        return kPDFBorderStyleInset;
    if (strcmp(name, "U") == 0)
        return kPDFBorderStyleUnderline;
    return kPDFBorderStyleSolid;
}

// The dash pattern a DASHED border answers when its /D is not an array of numbers: [3 2], measured.
// bs-d carries /S /D and no /D at all and answers [3 2]; bs-dash-string carries /S /D and a /D that is
// a PDF string and answers the same [3 2]; and bs-dash-custom carries /S /D with /D [7 5] and answers
// [7 5], which is the fixture that shows the array is read at all and that [3 2] is a default rather
// than the only answer.
static NSArray *charonDefaultDashPattern(void)
{
    return [NSArray arrayWithObjects:[NSNumber numberWithDouble:3.0], [NSNumber numberWithDouble:2.0], nil];
}

@implementation PDFBorder {
    // The dictionary the three members are read out of, in the header's own key names: PDFBorderKeyStyle
    // is @"S", PDFBorderKeyLineWidth is @"W" and PDFBorderKeyDashPattern is @"D".  W and S are here from
    // -init, because the host's fresh object answers both, and D is here exactly when a pattern is set -
    // which is what -borderKeyValues publishes, measured.
    NSMutableDictionary *_values;
}

// -init is NSObject's, which PDFBorder.h does not shadow, and the object it makes is the host's fresh
// object: style 0, lineWidth 1, a nil pattern, and a key-values dictionary of {S = 0, W = 1}.  Measured
// on the host with nothing set at all, and it is the same state an annotation with neither a /Border nor
// a /BS is read into, which is why the two agree.
- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _values = [NSMutableDictionary dictionary];
    [_values setObject:[NSNumber numberWithInteger:kPDFBorderStyleSolid] forKey:PDFBorderKeyStyle];
    [_values setObject:[NSNumber numberWithDouble:1.0] forKey:PDFBorderKeyLineWidth];
    return self;
}

// The port's own constructor, over the annotation dictionary the border is read out of.  It starts from
// the -init state and lets the dictionary's own two spellings overwrite what they name, in this order:
//
//   the /BS STYLE dictionary, when the annotation has one.  Its /S sets the style through the table
//   above, and its /D sets the pattern when the style came out dashed.
//
//   the /BS WIDTH, and only from that dictionary.  bs-width-only writes /Border [0 0 7] beside a /BS
//   whose only entry is /W 5 and answers 5, so /W wins; bs-style-only writes /Border [0 0 9] beside a
//   /BS that has a /S and a /D and no /W and answers 1 - the DEFAULT, not 9.  So a /BS that is present
//   at all takes the width question entirely: /Border's third element is not its fallback.
//
//   the /Border ARRAY, and only when there is no /BS dictionary.  The third element and not the last is
//   border-long (/Border [1 2 3 4] answers 3); the two corner radii are not read is border-radii
//   ([5 7 2] answers 2); a negative width is a width is border-negative ([0 0 -2.5] answers -2.5); a zero
//   is a value and not an absent one is border-zero ([0 0 0] answers 0); and the default 1 is
//   border-short ([0 0]), border-radii-only ([5 7]) and border-none.
//
// A /W that is not a number is REFUSED rather than coerced: bs-width-string writes /W (a PDF string)
// beside a dashed /S and no /Border, and the width answers the default 1 while the STYLE answers dashed -
// so the width and the style are read independently and one unreadable key does not lose the other.
- (instancetype)initWithCharonAnnotationDictionary:(CGPDFDictionaryRef)annotation
{
    self = [self init];
    if (self == nil)
        return nil;
    if (annotation == NULL)
        return self;
    CGPDFDictionaryRef style = NULL;
    if (CGPDFDictionaryGetDictionary(annotation, "BS", &style) && style != NULL) {
        const char *name = NULL;
        PDFBorderStyle resolved = kPDFBorderStyleSolid;
        if (CGPDFDictionaryGetName(style, "S", &name))
            resolved = charonBorderStyleForName(name);
        [self setStyle:resolved];
        // CGPDFReal and not double: it is CGFloat, which is a float on armv7 and a double on arm64, and
        // the release's reader writes through that pointer.
        CGPDFReal width = 0;
        if (CGPDFDictionaryGetNumber(style, "W", &width))
            [self setLineWidth:(CGFloat)width];
        if (resolved == kPDFBorderStyleDashed) {
            NSMutableArray *pattern = [NSMutableArray array];
            CGPDFArrayRef array = NULL;
            if (CGPDFDictionaryGetArray(style, "D", &array) && array != NULL) {
                size_t count = CGPDFArrayGetCount(array);
                for (size_t i = 0; i < count; i++) {
                    CGPDFReal number = 0;
                    if (!CGPDFArrayGetNumber(array, i, &number))
                        continue;
                    [pattern addObject:[NSNumber numberWithDouble:(double)number]];
                }
            }
            // an absent /D, a /D that is not an array, and a /D whose elements are not numbers all leave
            // the pattern empty, and an empty pattern is the measured default rather than no answer
            [self setDashPattern:pattern.count ? pattern : charonDefaultDashPattern()];
        }
        return self;
    }
    CGPDFArrayRef array = NULL;
    if (CGPDFDictionaryGetArray(annotation, "Border", &array) && array != NULL) {
        CGPDFReal width = 0;
        if (CGPDFArrayGetNumber(array, 2, &width))
            [self setLineWidth:(CGFloat)width];
    }
    return self;
}

// -style and its setter change nothing else, which is measured: a fresh object with only the style set
// answers S = 3 and W = 1, and an object with a pattern set and the style set afterwards keeps the
// pattern (probe: "dash=@1 then style=beveled" answers D = (1), S = 2, W = 1).
- (PDFBorderStyle)style
{
    return (PDFBorderStyle)[[_values objectForKey:PDFBorderKeyStyle] integerValue];
}

- (void)setStyle:(PDFBorderStyle)style
{
    [_values setObject:[NSNumber numberWithInteger:(NSInteger)style] forKey:PDFBorderKeyStyle];
}

// -lineWidth and its setter likewise: W = 7 answers W 7 with S = 0, and both a zero and a negative width
// are kept rather than clamped (measured at 0 and at -3.5).
- (CGFloat)lineWidth
{
    return (CGFloat)[[_values objectForKey:PDFBorderKeyLineWidth] doubleValue];
}

- (void)setLineWidth:(CGFloat)lineWidth
{
    [_values setObject:[NSNumber numberWithDouble:(double)lineWidth] forKey:PDFBorderKeyLineWidth];
}

// -dashPattern is the array in the dictionary or nil, and the SETTER is the one member that changes more
// than its own key.  Measured, each with the sequence that fixes it:
//
//   a NON-EMPTY array sets the style to DASHED.  A fresh object with only the pattern set answers S = 1,
//   D = (7 5) - so it is not "publish what I was given" but "a pattern means a dashed border".
//
//   an EMPTY array sets the style to SOLID and publishes the empty array.  "dash = @[]" answers
//   S = 0, D = (); and a border whose style was Dashed answers S = 0 after @[] as well, so the setter
//   sets the style rather than leaving it.
//
//   nil does the same as an empty array: S = 0, D = (), and -dashPattern then answers an EMPTY array
//   rather than nil.  Measured on a fresh object with nothing else set, so it is not the tail of some
//   other setter's effect.
//
//   and the WIDTH is not touched by any of the three.  Measured four ways: W = 5 then a pattern then nil,
//   a pattern with no style set then nil, a style then W = 5 then a pattern then nil, and a style then
//   W = 5 with no pattern then a pattern then nil - all four answer W 5 with S = 0 and D = ().
- (NSArray *)dashPattern
{
    return [_values objectForKey:PDFBorderKeyDashPattern];
}

- (void)setDashPattern:(NSArray *)dashPattern
{
    [_values setObject:(dashPattern ?: [NSArray array]) forKey:PDFBorderKeyDashPattern];
    [self setStyle:dashPattern.count ? kPDFBorderStyleDashed : kPDFBorderStyleSolid];
}

// The dictionary itself, which is the host's own property: a COPY, so a caller holding it cannot change
// this object through it.  W and S are always in it and D is in it exactly when -dashPattern answers an
// array, which is measured on border-plain (two keys), bs-dash-solid (two keys, the pattern is nil) and
// bs-d (three).
- (NSDictionary *)borderKeyValues
{
    return [_values copy];
}

@end