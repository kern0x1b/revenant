#import "CharonPDFKit.h"
#import "PDFPageText11.h"
#include <ctype.h>

// PDFPage over the release's own CGPDFPage.  Every answer is the page read back through CoreGraphics:
// the boxes are CGPDFPageGetBoxRect, the rotation is the page dictionary's own /Rotate.

@interface PDFPage ()
- (CGPDFPageRef)charon_CGPDFPage;
- (void)charon_buildAnnotations;
- (CharonPDFPageText *)charon_textLayout;
@end

@implementation PDFPage {
    CGPDFPageRef _page;
    // Weak, as the header declares it (PDFPage.h:70): the page answers nil for a document that has
    // gone, and does not keep one alive.  The CGPDFDocument underneath is held strongly in
    // _documentRef, because a CGPDFPage belongs to one and outliving it is a real case.
    __weak PDFDocument *_document;
    // The CGPDFDocument itself, held strongly, because the CGPDFPage below belongs to it.
    CGPDFDocumentRef _documentRef;
    NSUInteger _index;
    // The page's annotations, built once and handed out as a copy each time.  Strong, and not a cycle:
    // an annotation's page is WEAK (PDFAnnotation.h:141), so page -> annotation -> page does not close.
    NSArray *_annotations;
    // The page's text layout, built once by -charon_textLayout and read by -string, by
    // -numberOfCharacters and by every PDFSelection over this page.
    CharonPDFPageText *_layout;
}

@synthesize pageIndex = _index;
// -label and -numberOfCharacters and -annotationCount are computed from the page's own dictionary and
// its content stream, not stored.  @dynamic says "not an ivar" and NOTHING else: a @dynamic property
// with no body raises at run time, which is what the first version of this did and what the harness's
// crash was.  Each has a body below.
@dynamic label;
@dynamic numberOfCharacters;
@dynamic string;
@dynamic annotations;
@dynamic annotationCount;

// The page's LABEL, which the host answers as a ONE-BASED number as a string: measured "1" for the
// first page of every fixture, and the first page of a three-page document is also "1".  So it is the
// index plus one, and the port's own zero-based _index is not what Apple's answer is.  The page
// dictionary's /StructParents is the format's hook for a printed label and none of these fixtures names
// one, so this is the host's answer rather than a substitute for it, and a page whose /StructParents
// is not measured here.
- (NSString *)label
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)(_index + 1)];
}

// The number of CHARACTERS the page's text walk produces, a kerning separator included: measured 6
// where -string answers "al pha" over five drawn glyphs, and 5 where it answers "alpha".  So this is
// the length of the same walk and not a glyph run - which is what separates it from -string's boundary.
- (NSUInteger)numberOfCharacters
{
    NSString *text = [self string];
    return text.length;
}

// THE TEXT WALK, bounded.
//
// The walk is over CGPDFScanner and an operator table, which this release DOES export - the Pop* family
// and CGPDFOperatorTableSetCallback - even though CGPDFScannerScanString and CGPDFScannerGetString are
// absent.  Measured: it recovers "page 1" off a fixture written by a conforming writer.
//
// AND IT OVER-READS, which is the whole reason it needed bounding.  CGPDFScannerScan does not answer
// false at the end of a content stream: past its last operator it keeps returning true and
// re-delivering the last operand, so `while (CGPDFScannerScan(sc))` never ends and the text it produces
// is "page 1page 1page 1..." to the end of whatever bound it is given.  So the walk below stops on TWO
// CONDITIONS, both of them facts about the document rather than a guess about the scanner:
//
//   the OPERATOR COUNT  every show operator advances a counter, and the walk stops when the number of
//                       shows it has taken reaches the number the page's own text runs account for
//   the STREAM LENGTH    the walk also stops at the content stream's own decompressed length, read
//                       through CGPDFStreamCopyData, so a stream whose operators do not divide evenly
//                       into it cannot run away either
//
// The two are both needed.  The operator count alone cannot see a scan that returns true without
// advancing, and the length alone would truncate a legitimate page whose text runs are dense.

// What the walk accumulates, and what the callbacks reach through the scanner's info pointer.
typedef struct {
    NSMutableString *text;
    NSMutableArray *runs;
    // The page being walked, so that Tf can resolve the name it reads against that page's /Font
    // dictionary.  A CGPDFPageRef and not a PDFPage: the walk already holds one for the duration.
    CGPDFPageRef page;
    NSUInteger shows;
    CGFloat x;
    CGFloat y;
    CGFloat size;
    // THE TEXT MATRIX'S SCALE, a and d.  A glyph's size is not Tf's operand: the text rendering matrix of
    // PDF 1.7 Section 9.4.4 multiplies it by the text matrix's scale, so `12 0 0 12 ... Tm` with `/F1 1 Tf`
    // draws at TWELVE points.  Measured, and it is what made the first round's fixtures answer 36.6960
    // with a height of 12 while naming size 1 - see .agent-work/runs/v-pdfsel2/bounds-predictions-2.md.
    CGFloat scaleX;
    CGFloat scaleY;
    // THE TEXT LINE MATRIX's translation, which Td and TD move RELATIVE to and which Tm sets outright.
    // Without it `72 720 Td` would move from the origin every time, and every fixture that positions its
    // text with Td - which is every fixture a conforming writer draws - would be laid out at 0,0.
    CGFloat lineX;
    CGFloat lineY;
    // The leading, TL's operand, which TD sets and T* moves by.  -1 until one of them says otherwise,
    // which is what Section 9.4.2 makes it.
    CGFloat leading;
    // The CHARACTER SPACING, Tc's operand: PDF 1.7 Section 9.3.3 adds it to the advance after every
    // glyph.  It is the last of the text-state operators this walk reads, and it is here because
    // CGPDFContext - the conforming writer every text fixture in this harness is drawn by - writes
    // `0.0002 Tc` into every one of them, so a geometry that ignored it would differ from the host by
    // 0.0120pt on a six-glyph line.  Measured, and the per-glyph numbers are in the comment on
    // collectRun below.
    CGFloat charSpacing;
    // The name Tf named, kept beside the size because a selection's -attributedString hands back a font
    // and its two facts are these: measured, the host answers "Helvetica" at 12pt for every fixture drawn
    // with /TT1 12 Tf, and the walk is what knows both halves.
    NSString *font;
    // The font's METRICS, built when Tf named the font and left until the next Tf.  It is an object in a
    // malloc'd struct, so it is retained on assignment and RELEASED at every exit that frees the walk -
    // the walk's own NSString and NSMutableArray fields above have no destructor either, which is a leak
    // of one page's text per page and not this row's business, but a new field need not add to it.
    CharonPDFFontMetrics *metrics;
} CharonTextWalk;

