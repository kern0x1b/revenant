#import "CharonPDFKit.h"

// PDFDestination over a /D - the destination array of PDF 1.7 Table 8.42 - which is
// [pageRef /XYZ left top zoom] or one of the six fit forms beside a page reference.  Both spellings the
// format gives a /D are handled by the same reader, because a /D is an array in all of them.
//
// Every rule below is measured on the host over fixtures whose dictionaries the harness writes, and each
// names the fixture that fixes it.

// The seven names Table 8.42 gives a destination, and the two the port has to refuse.  A /D whose second
// element is not one of these answers NO DESTINATION AT ALL: /Bogus (act-goto-unknown-name) and /Zoom
// (act-goto-wrong-name, a PDF 1.0 name the format dropped) both answer nil, and so does a /D that is not
// an array and not a name - a bare 3 (act-goto-shapes) and a dictionary (act-goto-dict) both answer nil.
// So the name is checked, not merely present.
static BOOL charonDestinationNameIsKnown(const char *name)
{
    if (name == NULL)
        return NO;
    return strcmp(name, "XYZ") == 0 || strcmp(name, "Fit") == 0 || strcmp(name, "FitH") == 0
           || strcmp(name, "FitV") == 0 || strcmp(name, "FitB") == 0 || strcmp(name, "FitBH") == 0
           || strcmp(name, "FitBV") == 0;
}

// The number at one position of the /D, or the unspecified sentinel when it is not there.  The format
// allows an integer or a real for any of them, so both are read: a left written as 5 and one written as
// 5.0 are the same left.
//
// The ZOOM is the one member for which a zero is not a value, and that is measured both ways rather than
// assumed: /XYZ 0 0 0 answers point 0,0 and zoom UNSPECIFIED, while /XYZ -1 -2 -3 answers point -1,-2
// and zoom -3.  So the point reads a zero and the zoom does not.
static CGFloat charonDestinationNumber(CGPDFArrayRef destination, size_t index)
{
    CGPDFReal number = 0;
    if (!CGPDFArrayGetNumber(destination, index, &number))
        return kPDFDestinationUnspecifiedValue;
    return (CGFloat)number;
}

// One -Wobjc-designated-initializers pair, and it is Apple's own shape here too.  The iOS 16.0
// arm64e cache gives PDFDestination its OWN -init (own -init: 1) while PDFDestination.h
// declares none - it declares only the designated -initWithPage:atPoint: at :29 - which makes
// an implementation's -init a convenience initializer and clang rejects one that calls
// [super init].  So this is the same arrangement as PDFAction11.m's four and as
// PKPaymentRequestStatus11.m's four: the method is implemented, because the cache says the class
// has one, and the diagnostic about its shape is scoped away rather than left standing.  Read
// with the tree's own census over that cache: .agent-work/v-pdfkit/own-inits.lua, through
// coordination/heavy.sh.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFDestination {
    // Weak, as PDFDestination.h declares it: a destination does not keep a page alive, and answers nil
    // once the page's document has gone.
    __weak PDFPage *_page;
    CGPoint _point;
    CGFloat _zoom;
}

@synthesize page = _page;
@synthesize point = _point;
@synthesize zoom = _zoom;

// -initWithPage:atPoint: is the header's own designated initializer (PDFDestination.h:22) and it is
// implemented because without it the class cannot be built at all, which is the question the coordinator
// asked about PDFBorder and answered by measurement.  What the host answers is measured: the page is
// kept, the point is the one it was given, and the ZOOM is unspecified - so a destination made in code
// has no scale until one is set.
// -initWithPage:atPoint: is the header's own designated initializer (PDFDestination.h:22) and it is
// implemented because without it the class cannot be built at all, which is the question the coordinator
// asked about PDFBorder and answered by measurement.  What the host answers is measured: the page is
// kept, the point is the one it was given, and the ZOOM is unspecified - so a destination made in code
// has no scale until one is set.
//
// AND a NIL PAGE ANSWERS NO OBJECT AT ALL.  That was found by the harness rather than asked for: written
// against a nil page first, [[PDFDestination alloc] initWithPage:nil atPoint:(3,4)] answers nil on the
// host, so every read off it answers nil or zero and [made copy] answers nil too - which is what the
// copy block reported before it was given a real page, and the reason this rule is in the file at all.
// The SDK does not say why; what is measured is that a caller who passes no page gets nothing back.
- (instancetype)initWithPage:(PDFPage *)page atPoint:(CGPoint)point
{
    if (page == nil)
        return nil;
    self = [super init];
    if (self == nil)
        return nil;
    _page = page;
    _point = point;
    _zoom = kPDFDestinationUnspecifiedValue;
    return self;
}

// -init is not a designated initializer in the header, and the host's own plain -init answers an OBJECT
// with no page, an unspecified point and an unspecified zoom - so it cannot be reached through
// -initWithPage:atPoint:, which answers nil for a nil page, and sets the members itself.
- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _point = CGPointMake(kPDFDestinationUnspecifiedValue, kPDFDestinationUnspecifiedValue);
    _zoom = kPDFDestinationUnspecifiedValue;
    return self;
}

