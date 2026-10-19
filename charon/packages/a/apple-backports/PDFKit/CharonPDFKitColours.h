// PDFAnnotation's three colours and its font, as DERIVATIONS over an annotation's dictionary.
//
// WHY THIS IS A HEADER AND NOT THE OBJECT'S OWN SOURCE.  The four members are implemented in
// PDFAnnotationColours11.m, which is the only object of the port that imports UIKit, and they are
// implemented by calling the five functions below.  The bodies live HERE, `static inline`, for a reason
// that is measured and not tidiness - and the same reason CharonLists.h gives for charon_screen_scale and
// its two neighbours: a C function a file that DEFINES A CLASS calls has to be reachable from a host
// differential that compiles the port's objects with its own sources, and a C symbol in a .m is a symbol
// that differential cannot link.
//
// The measurement that forced the shape: the only macOS binary on this machine that has a UIColor is the
// Mac Catalyst one, it links no PDFKit (`otool -L`) and still loads
// /System/iOSSupport/System/Library/Frameworks/PDFKit.framework at run time, and a CATEGORY in a later
// image REPLACES one in an earlier - so the platform's own PDFAnnotationUtilities answers the port's four
// selectors there and a differential written against the SELECTORS compares Apple's PDFKit against Apple's
// PDFKit.  That it is the category and not the port is measured too: a -777 sentinel planted in
// PDFAppearanceCharacteristics' own -init answered appearance.fresh.controlType=-777 in that same binary,
// so the CLASS's own members there do run.
//
// So the harness calls these functions DIRECTLY, on both platforms, over the same CGPDFDictionary the port
// read: the port's derivation against the platform's member, with no selector dispatch anywhere in the
// path that a later image can take over.  Both sides then wrap the result in their OWN platform's colour
// class - the host's NSColor and the port's UIColor - which is the whole of the platform difference
// color.m's header already describes.
//
// WHAT IS UNDER TEST, and what is not: these functions decide which key, which colour space, which
// components and which font name and size.  They do NOT decide what a UIColor is, and both sides build
// theirs from the CGColorRef returned here, so a difference in the comparison is a difference in the
// derivation and not in the wrapper.
//
// Every reading is keyed by the annotation's own /NM over annotation-colours.pdf, and the table, the
// 48 fixtures and the two readings an earlier index-keyed version of that fixture got wrong are in
// facts/PDFKit/Annotation11.md.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

// UIKit, for -[UIFont fontWithName:size:] and nothing else: it is how "does the platform have a font of
// that name" is asked, and that question is one of the port's THREE CLAUSES for -font, so it belongs here
// and not in a caller.  Putting it in the caller would have made the harness decide it, and a test that
// decides what it is testing is not a test.  The two importers of this header are PDFAnnotationColours11.m
// and the harness's color.m, and both have UIKit; the macOS port side never reads it.
#define CHARON_ANNOTATION_FONT_DEFAULT_NAME @"Helvetica"
#define CHARON_ANNOTATION_FONT_DEFAULT_SIZE ((CGFloat)12)

// One component of a PDF colour array, as a double, or false when it is not a number at all.
//
// TWO TRAPS IN ONE LINE OF COREGRAPHICS, and both of them cost this family a run each.
//
// 1  CGPDFArrayGetObject is ZERO-BASED.  Its index runs 0 .. count-1, the way PDFKit11.m, PDFPage11.m and
//    PDFAction11.m already read arrays in this library - so reading component i as `i + 1' walks off the
//    end on the LAST component and no other, which is the worst shape a bug can have: [1 0 0] reads two
//    components and then refuses, and a one-component [0.25] refuses outright.  That is how this answered
//    nil for bg-rgb, bg-gray, bg-btn, bg-cmyk and every /IC while the host answered all of them.
// 2  CGPDFArrayGetNumber does NOT fail on an integer, it answers ZERO.  It is `bool` and returns true for
//    an integer component whose value is 1 or 0, and the double it writes is 0 either way - so [1 0 0]
//    read through it is a BLACK colour and not a refusal, which is worse than the refusal because it looks
//    like an answer.  A PDF colour array is written with its components as bare numbers and CoreGraphics
//    types a bare `1' as kCGPDFObjectTypeInteger and a `0.5' as kCGPDFObjectTypeReal, so the object's own
//    TYPE is what says which reader to use, and that is what this switches on.
static inline BOOL charon_annotation_number(CGPDFArrayRef array, size_t index, double *out)
{
    CGPDFObjectRef component = NULL;
    if (!CGPDFArrayGetObject(array, index, &component) || component == NULL)
        return NO;
    switch (CGPDFObjectGetType(component)) {
    case kCGPDFObjectTypeInteger: {
        long integer = 0;
        if (!CGPDFObjectGetValue(component, kCGPDFObjectTypeInteger, &integer))
            return NO;
        *out = (double)integer;
        return YES;
    }
    case kCGPDFObjectTypeReal: {
        double real = 0;
        if (!CGPDFObjectGetValue(component, kCGPDFObjectTypeReal, &real))
            return NO;
        *out = real;
        return YES;
    }
    default:
        // a name, a string, an array, a dictionary or a stream is not a colour component
        return NO;
    }
}

