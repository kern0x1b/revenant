// What the HOST's -findString:withOptions: answers for every (fixture, needle) row of the
// word-boundary family, printed so a rule can be told from the answers rather than guessed.
//
//   xcrun clang -fobjc-arc -Wall tools/host-find.m -framework Foundation -framework PDFKit -o host-find
//   ./host-find <fixtures-dir>
//
// One line per row:  <fixture>  <needle, controls shown>  <count>  then per selection the string it
// covers (controls shown again - a range that takes a newline looks identical to one that does not if
// the newline is printed raw), the page indices, the range on page 0 and the bounds.
//
// The ranges are what the rule is made of, so they are printed as LOCATIONS {offset,length} rather than
// as text: a rule about characters has to be checked in the coordinates it claims to be about.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <PDFKit/PDFKit.h>
#include <stdio.h>

// The rows of the family.  The first block is the needle's POSITION on the line, the second its
// WHITESPACE, the third its PAGE: every row is one variable, and the fixture beside it is drawn by
// make-text-fixture.m through the same conforming writer as every other fixture in the harness.
typedef struct {
    const char *fixture;
    const char *needle;
    NSStringCompareOptions options;
} Row;

static NSString *visible(NSString *text)
{
    if (text == nil)
        return @"(nil)";
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '\n') [out appendString:@"\\n"];
        else if (c == '\r') [out appendString:@"\\r"];
        else if (c == '\t') [out appendString:@"\\t"];
        else [out appendFormat:@"%C", c];
    }
    return out;
}

// The fixtures directory main() is walking, so the helper below can build a path of its own.
static NSString *fixturesDirectory;

// Everything a selection can be asked, printed the one way: its string with the control characters
// visible, the pages it covers, and EVERY range on every one of those pages.  A selection that holds
// more than one range is a different object from one that holds a single one, and the count and the
// ranges are the only way to see which one this is.
static void printSelectionState(const char *label, PDFSelection *selection, PDFDocument *document)
{
    printf("%-26s string=%-18s pages=%lu", label,
           selection ? visible(selection.string).UTF8String : "(nil)",
           (unsigned long)selection.pages.count);
    for (NSUInteger p = 0; p < selection.pages.count; p++) {
        PDFPage *page = selection.pages[p];
        printf("  page%lu:", (unsigned long)[document indexForPage:page]);
        for (NSUInteger i = 0; i < [selection numberOfTextRangesOnPage:page]; i++)
            printf(" {%lu,%lu}", (unsigned long)[selection rangeAtIndex:i onPage:page].location,
                   (unsigned long)[selection rangeAtIndex:i onPage:page].length);
    }
    printf("  byLine=%lu\n", (unsigned long)selection.selectionsByLine.count);
}

// The fifth row of the mutator table needs a selection that was never in a find, so this builds one the
// way PDFSelection.h:20 says a caller does: -initWithDocument: is the container the mutators fill.
static PDFDocument *openFixture(const char *fixture)
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", fixturesDirectory, @(fixture)];
    return [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
}

// A NIL selection on a document that has already been searched is not the same question as one on a
// document that has not: a search leaves a cursor behind, and this asks for the two steps a caller makes
// in sequence - a find, then a continue-from-nil - with the needle of each named separately, so a state
// carried from one needle to the other is visible rather than guessed at.
static void afterSearch(const char *fixture, const char *searched, const char *thenNeedle,
                        unsigned searches)
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", fixturesDirectory, @(fixture)];
    PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
    if (document == nil) { printf("%-24s NO DOCUMENT\n", fixture); return; }
    for (unsigned i = 0; i < searches; i++)
        (void)[document findString:@(searched) withOptions:0];
    PDFSelection *from = [document findString:@(thenNeedle) fromSelection:nil withOptions:0];
    PDFPage *page0 = [document pageAtIndex:0];
    NSString *range = @"(nil)";
    if (from != nil && [from numberOfTextRangesOnPage:page0] > 0) {
        NSRange r = [from rangeAtIndex:0 onPage:page0];
        range = [NSString stringWithFormat:@"{%lu,%lu}", (unsigned long)r.location, (unsigned long)r.length];
    }
    printf("afterSearch  %-22s searched=%-8s x%u then from=nil needle=%-8s -> %s string=%-8s"
           " rangeOnPage0=%s\n",
           fixture, searched, searches, thenNeedle, from ? "an-object" : "(nil)",
           from ? visible(from.string).UTF8String : "-", from ? range.UTF8String : "-");
}

