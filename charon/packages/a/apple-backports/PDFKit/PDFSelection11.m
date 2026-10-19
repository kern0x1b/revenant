#import "CharonPDFKit.h"
#import "PDFPageText11.h"
#include <ctype.h>

// PDFSelection over the page's own text.  Every answer is arithmetic over the page layout: a selection is a
// list of spans, each a page and a range in that page's string, and everything below is a way of reading,
// joining or moving that list.
//
// It is here and not in PDFPage11.m because a selection belongs to no page and reads every page, and
// because the file exports PDFKit's own PDFSelection - a file whose exports a band's release already has is
// left out of that band (charon/AGENTS.md), so nothing outside this file may call anything in it.
//
// UIColor is the header's own type for the colour member (PDFSelection.h:44, PDFKitPlatform.h) and this
// translation unit only ever STORES one: it is never created here, because a port that reads documents has
// no colour to draw with and -[PDFSelection initWithDocument:] answers nil for it - measured.

// ONE SPAN: a page, the range -rangeAtIndex:onPage: answers, and the range -string reads.
//
// The two are not always the same length, and that is measured rather than designed: for the match
// "two\nthree" on cgfixture-lines2, -selectionsByLine answers line 0 with the range {4,4} and the string
// "two" - the line's RANGE carries the newline that ends it and the line's STRING does not.  So a span
// carries both, and a line's spans are built with the break left out of the text range only.
@interface CharonPDFSelectionSpan : NSObject
// The page, held STRONGLY: -pages answers the pages a selection covers, and PDFSelection.h:23 says so
// without saying the array is a weak one.  The document above it is weak on the page, so page -> selection
// -> page cannot close.
@property (nonatomic, strong) PDFPage *page;
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange textRange;
@end

@implementation CharonPDFSelectionSpan
@synthesize page = _page;
@synthesize range = _range;
@synthesize textRange = _textRange;
@end

// UIFont exists wherever a port of this library is actually used - UIKit is in every application - and not
// in a macOS process, which is one of the three binaries this harness builds.  So the font attribute is set
// where UIFont exists and the rest of the attributed string is built either way.  __has_include rather than
// a configuration flag, because the difference IS which headers the file is compiled against; and this is a
// .m file, not a package header, which is where charon/AGENTS.md forbids importing UIKit.
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#define CHARON_SELECTION_HAS_UIFONT 1
#endif

@interface PDFSelection ()
// The port's own setup, over spans the port's own searches and mutators built.  NOT an initializer: it is
// the shape -[PDFDocument initWithData:] uses with -charon_setUpWithData:, because a class whose header
// declares its own initializer as the designated one has to reach [super init] from THAT one, and the spans
// are a second thing to set afterwards.
- (void)charon_setUpWithSpans:(nullable NSArray<CharonPDFSelectionSpan *> *)spans
                      document:(nullable PDFDocument *)document;
@end

@implementation PDFSelection {
    // The spans, in page order and in range order within a page.  Ordered, because every member reads them
    // in that order and -string concatenates them in it.
    NSMutableArray<CharonPDFSelectionSpan *> *_spans;
    // The document the selection was made over, WEAK: a selection that outlives its document keeps its
    // ranges, which are numbers, and its pages, which are objects; it does not keep the document alive.
    __weak PDFDocument *_document;
    UIColor *_color;
}

// The port's own constructor, over spans the port's own searches and mutators built.  There is no other
// way in: PDFSelection.h has no -initWithRange: of any kind, and the class exists to hold what a find or a
// mutator produced.
- (void)charon_setUpWithSpans:(NSArray<CharonPDFSelectionSpan *> *)spans
                      document:(PDFDocument *)document
{
    _spans = spans != nil ? [spans mutableCopy] : [NSMutableArray array];
    _document = document;
}

- (instancetype)initWithDocument:(PDFDocument *)document
{
    self = [super init];
    if (self == nil)
        return nil;
    [self charon_setUpWithSpans:nil document:document];
    return self;
}

- (instancetype)init
{
    // The header makes -initWithDocument: the designated initializer, so a bare -init funnels into it with
    // no document: a selection with no ranges and no pages, which is what PDFSelection.h:20's own sentence
    // - "Returns and empty PDFSelection" - describes.  A convenience initializer has to reach a designated
    // one of its own class, so this is the shape the compiler asks for and the one PDFDocument11.m uses.
    return [self initWithDocument:nil];
}

