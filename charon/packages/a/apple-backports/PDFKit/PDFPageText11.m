#import "PDFPageText11.h"

// The page's text as three views of one walk.  Everything here is arithmetic over the runs the walk
// collected: the string, where each run's text begins in it, and where the line breaks are.  No rule of
// its own is decided here - the rules (a control byte in a run is a NUL, a line is trimmed, the runs of
// spaces inside a line collapse to one, a line ends with the break that joins it to the next) are the
// walk's and are written down in facts/PDFKit/Document11.md.

@implementation CharonPDFTextRun {
    // ONE RECT PER CHARACTER of `text`, in the order the characters were drawn, owned by the run.  They
    // are the substrate of -[PDFSelection boundsForPage:] and they are here rather than in the category
    // below because a CATEGORY CANNOT ADD AN IVAR - it would be a compile error, and the accessor pair
    // exists only so that the walk, which is in another file, can hand them over.
    CGRect *_charon_rects;
    NSUInteger _charon_rectCount;
}@synthesize text = _text;
@synthesize offset = _offset;
@synthesize x = _x;
@synthesize y = _y;
@synthesize size = _size;
@synthesize fontName = _fontName;

- (void)dealloc
{
    free(_charon_rects);
}

@end

// A run's per-character rects, as a C array the run OWNS.  Copied rather than pointed at, because the
// walk builds them on the stack of a callback and the run outlives that stack by a long way.
@implementation CharonPDFTextRun (CharonGeometry)

- (void)charon_setGlyphRects:(const CGRect *)rects count:(NSUInteger)count
{
    free(_charon_rects);
    _charon_rects = NULL;
    _charon_rectCount = 0;
    if (rects == NULL || count == 0)
        return;
    _charon_rects = malloc(sizeof(CGRect) * count);
    if (_charon_rects == NULL)
        return;                                 // a run with no rects, which the union skips
    memcpy(_charon_rects, rects, sizeof(CGRect) * count);
    _charon_rectCount = count;
}

- (CGRect)rectAtIndex:(NSUInteger)index
{
    if (_charon_rects == NULL || index >= _charon_rectCount)
        return CGRectNull;
    return _charon_rects[index];
}

@end

// THE FONT OF A RUN, read out of the page's own /Resources at the moment Tf named it.
//
// Two numbers out of the document and nothing else: the width of a code from /Widths, and the descent
// from the descriptor's /Descent.  Both are scaled by the size over 1000, because that is the unit
// PDF 1.7 writes both in (Table 8.27 for /Widths, Table 8.20 for /Descent).
//
// AND, FOR A FONT WITH NO /Widths, THE STANDARD FOURTEEN'S OWN METRICS, which is not in the document at
// all: it is normative data of PDF 1.7 Annex F and it lives in Base14Widths11.m, measured rather than
// transcribed.  That is the one case /Widths alone cannot answer, and it is the common one - a document
// relying on Helvetica or Courier usually carries no /Widths.
//
// The reader the SDK offers for it is NOT used, and the measurement is why: CGFontCreateWithFontName
// answers 43.2070 for "page 1" in Courier where the host answers 43.2000.  Nor is the embedded program,
// read through CGFontCreateWithDataProvider: it answers 36.7031 for the six characters of "page 1" where
// the host answers the /Widths' 72.0000 and 18.0000 on fixtures that disagree with it by eighteen points.
// Neither is read, and facts/PDFKit/Selection11.md has the table both refutations come from.
// The standard fourteen's metrics, over a Charon-prefixed class rather than over C functions: the release
// check reads a translation unit's exported symbols and exempts a Charon-prefixed object, so three
// lowercase C functions with `charon` in their names were reported as API no single release introduced.
// Measured on BP_LIBRARY=PDFKitBackports, and the call is in the header rather than here because this
// file and Base14Widths11.m are both in every band.
@interface CharonBase14Widths : NSObject
+ (int)widthForCode:(int)code inFaceNamed:(const char *)name;
+ (double)descentForFaceNamed:(const char *)name;
@end

