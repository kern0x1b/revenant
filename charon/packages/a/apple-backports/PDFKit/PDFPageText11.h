// PDFPageText11.h - one page's text, in the three coordinate systems a selection needs.
//
// A PDFSelection's range is an offset into the page's -[PDFPage string], its -selectionsByLine splits that
// string at the line breaks the walk put in it, and its geometry needs the run each character was drawn
// from.  So the walk's result is not a string: it is this, and the string is one of its three answers.
//
// Nothing here is PDFKit API.  The file that implements it exports no symbol any release has, which is
// what lets a band that already carries PDFKit leave it out: see the shared-C-function trap in
// charon/AGENTS.md.  The class names are the port's own, and the port's own registry says so.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// One run of drawn text: the characters, where they were drawn, and the text state they were drawn with.
//
// Every property is @synthesize'd EXPLICITLY: the port's compile line carries
// -Werror=objc-missing-property-synthesis, which is there because a member the port does not carry needs
// @dynamic rather than a silent ivar, and auto-synthesis would give one whether it was asked for or not.
@interface CharonPDFTextRun : NSObject
// The run's own characters, after the control-byte mapping the walk applies.
@property (nonatomic, copy) NSString *text;
// Where this run's text begins in the page's -string, which is what makes the string and the runs two
// views of ONE thing rather than two things that have to be kept in step.
@property (nonatomic) NSUInteger offset;
@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat y;
@property (nonatomic) CGFloat size;
// The name Tf named, and nil for a stream that draws text without naming a font.
@property (nonatomic, copy, nullable) NSString *fontName;
@end

// The category that carries a run's GEOMETRY, which is the whole of
// -[PDFSelection boundsForPage:]'s substrate.
//
// ONE RECT PER CHARACTER, filled by the WALK rather than computed later, because a character the line
// rule drops still moved the pen: a line drawn " alpha bravo " has its first character at the run's own x
// and its second one a space further on, and an arithmetic pass over the surviving characters alone would
// put them both at the run's x.
//
// A C ARRAY and not an NSArray of NSValue, for a reason the compile line found rather than a preference:
// NSValue's +valueWithRect: and -rectValue are UIKit's category (NSValue+UIGeometryExtensions.h) and not
// Foundation's, so a Foundation-only file - and this one is compiled into a macOS process that links no
// UIKit at all - cannot use them.  -rectAtIndex: answers CGRectNull past the end, which is what an empty
// run answers for every index, and the union below skips it.
@interface CharonPDFTextRun (CharonGeometry)
- (void)charon_setGlyphRects:(const CGRect *)rects count:(NSUInteger)count;
- (CGRect)rectAtIndex:(NSUInteger)index;
@end

// THE FONT OF A RUN, read out of the page's own /Resources at the moment Tf named it, with the width of
// every code the run drew already scaled by the size.
//
// The port's own class, and it lives in the file that exports no symbol any release has so that the
// walk in PDFPage11.m can reach it - a C function defined in a file that DOES export a band's symbol
// would be an undefined symbol in a band that leaves that file out (charon/AGENTS.md).
//
// /Widths AND /FirstChar, and nothing else, is what it reads for the advances: measured over four
// fixtures whose /Widths and whose embedded program disagree by eighteen points, on both sides, the host
// answered the /Widths every time, and it answered them for a font whose /FontFile2 no reader can open.
// facts/PDFKit/Selection11.md has the table and the run output.
//
// WHAT IS NOT READ, each because a fixture refutes it: the embedded /FontFile2 program through
// CGFontCreateWithDataProvider, and the /BaseFont name through CGFontCreateWithFontName - measured, the
// host answers the /Widths on four fixtures whose program disagrees with it by eighteen points.
//
// THE BASE FOURTEEN ARE THE EXCEPTION, and they are answered rather than left at zero.  A font with NO
// /Widths and a /BaseFont naming one of the fourteen is the shape every document relying on a standard
// font has, and the metrics are the FORMAT's data (PDF 1.7 Annex F) with no API on this release to hand
// them over: CGFontCreateWithFontName("Courier") answers 43.2070 for "page 1" where the host answers
// 43.2000.  So they are read out of CharonBase14Widths, measured per character and generated - see that
// file.  A font with neither /Widths nor one of the fourteen is the row's boundary, and -advanceForCode:
// answers 0 there, which is `hasWidths` answering NO.
@interface CharonPDFFontMetrics : NSObject