// A colour in one of three named spaces, from a PDF colour array.  PDF 1.7 Table 8.40 defines the shapes
// for a device colour: no component is no colour, one is gray, three is RGB and four is CMYK - so the
// COMPONENT COUNT is what selects the space, and the components are the ARRAY'S OWN.  Nothing converts:
// the host answers [1 0 0] as a kCGColorSpaceDeviceRGB colour carrying 1, 0, 0, 1.
//

// A +1 CGColorRef, which the CALLER releases, or NULL for no colour.  +1 because a colour outlives the
// call that built it - the host's UIColor outlives the getter that made it - and NULL because "no colour"
// is one of the measured answers and a colour is not something to invent for it.
static inline CGColorRef charon_annotation_device_colour(CGPDFArrayRef array)
{
    if (array == NULL)
        return NULL;
    size_t components = CGPDFArrayGetCount(array);
    CGColorSpaceRef space = NULL;
    if (components == 1)
        space = CGColorSpaceCreateDeviceGray();
    else if (components == 3)
        space = CGColorSpaceCreateDeviceRGB();
    else if (components == 4)
        space = CGColorSpaceCreateDeviceCMYK();
    // no component, or a shape Table 8.40 does not define: not a colour
    if (space == NULL)
        return NULL;
    // FIVE values for a space of at most four components, because CGColorCreate reads the space's OWN
    // component count PLUS one: the array's components and then the ALPHA, whatever the array says - a PDF
    // colour array has no alpha component (Table 8.40's shapes are gray, RGB and CMYK) and every measured
    // answer ends in one.  Zero-initialising the tail is how the first version answered every background
    // and interior colour with a zero ALPHA and the right hue: a colour with alpha 0 is invisible, and an
    // invisible colour is not the host's answer to any of these.
    CGFloat values[5] = {0, 0, 0, 0, 0};
    for (size_t i = 0; i < components; i++) {
        double component = 0;
        if (!charon_annotation_number(array, i, &component)) {
            CGColorSpaceRelease(space);
            return NULL;
        }
        values[i] = (CGFloat)component;
    }
    values[components] = 1;
    CGColorRef colour = CGColorCreate(space, values);
    CGColorSpaceRelease(space);
    return colour;
}

// A colour in one of the three named spaces, given the name and the components.  The names are looked up
// with CGColorSpaceCreateWithName, which is iOS 2.0; the names themselves are exported by CoreGraphics
// from 3.0 (kCGColorSpaceGenericGray, kCGColorSpaceGenericRGB, kCGColorSpaceGenericCMYK) and from 4.0
// (kCGColorSpaceGenericGrayGamma2_2), read out of the 4.3 and 6.1.3 armv7 caches' own export tries -
// so this SDK's API_AVAILABLE(ios(9.0)) on those three names is the header's annotation and not the
// export, and the port's 6.0 minimum binds them all.  Nothing here tests for a NULL space and nothing
// falls back: the deployment target makes the imports weak and the gate checks that they resolve.
static inline CGColorRef charon_annotation_named_colour(CFStringRef name, const CGFloat *components,
                                                        size_t count)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(name);
    if (space == NULL)
        return NULL;
    CGColorRef colour = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return colour;
}

// The colour off a PDF colour ARRAY key of the annotation, or off one level down inside a named
// dictionary - `appearance' says which, because /IC is the annotation's own and /BG is inside /MK, and
// that difference is the whole of why an earlier batch wrote /MK /BC and got nil.
static inline CGColorRef charon_annotation_colour_for_key(CGPDFDictionaryRef annotation, const char *key,
                                                          bool appearance)
{
    if (annotation == NULL)
        return NULL;
    CGPDFArrayRef array = NULL;
    if (appearance) {
        CGPDFObjectRef mark = NULL;
        if (!CGPDFDictionaryGetObject(annotation, "MK", &mark) || mark == NULL
            || CGPDFObjectGetType(mark) != kCGPDFObjectTypeDictionary)
            return NULL;
        CGPDFDictionaryRef appearanceDictionary = NULL;
        if (!CGPDFObjectGetValue(mark, kCGPDFObjectTypeDictionary, &appearanceDictionary)
            || appearanceDictionary == NULL)
            return NULL;
        if (!CGPDFDictionaryGetArray(appearanceDictionary, key, &array) || array == NULL)
            return NULL;
    } else {
        CGPDFObjectRef found = NULL;
        if (!CGPDFDictionaryGetObject(annotation, key, &found) || found == NULL
            || CGPDFObjectGetType(found) != kCGPDFObjectTypeArray)
            return NULL;
        if (!CGPDFObjectGetValue(found, kCGPDFObjectTypeArray, &array) || array == NULL)
            return NULL;
    }
    return charon_annotation_device_colour(array);
}

