#import "CharonPDFKit.h"

// PDFAnnotation over the release's own CGPDFDictionary.  Every answer is the annotation dictionary
// read back through CoreGraphics, plus the two rules the host's measurements established about it:
// a /Text annotation is shown as a 24x24 note icon, and /F's Print bit is what -shouldPrint reads.
//
// What is NOT here is as deliberate as what is.  A member whose host answer depends on something
// this dictionary does not carry is left unimplemented and its row says why, rather than answered
// with a constant that the next fixture would break.

// The size a /Text annotation answers on BOTH axes, measured on rects of 200x50 and 490x70, which both
// answer 24x24 - so it is a constant of the host's answer and not a function of the rectangle.  Named,
// and commented with what was NOT measured about it, so it is read as the measurement it is.
static const CGFloat kTextAnnotationSize = 24.0;

@interface PDFAnnotation ()
- (nullable CGPDFDictionaryRef)charon_CGPDFAnnotation;
@end

@implementation PDFAnnotation {
    CGPDFDictionaryRef _annotation;
    // Weak, as the header declares it (PDFAnnotation.h:141): the page answers nil once the document
    // has gone, and the annotation does not keep a document alive.
    __weak PDFPage *_page;
    NSString *_type;
    NSString *_contents;
    NSString *_userName;
    NSDate *_modificationDate;
    // The border, built once over the dictionary below, and REPLACEABLE by -setBorder:.  Held strongly:
    // a border is a value of this annotation, and a border handed to -setBorder: is held by reference,
    // so a change to it is visible through this annotation - which is what the host does.
    PDFBorder *_border;
    // The action and the destination, built once over the dictionary below.  Held strongly: both are
    // values of this annotation, and the destination holds its page weakly as its header declares.
    PDFAction *_action;
    PDFDestination *_destination;
    // Whether -setBorder: has been called at all, INCLUDING with nil.  It has to be its own flag and
    // not a test of _border: on a /Square, whose dictionary answers a border, the host answers nil after
    // -setBorder:nil and does NOT build one again - measured, annot-square answers border.set.nil = 1
    // where a rebuild would answer 0.  So a border that was set, to an object or to nil, is final.
    BOOL _borderSet;
}

// The port's own constructor, over the dictionary CoreGraphics already parsed out of the page's
// /Annots, and over the page it was found on.  Not Apple's initializer: -initWithBounds:forType:
// builds an annotation and writes it back into a document, which is the write path and not this.
- (instancetype)initWithCharonDictionary:(CGPDFDictionaryRef)annotation onPage:(PDFPage *)page
{
    self = [super init];
    if (self == nil)
        return nil;
    // The CGPDFDictionary belongs to the CGPDFDocument, which PDFDocument holds, and this annotation
    // is only ever reachable from a page of that document - so the owner is above us in the graph
    // and the borrowed pointer is safe for the lifetime of this object.
    _annotation = annotation;
    _page = page;
    return self;
}

- (CGPDFDictionaryRef)charon_CGPDFAnnotation
{
    return _annotation;
}

// -type, -contents, -userName and -modificationDate are memoised in their own ivars, but -bounds and
// -shouldPrint are COMPUTED from the dictionary on every call, and @dynamic is what says that.  Left
// to auto-synthesis, clang invents an ivar for each of them and then warns that the accessor never
// touches it - the same trap PDFPage11.m records for -label and -numberOfCharacters.
@dynamic bounds;
@dynamic shouldPrint;

// The other five ARE ivar-backed, and each is bound to its own ivar explicitly.  The gate compiles with
// -Werror=objc-missing-property-synthesis, which fires on a property that has a hand-written accessor and
// no explicit @synthesize or @dynamic - not because auto-synthesis is wrong, but because an accessor this
// port wrote by hand is a claim that the compiler should not second-guess silently.  PDFPage11.m does the
// same for -pageIndex, and the failure was found by the gate rather than by this port's own build, which
// does not pass that flag.
@synthesize type = _type;
@synthesize contents = _contents;
@synthesize userName = _userName;
@synthesize modificationDate = _modificationDate;
@synthesize page = _page;
@synthesize border = _border;
@synthesize action = _action;
@synthesize destination = _destination;

// The /SUBTYPE, as the name the header's PDFAnnotationSubtype is: "Text", "Link", "Square",
// "Highlight" - the dictionary's name object without its leading slash.
//
// This was recorded here first as five large negative integers, one per subtype, and that was wrong.
// The property is a NSString* const (PDFAnnotation.h:52) and the host answers an NSTaggedPointerString,
// which packs the characters INTO the pointer; reading it as a long therefore printed a tagged value
// rather than a type, and one that is stable across runs and distinct per subtype, which is exactly
// what made it look like a constant.  Measured with .agent-work/fin/typeof, built from the probe
// recorded in the facts file.
- (NSString *)type
{
    if (_type != nil)
        return _type;
    const char *name = NULL;
    if (!CGPDFDictionaryGetName(_annotation, "Subtype", &name) || name == NULL)
        return nil;
    // The name object carries no leading slash in the C string, so nothing is stripped here.
    _type = [[NSString alloc] initWithUTF8String:name];
    return _type;
}