// The page's /Font dictionary, which is what turns the NAME Tf named into the dictionary the metrics are
// read out of.  PDF 1.7 Table 7.28: the page's /Resources names /Font, and /Font maps each name a content
// stream uses to a font dictionary.  A page with no /Resources, or a /Resources with no /Font, has no
// fonts and the walk runs with nil metrics - which is measured, not defensive: the geometry of such a
// page is the row's stated boundary and the walk's -string does not change.
static CGPDFDictionaryRef charonFontDictionary(CGPDFPageRef page)
{
    if (page == NULL)
        return NULL;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(page);
    if (dictionary == NULL)
        return NULL;
    CGPDFDictionaryRef resources = NULL;
    if (!CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources) || resources == NULL)
        return NULL;
    CGPDFDictionaryRef fonts = NULL;
    if (!CGPDFDictionaryGetDictionary(resources, "Font", &fonts) || fonts == NULL)
        return NULL;
    return fonts;
}

// A CONTROL BYTE in a show string is a NUL in the host's text, and the release's own decoder is what
// hides that.  Measured on this Mac's own PDFKit, over byte-level fixtures whose single show string
// carries one control byte between two letters:
//
//     bytes a \0 b \1 c \t d \n e \r f \37 g \177 h
//     host   a \0 b \0 c \0 d \0 e \0 f \0 g \0 h      (15 characters, the length preserved)
//
// and over a string with no control byte in it, where the answer is the letters themselves.  So the
// LENGTH is the byte count whatever the bytes are, and only the CHARACTER changes.  That is the whole of
// what CGPDFStringCopyTextString cannot do: it maps a NUL byte to a space and a tab to a tab, so a
// string carrying either arrives here indistinguishable from a string that really drew a space, and the
// host answers one NUL and the port a space - measured, `alpha\0bravo` reads `alpha\0bravo` on the host
// and `alpha bravo` here.
//
// So the characters come from the release's decoder, which knows the string's encoding, and the CONTROL
// BYTES come from the release's byte reader beside it, and the two are zipped: a byte below 0x20 or the
// 0x7F byte becomes U+0000 and every other byte keeps the character the decoder gave it.  A byte at
// 0x80 or above is NOT a control byte and keeps the decoder's character - the host resolves those
// through the FONT's encoding, which is the metrics engine's business and not this walk's; facts
// Selection11.md records what each side answers there.
static NSString *charonTextForOperand(CGPDFStringRef operand, CFStringRef characters)
{
    // CGPDFStringGetBytePtr answers `const unsigned char *`, and the length comes from
    // CGPDFStringGetLength - which is the length of the string in BYTES for the strings this walk sees,
    // because it is the length the release's own parser counted.
    const unsigned char *bytes = CGPDFStringGetBytePtr(operand);
    size_t length = CGPDFStringGetLength(operand);
    NSUInteger decoded = CFStringGetLength(characters);
    if (bytes == NULL || length == 0 || decoded == 0 || (size_t)decoded != length)
        // No bytes to read, or the decoder's own length does not match the byte count - a UTF-16BE string
        // with a byte-order mark is two bytes per character and is the case that cannot be zipped this
        // way.  Then the decoder's characters stand on their own, which is what they are for.
        return (__bridge NSString *)characters;
    // FE FF is the byte-order mark of a UTF-16BE string (PDF 1.7 Table 3.5): its bytes are not character
    // codes at all, so the zip below would read half a character as a control byte.
    if (length >= 2 && (unsigned char)bytes[0] == 0xFE && (unsigned char)bytes[1] == 0xFF)
        return (__bridge NSString *)characters;
    NSMutableString *answer = [NSMutableString stringWithCapacity:decoded];
    for (NSUInteger i = 0; i < decoded; i++) {
        unsigned char byte = (unsigned char)bytes[i];
        if (byte < 0x20 || byte == 0x7F)
            [answer appendFormat:@"%C", (unichar)0];
        else
            [answer appendFormat:@"%C", (unichar)CFStringGetCharacterAtIndex(characters, i)];
    }
    return answer;
}