@implementation CharonPDFFontMetrics {
    // The /Widths entries, copied out of the document's array and ALREADY scaled to points, so a
    // character's advance is one array read and no arithmetic per character.  nil when the font has no
    // /Widths at all, which is when the base-fourteen table answers instead.
    NSArray<NSNumber *> *_advances;
    // /FirstChar, the code the first entry belongs to.  The index of a code is code - firstChar, and a
    // code outside the array's span has no width - which is what /LastChar does without being read.
    CGPDFInteger _firstChar;
    // THE STANDARD FOURTEEN'S FACE NAME, /BaseFont with the subset prefix stripped, and nil for any other
    // font.  Held as a C string rather than an NSString because it is only ever compared with strcmp
    // against the table's own names, and a substring of the document's name is not a name of its own.
    char *_faceName;
}

@synthesize descent = _descent;
@synthesize size = _size;
@synthesize hasWidths = _hasWidths;

+ (instancetype)metricsWithFontDictionary:(CGPDFDictionaryRef)fontDictionary size:(CGFloat)size
{
    if (fontDictionary == NULL)
        return nil;
    CharonPDFFontMetrics *metrics = [[CharonPDFFontMetrics alloc] init];
    metrics->_size = size;
    metrics->_firstChar = 0;
    CGPDFDictionaryGetInteger(fontDictionary, "FirstChar", &metrics->_firstChar);

    // /Widths, read as INTEGERS: CGPDFArrayGetInteger is what the SDK declares (CGPDFArray.h:51) and
    // there is no CGPDFArrayGetDouble in it at all, which is why this is not written the other way.
    CGPDFArrayRef widths = NULL;
    if (CGPDFDictionaryGetArray(fontDictionary, "Widths", &widths) && widths != NULL) {
        size_t count = CGPDFArrayGetCount(widths);
        NSMutableArray<NSNumber *> *scaled = [NSMutableArray arrayWithCapacity:count];
        CGFloat units = size / 1000.0;
        for (size_t i = 0; i < count; i++) {
            long width = 0;
            if (!CGPDFArrayGetInteger(widths, i, &width))
                width = 0;
            [scaled addObject:@((CGFloat)width * units)];
        }
        metrics->_advances = [scaled copy];
    }

    // The DESCENT, from the descriptor.  A font with no descriptor and no /Widths carries neither, and
    // then the descent is 0 and the rect sits ON the baseline: measured fixtures all carry one, and the
    // row says what happens when one is missing rather than inventing a value.
    // /BaseFont, with the subset prefix stripped, kept for the two things the /Widths above did not
    // answer.  "AAAAAB+Helvetica" is a SUBSET of Helvetica and not a face of its own, so the
    // six-character prefix and its plus are removed before the name is looked for - measured, not
    // assumed: the fixtures write both spellings and only the stripped one names a standard face.
    const char *base = NULL;
    if (CGPDFDictionaryGetName(fontDictionary, "BaseFont", &base) && base != NULL) {
        const char *face = base;
        if (strlen(face) > 7 && face[6] == '+')
            face += 7;
        size_t length = strlen(face);
        metrics->_faceName = malloc(length + 1);
        if (metrics->_faceName != NULL)
            memcpy(metrics->_faceName, face, length + 1);
    }

    // THE DESCENT, which puts the bottom of every rect, and which has TWO sources.  The descriptor's
    // /Descent when the font carries a descriptor - cgfixture-1.pdf's is -230, and 360 - 230 * 12 / 1000 =
    // 357.24, the host's answer to every digit.  The FACE'S OWN when it does not, which is the common
    // case: every fixture make-object-fixtures.py writes has no descriptor at all, and there the host
    // answers 717.2402 for a line drawn at 720, so a descent of 0 would be 2.76pt out.
    //
    // /Descent may be a real number, and the SDK's dictionary reader has no GetDouble for one:
    // CGPDFDictionaryGetNumber (CGPDFDictionary.h) is the reader and it answers the value whatever its
    // type was written as.  CGPDFReal, which is CGFloat and NOT double on armv7.
    CGFloat descent = 0;
    CGPDFDictionaryRef descriptor = NULL;
    if (CGPDFDictionaryGetDictionary(fontDictionary, "FontDescriptor", &descriptor) &&
        descriptor != NULL) {
        CGPDFReal value = 0;
        if (CGPDFDictionaryGetNumber(descriptor, "Descent", &value))
            descent = (CGFloat)value * (size / 1000.0);
    }
    if (descent == 0 && metrics->_faceName != nil)
        descent = (CGFloat)[CharonBase14Widths descentForFaceNamed:metrics->_faceName] * (size / 1000.0);
    metrics->_descent = descent;
    metrics->_hasWidths = metrics->_advances != nil || metrics->_faceName != nil;
    return metrics;
}