// The /RECT, except for a /Text annotation, which is a fixed square in the rect's top-left corner.
//
// Measured on the host, on a rect the rule was not fitted to: /Text with /Rect [10 20 500 90] answers
// {{10, 66}, {24, 24}}, so x is the rect's own minX, y is its maxY minus the size, and the size is 24.
// Every other subtype answers the rectangle it was written with: /Link [0 0 600 700] answers
// {{0, 0}, {600, 700}}, /Square [40 40 240 140] answers {{40, 40}, {200, 100}}, and /Highlight
// [0 0 200 30] answers {{0, 0}, {200, 30}}.  The rule is keyed on the subtype name and not on the /F
// flags or on the presence of an appearance stream.
//
// The size is a CONSTANT and not something derived from the rect: the two /Text fixtures have rects of
// 200x50 and 490x70 and both answer 24x24, so nothing about the rectangle produces it.  What the 24 IS
// - a note icon, a default annotation size, a minimum - was NOT measured, and this port does not claim
// it: the number is the host's answer on two rects and the facts file records the measurement.  Only
// /Text was asked, so a subtype that is neither /Text nor one of the four above is untested here and
// answers its own /Rect by the branch below.
- (CGRect)bounds
{
    if (_type == nil)
        [self type];
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, "Rect", &object) || object == NULL)
        return CGRectZero;
    // A /Rect is an ARRAY of four numbers in the format and this release has no rect object type at
    // all - CGPDFObjectType runs Null, Boolean, Integer, Real, Name, String, Array, Dictionary,
    // Stream - so it is read the way it is stored, one element at a time.
    if (CGPDFObjectGetType(object) != kCGPDFObjectTypeArray)
        return CGRectZero;
    CGPDFArrayRef array = NULL;
    if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array) || array == NULL)
        return CGRectZero;
    CGFloat number[4] = {0, 0, 0, 0};
    for (size_t i = 0; i < 4; i++) {
        CGPDFObjectRef element = NULL;
        if (!CGPDFArrayGetObject(array, i, &element) || element == NULL)
            return CGRectZero;
        // A PDF number is an integer or a real, and the format allows either for a coordinate, so both
        // are read; a coordinate written as 10 is the same coordinate as one written as 10.0.
        if (CGPDFObjectGetType(element) == kCGPDFObjectTypeInteger) {
            long integer = 0;
            if (!CGPDFObjectGetValue(element, kCGPDFObjectTypeInteger, &integer))
                return CGRectZero;
            number[i] = (CGFloat)integer;
        } else if (CGPDFObjectGetValue(element, kCGPDFObjectTypeReal, &number[i]) == false) {
            return CGRectZero;
        }
    }
    CGRect rect = CGRectMake(number[0], number[1], number[2] - number[0], number[3] - number[1]);
    if ([_type isEqualToString:@"Text"])
        return CGRectMake(CGRectGetMinX(rect), CGRectGetMaxY(rect) - kTextAnnotationSize,
                         kTextAnnotationSize, kTextAnnotationSize);
    return rect;
}

// The /CONTENTS, the annotation's own text.  Nil for an annotation that names none, which is measured
// on /Link and /Square and is a nil here because the key is absent and not because a default applies.

// The value of a key that this release holds as a PDF STRING object - /Contents, /T and /M all are.
// There is no CGPDFDictionaryGetData in this SDK and no CGPDFDataProvider to read bytes through, so the
// object is fetched and asked for its type, and a string is copied out of it.  A key that is absent,
// and a key that holds some other kind of object, both answer nil - which is the host's answer too
// for an annotation that names none.
- (NSString *)charon_stringForKey:(const char *)key
{
    if (_annotation == NULL)
        return nil;
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, key, &object) || object == NULL)
        return nil;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    if (type != kCGPDFObjectTypeString)
        return nil;
    CGPDFStringRef string = NULL;
    if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeString, &string) || string == NULL)
        return nil;
    CFStringRef text = CGPDFStringCopyTextString(string);
    if (text == NULL)
        return nil;
    NSString *answer = (__bridge_transfer NSString *)text;
    return answer;
}

- (NSString *)contents
{
    if (_contents != nil)
        return _contents;
    _contents = [self charon_stringForKey:"Contents"];
    return _contents;
}

// The /T, the annotation's title in the format and its author in the host's own words: measured "the
// annotator" for a /T of (the annotator), and nil for an annotation that names none.
//
// A /Widget answers nil whatever it names, which the format does not predict and the port's first
// version got wrong: widget-names carries five /Widget annotations - one with /FT /Btn and a /T, one
// with a /T and no /FT, one with /FT /Tx and a /T, one with /FT /Tx and a /TU (the alternate field name
// of PDF 2.0 Table 227) and one with neither - and the host answers nil for all five, while the same
// /T on a /Square (widget-names' sixth annotation) answers "square T".  So the key is read for an
// annotation that is not a widget and the member answers nil for one that is.  /TU is measured
// separately so that "a widget reads a different key" is not left standing unmeasured: it answers nil
// as well.
- (NSString *)userName
{
    if (_userName != nil)
        return _userName;
    if (_type == nil)
        [self type];
    if ([_type isEqualToString:@"Widget"])
        return nil;
    _userName = [self charon_stringForKey:"T"];
    return _userName;
}