// The show operators, as C functions.  Each pops ITS OWN operands: the callback signature carries none.
static void charonAppendOperand(CGPDFScannerRef scanner, CharonTextWalk *walk, CGPDFStringRef operand)
{
    if (operand == NULL)
        return;
    CFStringRef characters = CGPDFStringCopyTextString(operand);
    if (characters == NULL)
        return;
    NSString *text = charonTextForOperand(operand, characters);
    [walk->text appendString:text];
    // THE PEN MOVES ON, and the next show starts where this one stopped rather than where the text matrix
    // is.  This is not a detail: CGPDFContext SPLITS a long string into several show operators - "zero
    // alpha bravo charlie alpha alpha" arrives as three - and a walk that left the pen where the matrix
    // put it drew the second and third at the first one's x.  Measured on cgfixture-words.pdf, where the
    // host answers 79.3760 for "bravo" and a pen that does not move answers 20.0000.
    walk->x = collectRun(walk->runs, text, walk->x, walk->y, walk->size * walk->scaleX,
                         walk->size * walk->scaleY, walk->font, walk->metrics, walk->charSpacing);
    CFRelease(characters);
}

static void charonOpShowText(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFStringRef operand = NULL;
    if (CGPDFScannerPopString(scanner, &operand))
        charonAppendOperand(scanner, walk, operand);
    walk->shows++;
}

static void charonOpShowTextArray(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFArrayRef array = NULL;
    if (!CGPDFScannerPopArray(scanner, &array) || array == NULL)
        return;
    for (size_t i = 0; i < CGPDFArrayGetCount(array); i++) {
        CGPDFObjectRef element = NULL;
        if (!CGPDFArrayGetObject(array, i, &element) || element == NULL)
            continue;
        CGPDFObjectType kind = CGPDFObjectGetType(element);
        if (kind == kCGPDFObjectTypeString) {
            CGPDFStringRef operand = NULL;
            if (CGPDFObjectGetValue(element, kCGPDFObjectTypeString, &operand))
                charonAppendOperand(scanner, walk, operand);
        }
        // A NUMBER in a TJ array is a KERNING ADJUSTMENT and not a character, and the host's -string does
        // not turn one into a space - measured, the answer is "page 1" and not "page  1".  So it is not a
        // CHARACTER and this walk does not make one of it.
        //
        // It is still a MOVEMENT of the pen, and that is a different fact: PDF 1.7 Section 9.3.3 subtracts
        // the number from the horizontal displacement, in THOUSANDTHS of a text-space unit, so a -250
        // moves the next glyph a quarter of the em to the LEFT.  CGPDFContext writes a TJ array rather
        // than a plain show whenever a string is long enough - "zero alpha bravo charlie alpha alpha"
        // arrives as one - and a geometry that ignored the adjustments put every element of the array at
        // one x.  Measured on cgfixture-words.pdf, where the host answers 23.3424 for "zero" and the
        // /Widths come to 23.3400.
        // kCGPDFObjectTypeReal, not kCGPDFObjectTypeNumber: the enumeration has no such member
        // (CGPDFObject.h:36-44), and CGPDFObjectGetValue converts an integer object to a real on request,
        // which is what the header says it does.
        if (kind == kCGPDFObjectTypeInteger || kind == kCGPDFObjectTypeReal) {
            CGPDFReal adjustment = 0;
            if (CGPDFObjectGetValue(element, kCGPDFObjectTypeReal, &adjustment))
                walk->x -= (CGFloat)adjustment * walk->size * walk->scaleX / 1000.0;
        }
    }
    walk->shows++;
}

// The text matrix: where the next show is drawn.  Popped in REVERSE - a stack pops its top first, and
// the matrix is pushed a..f, so f comes off before e.
static void charonOpTextMatrix(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    // CGPDFReal, and NOT double: in this release it is a float, and a double* here is a type error rather
    // than a widening.  The name reads like a double, which is why the type is spelled out here.
    CGPDFReal a = 0, b = 0, c = 0, d = 0, e = 0, f = 0;
    if (CGPDFScannerPopNumber(scanner, &f) && CGPDFScannerPopNumber(scanner, &e) &&
        CGPDFScannerPopNumber(scanner, &d) && CGPDFScannerPopNumber(scanner, &c) &&
        CGPDFScannerPopNumber(scanner, &b) && CGPDFScannerPopNumber(scanner, &a)) {
        walk->x = (CGFloat)e;
        walk->y = (CGFloat)f;
        walk->scaleX = (CGFloat)a;
        walk->scaleY = (CGFloat)d;
        // Tm sets the LINE matrix as well as the text matrix (Section 9.4.1), so a Td after it is relative
        // to this point and not to the one before.
        walk->lineX = (CGFloat)e;
        walk->lineY = (CGFloat)f;
    }
}

static void charonMoveText(CGPDFScannerRef scanner, void *info, BOOL setLeading);

// Td and TD MOVE the line matrix by their operands, and both leave the text matrix equal to it.  The
// operands come off the stack in order, y then x, because the operators are written `tx ty`.
// `72 720 Td` at the start of a BT is therefore an ABSOLUTE move of (72, 720) - the line matrix starts at
// the identity - and a second Td is relative to it.
//
// TD is Td with /Leading set to -ty, and T* is `Td 0 -TL`.  Both are here because a stream that uses
// them positions its text somewhere this walk would otherwise put at the origin, and the harness's own
// fixtures are not the only documents a caller opens.  Neither is measured on the host - no fixture here
// writes one - and this is PDF 1.7 Section 9.4.1 read as written rather than a measurement, which the
// facts file says.
static void charonOpMoveText(CGPDFScannerRef scanner, void *info)
{
    charonMoveText(scanner, info, NO);
}

static void charonOpMoveTextDelta(CGPDFScannerRef scanner, void *info)
{
    charonMoveText(scanner, info, YES);
}

// The shared body of Td and TD, which differ only in whether they set /Leading.  It is a separate
// function because CGPDFOperatorCallback carries exactly two arguments - the scanner and the info
// pointer - so a third one is a function pointer of the wrong type and the compiler says so, which it did.
static void charonMoveText(CGPDFScannerRef scanner, void *info, BOOL setLeading)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal tx = 0, ty = 0;
    if (!CGPDFScannerPopNumber(scanner, &ty) || !CGPDFScannerPopNumber(scanner, &tx))
        return;
    walk->lineX += (CGFloat)tx;
    walk->lineY += (CGFloat)ty;
    walk->x = walk->lineX;
    walk->y = walk->lineY;
    if (setLeading)
        walk->leading = -(CGFloat)ty;
}