// -backgroundColor: /MK's /BG.  NOT /BC - /BC is the BORDER colour of Table 8.40 and is the key
// -[PDFAnnotation border] reads, and bg-bc-beside carries both and answers the /BG.
static inline CGColorRef charon_annotation_background_colour(CGPDFDictionaryRef annotation)
{
    return charon_annotation_colour_for_key(annotation, "BG", true);
}

// -interiorColor: the annotation's OWN /IC, which is not an /MK key.  The 26.2 header names /Circle,
// /Line and /Square as the subtypes that use it; the host answers it on every subtype measured.
static inline CGColorRef charon_annotation_interior_colour(CGPDFDictionaryRef annotation)
{
    return charon_annotation_colour_for_key(annotation, "IC", false);
}

// The /DA as the tokens a reader can take off it: whitespace-separated words, in order, each either a
// name - written /x in the file, slash and all - or something else, which is a number.  An NSArray of
// NSString rather than a C array of object pointers under ARC, which cannot be written to through a plain
// `NSString **` at all; and one filter, because an EMPTY word between two spaces is not a token of a
// content stream.
static inline NSArray *charon_annotation_da_tokens(NSString *text)
{
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *word in [text componentsSeparatedByCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (word.length == 0)
            continue;
        // the slash is KEPT: a name and an operator are told apart by it, and both callers need to know
        // which one a token is
        [tokens addObject:word];
    }
    return tokens;
}

// Whether a token is an OPERATOR - that is, an operator and not a name, which is what tells `/g' the name
// of a font from `g' the gray operator.  One token cannot be both: in a content stream a token written /x
// is a name and a token written x is a keyword or a number.
static inline BOOL charon_annotation_da_is_operator(NSString *token, NSString *wanted)
{
    return ![token hasPrefix:@"/"] && [token isEqualToString:wanted];
}

// The /DA as text, or NULL when the annotation carries none - and the ABSENCE is one of the answers,
// because no /DA and a /DA with no readable fill are two different defaults.
static inline NSString *charon_annotation_da_text(CGPDFDictionaryRef annotation, bool *present)
{
    *present = NO;
    if (annotation == NULL)
        return nil;
    CGPDFObjectRef found = NULL;
    if (!CGPDFDictionaryGetObject(annotation, "DA", &found) || found == NULL
        || CGPDFObjectGetType(found) != kCGPDFObjectTypeString)
        return nil;
    CGPDFStringRef string = NULL;
    if (!CGPDFObjectGetValue(found, kCGPDFObjectTypeString, &string) || string == NULL)
        return nil;
    CFStringRef text = CGPDFStringCopyTextString(string);
    if (text == NULL)
        return nil;
    *present = YES;
    return (__bridge NSString *)text;
}

// -fontColor: the /DA's FIRST fill operand, and only a fill one.  Text is painted with the fill colour,
// so g and rg are read and G, RG and K - which set the stroke - are not; and k is not read either, which
// is the host's behaviour and not the format's, measured on two CMYK values whose conversions are red and
// cyan and which both answer the default.
//
// The operand's POSITION does not decide, being FIRST does: `0.5 g 1 0 0 rg' answers the gray and
// `1 0 0 rg 0.5 g' answers the RGB, so this is a defaults read and not a replay of a content stream.  A
// colour operator with the wrong operand count is not refused but reads the numbers IN FRONT of it, which
// is what makes `0.5 0.25 g' answer 0.25.
//
// The spaces are the GENERIC ones and not device ones - the host does not answer DeviceGray for `0 g' -
// and the two defaults differ: no /DA at all gives the gamma 2.2 gray and a /DA with no readable fill
// gives the gamma 1.0 one.
static inline CGColorRef charon_annotation_font_colour(CGPDFDictionaryRef annotation)
{
    bool present = NO;
    NSString *text = charon_annotation_da_text(annotation, &present);
    if (!present)
        return charon_annotation_named_colour(kCGColorSpaceGenericGrayGamma2_2,
                                              (const CGFloat[]){0, 1}, 2);
    NSArray *tokens = charon_annotation_da_tokens(text);
    for (NSUInteger i = 0; i < tokens.count; i++) {
        NSString *token = tokens[i];
        if (charon_annotation_da_is_operator(token, @"rg") && i >= 3) {
            CGFloat values[4] = {(CGFloat)[tokens[i - 3] doubleValue],
                                 (CGFloat)[tokens[i - 2] doubleValue],
                                 (CGFloat)[tokens[i - 1] doubleValue], 1};
            return charon_annotation_named_colour(kCGColorSpaceGenericRGB, values, 4);
        }
        if (charon_annotation_da_is_operator(token, @"g") && i >= 1) {
            CGFloat values[2] = {(CGFloat)[tokens[i - 1] doubleValue], 1};
            return charon_annotation_named_colour(kCGColorSpaceGenericGray, values, 2);
        }
    }
    // a /DA with no fill operand in it: the generic gray of an unread one, which is not the no-/DA default
    return charon_annotation_named_colour(kCGColorSpaceGenericGray, (const CGFloat[]){0, 1}, 2);
}