// The /M, the annotation's modification date, in the format's own D:YYYYMMDDHHmmSS spelling.
//
// This is the ONE date form measured - a /M of D:20260930000000 answers 2026-09-30 00:00:00 +0000 -
// and a partial date (D:2026, D:202609) and the trailing Z are NOT implemented, because nothing
// measured says what the host makes of them and a guessed UTC offset would be an answer, not a
// reading.  A partial date here answers nil, and the row says so.
- (NSDate *)modificationDate
{
    if (_modificationDate != nil)
        return _modificationDate;
    NSString *date = [self charon_stringForKey:"M"];
    if (date.length < 16 || ![date hasPrefix:@"D:"])
        return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    _modificationDate = [formatter dateFromString:[date substringFromIndex:2]];
    return _modificationDate;
}

// -shouldPrint reads /F's PRINT bit when /F is there, and answers YES when it is NOT there.  Both
// halves are measured, and the fixtures that separate them are: /F 0 answers NO, /F 2 - Hidden alone,
// Print still clear - answers NO, /F 4 answers YES, and a /Link with NO /F answers YES.  Without that
// last one the rule "mirrors the bit" and the rule "any nonzero /F" both fit the other three, and the
// port's own first version - which read a missing integer as zero - answered NO for a /Link the host
// prints.  The differential named the two fixtures and the default is in the code because of it.
//
// A /Popup is the exception and the port's first version did not have it: popup-flags carries four
// /Popup annotations with /F 4, /F 0, /F 2 and no /F at all, and the host answers shouldPrint=NO for
// ALL FOUR - so no reading of the Print bit fits, and "the bit, except never for a popup" is what the
// four fixtures between them establish.  The same fixture carries a /Square and a /Stamp with /F 4, and
// both answer YES, so the exception is the subtype and not the file.
//
// -shouldDisplay is NOT the companion of that bit and is not implemented: /F 2 answers YES for it, so
// the format's Hidden bit is not what it reads, and it answered YES for every /F measured here (0, 2,
// 4) across nine fixtures.  What turns it off is not identified, and a constant YES would be a
// hard-coded answer that one more fixture could break.  The row names this boundary.
- (BOOL)shouldPrint
{
    if (_annotation == NULL)
        return NO;
    if (_type == nil)
        [self type];
    if ([_type isEqualToString:@"Popup"])
        return NO;
    // An ABSENT /F answers YES, and the differential is what found that: the /Link fixtures write no
    // /F at all and the host answers shouldPrint=1 for them, so reading a missing integer as 0 and
    // testing its Print bit would answer NO where the host answers YES.  It is the same default
    // pattern as /C and /Border - a missing key is not always nil - so the key's PRESENCE is the
    // first question and its value the second.
    long flags = 0;
    if (!CGPDFDictionaryGetInteger(_annotation, "F", &flags))
        return YES;
    return (flags & 4) != 0;
}

// The PAGE the annotation was found on, which the host answers as an object for all nine fixtures.
// It is passed in rather than read from /P: the dictionary's /P is an indirect reference into the same
// document, and resolving it to a PDFPage would mean a page lookup by object number, which the port's
// page objects do not index by.  The answer is the page this annotation was created from, which is the
// same object the host hands back for a document that is still alive, and nil once that document has
// gone, which is what the weak reference is for.
- (PDFPage *)page
{
    return _page;
}

// -border, and nil is a MEASURED answer here and not a missing one.  Two rules, both fixed by
// fixtures whose dictionaries the harness writes, and the second is only visible because the first
// exists:
//
//   a /Border array or a /BS dictionary in the annotation  answers a border, for EVERY subtype.
//     border-plain (/Square with /Border [0 0 3]) answers W 3, and border-on-nontype puts a /Border
//     on /Highlight, /Text, /Link, /Stamp and /Popup - the five subtypes that answer nil without one -
//     and every one of them answers W 6.  bs-on-nontype does the same with a /BS instead, on a
//     /Highlight, and answers a dashed W 6.  So "the file names one" is the whole of it, and it does
//     not depend on the subtype.
//
//   NEITHER, and the subtype decides.  A DEFAULT border - solid, lineWidth 1 - is answered by the
//     geometry annotations /Circle, /FreeText, /Ink, /Line and /Square (noborder-circle,
//     noborder-freetext, noborder-ink, noborder-line-l, noborder-none, all answering W 1), which is
//     the set PDFAnnotation.h:165 names ("the geometry annotations (Circle, Ink, Line, Square)") with
//     /FreeText measured alongside them.  And a /Widget answers one exactly when its /MK names a
//     BORDER COLOUR the format allows: widget-bc writes four /Widget annotations whose /BC are, in
//     order, [0 0 0 1] (CMYK, four components), (a string), 0.5 (a bare number) and [0.25 0.5 0.75]
//     (RGB, three), and the host answers a border for the first and the last and nil for the middle
//     two.  With noborder-widget-bc ([0 0 1]), noborder-widget-bc-gray ([1]), noborder-widget-bc-empty
//     ([]) and mk-two ([0.25 0.5]) that is every component count the format defines - none, one, three
//     and four give a border - plus the two it does not.  The reading is the host's own: a /BC it
//     cannot make a colour of leaves no border colour, and it logs "Cannot create color from given
//     array of component count 2" while doing it.  A /BG, a BACKGROUND colour, is not a border colour:
//     noborder-widget-bg (/MK << /BG [1 0 0] >>) answers nil, and so do noborder-widget (no /MK),
//     noborder-widget-t (a /T) and noborder-widget-tm (a /Tm).  /MK is where PDF 1.7 Table 8.40 puts
//     /BC, and a widget with a border colour is a widget with a border to draw.
//
//   every other subtype answers nil with neither: /Highlight, /Link, /Popup, /Stamp, /Text,
//     /Underline and /StrikeOut (noborder-highlight, border-link, noborder-popup, noborder-stamp,
//     noborder-text, noborder-underline, noborder-strikeout).
//
// A /Border of the wrong type - neither array nor dictionary - takes the first branch, because the KEY
// is present; PDFBorder11.m then finds no array and answers the default width, which is what
// border-on-nontype's five subtypes answer for a /Border that is an array.
//