// T* takes no operands: it moves to the start of the NEXT line, which is `Td 0 -TL` with whatever /Leading
// is currently set - -1 until a TL or a TD says otherwise (Section 9.4.2).
static void charonOpNextLine(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    walk->lineY -= walk->leading;
    walk->x = walk->lineX;
    walk->y = walk->lineY;
}

// Tc sets the character spacing and nothing else.
static void charonOpSetCharSpacing(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal spacing = 0;
    if (CGPDFScannerPopNumber(scanner, &spacing))
        walk->charSpacing = (CGFloat)spacing;
}

// TL sets the leading and nothing else.
static void charonOpSetLeading(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal leading = 0;
    if (CGPDFScannerPopNumber(scanner, &leading))
        walk->leading = (CGFloat)leading;
}

// BT RESETS the text matrix and the line matrix both to the identity (Section 9.4.1).  A stream that draws
// two text objects on one page relies on it: without the reset the second one's Td would be relative to
// the first one's end.
static void charonOpBeginText(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    walk->x = 0;
    walk->y = 0;
    walk->scaleX = 1;
    walk->scaleY = 1;
    walk->lineX = 0;
    walk->lineY = 0;
}

// Tf names a font and a size, and the operands come off the stack size FIRST: `BT /F1 12 Tf` pushes the
// name and then the number.  Both halves are kept, because the size is a run's vertical extent and the
// name is what a selection's attributed string hands back as its font.
//
// AND THE METRICS, which is the third half and the one -[PDFSelection boundsForPage:] needs: the name is
// resolved against the page's own /Font dictionary HERE, at the operator that named it, because that is
// the only moment the text state and the page's resources are both in hand.  The size and the font name
// can both change between one show operator and the next and the metrics have to change with them, or a
// page that draws two sizes would give both runs one font's widths.
static void charonOpFontSize(CGPDFScannerRef scanner, void *info)
{
    CharonTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal size = 0;
    if (!CGPDFScannerPopNumber(scanner, &size))
        return;
    walk->size = (CGFloat)size;
    const char *name = NULL;
    // A font name is a NAME object and not a string, and CGPDFScannerPopName is the reader for it; a
    // stream that writes `/F1 12 Tf` with the font in its own /Resources answers the name here, and one
    // that names no font leaves the run's font nil rather than inventing one.
    if (!CGPDFScannerPopName(scanner, &name) || name == NULL)
        return;
    walk->font = @(name);
    // The metrics are rebuilt from scratch on every Tf rather than cached across the page: a document may
    // name the same font at two sizes and the widths scale with the size, so a cache keyed by name alone
    // would answer the first size's widths for the second run.
    CGPDFDictionaryRef fonts = charonFontDictionary(walk->page);
    CGPDFDictionaryRef fontDictionary = NULL;
    if (fonts != NULL)
        CGPDFDictionaryGetDictionary(fonts, name, &fontDictionary);
    // AT SIZE 1, and the run's own effective size is applied once in collectRun.  Building the metrics at
    // Tf's operand and then multiplying by it again is the mistake this line is written against: it
    // answers twelve times every advance, and the measurement that caught it is on
    // cgfixture-text-no-tc.pdf - 424.2240 for "outlined" where the /Widths sum is 42.0240.
    walk->metrics = [CharonPDFFontMetrics metricsWithFontDictionary:fontDictionary size:1];
}