// The /DA's font SIZE, read independently of the name: font-size-only (`12 Tf' with no name) answers
// Helvetica at 12 and font-name-only (`/Helv Tf' with no size) answers Helvetica at 12, so the default is
// 12 whichever half is missing, and font-unknown (`/Nonexistent 9 Tf') answers 9 - the size is kept even
// when the name is not.
static inline CGFloat charon_annotation_font_size(CGPDFDictionaryRef annotation)
{
    bool present = NO;
    NSString *text = charon_annotation_da_text(annotation, &present);
    if (!present)
        return CHARON_ANNOTATION_FONT_DEFAULT_SIZE;
    NSArray *tokens = charon_annotation_da_tokens(text);
    for (NSUInteger i = 0; i < tokens.count; i++) {
        if (!charon_annotation_da_is_operator(tokens[i], @"Tf") || i < 1)
            continue;
        NSString *sizeToken = tokens[i - 1];
        if ([sizeToken hasPrefix:@"/"])
            break;
        return (CGFloat)[sizeToken doubleValue];
    }
    return CHARON_ANNOTATION_FONT_DEFAULT_SIZE;
}

// The /DA's font NAME, resolved.  Three clauses, and every one of them is pinned by a named fixture over
// annotation-colours.pdf:
//
//   1  the name AS WRITTEN, when the platform has a font of that name: font-courier-7 (/Courier) answers
//      Courier, and font-full-oblique (/Helvetica-Oblique) and font-full-roman (/Times-Roman) answer
//      themselves - the abbreviations in clause 2 are a fallback and not the whole of the lookup.
//   2  an EXACT table of THREE abbreviations: Helv, HeBo and Cour.  That is the whole of what the host
//      resolves out of the standard fourteen's fourteen - font-abbrev-hebo answers Helvetica-Bold and
//      font-abbrev-cour answers Courier, while HeOb, HeBO, CoBo, CoOb, CBO, TiRo, TiBo, TiIt, TiBI, Symb
//      and ZaDb all answer Helvetica.  It is EXACT and case-SENSITIVE: font-case-upper (/HELV),
//      font-case-mixed (/Hebo) and the three prefixes font-prefix-h, -co and -ti (/H, /Co, /Ti) all
//      answer Helvetica.
//   3  anything else is HELVETICA - font-unknown and the eleven abbreviations of clause 2 - which is what
//      font-abbrev-helv and font-abbrev-heob and every /DA-less annotation of the fixture answer.
//
// NEVER nil, and the SIZE is a separate call so that the two are read from the /DA INDEPENDENTLY, which is
// what the fixtures measure: a name is no reason to lose a size.
static inline NSString *charon_annotation_font_name(CGPDFDictionaryRef annotation)
{
    bool present = NO;
    NSString *text = charon_annotation_da_text(annotation, &present);
    if (!present)
        return CHARON_ANNOTATION_FONT_DEFAULT_NAME;
    NSArray *tokens = charon_annotation_da_tokens(text);
    for (NSUInteger i = 0; i < tokens.count; i++) {
        if (!charon_annotation_da_is_operator(tokens[i], @"Tf") || i < 2)
            continue;
        NSString *nameToken = tokens[i - 2];
        if (![nameToken hasPrefix:@"/"])
            break;
        NSString *name = [nameToken substringFromIndex:1];
        CGFloat size = charon_annotation_font_size(annotation);
        // clause 1: the name AS WRITTEN, when the platform has a font of that name
        if ([UIFont fontWithName:name size:size] != nil)
            return name;
        // clause 2: the three abbreviations, matched EXACTLY
        if ([name isEqualToString:@"Helv"])
            return @"Helvetica";
        if ([name isEqualToString:@"HeBo"])
            return @"Helvetica-Bold";
        if ([name isEqualToString:@"Cour"])
            return @"Courier";
        // clause 3, and the no-/DA default
        break;
    }
    return CHARON_ANNOTATION_FONT_DEFAULT_NAME;
}