// -setBorder: stores the object BY REFERENCE, measured: -border answers the very object that was set,
// a change made to that object afterwards is visible through -border, and setting nil makes -border
// answer nil again.  So the annotation holds the object and does not copy it, and a border that was
// set is not rebuilt from the dictionary.
- (void)setBorder:(PDFBorder *)border
{
    _border = border;
    _borderSet = YES;
}

// -action is the /A dictionary, through PDFAction's own factory, and nil for an annotation that names
// none.  Three things are measured about it:
//
//   an action dictionary with NO /S answers nil (act-no-s), so the key's presence is not enough.
//
//   an /S the format does not name answers the BASE class with -type the name it carried (act-unknown-s,
//   "Bogus") - not nil, and not a subclass.
//
//   an /Named action whose /N is outside the eight the host builds answers NO ACTION AT ALL
//   (act-named-all: None, PreviousPage, ZoomIn, ZoomOut and a name the format does not list).
//
// And a BARE /Dest produces an action: ann-dest-array and ann-dest-named carry a /Dest and no /A, and
// the host answers a PDFActionGoTo for both - the format's own rule that a /Dest without /A is a /GoTo
// to that destination.  Where both are written the /A one is the action (ann-dest-and-a) and the /Dest
// one is the destination.
- (PDFAction *)action
{
    if (_action != nil)
        return _action;
    if (_annotation == NULL)
        return nil;
    CGPDFDictionaryRef action = NULL;
    if (CGPDFDictionaryGetDictionary(_annotation, "A", &action) && action != NULL) {
        _action = [PDFAction charon_actionWithDictionary:action inDocument:[self charon_document]];
        return _action;
    }
    if (![self charon_hasDestination])
        return nil;
    // a BARE /Dest stands for a /GoTo to itself - the format's own rule, and measured: ann-dest-array
    // and ann-dest-named carry a /Dest and no /A and the host answers a PDFActionGoTo for both.  It is
    // built through the header's own -initWithDestination: over the very destination object this
    // annotation answers, so the action's destination and -destination are one object and not two reads
    // of the same array.
    // The destination is read through the PRIVATE builder and not through -destination, because
    // -destination reads the ACTION's destination: going through it here is infinite recursion, and it
    // showed up as a SIGSEGV on the first run rather than as a wrong answer.
    PDFDestination *destination = [self charon_destinationFromDest];
    if (destination == nil)
        return nil;
    _action = [[PDFActionGoTo alloc] initWithDestination:destination];
    return _action;
}

// The /Dest of this annotation's own dictionary, over the three spellings, and NOT through -destination.
// nil for a /Dest that is a dictionary, which is measured: the host reads no destination from that
// spelling (ann-dest-dict), and it reads no action from it either.
- (PDFDestination *)charon_destinationFromDest
{
    if (_destination != nil)
        return _destination;
    if (_annotation == NULL)
        return nil;
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, "Dest", &object) || object == NULL)
        return nil;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    if (type == kCGPDFObjectTypeArray) {
        CGPDFArrayRef array = NULL;
        if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array) || array == NULL)
            return nil;
        _destination = [[PDFDestination alloc] initWithCharonDestinationArray:array
                                                                    inDocument:[self charon_document]];
        return _destination;
    }
    if (type == kCGPDFObjectTypeName || type == kCGPDFObjectTypeString) {
        // the NAMED spelling.  A destination IS built and its page is nil - measured on both /Dests
        // spellings, ann-dest-named and ann-dest-named-dict - and nothing about a name says where, so
        // the point and the zoom stay unspecified.  The port does not resolve the name: the host does not
        // either on these fixtures, and a name it DID resolve would be a second answer nothing measured.
        _destination = [[PDFDestination alloc] initWithCharonDestinationArray:NULL
                                                                    inDocument:[self charon_document]];
        return _destination;
    }
    return nil;
}

// -destination is the DESTINATION OF THE ACTION, and not the /Dest read on its own.  That is measured,
// and it is the opposite of what the first version of this did: ann-dest-and-a carries BOTH a /Dest
// whose /XYZ names (1, 2) with zoom 3 and an /A whose /D is a /Fit, and the host answers point
// UNSPECIFIED - the /A's - where a read of the /Dest would have answered 1, 2 and 3.
//
// So -destination is one line over -action: the destination of a /GoTo, and nil for every other action.
// That is also why a bare /Dest produces one: the synthesised GoTo carries it (ann-dest-array answers
// point 11, 22 and zoom 0.5 off a /Dest with no /A at all), and why a NAMED /Dest answers a destination
// whose page is nil rather than no destination.
//
// And the DICTIONARY spelling of a /Dest answers NIL for both members (ann-dest-dict): the host reads no
// destination from it, and -destination follows because no action is built from one either.
- (PDFDestination *)destination
{
    PDFAction *action = [self action];
    if (![action isKindOfClass:[PDFActionGoTo class]])
        return nil;
    return [(PDFActionGoTo *)action destination];
}