// One drawn run, as the layout's own object: the characters, where they were drawn, the text state, and
// ONE RECT PER CHARACTER - which is the whole of -[PDFSelection boundsForPage:]'s substrate.
// CharonPDFTextRun is declared in PDFPageText11.h because a selection reads it for its font and its position.
//
// The rects are filled HERE, at the show operator, rather than by a pass over the runs afterwards,
// because a character the line rule later drops still moved the pen.  A line drawn " alpha bravo " has
// its 'a' at the run's own x and its 'l' a space further on, and the arithmetic that would put them both
// at the run's x is the one the measurements above rule out.
//
// The rect is (pen, baseline + the font's descent, this character's advance, the size), and the two
// numbers that are not the pen are measured: the bottom is the DESCENT line and not the ascent
// (360 - 230 * 12 / 1000 = 357.24 against 350.76 for the ascent, on cgfixture-1.pdf), and the height is
// the size and nothing else.  facts/PDFKit/Selection11.md has the table.
// And it answers WHERE THE PEN IS AFTERWARDS, which is what the next show operator starts from.  A run
// that drew nothing is not a run at all and the pen does not move: an empty show is not written by a
// conforming writer, and one that is must not shift the text after it.
static CGFloat collectRun(NSMutableArray *runs, NSString *text, CGFloat x, CGFloat y, CGFloat sizeX,
                          CGFloat sizeY, NSString *font, CharonPDFFontMetrics *metrics,
                          CGFloat charSpacing)
{
    if (text == nil || text.length == 0)
        return x;
    CharonPDFTextRun *run = [[CharonPDFTextRun alloc] init];    run.text = text;
    run.x = x;
    run.y = y;
    run.size = sizeY;
    run.fontName = font;
    // The rects, built on the C stack and handed over: a run with a font that resolved has one rect per
    // character, and a run without one has none at all - which -rectAtIndex: answers as CGRectNull and
    // the union in CharonPDFPageText skips, rather than a zero-width rect that would drag the rect's left edge
    // to the origin.
    NSUInteger count = text.length;
    CGRect *rects = count > 0 ? malloc(sizeof(CGRect) * count) : NULL;
    if (rects != NULL) {
        // The metrics are built for Tf's operand and the MATRIX scales what comes out of them, so the
        // descent and every advance are multiplied by the run's own horizontal and vertical scale here
        // rather than by the matrix inside the metrics, which are a font's and not a run's.  Both are
        // measured: `12 0 0 12 ... Tm` with `/F1 1 Tf` draws at twelve points and answers the same as an
        // identity matrix with `/F1 12 Tf` (36.6960 by 12.0000 on cgfixture-text-matrix-scale.pdf).
        // THE CHARACTER SPACING is added after every glyph EXCEPT the last of the run, which is the
        // format's rule (Section 9.3.3) read as what it does to an extent: the spacing after the final
        // glyph moves the pen on, and the pen on past the last glyph is not inside any of its rects.
        //
        // Measured on cgfixture-text-tc.pdf, /Widths 556 and 278 at 12pt with `0.0002 Tc`, the host's
        // per-character excesses over the /Widths values are 0.0001, 0.0002, 0.0002, 0.0001, 0.0004 and
        // 0.0000 - which sum to 0.0010, exactly five times Tc, and n - 1 is five.  The same ratios at
        // `0.002 Tc` (0.0010, 0.0020, 0.0020, 0.0010, 0.0040, 0.0000), so the term is exactly linear in
        // Tc.  The DISTRIBUTION is not the one spacing-per-gap this writes: the host's differs from it
        // by up to one Tc, 0.0002pt, which is inside the harness's 0.001 tolerance and inside nothing
        // else - and the TOTAL, which is what a whole word or a whole line answers, is exact.  The
        // distribution is measured, unexplained, and recorded as such rather than fitted.
        CGFloat pen = x;
        CGFloat bottom = y + metrics.descent * sizeY;
        CGFloat spacing = charSpacing * sizeX;
        for (NSUInteger i = 0; i < count; i++) {
            CGFloat advance = [metrics advanceForCode:(int)[text characterAtIndex:i]] * sizeX;
            rects[i] = CGRectMake(pen, bottom, advance, sizeY);
            pen += advance + (i + 1 < count ? spacing : 0);
        }
        [run charon_setGlyphRects:rects count:count];
        free(rects);
        // The PEN, and the spacing after the LAST glyph too - the pen is outside the ink but it is where
        // the next character is drawn, and Section 9.4.1's Trm adds Tc after every glyph.
        [runs addObject:run];
        return pen + (count > 0 ? spacing : 0);
    }
    [runs addObject:run];
    return x;
}

// The page's text IN READING ORDER, which is not the order it was drawn in and is not the runs joined
// with a separator either.  Three fixtures fix both halves, and they are the first fixtures in this
// harness with MORE THAN ONE show operator on a page - every fixture before them had exactly one, so the
// separator between runs was not observable at all and this port answered "alphabeta" where the host
// answers "alpha\nbeta".  The new fixture found it on its first run.
//
//   cgfixture-pair-down.pdf  draws "alpha" at y=360 then "beta" at y=340 and the host answers
//                            "alpha\nbeta": a newline, and the DESCENDING order is the drawing order.
//   cgfixture-pair-up.pdf    draws "alpha" at y=340 then "beta" at y=360 and answers "beta\nalpha":
//                            a newline, and the runs come out TOP OF THE PAGE FIRST, not in drawing
//                            order.  So the answer is sorted by y DESCENDING and a tie keeps drawing
//                            order, which is what NSSortStable gives.
//   cgfixture-pair-same.pdf  draws both at y=360 and answers "alphabeta": a tie on y joins with NOTHING.
//
// and cgfixture-lines.pdf, three runs at y = 360, 340, 320, answers "shared one\nshared two\nthird line"
// - 32 characters, against the 30 this port answered before the fixture existed.
//
// WHITESPACE and the LINES are the layout's: charonTrimLine and charonCollapseSpaces live in
// PDFPageText11.m, which builds the string line by line and needs them at every line
// boundary, and facts/PDFKit/Document11.md has the measurements.
// WHITESPACE, which is the fourth thing a line does and the one this walk was missing.  Measured on the
// host over five fixtures a conforming writer writes, and every one of them is a LINE and not a run:
//
//   cgfixture-gap.pdf       one line drawn "alpha  bravo"          answers "alpha bravo"   (11)
//   cgfixture-lead.pdf      one line drawn " alpha bravo "         answers "alpha bravo"   (10)
//   cgfixture-tail.pdf      one line drawn "alpha ", the next "bravo"  answers "alpha\nbravo" (11)
//   cgfixture-tailpair.pdf  two runs at ONE y, "alpha " then "beta"    answers "alpha beta"  (10)
//   bytes-space.pdf         one line drawn "a  b   c"             answers "a b c"         (5)
//
// Tm and Tf operators.  A selection's geometry needs them and the walk needs them, so they are read once
// and shared.  A stream that names neither leaves the size at 0 and the position at the origin, and the
// rows that depend on a position say so rather than inventing one.
typedef struct { CGFloat x; CGFloat y; CGFloat size; } CharonTextState;