// the value a row passes to ask for a REAL nil selection, named so a reader does not have to count: an
// out-of-range subscript and a nil argument are different questions and conflating them is what made the
// first run of this script unreadable
#define NO_MATCH ((NSUInteger)-1)

static void fromSelection(const char *fixture, const char *needle, NSStringCompareOptions options,
                          NSUInteger takeFromMatch, NSUInteger occurrence, BOOL fresh)
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", fixturesDirectory, @(fixture)];
    PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
    if (document == nil) { printf("%-24s NO DOCUMENT\n", fixture); return; }
    // A FRESH document has been asked nothing.  The rows that are not fresh call
    // -findString:withOptions: first, to get the selection they start from, and that call may leave the
    // document in a state a caller starting from nil would not be in - so the two kinds of row are told
    // apart here rather than by the reader working out which is which.
    NSArray<PDFSelection *> *all = fresh ? @[] : [document findString:@(needle) withOptions:options];
    PDFSelection *start = (takeFromMatch == NO_MATCH || takeFromMatch >= all.count)
        ? nil : all[takeFromMatch];
    PDFSelection *from = [document findString:@(needle) fromSelection:start withOptions:options];
    PDFPage *page0 = [document pageAtIndex:0];
    NSString *range = @"(nil)";
    if (from != nil && page0 != nil && [from numberOfTextRangesOnPage:page0] > 0) {
        NSRange r = [from rangeAtIndex:0 onPage:page0];
        range = [NSString stringWithFormat:@"{%lu,%lu}", (unsigned long)r.location,
                 (unsigned long)r.length];
    }
    printf("fromSelection %-22s needle=%-8s options=%lu %-10s from=%s -> %s  string=%-8s"
           " rangeOnPage0=%s\n",
           fixture, needle, (unsigned long)options, fresh ? "FRESH" : "searched-first",
           takeFromMatch == NO_MATCH ? "nil" : [@(takeFromMatch) stringValue].UTF8String,
           from ? "an-object" : "(nil)", from ? visible(from.string).UTF8String : "-",
           from ? range.UTF8String : "-");
    (void)occurrence;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: host-find <fixtures-dir>\n");
            return 2;
        }
        NSString *directory = @(argv[1]);
        fixturesDirectory = directory;
        static const Row rows[] = {
            // the same word three times, and at the end of the text the third time
            { "cgfixture-words.pdf", "zero", 0 },
            { "cgfixture-words.pdf", "alpha", 0 },
            { "cgfixture-words.pdf", "bravo", 0 },
            { "cgfixture-words.pdf", "charlie", 0 },
            { "cgfixture-words.pdf", "pha", 0 },
            { "cgfixture-words.pdf", "a b", 0 },
            { "cgfixture-words.pdf", "alpha bravo", 0 },
            { "cgfixture-words.pdf", "alpha alpha", 0 },
            { "cgfixture-words.pdf", "zero alpha bravo charlie alpha alpha", 0 },
            // two spaces between the words
            { "cgfixture-gap.pdf", "alpha", 0 },
            { "cgfixture-gap.pdf", "bravo", 0 },
            { "cgfixture-gap.pdf", "a  b", 0 },
            { "cgfixture-gap.pdf", "alpha  bravo", 0 },
            // three lines of different words: a line end, a line start and the end of the text
            { "cgfixture-lines2.pdf", "one", 0 },
            { "cgfixture-lines2.pdf", "two", 0 },
            { "cgfixture-lines2.pdf", "three", 0 },
            { "cgfixture-lines2.pdf", "four", 0 },
            { "cgfixture-lines2.pdf", "five", 0 },
            { "cgfixture-lines2.pdf", "six", 0 },
            { "cgfixture-lines2.pdf", "two\nthree", 0 },
            { "cgfixture-lines2.pdf", "o t", 0 },
            // a match that ends at a line end but does not start at one, and one that spans the space
            { "cgfixture-lines2.pdf", "ne two", 0 },
            { "cgfixture-lines2.pdf", "e two", 0 },
            // a line with no text between two that have some, and a newline INSIDE one show
            { "cgfixture-blank.pdf", "alpha", 0 },
            { "cgfixture-blank.pdf", "bravo", 0 },
            { "cgfixture-inline.pdf", "alpha", 0 },
            { "cgfixture-inline.pdf", "bravo", 0 },
            // the DRAWN trailing space and the doubled space, asked through the page's own -string: this
            // is what says whether the whitespace of a run survives into the text the ranges are offsets
            // into, which the port's own walk has to answer the same way
            { "cgfixture-gap.pdf", "alpha bravo", 0 },
            { "cgfixture-tail.pdf", "alpha\nbravo", 0 },
            // a drawn trailing space at the end of the first line
            { "cgfixture-tail.pdf", "alpha", 0 },
            { "cgfixture-tail.pdf", "bravo", 0 },
            { "cgfixture-tail.pdf", "alpha \nbravo", 0 },
            // a space at the START of a run and at the end of the last one, and two runs at the same y
            // where the first ends in a space
            { "cgfixture-lead.pdf", "alpha", 0 },
            { "cgfixture-lead.pdf", "bravo", 0 },
            { "cgfixture-lead.pdf", "charlie", 0 },
            { "cgfixture-tailpair.pdf", "alpha", 0 },
            { "cgfixture-tailpair.pdf", "beta", 0 },
            // matches that END INSIDE a word: the one thing R does not yet say
            { "cgfixture-words.pdf", "al", 0 },
            { "cgfixture-words.pdf", "alph", 0 },
            { "cgfixture-words.pdf", "bra", 0 },
            { "cgfixture-words.pdf", "charli", 0 },
            { "cgfixture-words.pdf", "ze", 0 },
            // a tab inside a run
            { "cgfixture-tab.pdf", "alpha", 0 },
            { "cgfixture-tab.pdf", "bravo", 0 },
            // two pages with different text: a needle spanning the boundary, and one inside a page
            { "cgfixture-cross.pdf", "alpha", 0 },
            { "cgfixture-cross.pdf", "bravo", 0 },
            { "cgfixture-cross.pdf", "charlie", 0 },
            { "cgfixture-cross.pdf", "delta", 0 },
            { "cgfixture-cross.pdf", "bravo charlie", 0 },
            { "cgfixture-cross.pdf", "alpha charlie", 0 },
            // the OPTIONS the header names, on the fixture with three "alpha" in it
            { "cgfixture-words.pdf", "ALPHA", 0 },
            { "cgfixture-words.pdf", "ALPHA", NSCaseInsensitiveSearch },
            { "cgfixture-words.pdf", "alpha", NSCaseInsensitiveSearch },
            { "cgfixture-words.pdf", "al.ha", 0 },
            { "cgfixture-words.pdf", "al.ha", NSLiteralSearch },
            { "cgfixture-words.pdf", "alpha", NSBackwardsSearch },
            { "cgfixture-words.pdf", "alpha bravo charlie", NSBackwardsSearch },
            // the SECOND find entry point, over the fixture with three matches of one word: it takes a
            // selection to start after, so its rows are written as a small script rather than as a needle
            // each - see the fromSelection block below
            // the six the earlier session measured, asked again in the same run so one table holds them
            { "cgfixture-lines.pdf", "shared", 0 },
            { "cgfixture-lines.pdf", "shared one", 0 },
            { "cgfixture-lines.pdf", "one", 0 },
            { "cgfixture-lines.pdf", "third", 0 },
            { "cgfixture-lines.pdf", "line", 0 },
            { "cgfixture-1.pdf", "page", 0 },
            { "cgfixture-1.pdf", "1", 0 },
            { "cgfixture-1.pdf", "nothing here", 0 },
        };
        size_t count = sizeof(rows) / sizeof(rows[0]);
        for (size_t r = 0; r < count; r++) {
            NSString *path = [directory stringByAppendingPathComponent:
                              [NSString stringWithUTF8String:rows[r].fixture]];
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            NSString *needle = @(rows[r].needle);
            if (document == nil) {
                printf("%-24s %-20s NO DOCUMENT\n", rows[r].fixture, visible(needle).UTF8String);
                continue;
            }
            // the page's own text FIRST, printed with its controls visible: a range is an offset into it,
            // so a table of ranges is unreadable without the string the offsets are offsets into
            for (NSUInteger p = 0; p < document.pageCount; p++) {
                NSString *text = [[document pageAtIndex:p] string];
                // the LENGTH beside the visible text, because a string holding a NUL prints as its own
                // prefix and a range that reaches past it would look impossible: the offsets a range is
                // made of are offsets into THIS string, so its length is part of every row that follows
                printf("%-24s page-%lu -string=%s length=%lu\n", rows[r].fixture, (unsigned long)p,
                       visible(text).UTF8String, (unsigned long)text.length);
            }
            NSArray<PDFSelection *> *found = [document findString:needle withOptions:rows[r].options];
            printf("%-24s needle=%-20s options=%lu count=%lu\n", rows[r].fixture,
                   visible(needle).UTF8String, (unsigned long)rows[r].options,
                   (unsigned long)found.count);
            for (NSUInteger i = 0; i < found.count; i++) {
                PDFSelection *selection = found[i];
                // The page INDEX is asked of the DOCUMENT, not of the page: the host's PDFPage carries no
                // pageIndex of its own (PDFPage.h), and asking a page for its position in the document is
                // what the port's own -pageIndex answers, so the two are the same number by name.
                NSMutableString *pages = [NSMutableString string];
                for (NSUInteger p = 0; p < selection.pages.count; p++)
                    [pages appendFormat:@"%lu,",
                                       (unsigned long)[document indexForPage:selection.pages[p]]];
                PDFPage *page0 = [document pageAtIndex:0];
                NSString *range = @"(nil)";
                if (page0 != nil && [selection numberOfTextRangesOnPage:page0] > 0) {
                    NSRange r0 = [selection rangeAtIndex:0 onPage:page0];
                    range = [NSString stringWithFormat:@"{%lu,%lu}", (unsigned long)r0.location,
                             (unsigned long)r0.length];
                }
                CGRect bounds = page0 != nil ? [selection boundsForPage:page0] : CGRectZero;
                printf("    [%lu] string=%-22s pages=%-6s ranges0=%-9s bounds0=%.4f,%.4f,%.4f,%.4f"
                       "  color=%s  byLine=%lu\n",
                       (unsigned long)i, visible(selection.string).UTF8String, pages.UTF8String,
                       range.UTF8String, bounds.origin.x, bounds.origin.y, bounds.size.width,
                       bounds.size.height, selection.color ? "a-colour" : "(nil)",
                       (unsigned long)selection.selectionsByLine.count);
            }
        }

        printf("\n== the second entry point\n");
        // A NIL selection is the row that says what nil means: the fixture with THREE matches answered
        // the SECOND one from nil, which no reading of "start at the beginning" explains.  A needle with
        // ONE match on the same fixture says whether nil means "the first match, exclusive" or whether
        // something else is going on.
        fromSelection("cgfixture-words.pdf", "bravo", 0, NO_MATCH, 0, NO);
        fromSelection("cgfixture-words.pdf", "bravo", NSBackwardsSearch, NO_MATCH, 0, NO);
        fromSelection("cgfixture-words.pdf", "charlie", 0, NO_MATCH, 0, NO);
        // and whether a BACKWARDS search crosses a page: cgfixture-3.pdf carries "page 1", "page 2" and
        // "page 3", so "page" matches once per page, and a backwards search from page 2's match can only
        // answer page 1's if it crosses
        fromSelection("cgfixture-3.pdf", "page", NSBackwardsSearch, 0, 0, NO);
        fromSelection("cgfixture-3.pdf", "page", NSBackwardsSearch, 1, 1, NO);
        fromSelection("cgfixture-3.pdf", "page", 0, 0, 0, NO);
        fromSelection("cgfixture-3.pdf", "page", 0, 1, 1, NO);
        fromSelection("cgfixture-3.pdf", "page", 0, 2, 2, NO);
        // the same two questions on a document NOTHING has been asked, which is what says whether the
        // rows above moved because of the findString: call they made first
        fromSelection("cgfixture-words.pdf", "alpha", 0, NO_MATCH, 0, YES);
        fromSelection("cgfixture-3.pdf", "page", 0, NO_MATCH, 0, YES);
        fromSelection("cgfixture-words.pdf", "alpha", NSBackwardsSearch, NO_MATCH, 0, YES);
        fromSelection("cgfixture-words.pdf", "alpha", 0, 0, 0, NO);
        fromSelection("cgfixture-words.pdf", "alpha", 0, 1, 1, NO);
        fromSelection("cgfixture-words.pdf", "alpha", 0, 2, 2, NO);
        fromSelection("cgfixture-words.pdf", "alpha", NSBackwardsSearch, 0, 0, NO);
        fromSelection("cgfixture-words.pdf", "alpha", NSBackwardsSearch, 2, 2, NO);
        fromSelection("cgfixture-cross.pdf", "bravo", NSBackwardsSearch, 0, 0, NO);

        printf("\n== what a search leaves behind\n");
        afterSearch("cgfixture-words.pdf", "bravo", "alpha", 1);
        afterSearch("cgfixture-words.pdf", "alpha", "alpha", 2);
        afterSearch("cgfixture-words.pdf", "alpha", "bravo", 1);

        printf("\n== the five mutators\n");
        //
        // A FRESH DOCUMENT PER ROW, and the reason is measured rather than tidiness: the array a search
        // answers is the DOCUMENT's own, so the next search on the same document replaces its contents.
        // Asking for four needles in a row gave every row the answers of the last one, and one array came
        // back with one element where a fresh document gives three.  Each row below therefore opens its
        // own document and takes only what it needs.
        {
            // addSelection: over a contiguous range, over a disjoint one, and over an overlap
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *one = [[words findString:@"alpha" withOptions:0][0] copy];
            [one addSelection:[[words findString:@"alpha bravo charlie" withOptions:0][0] copy]];
            printSelectionState("addSelection contiguous", one, words);
        }
        {
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *one = [[words findString:@"alpha" withOptions:0][0] copy];
            [one addSelection:[[words findString:@"alpha alpha" withOptions:0][0] copy]];
            printSelectionState("addSelection disjoint", one, words);
        }
        {
            // an overlap in each of the three shapes: the added range inside, containing, and crossing
            PDFDocument *inside = openFixture("cgfixture-words.pdf");
            PDFSelection *base = [[inside findString:@"alpha alpha" withOptions:0][0] copy];
            printSelectionState("base alpha alpha", base, inside);
            @try {
                PDFSelection *added = [[inside findString:@"alpha" withOptions:0][0] copy];
                [base addSelection:added];
                printSelectionState("added inside", base, inside);
            } @catch (NSException *raised) {
                printf("added inside                RAISED %s: %s\n", [[raised name] UTF8String],
                       [[raised reason] UTF8String] ?: "(no reason)");
            }
        }
        {
            PDFDocument *crossing = openFixture("cgfixture-words.pdf");
            PDFSelection *base = [[crossing findString:@"alpha alpha" withOptions:0][0] copy];
            PDFSelection *added = [[crossing findString:@"alpha bra" withOptions:0][0] copy];
            @try {
                [base addSelection:added];
                printSelectionState("added crossing", base, crossing);
            } @catch (NSException *raised) {
                printf("added crossing              RAISED %s: %s\n", [[raised name] UTF8String],
                       [[raised reason] UTF8String] ?: "(no reason)");
            }
        }
        {
            PDFDocument *containing = openFixture("cgfixture-words.pdf");
            PDFSelection *base = [[containing findString:@"alpha" withOptions:0][0] copy];
            PDFSelection *added = [[containing findString:@"alpha alpha" withOptions:0][0] copy];
            @try {
                [base addSelection:added];
                printSelectionState("added containing", base, containing);
            } @catch (NSException *raised) {
                printf("added containing            RAISED %s: %s\n", [[raised name] UTF8String],
                       [[raised reason] UTF8String] ?: "(no reason)");
            }
        }
        {
            // addSelections:, several at once, one of them overlapping
            PDFDocument *many = openFixture("cgfixture-words.pdf");
            PDFSelection *base = [[many findString:@"alpha alpha" withOptions:0][0] copy];
            NSArray<PDFSelection *> *additions = @[
                [[many findString:@"alpha" withOptions:0][0] copy],
                [[many findString:@"alpha bra" withOptions:0][0] copy],
            ];
            [base addSelections:additions];
            printSelectionState("addSelections two", base, many);
        }
        {
            // extendSelectionAtEnd: and extendSelectionAtStart:, in characters
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *end = [[words findString:@"alpha" withOptions:0][0] copy];
            [end extendSelectionAtEnd:3];
            printSelectionState("extendSelectionAtEnd: 3", end, words);
        }
        {
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *start = [[words findString:@"alpha" withOptions:0][0] copy];
            [start extendSelectionAtStart:2];
            printSelectionState("extendSelectionAtStart: 2", start, words);
        }
        {
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *both = [[words findString:@"alpha" withOptions:0][0] copy];
            [both extendSelectionAtStart:2];
            [both extendSelectionAtEnd:3];
            printSelectionState("both ends", both, words);
        }
        {
            // extendSelectionForLineBoundaries, inside one line and across two
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *line = [[words findString:@"alpha" withOptions:0][0] copy];
            [line extendSelectionForLineBoundaries];
            printSelectionState("extendForLine 1 line", line, words);
        }
        {
            PDFDocument *lines2 = openFixture("cgfixture-lines2.pdf");
            PDFSelection *twoLine = [[lines2 findString:@"two\nthree" withOptions:0][0] copy];
            printSelectionState("two-line selection", twoLine, lines2);
            [twoLine extendSelectionForLineBoundaries];
            printSelectionState("extendForLine 2 lines", twoLine, lines2);
        }
        {
            // across PAGES: cgfixture-3.pdf carries "page 1", "page 2", "page 3"
            PDFDocument *three = openFixture("cgfixture-3.pdf");
            NSArray<PDFSelection *> *pages = [three findString:@"page" withOptions:0];
            for (NSUInteger i = 0; i < pages.count; i++)
                printSelectionState("page match", [pages[i] copy], three);
            PDFSelection *ontoNext = [pages[1] copy];
            [ontoNext extendSelectionAtEnd:20];
            printSelectionState("extendEnd 20 from page 2", ontoNext, three);
            PDFSelection *ontoPrevious = [pages[1] copy];
            [ontoPrevious extendSelectionAtStart:20];
            printSelectionState("extendStart 20 from page 2", ontoPrevious, three);
            PDFSelection *pastTheEnd = [pages[2] copy];
            [pastTheEnd extendSelectionAtEnd:20];
            printSelectionState("extendEnd 20 from page 3", pastTheEnd, three);
            PDFSelection *beforeTheStart = [pages[0] copy];
            [beforeTheStart extendSelectionAtStart:20];
            printSelectionState("extendStart 20 from page 1", beforeTheStart, three);
        }
        {
            // the container the header describes: an empty selection, then one added, then several
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *container = [[PDFSelection alloc] initWithDocument:words];
            printSelectionState("initWithDocument:", container, words);
            [container addSelection:[[words findString:@"alpha" withOptions:0][0] copy]];
            printSelectionState("container + 1", container, words);
            [container addSelections:@[ [[words findString:@"alpha alpha" withOptions:0][0] copy],
                                         [[words findString:@"alpha bra" withOptions:0][0] copy] ]];
            printSelectionState("container + 2 more", container, words);
        }

        {
            // ADJACENT ranges with a space between them: whether the normalization merges ranges that TOUCH
            // or only ranges that OVERLAP
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *base = [[words findString:@"alpha" withOptions:0][0] copy];
            [base addSelection:[[words findString:@"bra" withOptions:0][0] copy]];
            printSelectionState("adjacent alpha + bra", base, words);
        }
        {
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *zero = [[words findString:@"alpha" withOptions:0][0] copy];
            [zero extendSelectionAtEnd:0];
            printSelectionState("extendSelectionAtEnd: 0", zero, words);
        }
        {
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *back = [[words findString:@"alpha" withOptions:0][0] copy];
            [back extendSelectionAtEnd:-1];
            printSelectionState("extendSelectionAtEnd: -1", back, words);
        }
        {
            PDFDocument *words = openFixture("cgfixture-words.pdf");
            PDFSelection *back = [[words findString:@"alpha" withOptions:0][0] copy];
            [back extendSelectionAtStart:-1];
            printSelectionState("extendSelectionAtStart: -1", back, words);
        }

        printf("\n== the line split and the attributed string\n");
        for (NSString *fixture in @[ @"cgfixture-lines2.pdf", @"cgfixture-lines.pdf" ]) {
            NSString *path = [NSString stringWithFormat:@"%@/%@", directory, fixture];
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            NSString *needle = [fixture isEqualToString:@"cgfixture-lines2.pdf"] ? @"two\nthree" : @"shared";
            for (PDFSelection *selection in [document findString:needle withOptions:0]) {
                NSArray<PDFSelection *> *byLine = selection.selectionsByLine;
                printf("%-22s selection=%-14s length=%-3lu byLine=%lu\n", fixture.UTF8String,
                       visible(selection.string).UTF8String, (unsigned long)selection.string.length,
                       (unsigned long)byLine.count);
                PDFPage *page0 = [document pageAtIndex:0];
                for (NSUInteger i = 0; i < byLine.count; i++) {
                    PDFSelection *line = byLine[i];
                    NSRange r = [line numberOfTextRangesOnPage:page0] > 0
                        ? [line rangeAtIndex:0 onPage:page0] : NSMakeRange(NSNotFound, 0);
                    printf("   line %lu string=%-12s length=%-3lu range={%lu,%lu}\n", (unsigned long)i,
                           visible(line.string).UTF8String, (unsigned long)line.string.length,
                           (unsigned long)r.location, (unsigned long)r.length);
                }
                NSAttributedString *attributed = selection.attributedString;
                // the FONT is read by NAME and by SIZE and nothing else: the two things a UIFont on the
                // port and an NSFont here can both answer, so the differential compares what is portable
                NSRange fontRange = NSMakeRange(0, 0);
                NSFont *font = [attributed length] > 0
                    ? [attributed attribute:NSFontAttributeName atIndex:0 effectiveRange:&fontRange] : nil;
                printf("   attributed length=%lu string=%-14s font=%s size=%.4f"
                       " fontRunFromZero=%lu\n",
                       (unsigned long)attributed.length, visible(attributed.string).UTF8String,
                       font ? [font fontName].UTF8String : "(nil)", (double)[font pointSize],
                       (unsigned long)(attributed.length > 0 ? fontRange.length : 0));
            }
        }
    }
    return 0;
}