// Whether the annotation names a /Dest at all, which is the whole of the difference between an /A that
// says where to go and a /Dest that does.  A /Dest the host does not READ still counts: ann-dest-dict
// carries the dictionary spelling and the host answers no destination for it, but it is also the fixture
// that shows a bare /Dest is what produces the synthesised action.
- (BOOL)charon_hasDestination
{
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, "Dest", &object) || object == NULL)
        return NO;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    return type == kCGPDFObjectTypeArray || type == kCGPDFObjectTypeName || type == kCGPDFObjectTypeString
           || type == kCGPDFObjectTypeDictionary;
}

// The document this annotation's page belongs to, which is what a destination has to be resolved
// against - and it is nil once that document has gone, which is the weak page reference at work.
- (PDFDocument *)charon_document
{
    return [_page document];
}
- (PDFBorder *)border
{
    if (_borderSet)
        return _border;
    if (_annotation == NULL)
        return nil;
    if (_border != nil)
        return _border;
    // the subtype, read once: -type is the annotation's own /Subtype as a string
    NSString *type = [self type];
    BOOL named = NO;
    CGPDFObjectRef object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "Border", &object) && object != NULL)
        named = YES;
    object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "BS", &object) && object != NULL)
        named = YES;
    if (!named) {
        // the default cases, and nothing else answers a border without the file naming one
        if ([type isEqualToString:@"Square"] || [type isEqualToString:@"Circle"]
            || [type isEqualToString:@"Ink"] || [type isEqualToString:@"Line"]
            || [type isEqualToString:@"FreeText"]) {
            named = YES;
        } else if ([type isEqualToString:@"Widget"]) {
            // a /Widget with a border COLOUR, which is /MK's /BC - and only a colour the format's
            // four component counts describe, which is the whole of the difference between widget-bc
            // and mk-two.
            CGPDFObjectRef mark = NULL;
            if (CGPDFDictionaryGetObject(_annotation, "MK", &mark) && mark != NULL
                && CGPDFObjectGetType(mark) == kCGPDFObjectTypeDictionary) {
                CGPDFDictionaryRef appearance = NULL;
                if (CGPDFObjectGetValue(mark, kCGPDFObjectTypeDictionary, &appearance)
                    && appearance != NULL) {
                    CGPDFArrayRef colour = NULL;
                    if (CGPDFDictionaryGetArray(appearance, "BC", &colour) && colour != NULL) {
                        size_t components = CGPDFArrayGetCount(colour);
                        // PDF 1.7 Table 8.40: none of them is no colour, one is gray, three is RGB and
                        // four is CMYK.  Anything else is not a colour, and a widget without a border
                        // colour has no border to draw - measured on all four counts and on the two
                        // shapes that are not arrays at all.
                        if (components == 0 || components == 1 || components == 3 || components == 4)
                            named = YES;
                    }
                }
            }
        }
    }
    if (!named)
        return nil;
    _border = [[PDFBorder alloc] initWithCharonAnnotationDictionary:_annotation];
    return _border;
}

// YES when the annotation's /AP dictionary carries an /N appearance STREAM. The /N of a plain annotation is a
// stream, not a dictionary, which is why this reads it with CGPDFDictionaryGetStream and not the dictionary
// reader the button states use. A /AP with only a /D (down) appearance answers NO, measured by
// tests/backports/host/pdfkit-annotations (annot-ap-down.pdf, annot-ap.pdf).
- (BOOL)hasAppearanceStream
{
    if (_annotation == NULL)
        return NO;
    CGPDFDictionaryRef appearance = NULL;
    if (!CGPDFDictionaryGetDictionary(_annotation, "AP", &appearance) || appearance == NULL)
        return NO;
    CGPDFStreamRef normal = NULL;
    return CGPDFDictionaryGetStream(appearance, "N", &normal) && normal != NULL;
}

// The /Open flag, which the host answers the same way on every subtype measured (Text, Square and Link
// with /Open true answer YES; a key that is absent or false answers NO). It is a boolean in the format's own
// annotation dictionary and carries no default of its own.
- (BOOL)open
{
    if (_annotation == NULL)
        return NO;
    CGPDFBoolean open = NO;
    return CGPDFDictionaryGetBoolean(_annotation, "Open", &open) && open;
}

// The URL of a URI action, and of a Launch (the file it names): a /Link whose /A is /URI answers the /URI
// (annot-uri.pdf, annot-link-h.pdf), and a /Link whose /A is /Launch answers the file the /F names, resolved
// against the document's directory (annot-launch.pdf). A /Link with a bare /Dest (a GoTo), a remote GoTo
// (annot-gotor.pdf), or no /A answers nil. The URL is the one the action already holds.
- (nullable NSURL *)URL
{
    PDFAction *action = self.action;
    if (![action isKindOfClass:[PDFActionURL class]])
        return nil;
    return ((PDFActionURL *)action).URL;
}