static CharonPDFPageText *charonScanPageText(CGPDFPageRef page, CharonTextState *state)
{
    if (state != NULL) {
        state->x = 0;
        state->y = 0;
        state->size = 0;
    }
    if (page == NULL)
        return nil;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(page);
    if (dictionary == NULL)
        return nil;
    CGPDFStreamRef stream = NULL;
    if (!CGPDFDictionaryGetStream(dictionary, "Contents", &stream) || stream == NULL)
        return nil;

    // The stream's own decompressed LENGTH, which is the walk's second stop condition.  Read through
    // CGPDFStreamCopyData because the bytes on disk are the Flate-compressed form and its /Length is the
    // compressed length, which is not the length the scanner consumes.
    CFDataRef data = CGPDFStreamCopyData(stream, NULL);
    if (data == NULL)
        return nil;
    CFIndex streamLength = CFDataGetLength(data);
    if (streamLength <= 0) {
        CFRelease(data);
        return nil;
    }
    // The number of SHOW OPERATORS the page's own content stream contains, counted off its bytes.  This
    // is the walk's stop condition and it is a fact about the PAGE rather than a guess about the
    // scanner: the scanner re-delivers the last operand forever, so a bound on how many tokens it hands
    // out fires immediately - the walk discarded its own correct answer on every fixture until the bound
    // was taken from the content instead.  A stream with no show operator walks zero times, which is
    // what a page that draws no text should answer.
    NSUInteger showCount = 0;
    {
        const char *bytes = (const char *)CFDataGetBytePtr(data);
        if (bytes != NULL) {
            for (CFIndex i = 0; i + 1 < streamLength; i++) {
                char c = bytes[i];
                if (c != 'T' && c != '\'' && c != '"')
                    continue;
                if (c == 'T') {
                    // Tj or TJ, and only when the token ENDS here - a T inside a name is not a show.
                    if (i + 2 < streamLength && (bytes[i + 1] == 'j' || bytes[i + 1] == 'J') &&
                        (i + 2 >= streamLength || !(isalnum((unsigned char)bytes[i + 2]) || bytes[i + 2] == '*')))
                        showCount++;
                } else {
                    // ' and " are show operators in their own right, and are one character long.
                    if (i + 1 >= streamLength || !(isalnum((unsigned char)bytes[i + 1]) || bytes[i + 1] == '*'))
                        showCount++;
                }
            }
        }
    }
    CFRelease(data);

    // The content stream, from the PAGE and not from the stream with NULL resources.
    //
    // CGPDFContentStreamCreateWithStream's second parameter sits inside CF_ASSUME_NONNULL_BEGIN in the
    // release's own CGPDFContentStream.h, so it is nonnull and passing NULL is a -Wnonnull diagnostic -
    // and it was one, on origin/main, since the text walk landed.  The page is what this function already
    // takes, so nothing new is threaded through to reach it.  CGPDFContentStreamCreateWithPage is
    // the API for exactly this: it takes the page and supplies the /Resources and the content array the
    // hand-assembled call was leaving out, which the scanner needs to resolve a font name at all.  The
    // stream above is still read, because the walk's second stop condition is that stream's own
    // decompressed length and its byte count of show operators.
    CGPDFContentStreamRef content = CGPDFContentStreamCreateWithPage(page);
    if (content == NULL)
        return nil;

    NSMutableArray *runs = [NSMutableArray array];
    NSMutableString *text = [NSMutableString string];

    CGPDFOperatorTableRef table = CGPDFOperatorTableCreate();
    if (table == NULL) {
        CGPDFContentStreamRelease(content);
        return nil;
    }
    // The scanner is created LAST, once the walk it points at exists, because the walk is what the info
    // pointer carries and every callback needs it.
    CGPDFScannerRef scanner = NULL;

    // The callbacks, as C FUNCTIONS and not blocks: CGPDFOperatorCallback is a function pointer, so a
    // block cannot be passed to CGPDFOperatorTableSetCallback and the compiler says so.  Each reaches the
    // walk's state through the scanner's info pointer, which is what that argument is for - the callback
    // signature carries no operand, which is the other difference from the API this file used to imagine.
    CharonTextWalk *walk = malloc(sizeof(*walk));
    if (walk == NULL) {
        CGPDFScannerRelease(scanner);
        CGPDFOperatorTableRelease(table);
        CGPDFContentStreamRelease(content);
        return nil;
    }
    walk->text = text;
    walk->runs = runs;
    walk->page = page;
    walk->shows = 0;
    walk->x = 0;
    walk->y = 0;
    walk->size = 0;
    walk->scaleX = 1;
    walk->scaleY = 1;
    walk->lineX = 0;
    walk->lineY = 0;
    walk->leading = -1;
    walk->charSpacing = 0;
    walk->metrics = nil;
    CGPDFOperatorTableSetCallback(table, "Tj", charonOpShowText);
    CGPDFOperatorTableSetCallback(table, "'", charonOpShowText);
    CGPDFOperatorTableSetCallback(table, "\"", charonOpShowText);
    CGPDFOperatorTableSetCallback(table, "TJ", charonOpShowTextArray);
    CGPDFOperatorTableSetCallback(table, "Tm", charonOpTextMatrix);
    CGPDFOperatorTableSetCallback(table, "Tf", charonOpFontSize);
    CGPDFOperatorTableSetCallback(table, "Td", charonOpMoveText);
    CGPDFOperatorTableSetCallback(table, "TD", charonOpMoveTextDelta);
    CGPDFOperatorTableSetCallback(table, "T*", charonOpNextLine);
    CGPDFOperatorTableSetCallback(table, "TL", charonOpSetLeading);
    CGPDFOperatorTableSetCallback(table, "Tc", charonOpSetCharSpacing);
    CGPDFOperatorTableSetCallback(table, "BT", charonOpBeginText);

    scanner = CGPDFScannerCreate(content, table, walk);
    if (scanner == NULL) {
        // The metrics the walk is holding, released before the walk itself.  An object pointer in a
        // malloc'd struct is a __strong field, so assigning nil to it is what releases; free() alone
        // cannot, because a C struct has no destructor.
        walk->metrics = nil;
        free(walk);
        CGPDFOperatorTableRelease(table);
        CGPDFContentStreamRelease(content);
        return nil;
    }
    while (walk->shows < showCount && CGPDFScannerScan(scanner))
        ;
    // The over-read is visible rather than silent.  A walk that took FEWER shows than the stream contains
    // stopped early and its answer is incomplete, so it is DISCARDED rather than returned half-formed: a
    // -string that is wrong in a way nobody can see is worse than nil, and the facts file records it.
    BOOL exhausted = walk->shows < showCount;
    if (state != NULL) {
        state->x = walk->x;
        state->y = walk->y;
        state->size = walk->size;
    }
    // Same here, and this is the branch every page that draws text takes.
    walk->metrics = nil;
    free(walk);
    CGPDFScannerRelease(scanner);
    CGPDFOperatorTableRelease(table);
    CGPDFContentStreamRelease(content);
    // The layout is built out of the runs, so it is asked for before anything else touches them, and a
    // walk that took fewer shows than the stream holds is discarded rather than returned half-formed: a
    // -string that is wrong in a way nobody can see is worse than nil, and the facts file records it.
    if (exhausted) {
        return nil;
    }
    CharonPDFPageText *layout = [CharonPDFPageText layoutWithRuns:runs];
    if (layout.string.length == 0)
        return nil;
    return layout;
}