// nil for a font dictionary that is not there, or that names no /Widths: see the note above.
+ (nullable instancetype)metricsWithFontDictionary:(nullable CGPDFDictionaryRef)fontDictionary
                                              size:(CGFloat)size;
// The width of one code in POINTS: the /Widths entry scaled by the size over 1000, which is the unit
// /Widths is written in (PDF 1.7 Table 8.27), and 0 for a font with no /Widths.
- (CGFloat)advanceForCode:(int)code;
// The font's DESCENT scaled the same way.  This is what puts the bottom of the rect: the baseline minus
// nothing, plus the descent, which is the measurement - 360 - 230 * 12 / 1000 = 357.24 on
// cgfixture-1.pdf, against 350.76 for the ascent and 351.40 for the cap height.
@property (nonatomic, readonly) CGFloat descent;
// The size the metrics were built for, which is Tf's own operand and the height of every rect.
@property (nonatomic, readonly) CGFloat size;
// NO, for a font whose /Widths were not there: the caller says so rather than answering zeroes silently.
@property (nonatomic, readonly) BOOL hasWidths;

@end

@interface CharonPDFPageText : NSObject

// The page's -[PDFPage string], or nil for a page whose walk was DISCARDED for taking fewer shows than
// its content stream holds.  The runs and the lines are empty in that case too.
@property (nonatomic, readonly, copy, nullable) NSString *string;
// The runs, in the order the string is built from them: sorted by y DESCENDING, a tie in drawing order.
@property (nonatomic, readonly, copy) NSArray<CharonPDFTextRun *> *runs;

// Built from runs the walk already collected in DRAWING order; the ordering above is applied here, so the
// walk does not care and the string is a property of the runs rather than a second thing to keep.
+ (nullable instancetype)layoutWithRuns:(NSArray<CharonPDFTextRun *> *)drawnRuns;

// The page's text over a range, or nil for a range outside it.
- (nullable NSString *)substringForRange:(NSRange)range;

// THE RECT OVER A RANGE, which is what -[PDFSelection boundsForPage:] answers with.
//
// The union of the per-character rects the walk filled in, and nothing else: a range inside one line is
// its own characters' rects side by side, a range over two lines is their union, and because every rect
// runs from its own baseline's descent up by the size, the union of two lines twenty apart is
// 20 + 12 = 32 high and starts at the FIRST line's descent - both measured on cgfixture-lines2, where
// "two\nthree" answers 42.0384 by 32.0.
//
// CGRectNull for a range that touches no character: a page the selection does not cover never asks.
- (CGRect)boundsForRange:(NSRange)range;

// THE LINES.  A line is [start, end) in the string, and `end` is one PAST the line-break character when
// the line has one - measured: for the match "two\nthree" on cgfixture-lines2, -selectionsByLine answers
// line 0 with the range {4,4} and the string "two", so the line's RANGE carries the newline and the line's
// STRING does not.  A page with no break has one line, which is the whole string.
- (NSUInteger)numberOfLines;
- (NSRange)lineRangeAtIndex:(NSUInteger)index;
// The lines a range touches, in order, as NSValue-wrapped NSRanges.  A range inside one line answers one;
// a range across two answers two.
- (NSArray<NSValue *> *)lineRangesForRange:(NSRange)range;
// The run a character came from, or nil for an offset the string does not have.
- (nullable CharonPDFTextRun *)runForOffset:(NSUInteger)offset;

@end

// THE LINE RULE, and where it lives.  A line is trimmed of U+0020 at both ends and every run of U+0020
// inside it collapses to one - measured, and facts/PDFKit/Document11.md has the five fixtures.  It is
// applied in -[CharonPDFPageText layoutWithRuns:] rather than exposed, because the layout is the only thing that
// builds page text out of runs and it needs the CHARACTER MAPPING as well as the string: a collapse or a
// trim moves every character after it, so a run's offset into the finished string is not its offset into
// the line it was drawn in.

NS_ASSUME_NONNULL_END