// Members that are measured and NOT implemented here, each with the boundary that keeps it out.  They
// are listed so the omission is a decision on the record and not an oversight, and their rows carry
// the same reasons.
//
//   -color             reads /C when written (measured: 1 0 0 -> "Device RGB colorspace 1 0 0 1"), but
//                      the ABSENT answer is subtype-dependent: /Highlight answers a default sRGB
//                      yellow (0.980392 0.803922 0.352941 1) where /Link and /Square answer nil.  A
//                      plain read of /C would answer nil for a highlight the host paints.
//   -shouldDisplay     measured YES for /F 0, 2 and 4, and not the Hidden bit; see above.
//   -isHighlighted     measured NO on all nine fixtures, and on a /Link and a /Highlight carrying /H /I or
//                      /H /N (annot-link-h.pdf, annot-link-h-n.pdf, annot-highlight.pdf): /H is not what
//                      answers it, so the key that changes it is not identified.
//   -popup, -action    PDFAnnotationPopup and PDFAction are classes of their own; nothing measured.
//   -border            NOT here any more: it is implemented below, over PDFBorder11.m, because the
//                      subtype-dependent absent answer it was waiting for is measured - see -border.
//   -annotationKeyValues and the five -setValue:/-valueForAnnotationKey: members  the annotation-key
//                      API is its own family, and -setValue: is a WRITE path this port does not have.
//   -drawWithBox:inContext:  draws, and a windowless host answers nothing to compare against.
//   -initWithBounds:forType:withProperties:, -initWithDictionary:forPage:, -initWithBounds:  write a
//                      new annotation into a document; the port reads annotations, and a constructor
//                      that cannot be read back would be untestable.
//   -toolTip, -mouseUpAction, -removeAllAppearanceStreams, -drawWithBox:  deprecated members of the
//                      same unwritten or undrawn surface.

@end

// The nine /Ff bit members live in their own CATEGORY IMPLEMENTATION because that is where their
// properties are declared: a property declared in a category cannot be implemented in the class's own
// @implementation, and clang says so.  -charon_flags is the one thing they share, so it is declared in
// CharonPDFKit.h's CharonInternals category and defined here with them.
//
@implementation PDFAnnotation (PDFAnnotationUtilitiesSubset)

// Each is COMPUTED from the /Ff word on every call, so @dynamic says "not an ivar" and NOTHING else - a
// @dynamic property with no body raises at run time, which is what the first version of PDFPage's -label
// did and what the harness's crash was.
@dynamic readOnly;
@dynamic multiline;
@dynamic isPasswordField;
@dynamic comb;
@dynamic allowsToggleToOff;
@dynamic radiosInUnison;
@dynamic listChoice;
@dynamic widgetControlType;
@dynamic activatableTextField;
@dynamic fieldName;
@dynamic buttonWidgetStateString;
@dynamic buttonWidgetState;

// The /AP /N walk's context, and the applier itself.  C rather than a block because the release's block
// form of this call is iOS 12 and neither band carries it - see the note at the call.
typedef struct { NSString *onState; } CharonOnState;

// The release's applier function returns VOID - only the iOS 12 block form returns bool - so there is
// no early exit, and the loop stops mattering once a name is found because the guard below does.
static void charonTakeOnState(const char *key, CGPDFObjectRef value, void *info)
{
    CharonOnState *state = (CharonOnState *)info;
    if (key == NULL || state == NULL || state->onState != nil)
        return;                     // one is enough: the first non-/Off key names the on state
    if (strcmp(key, "Off") == 0)
        return;
    state->onState = [[NSString alloc] initWithUTF8String:key];
}

// The NAME of this widget's on-state, which is the /AP /N key that is not /Off and "Yes" when there is
// no /AP at all.
//
// Eighteen fixtures that carry no /AP answer "Yes" - every /Btn and every /Tx shape in the widget
// fixtures, whatever /AS and /V say - so "Yes" is the DEFAULT and not the answer.  button-ap-states.pdf
// has five annotations whose /AP /N is keyed on /On, /Yes and /Marked, and it answers those names:
//
//   /AS /Off, /N keyed /On      -> "On"
//   /AS /On,  /N keyed /On      -> "On"
//   /AS /Yes, /N keyed /Yes     -> "Yes"
//   /AS /Yes, /N keyed /Marked  -> "Marked"     <- and its STATE is 0, because /AS does not name it
//   /AS /Marked, /N keyed /Marked -> "Marked"  <- and its STATE is 1
//
// So the name is read out of the /AP's own /N keys - the one that is not /Off - and not from /AS and not
// from /V.  Two of the five are what make it a rule rather than an echo of /AS: an /N keyed /Marked gives
// "Marked" whatever /AS says.
- (NSString *)buttonWidgetStateString
{
    if (_annotation == NULL)
        return @"Yes";
    CGPDFDictionaryRef appearance = NULL;
    if (!CGPDFDictionaryGetDictionary(_annotation, "AP", &appearance) || appearance == NULL)
        return @"Yes";
    CGPDFDictionaryRef normal = NULL;
    if (!CGPDFDictionaryGetDictionary(appearance, "N", &normal) || normal == NULL)
        return @"Yes";
    // The /N keys are walked with CGPDFDictionaryApplyFunction and NOT with
    // CGPDFDictionaryApplyBlock: the block form is CG_AVAILABLE_STARTING(10.14, 12.0) and this port's
    // bands are 6.1.3 and 4.3, so a block here would not link.  The function form is
    // CG_AVAILABLE_STARTING(10.3, 2.0) and carries its context in an `info` pointer.
    CharonOnState state = {nil};
    CGPDFDictionaryApplyFunction(normal, charonTakeOnState, &state);
    return state.onState ?: @"Yes";
}