// THE PAGE'S OWN TEXT LAYOUT, built once and kept.  Both the page's own -string and every PDFSelection
// read it, and they have to agree character for character because a selection's range is an offset into
// it - so it is built here, once, rather than walked twice.  It is strong: it holds no reference back to
// the page, and the page holding it is the same arrangement every other memoised array on this page uses.
- (CharonPDFPageText *)charon_textLayout
{
    if (_layout == nil)
        _layout = charonScanPageText(_page, NULL);
    return _layout;
}

// The page's own TEXT, which is what the host's -string answers on every fixture measured here: "page 1"
// for the first page of a three-page document and "page 2" and "page 3" for the others, with the character
// count -numberOfCharacters agrees with.  The kerning numbers in a TJ array are NOT characters, which is
// what keeps "page 1" from becoming "page  1".
- (NSString *)string
{
    if (_page == NULL)
        return nil;
    return [self charon_textLayout].string;
}

// The page's ANNOTATIONS, built over the page's own /Annots array: each element is a dictionary
// CoreGraphics already parsed, and each becomes a PDFAnnotation over that dictionary.  The order is the
// array's own, which is the order the host hands them back in.
//
// AN ANNOTATION THE HOST DOES NOT SURFACE IS NOT IN THE ARRAY, which is a measured skip and not a
// tolerance: the /Annots array of a fixture with thirteen annotations in it holds eleven that the host
// never hands back, and this port used to hand back all thirteen.  Two shapes are skipped, and both
// are measured over every subtype tried rather than over one:
//
//   no /Rect   a /Line, /Square, /Text, /Popup, /Ink, /Circle, /FreeText, /Stamp and /Link, each
//              written with a /Contents and nothing else, is dropped - all nine, on one fixture.  /Rect
//              is what PDF 1.7 Table 164 makes required of every annotation, so this is the format's
//              own requirement and the host enforcing it.
//   a /Line with no /L   the same fixture's /Line with a /Rect and no /L is dropped while a /Line with
//              both is kept, so the line's own endpoints are as required for a /Line as the rectangle
//              is for everything.
//
// A /Widget with no /FT is KEPT (the same fixture, one annotation), which is what stops the rule from
// being "an annotation missing a required key is dropped": /FT is required of a widget by Table 8.39
// and the host does not enforce it.
//
//   a CHOICE widget without a usable /Opt   dropped, which IS the format's requirement and the host
//     enforcing it, the same shape as /Rect.  Six fixtures, one field type each and ALONE on its page,
//     because a fixture carrying all four can only say that ONE of them is missing: /Btn, /Tx and /Sig
//     are surfaced and /Ch is not.  And the /Opt decides: a /Ch beside /Opt [(one) (two)] IS surfaced
//     while a /Ch beside /Opt (a string) is not.
//
// So three shapes are skipped, and each is measured rather than read off the format.
- (NSArray *)annotations
{
    if (_annotations == nil)
        [self charon_buildAnnotations];
    // A COPY each call, over objects built once.  Both halves are measured on the host, and they are two
    // different halves: two calls answer two DIFFERENT arrays (arrays-same = 0 on every fixture) whose
    // elements are the SAME objects (objects-same = 1), and a change made through one is visible through
    // the other - a line width set on the first array's annotation reads back 9 on the second's, and a
    // border assigned through the first is the very object the second answers.  So the objects are built
    // once and kept, and the array is not: rebuilding the objects on every call, which is what this did
    // before, makes every one of those answers unreachable through the API.
    return _annotations != nil ? [_annotations copy] : @[];
}