// The spans on one page, in order.  The selection's own list is already in page order, so this is one pass
// and not a sort - and it is the answer -numberOfTextRangesOnPage: counts and -rangeAtIndex:onPage: indexes.
// One span of the port's own, as a search builds it.
//
// THE TEXT RANGE IS NOT ALWAYS THE RANGE, and the difference is measured rather than designed: a match that
// ends at a line break takes that break into its RANGE and leaves it out of its STRING - the host answers
// {7,4} and the string "one" for the needle "one" on cgfixture-lines.pdf, where the fourth character is the
// newline the walk joins lines with.  So every span whose range ends on a line break has a text range one
// shorter, which is the same rule -selectionsByLine's lines answer by.
- (void)charon_addSpanOnPage:(PDFPage *)page range:(NSRange)range
{
    if (page == nil || range.location == NSNotFound || range.length == 0)
        return;
    CharonPDFSelectionSpan *span = [[CharonPDFSelectionSpan alloc] init];
    span.page = page;
    span.range = range;
    span.textRange = charonTextRangeForRange(page, range);
    [_spans addObject:span];
}

- (NSArray<CharonPDFSelectionSpan *> *)charon_spansOnPage:(PDFPage *)page
{
    NSMutableArray<CharonPDFSelectionSpan *> *answer = [NSMutableArray array];
    if (page == nil)
        return answer;
    for (CharonPDFSelectionSpan *span in _spans) {
        if (span.page == page)
            [answer addObject:span];
    }
    return answer;
}

// A span's TEXT range: its range, less the line break at the end of it when there is one.  Measured, and the
// two places that need it are a match that ends at a break and a line selection, which is why it is a
// function of the page and the range and not a thing each of them works out.
static NSRange charonTextRangeForRange(PDFPage *page, NSRange range)
{
    NSRange textRange = range;
    if (page == nil || textRange.length == 0)
        return textRange;
    NSString *text = [page charon_textLayout].string;
    NSUInteger last = NSMaxRange(textRange);
    if (text != nil && last <= text.length && [text characterAtIndex:last - 1] == '\n')
        textRange.length -= 1;
    return textRange;
}

// The pages of a selection are "sorted by page index" (PDFSelection.h:23), and the port's own -[PDFPage
// pageIndex] is that number: the index -[PDFDocument pageAtIndex:] was handed.  It is the port's own member
// - the host's PDFPage has no -pageIndex of its own, which is why that row is inert - so using it here keeps
// this family off PDFDocument's other members, which are another worker's.
- (NSUInteger)charon_pageIndexOf:(PDFPage *)page
{
    return page.pageIndex;
}

- (NSArray<PDFPage *> *)pages
{
    NSMutableArray<PDFPage *> *answer = [NSMutableArray array];
    PDFPage *last = nil;
    for (CharonPDFSelectionSpan *span in _spans) {
        if (span.page != last) {
            [answer addObject:span.page];
            last = span.page;
        }
    }
    return answer;
}

- (NSString *)string
{
    if (_spans.count == 0)
        return nil;                    // measured: a fresh selection answers nil, not an empty string
    NSMutableString *answer = [NSMutableString string];
    PDFPage *page = nil;
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        if (span.page != page) {
            // BETWEEN PAGES the texts are joined with a newline and WITHIN a page with nothing, both
            // measured: a selection over "page 2" and "page 3" answers "page 2\npage 3", and one over
            // "zero" and "alpha bra" answers "zeroalpha bra".
            if (page != nil)
                [answer appendString:@"\n"];
            page = span.page;
        }
        NSString *piece = [layout substringForRange:span.textRange];
        if (piece != nil)
            [answer appendString:piece];
    }
    return answer;
}

- (NSAttributedString *)attributedString
{
    NSString *text = [self string];
    if (text == nil)
        return nil;                    // measured: a fresh selection's attributed string is nil
    NSMutableAttributedString *answer = [[NSMutableAttributedString alloc] initWithString:text];
#ifdef CHARON_SELECTION_HAS_UIFONT
    // The font is the one the walk recorded: the name Tf named and the size beside it.  Measured, the host
    // answers "Helvetica" at 12pt for every fixture drawn with /TT1 12 Tf, and one attribute run over the
    // whole string.  It is applied per span, because a span knows the run its first character came from and
    // a selection can cross runs and pages.
    NSUInteger at = 0;
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        CharonPDFTextRun *run = [layout runForOffset:span.textRange.location];
        NSUInteger length = span.textRange.length;
        if (run == nil || length == 0)
            continue;
        NSString *name = run.fontName;
        if (name.length == 0)
            continue;
        UIFont *font = [UIFont fontWithName:name size:run.size];
        if (font != nil)
            [answer addAttribute:NSFontAttributeName value:font range:NSMakeRange(at, length)];
        at += length;
    }