// Whether this widget is ON.  Three clauses, and the 31 measured shapes they predict are:
//
//   1  /AS names the on-state, OR /V names it.  Each half is needed and each has a fixture that says so:
//      /AS /Yes with no /V is 1 (button-as-alone), and /V /Yes with no /AS is ALSO 1 (button-v-only), and
//      a reading in which only /AS counts is refuted by that second fixture.
//
//   2  BOTH name a state that is not /Off.  Needed for the two shapes where neither names the on-state
//      and the answer is still 1: /AS /On with /V /On (button-as-and-v) and /AS /On with /V /Yes
//      (button-asoff-von).  The coordinator's hypothesis - "/V names the SAME state /AS names" - is
//      REFUTED by the second of those, where /AS names /On and /V names /Yes, and the two do not match.
//      A /V of /Off does not count, which button-asoff-von's /AS /On with /V /Off (0) fixes.
//
//   3  the widget must be a BUTTON, and the /FT must be ON THE WIDGET.  Every /Tx answers -1 whatever it
//      carries (text-as, four states), and so do all six button-merged-* shapes, whose /Btn FIELD carries
//      the /FT while the widget reaches it through /Parent.  So the field type is not inherited.
//
// and the on-state itself is -buttonWidgetStateString's answer, which is the /AP /N key that is not /Off
// and "/Yes" when there is no /AP.
- (NSInteger)buttonWidgetState
{
    if (_annotation == NULL)
        return -1;
    const char *fieldType = NULL;
    if (!CGPDFDictionaryGetName(_annotation, "FT", &fieldType) || fieldType == NULL)
        return -1;
    if (strcmp(fieldType, "Btn") != 0)
        return -1;
    NSString *onState = [self buttonWidgetStateString];
    NSString *appearance = nil;
    NSString *value = nil;
    CGPDFObjectRef object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "AS", &object) && object != NULL
        && CGPDFObjectGetType(object) == kCGPDFObjectTypeName) {
        const char *name = NULL;
        if (CGPDFObjectGetValue(object, kCGPDFObjectTypeName, &name) && name != NULL)
            appearance = [[NSString alloc] initWithUTF8String:name];
    }
    object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "V", &object) && object != NULL
        && CGPDFObjectGetType(object) == kCGPDFObjectTypeName) {
        const char *name = NULL;
        if (CGPDFObjectGetValue(object, kCGPDFObjectTypeName, &name) && name != NULL)
            value = [[NSString alloc] initWithUTF8String:name];
    }
    if (appearance != nil && [appearance isEqualToString:onState])
        return 1;
    if (value != nil && [value isEqualToString:onState])
        return 1;
    // NAMES CARRY NO LEADING SLASH: CGPDFDictionaryGetName strips it and CGPDFDictionaryApplyFunction's
    // key has none either, which is why -buttonWidgetStateString answers "Yes" and "Marked" and not
    // "/Yes".  The first version compared against @"/Off" and so never matched it, and the three shapes
    // where one of the two keys is /Off came out 1 where the host answers 0 - the differential found all
    // three at once.
    if (appearance != nil && ![appearance isEqualToString:@"Off"] && value != nil
        && ![value isEqualToString:@"Off"])
        return 1;
    return 0;
}

// The dictionary the harness reads to decide which keys are comparable - see CharonPDFKit.h.
- (CGPDFDictionaryRef)charon_CGPDFDictionary
{
    return _annotation;
}

// The /Ff FLAG WORD, or 0 when the annotation names none.  Table 8.39 makes it an integer, and
// CGPDFDictionaryGetInteger refuses anything else, so a /Ff that is a string or an array leaves every
// bit clear - which is the measured answer for an annotation that carries no /Ff at all
// (widget-noflags.pdf) and the answer the port gives for a /Ff of the wrong type.
- (long)charon_flags
{
    long flags = 0;
    if (_annotation == NULL)
        return 0;
    if (!CGPDFDictionaryGetInteger(_annotation, "Ff", &flags))
        return 0;
    return flags;
}

// The PDFAnnotation (PDFAnnotationUtilities) members that are /Ff bit reads.  Each names the fixture
// that fixes it: widget-flags.pdf carries ONE ANNOTATION PER BIT with only that bit set, and
// widget-allflags.pdf carries every bit at once, so a member is measured both against its own bit alone
// and against the lot.
//
// Three of them are the NEGATION of a bit, which is measured and not a convenience: bit 15 alone answers
// allowsToggleToOff NO and every other single-bit fixture answers YES; bit 18 alone answers listChoice NO
// and the rest YES.
//
// And radiosInUnison is NOT bit 16, whose name in Table 8.39 is RadioInUnison: bit 16 alone answers NO
// and bit 26 alone answers YES, so it is bit 26 - RichText - that this member reads.
- (BOOL)isReadOnly
{
    return ([self charon_flags] & (1 << 0)) != 0;
}

- (BOOL)isMultiline
{
    return ([self charon_flags] & (1 << 12)) != 0;
}

- (BOOL)isPasswordField
{
    return ([self charon_flags] & (1 << 13)) != 0;
}