- (void)dealloc
{
    free(_faceName);
}

- (CGFloat)advanceForCode:(int)code
{
    if (_advances != nil) {
        long at = (long)code - (long)_firstChar;
        if (at < 0 || (size_t)at >= _advances.count)
            return 0;               // outside the /Widths span: no width, not the first or the last one
        return (CGFloat)[[_advances objectAtIndex:(NSUInteger)at] doubleValue];
    }
    if (_faceName == nil)
        return 0;                   // no /Widths and not a standard fourteen: no advance this port can reach
    int width = [CharonBase14Widths widthForCode:code inFaceNamed:_faceName];
    if (width < 0)
        return 0;                   // a code outside the measured span, or a face the table does not carry
    return (CGFloat)width * _size / 1000.0;
}

@end

@implementation CharonPDFPageText {
    // The offsets of the line-break characters in _string, ascending.  Computed once, because a
    // selection asks for a line range per line and a page with many lines would otherwise walk them again.
    NSUInteger *_breaks;
    NSUInteger _breakCount;
    // WHERE EACH CHARACTER CAME FROM: one entry per character of every run's own text, holding the
    // offset it ended up at in _string, or NSNotFound for a character the line rule dropped.  It is
    // what -boundsForRange: walks, and it is built where the mapping already is - inside closeLine -
    // rather than recomputed, because the mapping a collapse or a trim uses is the reverse direction.
    NSArray<NSNumber *> *_charOffsets;
}

@synthesize string = _string;
@synthesize runs = _runs;

// ONE LINE, closed: trimmed at both ends, every run of U+0020 inside it collapsed to one, and the
// mapping back to where each kept character was, because a collapse or a trim moves every character
// after it and a run's offset has to be its offset into the FINISHED string.
//
// The two halves of the rule are measured over five fixtures and the mapping is not a rule at all, it is
// the arithmetic: facts/PDFKit/Document11.md has the table, and this is the only place it is applied.
static NSString *charonCloseLine(NSString *line, NSUInteger **mapping, NSUInteger *mappingCount)
{
    NSUInteger length = line.length;
    NSUInteger start = 0;
    NSUInteger end = length;
    while (start < end && [line characterAtIndex:start] == ' ')
        start++;
    while (end > start && [line characterAtIndex:end - 1] == ' ')
        end--;
    NSMutableString *closed = [NSMutableString stringWithCapacity:end - start];
    NSMutableArray<NSNumber *> *from = [NSMutableArray arrayWithCapacity:end - start];
    BOOL afterSpace = NO;
    for (NSUInteger i = start; i < end; i++) {
        unichar c = [line characterAtIndex:i];
        if (c == ' ') {
            if (afterSpace)
                continue;                       // collapsed away, and nothing after it moves either
            afterSpace = YES;
        } else {
            afterSpace = NO;
        }
        [closed appendFormat:@"%C", c];
        [from addObject:@(i)];
    }
    *mappingCount = from.count;
    if (from.count > 0) {
        *mapping = malloc(sizeof(NSUInteger) * from.count);
        if (*mapping == NULL) {
            *mappingCount = 0;
            return nil;
        }
        for (NSUInteger i = 0; i < from.count; i++)
            (*mapping)[i] = [[from objectAtIndex:i] unsignedIntegerValue];
    }
    return closed;
}