#endif
    return answer;
}

- (NSUInteger)numberOfTextRangesOnPage:(PDFPage *)page
{
    return [self charon_spansOnPage:page].count;
}

- (NSRange)rangeAtIndex:(NSUInteger)index onPage:(PDFPage *)page
{
    NSArray<CharonPDFSelectionSpan *> *spans = [self charon_spansOnPage:page];
    // Measured, both answers and neither of them a raise: an index past the end of a page's ranges, and any
    // index on a page the selection does not cover, answer {NSNotFound, 0}.
    if (index >= spans.count)
        return NSMakeRange(NSNotFound, 0);
    return spans[index].range;
}

- (CGRect)boundsForPage:(PDFPage *)page
{
    // A PAGE THE SELECTION DOES NOT COVER answers CGRectNull, which is the +inf,+inf,0,0 the host
    // answers and which is what "no bounds" IS in CoreGraphics: measured, and it is the same value for
    // every page a selection misses and for a fresh selection's every page.
    //
    // Reading a nonnull parameter is not tested against NULL: the port's rule (QUEUE.md, v-tail-a6) is
    // that a NULL test of a parameter the header declares nonnull is made through a volatile read, or
    // not at all, so this answers CGRectNull for a nil page without a NULL test at all.
    NSArray<CharonPDFSelectionSpan *> *spans = [self charon_spansOnPage:page];
    if (spans.count == 0)
        return CGRectNull;
    // The union over EVERY range the selection has on this page, and not just the first: two ranges on
    // one page are one rect, and the union is the only shape that says so.  The spans do not overlap -
    // -addSelection: removes overlaps - so the union is also the tightest rect over both.
    CGRect answer = CGRectNull;
    for (CharonPDFSelectionSpan *span in spans) {
        // The RANGE and not the text range: a match that takes the line break after it has a range one
        // character longer than its text, and the break is a position on the page with no glyph, so
        // including it changes nothing - which is measured rather than argued, because the host's rect
        // for the needle "one" on cgfixture-lines.pdf is over the range that carries the break.
        CGRect rect = [[span.page charon_textLayout] boundsForRange:span.range];
        if (CGRectIsNull(rect))
            continue;
        answer = CGRectIsNull(answer) ? rect : CGRectUnion(answer, rect);
    }
    return answer;
}

- (NSArray<PDFSelection *> *)selectionsByLine
{
    NSMutableArray<PDFSelection *> *answer = [NSMutableArray array];
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        NSArray<NSValue *> *lines = [layout lineRangesForRange:span.range];
        for (NSValue *boxed in lines) {
            NSRange hit = [boxed rangeValue];
            CharonPDFSelectionSpan *line = [[CharonPDFSelectionSpan alloc] init];
            line.page = span.page;
            line.range = hit;
            // The line's STRING stops before the break that ends it, while its RANGE carries it: measured,
            // line 0 of the match "two\nthree" answers {4,4} and the string "two".
            line.textRange = charonTextRangeForRange(span.page, hit);
            PDFSelection *selection = [[PDFSelection alloc] initWithDocument:_document];
            [selection charon_setUpWithSpans:@[ line ] document:_document];
            [answer addObject:selection];
        }
    }
    return answer;
}

- (UIColor *)color
{
    return _color;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
}

#pragma mark - the mutators