- (BOOL)hasComb
{
    return ([self charon_flags] & (1 << 24)) != 0;
}

- (BOOL)allowsToggleToOff
{
    // bit 15 NoToggleToOff is the negation, AND bit 17 Pushbutton clears it as well - measured on the
    // two single-bit fixtures that each answer NO while the other eleven answer YES.  So this is
    // "neither bit 15 nor bit 17", which is what the fixtures say and not a reading of the table.
    return ([self charon_flags] & ((1 << 14) | (1 << 16))) == 0;
}

- (BOOL)radiosInUnison
{
    return ([self charon_flags] & (1 << 25)) != 0;
}

- (BOOL)isListChoice
{
    return ([self charon_flags] & (1 << 17)) == 0;
}

- (PDFWidgetControlType)widgetControlType
{
    // NOT a two-bit field read as a shift.  Measured on four fixtures: neither bit answers 2
    // (CheckBox), bit 17 alone answers 0 (PushButton), bit 16 alone answers 1 (RadioButton), and both at
    // once - widget-allflags - answers 1.  So it is a PRIORITY: bit 16 wins, else bit 17, else the
    // CheckBox default.  A shift of the pair by 16 would answer 0, 1, 2 and 3 for those four, so the
    // default of 2 is what told the two rules apart.
    long flags = [self charon_flags];
    if ((flags & (1 << 15)) != 0)
        return kPDFWidgetRadioButtonControl;
    if ((flags & (1 << 16)) != 0)
        return kPDFWidgetPushButtonControl;
    return kPDFWidgetCheckBoxControl;
}

// The /T of the MERGED FIELD AND WIDGET, which is what -fieldName reads when the pair names anything,
// and nil when neither does.  Four fixtures, and the shape that makes this a rule and not a guess:
//
//   widget-t-literal.pdf   /T (the field) on the widget            -> "the field"
//   widget-t-empty.pdf     /T ()                                    -> ""   the empty string, read
//   widget-t-name.pdf      /T /TheField, a NAME not a string        -> nil  NOT read, and the member
//                                                                          falls back to its own name
//   widget-t-merged.pdf    the widget's /Parent is a FIELD carrying /T (parent field)
//                                                                  -> "parent field"
//   widget-t-mergedname.pdf the same, and the widget carries /T (child too) too
//                                                                  -> "parent field.child too"
//
// So a widget's own /T is APPENDED to the parent's with a DOT between them, rather than overriding it,
// and both are read as PDF STRINGS only.  That is measured; what the host does when NEITHER names anything
// is not - see -fieldName's row.
- (NSString *)fieldName
{
    if (_annotation == NULL)
        return nil;
    // the parent's /T first, then the widget's own, joined with a dot when both are there
    NSString *own = nil;
    CGPDFObjectRef title = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "T", &title) && title != NULL
        && CGPDFObjectGetType(title) == kCGPDFObjectTypeString) {
        CGPDFStringRef string = NULL;
        if (CGPDFObjectGetValue(title, kCGPDFObjectTypeString, &string) && string != NULL) {
            CFStringRef text = CGPDFStringCopyTextString(string);
            if (text != NULL)
                own = (__bridge_transfer NSString *)text;
        }
    }
    // and the parent's, which is where a field written apart from its widget keeps it.  BOTH are joined
    // with a dot when both are there - widget-t-mergedname.pdf answers "parent field.child too" - so
    // neither half may be returned early.  The first version returned the widget's own as soon as it had
    // one and answered "child too" where the host answers both, and the differential found it.
    NSString *inherited = nil;
    CGPDFDictionaryRef parent = NULL;
    if (CGPDFDictionaryGetDictionary(_annotation, "Parent", &parent) && parent != NULL) {
        CGPDFObjectRef parentTitle = NULL;
        if (CGPDFDictionaryGetObject(parent, "T", &parentTitle) && parentTitle != NULL
            && CGPDFObjectGetType(parentTitle) == kCGPDFObjectTypeString) {
            CGPDFStringRef string = NULL;
            if (CGPDFObjectGetValue(parentTitle, kCGPDFObjectTypeString, &string) && string != NULL) {
                CFStringRef text = CGPDFStringCopyTextString(string);
                if (text != NULL)
                    inherited = (__bridge_transfer NSString *)text;
            }
        }
    }
    if (inherited == nil)
        return own;
    if (own == nil)
        return inherited;
    return [NSString stringWithFormat:@"%@.%@", inherited, own];
}

- (BOOL)isActivatableTextField
{
    // NOT a bit and NOT just the absence of bit 1: it is a TEXT field that is not read-only.  Measured on
    // widget-fttx1 (/Tx answers YES), widget-ftbtn0 (/Btn NO), widget-ftsig3 (/Sig NO), widget-ftch4 (a
    // /Ch with an /Opt NO), the thirteen /Tx fixtures of widget-flags.pdf - of which the bit-1 one
    // answers NO and the other twelve YES - and every /Link in the harness, which has no /FT and answers
    // NO.  So the field type has to be /Tx as well as the flag being clear.
    const char *fieldType = NULL;
    if (_annotation == NULL || !CGPDFDictionaryGetName(_annotation, "FT", &fieldType)
        || fieldType == NULL || strcmp(fieldType, "Tx") != 0)
        return NO;
    return ![self isReadOnly];
}

@end