// -copyWithZone: is the NSCopying conformance CharonPDFKit.h declares.  Measured: the copy is a NEW
// object of the same class, its PAGE IS THE SAME OBJECT - a destination names a page and does not own it,
// and the page is weak here exactly as PDFDestination.h:19 declares - and its state is independent, so a
// zoom set on the copy leaves the original alone.  The initializer is the header's own, so the copy is
// built through it and the zoom is then set; nothing else needs copying.
- (id)copyWithZone:(NSZone *)zone
{
    // NOT through -initWithPage:atPoint:, which answers nil for a nil page: a destination with no page
    // is a real object here - a named destination and a plain -init both make one - and it has to be
    // copyable.  Whether the host's copy of such a destination answers an object or nil is measured, in
    // the harness's own copy.nopage.* keys, rather than assumed.
    PDFDestination *copy = [[[self class] alloc] init];
    copy->_page = _page;
    copy->_point = _point;
    copy->_zoom = _zoom;
    return copy;
}

// The same reader over the destination ARRAY itself, which is what an action's /D holds under a key and
// what an annotation's /Dest holds directly.  A NULL array is the case the measurement calls for twice:
// a named destination answers a destination with no page, and this is how one is built.
//
//   the FIRST element must resolve to a page.  CGPDFArrayGetDictionary follows the indirect reference,
//   so the pointer that comes back is the page's own dictionary, and the port matches it against
//   CGPDFPageGetDictionary over the document's pages - measured: a /D naming the second page of a
//   two-page document answers that page, and a /D naming object 99, which is not a page, answers nil
//   (act-goto-bad-page, act-goto-badpage-xyz) while still answering the /XYZ numbers.  With no array at
//   all there is no first element and the page is nil.
//
//   the SECOND element must be a name the format lists - see charonDestinationNameIsKnown - and /XYZ
//   alone is read: element 2 is x, element 3 is y and element 4 is the zoom, each independently.  /XYZ 5 6
//   answers (5, 6) and an unspecified zoom, /XYZ 7 answers (7, unspecified), /XYZ with no numbers answers
//   an unspecified point and zoom, and /Bogus or /Zoom answers NO DESTINATION - which is why the reader
//   returns the object with nothing in it rather than a half-read one.
//
//   every OTHER fit name - /Fit, /FitB, /FitH, /FitBH, /FitBV - answers an unspecified point AND an
//   unspecified zoom, measured one fixture each, even though /FitH and /FitBH and /FitBV carry numbers
//   of their own: those numbers are the box to fit, not a position, and none of them is read.
- (instancetype)initWithCharonDestinationArray:(CGPDFArrayRef)destination
                                    inDocument:(PDFDocument *)document
{
    // A NULL array is the NAMED spelling and answers an OBJECT with nothing in it - measured, a named
    // destination produces a PDFDestination whose page is nil.  Every refusal below answers NO object at
    // all, which is a different answer, and that is why this case is first and alone.
    if (destination == NULL)
        return [self init];

    // The NAME decides whether there is a destination at all, and both halves are measured:
    //
    //   the SECOND element must be one the format lists.  act-goto-shapes' [3 0 R] - one element and no
    //   name at all - and [3 0 R /Zoom 3] answer NO destination on the host, and so does /Bogus.
    //
    //   the FIRST element must not be a NAME.  [/XYZ 1 2 3] answers NO destination on the host with a
    //   perfectly good /XYZ behind it, and this SDK reports that first element as a name where every
    //   page reference is reported as a dictionary - measured over every act-goto fixture, and it is
    //   what tells "no page named" from "no page wanted".
    const char *name = NULL;
    if (!CGPDFArrayGetName(destination, 1, &name) || !charonDestinationNameIsKnown(name))
        return nil;
    const char *firstName = NULL;
    if (CGPDFArrayGetName(destination, 0, &firstName))
        return nil;

    self = [self init];
    if (self == nil)
        return nil;

    // The page and the numbers are read INDEPENDENTLY, and that is measured too: act-goto-badpage-xyz's
    // /D is [99 0 R /XYZ 1 2 3] where object 99 is not a page, and the host answers page nil AND point
    // 1,2 with zoom 3.  So a first element that resolves to no page does not stop the reader, and an
    // earlier version that returned there answered the unspecified sentinel for all three.
    CGPDFDictionaryRef referenced = NULL;
    if (CGPDFArrayGetDictionary(destination, 0, &referenced) && referenced != NULL)
        _page = [self charon_pageForDictionary:referenced inDocument:document];

    if (strcmp(name, "XYZ") != 0)
        return self;                     // every other fit name answers an unspecified position
    _point = CGPointMake(charonDestinationNumber(destination, 2),
                         charonDestinationNumber(destination, 3));
    CGFloat zoom = charonDestinationNumber(destination, 4);
    // the zero, measured on act-goto-shapes' /XYZ 0 0 0, which answers an unspecified zoom while its
    // point answers 0,0 - and measured against /XYZ -1 -2 -3, whose zoom answers -3
    _zoom = zoom != 0 ? zoom : kPDFDestinationUnspecifiedValue;
    return self;
}

// The page whose own dictionary is this one, over the document's pages in order.  There is no object
// number in this SDK's C API, so identity of the resolved page dictionary is the mapping, and it was
// measured to hold before it was relied on: element 0 of a /D naming object 4 resolves to a pointer
// equal to CGPDFPageGetDictionary of page 2 and not of page 1.
- (PDFPage *)charon_pageForDictionary:(CGPDFDictionaryRef)dictionary inDocument:(PDFDocument *)document
{
    if (document == nil)
        return nil;
    NSUInteger count = [document pageCount];
    for (NSUInteger index = 0; index < count; index++) {
        PDFPage *page = [document pageAtIndex:index];
        CGPDFPageRef cgPage = [page charon_CGPDFPage];
        if (cgPage == NULL)
            continue;
        if (CGPDFPageGetDictionary(cgPage) == dictionary)
            return page;
    }
    return nil;
}

@end
#pragma clang diagnostic pop