+ (instancetype)layoutWithRuns:(NSArray<CharonPDFTextRun *> *)drawnRuns
{
    if (drawnRuns == nil)
        return nil;
    CharonPDFPageText *layout = [[CharonPDFPageText alloc] init];
    NSArray<CharonPDFTextRun *> *ordered = [drawnRuns sortedArrayWithOptions:NSSortStable
                                                        usingComparator:^NSComparisonResult(id a, id b) {
        CharonPDFTextRun *left = a, *right = b;
        if (left.y > right.y)
            return NSOrderedAscending;      // higher on the page first
        if (left.y < right.y)
            return NSOrderedDescending;
        return NSOrderedSame;                // a tie keeps drawing order
    }];
    NSMutableString *text = [NSMutableString string];
    NSMutableArray<CharonPDFTextRun *> *runs = [NSMutableArray arrayWithCapacity:ordered.count];
    NSMutableArray<NSNumber *> *breaks = [NSMutableArray array];
    // WHERE EACH CHARACTER ENDED UP, in the same order the runs are, and built by the same pass that
    // remaps the runs' offsets - see _charOffsets.
    NSMutableArray<NSNumber *> *charOffsets = [NSMutableArray array];
    // The line being built, and the runs in it with their offsets INSIDE it - which are not their offsets
    // in the string, because the line is trimmed and collapsed when it closes.
    NSMutableString *line = [NSMutableString string];
    NSMutableArray<CharonPDFTextRun *> *lineRuns = [NSMutableArray array];
    CGFloat previousY = 0;
    BOOL first = YES;
    // Close the line, put it in the string, and hand every run in it the offset it ends up at.
    void (^closeLine)(void) = ^{
        NSUInteger *mapping = NULL;
        NSUInteger mappingCount = 0;
        NSString *closed = charonCloseLine(line, &mapping, &mappingCount);
        NSUInteger lineStart = text.length;
        if (closed != nil)
            [text appendString:closed];
        for (CharonPDFTextRun *run in lineRuns) {
            // The run's first character INSIDE THE LINE, which is the index `mapping` is written against.
            // It is read BEFORE the remap and kept, because the remap overwrites run->offset with the
            // FINISHED string's offset and reading it afterwards indexes the mapping with a number from
            // the other coordinate system.  That was the bug this line is here for, and it showed up as a
            // rect that started two characters into the line and moved when the file was recompiled -
            // the mapping had already been freed and the numbers were whatever was on the heap.
            NSUInteger base = run.offset;
            run.offset = mappingCount > base && base != NSUIntegerMax ? lineStart + mapping[base]
                                                                     : lineStart;
            [runs addObject:run];
            // AND WHERE EACH OF ITS CHARACTERS WENT, with the same base.  A character the trim or the
            // collapse dropped has no offset of its own and gets NSNotFound, which is what
            // -boundsForRange: skips: its rect is real and the walk filled it in, but no range can name it.
            NSUInteger length = run.text.length;
            for (NSUInteger i = 0; i < length; i++) {
                NSUInteger at = base + i;
                if (mappingCount > at && at != NSUIntegerMax)
                    [charOffsets addObject:@(lineStart + mapping[at])];
                else
                    [charOffsets addObject:@(NSNotFound)];            }
        }
        // AFTER both loops: the second one reads the mapping, and freeing it before that is what made the
        // answer depend on the heap.
        free(mapping);        [lineRuns removeAllObjects];
        [line setString:@""];
    };
    for (CharonPDFTextRun *run in ordered) {
        if (run.text == nil || run.text.length == 0)
            continue;
        if (!first && run.y != previousY) {
            closeLine();
            [breaks addObject:@(text.length)];       // the break character goes here
            [text appendString:@"\n"];
        }
        // A tie on y joins with NOTHING, so the line so far is not re-trimmed as it grows - measured, and
        // re-trimming it is what would turn "alpha " + "beta" into "alphabeta".
        run.offset = line.length;
        [line appendString:run.text];
        [lineRuns addObject:run];
        previousY = run.y;
        first = NO;
    }
    if (!first)
        closeLine();
    layout->_string = [text copy];
    layout->_runs = [runs copy];
    layout->_charOffsets = [charOffsets copy];
    layout->_breakCount = breaks.count;
    if (breaks.count > 0) {
        layout->_breaks = malloc(sizeof(NSUInteger) * breaks.count);
        if (layout->_breaks == NULL) {
            layout->_breakCount = 0;
        } else {
            for (NSUInteger i = 0; i < breaks.count; i++)
                layout->_breaks[i] = [[breaks objectAtIndex:i] unsignedIntegerValue];
        }
    }
    return layout;
}