// The spans of the two selections, as ONE ordered list with the overlaps removed - which is what the header
// says happens when the selection added overlaps this one: the overlapping parts are removed (PDFSelection.h:67).
// Measured over five shapes: an added span INSIDE one of these is dropped, a crossing one is kept whole, and
// two spans with a space between them stay two spans - so the merge is by OVERLAP and not by adjacency.
- (void)charon_unionWith:(NSArray<CharonPDFSelectionSpan *> *)other
{
    if (other.count == 0)
        return;
    NSMutableArray<CharonPDFSelectionSpan *> *merged = [NSMutableArray arrayWithArray:_spans];
    [merged addObjectsFromArray:other];
    [merged sortUsingComparator:^NSComparisonResult(CharonPDFSelectionSpan *a, CharonPDFSelectionSpan *b) {
        NSUInteger left = [self charon_pageIndexOf:a.page];
        NSUInteger right = [self charon_pageIndexOf:b.page];
        if (left != right)
            return left < right ? NSOrderedAscending : NSOrderedDescending;
        if (a.range.location < b.range.location)
            return NSOrderedAscending;
        if (a.range.location > b.range.location)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray<CharonPDFSelectionSpan *> *answer = [NSMutableArray array];
    for (CharonPDFSelectionSpan *span in merged) {
        CharonPDFSelectionSpan *last = answer.lastObject;
        if (last != nil && last.page == span.page && NSMaxRange(last.range) >= span.range.location &&
            span.range.location <= NSMaxRange(last.range)) {
            // OVERLAPPING or touching on the SAME page: the union is the wider range, and its text range is
            // the wider one too, because the text of a selection is the concatenation of its spans'.
            NSUInteger start = MIN(last.range.location, span.range.location);
            NSUInteger end = MAX(NSMaxRange(last.range), NSMaxRange(span.range));
            last.range = NSMakeRange(start, end - start);
            last.textRange = NSMakeRange(start, end - start);
            continue;
        }
        [answer addObject:span];
    }
    [_spans setArray:answer];
}

- (void)addSelection:(PDFSelection *)selection
{
    // The host raises NSGenericException "addSelection: selection document mismatch" when the selection comes
    // from a different document, even one opened on the same file (measured).  The port answers the same: the
    // check is on the DOCUMENT and not on the text, because the header says a selection is "a range of text
    // on one or many pages" of one document.
    if (selection == nil)
        return;
    if (selection->_document != nil && _document != nil && selection->_document != _document)
        [NSException raise:NSGenericException
                    format:@"addSelection: selection document mismatch"];
    [self charon_unionWith:selection->_spans];
}

- (void)addSelections:(NSArray<PDFSelection *> *)selections
{
    // All of them are added and the overlaps are removed ONCE at the end, which is the whole difference
    // -addSelections: names over a loop of -addSelection: (PDFSelection.h:73).  Measured: three selections in
    // one call all land.
    NSMutableArray<CharonPDFSelectionSpan *> *spans = [NSMutableArray array];
    for (PDFSelection *selection in selections) {
        if (selection == nil)
            continue;
        if (selection->_document != nil && _document != nil && selection->_document != _document)
            [NSException raise:NSGenericException
                        format:@"addSelection: selection document mismatch"];
        [spans addObjectsFromArray:selection->_spans];
    }
    [self charon_unionWith:spans];
}

// The page after one, and the page before one, in the DOCUMENT's order.  A nil answer means there is no such
// page, which is what stops an extend at the last page (measured: extending the last page's match by 20
// characters changes nothing).
- (PDFPage *)charon_pageAfter:(PDFPage *)page
{
    PDFDocument *document = page.document;
    if (document == nil)
        return nil;
    NSUInteger at = [self charon_pageIndexOf:page];
    if (at + 1 >= document.pageCount)
        return nil;
    return [document pageAtIndex:at + 1];
}

- (PDFPage *)charon_pageBefore:(PDFPage *)page
{
    PDFDocument *document = page.document;
    if (document == nil)
        return nil;
    NSUInteger at = [self charon_pageIndexOf:page];
    if (at == 0)
        return nil;
    return [document pageAtIndex:at - 1];
}

// A selection's last span's end, or its first span's start, and WHICH PAGE they are on - the two facts every
// extend needs, because an extend can run off the end of a page onto the next one.
- (CharonPDFSelectionSpan *)charon_lastSpan
{
    return _spans.lastObject;
}

- (void)charon_extendEndBy:(NSInteger)count
{
    if (_spans.count == 0 || count == 0)
        return;
    while (count != 0) {
        CharonPDFSelectionSpan *last = [self charon_lastSpan];
        if (last == nil)
            return;
        CharonPDFPageText *layout = [last.page charon_textLayout];
        NSUInteger length = layout.string.length;
        NSInteger room = (NSInteger)(length - NSMaxRange(last.range));
        if (count > 0) {
            NSInteger take = MIN(count, room);
            last.range = NSMakeRange(last.range.location, last.range.length + (NSUInteger)take);
            last.textRange = last.range;
            count -= take;
            if (count == 0)
                return;
            PDFPage *next = [self charon_pageAfter:last.page];
            if (next == nil)
                return;                          // the last page: measured, nothing changes
            CharonPDFSelectionSpan *span = [[CharonPDFSelectionSpan alloc] init];
            span.page = next;
            span.range = NSMakeRange(0, 0);
            span.textRange = NSMakeRange(0, 0);
            [_spans addObject:span];
            continue;
        }
        NSInteger give = MIN(-count, (NSInteger)last.range.length);
        last.range = NSMakeRange(last.range.location, last.range.length - (NSUInteger)give);
        last.textRange = last.range;
        count += give;
        if (count == 0)
            return;
        if (last.range.length == 0) {
            [_spans removeObject:last];
            continue;
        }
        return;
    }
}

- (void)charon_extendStartBy:(NSInteger)count
{
    if (_spans.count == 0 || count == 0)
        return;
    while (count != 0) {
        CharonPDFSelectionSpan *first = _spans.firstObject;
        if (first == nil)
            return;
        if (count > 0) {
            NSInteger room = (NSInteger)first.range.location;
            NSInteger take = MIN(count, room);
            first.range = NSMakeRange(first.range.location - (NSUInteger)take, first.range.length + (NSUInteger)take);
            first.textRange = first.range;
            count -= take;
            if (count == 0)
                return;
            PDFPage *previous = [self charon_pageBefore:first.page];
            if (previous == nil)
                return;                          // the first page: measured, nothing changes
            CharonPDFPageText *layout = [previous charon_textLayout];
            CharonPDFSelectionSpan *span = [[CharonPDFSelectionSpan alloc] init];
            span.page = previous;
            NSUInteger end = layout.string.length;
            span.range = NSMakeRange(end, 0);
            span.textRange = NSMakeRange(end, 0);
            [_spans insertObject:span atIndex:0];
            continue;
        }
        NSInteger give = MIN(-count, (NSInteger)first.range.length);
        first.range = NSMakeRange(first.range.location + (NSUInteger)give, first.range.length - (NSUInteger)give);
        first.textRange = first.range;
        count += give;
        if (count == 0)
            return;
        if (first.range.length == 0) {
            [_spans removeObject:first];
            continue;
        }
        return;
    }
}

- (void)extendSelectionAtEnd:(NSInteger)succeed
{
    [self charon_extendEndBy:succeed];
}

- (void)extendSelectionAtStart:(NSInteger)precede
{
    [self charon_extendStartBy:precede];
}

- (void)extendSelectionForLineBoundaries
{
    // The header says the selection reaches from the start to the finish of the selected lines of text, and that on a
    // single line it is extended to the full line width (PDFSelection.h:79).  Measured: inside
    // one line of cgfixture-words the whole 36 characters, and across two lines that already contain their
    // rows of text, no change at all.
    if (_spans.count == 0)
        return;
    CharonPDFSelectionSpan *first = _spans.firstObject;
    CharonPDFPageText *firstLayout = [first.page charon_textLayout];
    NSArray<NSValue *> *firstLines = [firstLayout lineRangesForRange:first.range];
    if (firstLines.count > 0)
        first.range = [[firstLines firstObject] rangeValue];
    CharonPDFSelectionSpan *last = [self charon_lastSpan];
    CharonPDFPageText *lastLayout = [last.page charon_textLayout];
    NSArray<NSValue *> *lastLines = [lastLayout lineRangesForRange:last.range];
    if (lastLines.count > 0)
        last.range = [[lastLines lastObject] rangeValue];
    // The text ranges follow the ranges, EXCEPT at a line's trailing break: a line's string stops before it,
    // which is the same rule -selectionsByLine answers with.
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        NSRange textRange = span.range;
        NSUInteger last2 = NSMaxRange(textRange);
        if (last2 > textRange.location && last2 <= layout.string.length &&
            [layout.string characterAtIndex:last2 - 1] == '\n')
            textRange.length -= 1;
        span.textRange = textRange;
    }
}

#pragma mark - NSCopying

// A DEEP copy, which is what the host answers: extending a copy left the selection it was copied from at
// {5,5} and moved the copy to {5,8}, and two copies are two objects (measured).
- (id)copyWithZone:(NSZone *)zone
{
    NSMutableArray<CharonPDFSelectionSpan *> *spans = [NSMutableArray arrayWithCapacity:_spans.count];
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFSelectionSpan *copy = [[CharonPDFSelectionSpan alloc] init];
        copy.page = span.page;
        copy.range = span.range;
        copy.textRange = span.textRange;
        [spans addObject:copy];
    }
    PDFSelection *copy = [[PDFSelection alloc] initWithDocument:_document];
    [copy charon_setUpWithSpans:spans document:_document];
    copy->_color = _color;
    return copy;
}

@end