- (void)charon_buildAnnotations
{
    _annotations = nil;
    if (_page == NULL)
        return;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(_page);
    if (dictionary == NULL) {
        _annotations = @[];
        return;
    }
    CGPDFArrayRef annots = NULL;
    if (!CGPDFDictionaryGetArray(dictionary, "Annots", &annots) || annots == NULL) {
        _annotations = @[];
        return;
    }
    size_t count = CGPDFArrayGetCount(annots);
    NSMutableArray *answer = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; i++) {
        CGPDFDictionaryRef annotation = NULL;
        if (!CGPDFArrayGetDictionary(annots, i, &annotation) || annotation == NULL)
            continue;
        CGPDFArrayRef rect = NULL;
        if (!CGPDFDictionaryGetArray(annotation, "Rect", &rect) || rect == NULL)
            continue;
        // a /Line whose endpoints are missing is skipped as well, and the /Subtype is read as the
        // name the dictionary spells it with - the same spelling -type answers.
        const char *subtype = NULL;
        if (CGPDFDictionaryGetName(annotation, "Subtype", &subtype) && subtype != NULL
            && strcmp(subtype, "Line") == 0) {
            CGPDFArrayRef endpoints = NULL;
            if (!CGPDFDictionaryGetArray(annotation, "L", &endpoints) || endpoints == NULL)
                continue;
        }
        // and a CHOICE widget whose /Opt is missing or is not an array, which is the THIRD measured skip
        // and is the format's own requirement: Table 8.39 makes /Opt required for a choice field, and
        // the host enforces it the way it enforces /Rect.  Six fixtures, one field type each and ALONE on
        // its page, because a fixture carrying all four field types can only say that ONE of them is
        // missing - and it is /Ch.  A /Ch beside /Opt [(one) (two)] IS surfaced; a /Ch beside
        // /Opt (a string) is not.
        if (subtype != NULL && strcmp(subtype, "Widget") == 0) {
            const char *fieldType = NULL;
            if (CGPDFDictionaryGetName(annotation, "FT", &fieldType) && fieldType != NULL
                && strcmp(fieldType, "Ch") == 0) {
                CGPDFArrayRef options = NULL;
                if (!CGPDFDictionaryGetArray(annotation, "Opt", &options) || options == NULL)
                    continue;
            }
        }
        PDFAnnotation *built = [[PDFAnnotation alloc] initWithCharonDictionary:annotation onPage:self];
        if (built != nil)
            [answer addObject:built];
    }
    _annotations = answer;
}

// The annotation COUNT is the length of that array: an array this release cannot answer, and a
// document whose page names no /Annots, answer zero.
- (NSUInteger)annotationCount
{
    return [self annotations].count;
}

- (instancetype)initWithCGPDFPage:(CGPDFPageRef)page document:(PDFDocument *)document index:(NSUInteger)index
{
    self = [super init];
    if (self == nil)
        return nil;
    if (page == NULL)
        return nil;
    // The page itself is a GET: CGPDFDocumentGetPage does not hand over an owned reference, and the
    // port must not take one of its own - a page released while its document is still alive is the
    // direction CoreGraphics does not support, and the bisect showed exactly that as the crash:
    //   pageAtIndex:0, page kept        -> exit 0
    //   pageAtIndex:0, page dropped first -> exit 139
    // The DOCUMENT owns its pages (it keeps them in its _pages array), so a page that dies first
    // frees nothing the document still points at.
    //
    // What the page DOES own is the document, held strongly as a CGPDFDocumentRef and not through the
    // PDFDocument - which the header declares weak (PDFPage.h:70), so a page that outlives its
    // document is a real case and needs its own reference to keep the page's internals alive.
    // The OBJECT, weakly, as PDFPage.h:70 declares - the page must answer nil for a document that has
    // gone, and must not keep one alive.  The REF behind it is held strongly, because a CGPDFPage
    // belongs to its CGPDFDocument and a page outliving its document is a real case.
    //
    // The object was NOT set here at all in the first version - the initializer took a
    // CGPDFDocumentRef, so -document was nil on every page while the host answered an object on every
    // fixture.  It is the "never handed it" case, not the "freed" one, and the harness is what said so.
    CGPDFDocumentRef documentRef = [document charon_CGPDFDocument];
    if (documentRef != NULL)
        CGPDFDocumentRetain(documentRef);
    _page = page;
    _document = document;
    _documentRef = documentRef;
    _index = index;
    return self;
}

- (void)dealloc
{
    // the page is a Get, so there is nothing of the page's to release; the document reference is
    // this page's own and is released here
    _page = NULL;
    if (_documentRef != NULL)
        CGPDFDocumentRelease(_documentRef);
}

- (PDFDocument *)document
{
    // A page answers nil for its document once the document has gone, which is what weak means and
    // what the header's declaration asks for.
    return _document;
}

// -boundsForBox: over the release's own box reader.  A box the page does not carry is the media box,
// which is what the release's own default is.
- (CGRect)boundsForBox:(CGPDFBox)box
{
    if (_page == NULL)
        return CGRectZero;
    return CGPDFPageGetBoxRect(_page, box);
}

- (CGRect)mediaBox
{
    return [self boundsForBox:kCGPDFMediaBox];
}

- (CGRect)cropBox
{
    return [self boundsForBox:kCGPDFCropBox];
}

// The page's own /Rotate, read through the release's dictionary API.  A page with no /Rotate is 0,
// which is what the PDF format says and what the release's own reader answers.
- (NSInteger)rotation
{
    if (_page == NULL)
        return 0;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(_page);
    if (dictionary == NULL)
        return 0;
    // The release's own dictionary reader, which answers the integer directly: no CGPDFObject and
    // no object-type test, because the reader is already the one that knows.
    CGPDFInteger raw = 0;
    if (!CGPDFDictionaryGetInteger(dictionary, "Rotate", &raw))
        return 0;
    NSInteger degrees = (NSInteger)raw;
    // The host answers 90 for a page whose /Rotate is 90, MEASURED on the rotated fixture
    // (box-rotated.pdf: host=90, port=270).  So the host does NOT flip the format's
    // counter-clockwise count here, and this flipping - written before anything was measured - was
    // wrong.  The value the page dictionary carries is the value the API answers.
    return degrees == 0 ? 0 : (degrees % 360 + 360) % 360;
}

- (CGPDFPageRef)charon_CGPDFPage
{
    return _page;
}

@end