- (void)dealloc
{
    free(_breaks);
}

- (NSUInteger)numberOfLines
{
    if (_string == nil || _string.length == 0)
        return 0;
    return _breakCount + 1;
}

- (NSRange)lineRangeAtIndex:(NSUInteger)index
{
    if (_string == nil || index >= [self numberOfLines])
        return NSMakeRange(NSNotFound, 0);
    NSUInteger start = 0;
    for (NSUInteger i = 0; i < index; i++)
        start = _breaks[i] + 1;
    NSUInteger end = index < _breakCount ? _breaks[index] + 1 : (NSUInteger)_string.length;
    return NSMakeRange(start, end - start);
}

- (NSArray<NSValue *> *)lineRangesForRange:(NSRange)range
{
    NSMutableArray<NSValue *> *answer = [NSMutableArray array];
    if (_string == nil || range.location >= _string.length || range.length == 0)
        return answer;
    for (NSUInteger i = 0; i < [self numberOfLines]; i++) {
        NSRange line = [self lineRangeAtIndex:i];
        if (line.location == NSNotFound)
            break;
        NSRange hit = NSIntersectionRange(line, range);
        if (hit.length > 0)
            [answer addObject:[NSValue valueWithRange:hit]];
    }
    return answer;
}

- (CGRect)boundsForRange:(NSRange)range
{
    // The union of the characters the range names, and nothing else.  Not the union of the RUNS: a
    // selection over one word of a line is that word's own characters, and a run's rect is its whole
    // drawn text, which is the line in the overwhelming majority of cases.
    if (_string == nil || range.location == NSNotFound || range.length == 0)
        return CGRectNull;
    NSUInteger first = range.location;
    NSUInteger last = NSMaxRange(range);
    CGRect answer = CGRectNull;
    NSUInteger at = 0;
    for (CharonPDFTextRun *run in _runs) {
        NSUInteger count = run.text.length;
        for (NSUInteger i = 0; i < count && at < _charOffsets.count; i++, at++) {
            NSUInteger offset = [[_charOffsets objectAtIndex:at] unsignedIntegerValue];
            if (offset == NSNotFound || offset < first || offset >= last)
                continue;                       // dropped by the line rule, or outside the range
            CGRect rect = [run rectAtIndex:i];
            if (CGRectIsNull(rect))
                continue;                       // a run whose font resolved to nothing
            answer = CGRectIsNull(answer) ? rect : CGRectUnion(answer, rect);
        }
    }
    return answer;
}

- (NSString *)substringForRange:(NSRange)range
{
    if (_string == nil || range.location == NSNotFound || range.length == 0)
        return nil;
    if (range.location + range.length > _string.length)
        return nil;
    return [_string substringWithRange:range];
}

- (CharonPDFTextRun *)runForOffset:(NSUInteger)offset
{
    if (_string == nil || offset >= _string.length)
        return nil;
    for (CharonPDFTextRun *run in _runs) {
        if (offset >= run.offset && offset < run.offset + run.text.length)
            return run;
    }
    return nil;
}

@end