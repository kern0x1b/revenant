// textkit2.m - every implemented method of the range layer of TextKit 2, called on the release, as a device
// binary run under xmake emulate. The port's own classes are the only ones of their names on iOS 6.1.3, so there
// is nothing to compare against here: what this proves is that each method answers, and that none of them
// crashes on the release. What each answer is was measured against the host's own UIKit and is in
// packages/a/apple-backports/facts/UIKit/NSTextRange15.md; the checks here are the same rules, held on the
// release.
//
// A data source of the test's own is written out below, so the navigation object is asked real questions about a
// real document rather than only about its own absence. The content manager is not carried by this port yet, so
// the two derived ranges of a paragraph are nil here, and that is what the check says.
#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

// A location over an offset, which is all NSTextLocation asks for.
@interface CallTestLocation : NSObject <NSTextLocation>
@property (nonatomic, readonly) NSInteger offset;
- (instancetype)initWithOffset:(NSInteger)offset;
@end

@implementation CallTestLocation

@synthesize offset = _offset;

- (instancetype)initWithOffset:(NSInteger)offset
{
    if ((self = [super init]))
        _offset = offset;
    return self;
}

- (NSComparisonResult)compare:(id<NSTextLocation>)location
{
    NSInteger other = [(CallTestLocation *)location offset];
    return _offset == other ? NSOrderedSame : (_offset < other ? NSOrderedAscending : NSOrderedDescending);
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isKindOfClass:[CallTestLocation class]] && [object offset] == _offset);
}

- (NSUInteger)hash { return (NSUInteger)_offset; }
- (NSString *)description { return [NSString stringWithFormat:@"%ld", (long)_offset]; }

@end

static id<NSTextLocation> at(NSInteger offset)
{
    return [[CallTestLocation alloc] initWithOffset:offset];
}

// A document of "abcdefghij" with a break after every third character, which is what the granularity answers and
// the offsets are read out of. The real content manager is the next group's work; this is the protocol the
// navigation object is written against, and answering it is the navigation object's whole job.
static const char *const kText = "abcdefghij";
static const NSInteger kBreak = 3;

@interface CallTestSource : NSObject <NSTextSelectionDataSource>
@property (nonatomic, strong, readonly) NSTextRange *documentRange;
- (instancetype)initWithLength:(NSInteger)length;
@end

@implementation CallTestSource {
    NSInteger _length;
}

@synthesize documentRange = _documentRange;

- (instancetype)initWithLength:(NSInteger)length
{
    if ((self = [super init])) {
        _length = length;
        _documentRange = [[NSTextRange alloc] initWithLocation:at(0) endLocation:at(length)];
    }
    return self;
}

- (void)enumerateSubstringsFromLocation:(id<NSTextLocation>)location
                                options:(NSStringEnumerationOptions)options
                             usingBlock:(void (^)(NSString *, NSTextRange *, NSTextRange *, BOOL *))block
{
    for (NSInteger start = 0; start < _length; start += kBreak) {
        NSInteger end = start + kBreak < _length ? start + kBreak : _length;
        if (end == start)
            continue;
        NSString *substring = [[NSString stringWithCharacters:kText + start length:en - (NSUInteger)start]
            substringWithRange:NSMakeRange(0, end - start)];
        NSTextRange *range = [[NSTextRange alloc] initWithLocation:at(start) endLocation:at(end)];
        NSTextRange *enclosing = [[NSTextRange alloc] initWithLocation:at(start) endLocation:at(end)];
        if (!block(substring, range, enclosing, (BOOL *)NULL))
            break;
    }
}

- (NSTextRange *)textRangeForSelectionGranularity:(NSTextSelectionGranularity)granularity
                                 enclosingLocation:(id<NSTextLocation>)location
{
    NSInteger offset = [(CallTestLocation *)location offset];
    if (offset < 0 || offset > _length || self.documentRange.isEmpty)
        return nil;
    if (granularity == NSTextSelectionGranularityCharacter)
        return [[NSTextRange alloc] initWithLocation:at(offset) endLocation:at(offset)];
    NSInteger start = (offset / kBreak) * kBreak;
    NSInteger end = start + kBreak < _length ? start + kBreak : _length;
    return [[NSTextRange alloc] initWithLocation:at(start) endLocation:at(end)];
}

- (id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)location withOffset:(NSInteger)offset
{
    NSInteger where = [(CallTestLocation *)location offset] + offset;
    if (where < 0 || where > _length)
        return nil;
    return at(where);
}

- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to
{
    return [(CallTestLocation *)to offset] - [(CallTestLocation *)from offset];
}

- (NSTextSelectionNavigationWritingDirection)baseWritingDirectionAtLocation:(id<NSTextLocation>)location
{
    return NSTextSelectionNavigationWritingDirectionLeftToRight;
}

- (void)enumerateCaretOffsetsInLineFragmentAtLocation:(id<NSTextLocation>)location
                                          usingBlock:(void (^)(CGFloat, id<NSTextLocation>, BOOL, BOOL *))block
{
    NSTextRange *line = [self textRangeForSelectionGranularity:NSTextSelectionGranularityLine
                                              enclosingLocation:location];
    if (!line)
        return;
    for (id<NSTextLocation> caret = line.location;;) {
        if (!block(0, caret, YES, (BOOL *)NULL))
            break;
        if ([caret isEqual:line.endLocation])
            break;
        caret = [self locationFromLocation:caret withOffset:1];
        if (!caret)
            break;
    }
}

- (NSTextRange *)lineFragmentRangeForPoint:(CGPoint)point inContainerAtLocation:(id<NSTextLocation>)location
{
    // One line for the whole document, which is all a data source without soft wrapping has to say.
    return self.documentRange;
}

@end

static NSString *described(id object)
{
    if (!object)
        return @"(nil)";
    NSString *text = [object description];
    NSRegularExpression *addresses = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-fA-F]+"
                                                                              options:0
                                                                                error:NULL];
    return [addresses stringByReplacingMatchesInString:text
                                               options:0
                                                 range:NSMakeRange(0, text.length)
                                          withTemplate:@"0xX"];
}

static NSTextRange *range(NSInteger from, NSInteger to)
{
    if (to < 0)
        return [[NSTextRange alloc] initWithLocation:at(from)];
    return [[NSTextRange alloc] initWithLocation:at(from) endLocation:at(to)];
}

// Every method the headers mark unavailable, held to the port's own answer: it raises and names the
// initialiser to use, where the host faults.
static void check_unavailable(void)
{
    @try {
        (void)[[NSTextRange alloc] init];
        charon_check(NO, "a range refuses a bare -init", "it made one");
    } @catch (NSException *exception) {
        charon_check([exception.name isEqualToString:NSInternalInconsistencyException], "a range refuses a bare -init",
                     exception.name);
    }
    @try {
        (void)[NSTextRange new];
        charon_check(NO, "a range refuses +new", "it made one");
    } @catch (NSException *exception) {
        charon_check([exception.name isEqualToString:NSInternalInconsistencyException], "a range refuses +new",
                     exception.name);
    }
    @try {
        (void)[[NSTextSelection alloc] init];
        charon_check(NO, "a selection refuses a bare -init", "it made one");
    } @catch (NSException *exception) {
        charon_check([exception.name isEqualToString:NSInternalInconsistencyException],
                     "a selection refuses a bare -init", exception.name);
    }
    @try {
        (void)[[NSTextSelectionNavigation alloc] init];
        charon_check(NO, "a navigation object refuses a bare -init", "it made one");
    } @catch (NSException *exception) {
        charon_check([exception.name isEqualToString:NSInternalInconsistencyException],
                     "a navigation object refuses a bare -init", exception.name);
    }
    @try {
        (void)[NSTextSelectionNavigation new];
        charon_check(NO, "a navigation object refuses +new", "it made one");
    } @catch (NSException *exception) {
        charon_check([exception.name isEqualToString:NSInternalInconsistencyException],
                     "a navigation object refuses +new", exception.name);
    }
}

static void check_ranges(void)
{
    NSTextRange *empty = range(3, -1);
    charon_check(empty.isEmpty, "a range with no end is empty", "it is not");
    charon_check([empty.endLocation isEqual:empty.location], "and answers its start as its end", "it does not");
    charon_check([empty description] != nil, "a range describes itself", "it does not");

    NSTextRange *a = range(0, 10), *b = range(5, 15), *c = range(20, 25);
    for (NSInteger where = 0; where <= 11; where++)
        charon_check([a containsLocation:at(where)] == (where >= 0 && where < 10),
                     NAMED("0...10 holds location %ld", (long)where), "the rule is not the header's");
    charon_check(![empty containsLocation:at(3)], "an empty range holds nothing, itself included", "it holds itself");
    charon_check([a containsRange:b] == NO && [a containsRange:a] && [a containsRange:range(0, 5)] &&
                     [a containsRange:range(3, 3)] && ![a containsRange:range(10, 10)] && [a containsRange:c] == NO,
                 @"0...10 holds a range with contents closed at both ends and an empty one inside it", "the rule differs");
    charon_check(![a intersectsWithTextRange:c] && [a intersectsWithTextRange:b] && ![a intersectsWithTextRange:empty],
                 @"two ranges share contents only when each starts before the other ends", "the rule differs");
    charon_check([[a textRangeByIntersectingWithTextRange:b] description] == @"5...10" &&
                     [a textRangeByIntersectingWithTextRange:c] == nil &&
                     [[a textRangeByIntersectingWithTextRange:range(0, 15)] description] == @"0...10",
                 @"the intersection is the later start and the earlier end", "the rule differs");
    charon_check([[a textRangeByFormingUnionWithTextRange:b] description] == @"0...15" &&
                     [[a textRangeByFormingUnionWithTextRange:c] description] == @"0...25" &&
                     [[a textRangeByFormingUnionWithTextRange:empty] description] == @"0...10" &&
                     [[range(0, 0) textRangeByFormingUnionWithTextRange:b] description] == @"5...10" &&
                     [[range(0, 0) textRangeByFormingUnionWithTextRange:range(3, 3)] description] == @"3...3",
                 @"the union is the envelope, or the range that has contents", "the rule differs");
    charon_check([a isEqualToTextRange:range(0, 10)] && ![a isEqualToTextRange:b] && [a isEqual:a] &&
                     [a isKindOfClass:[NSObject class]],
                 @"a range is equal to a range over the same two places", "the rule differs");
    charon_check([a hash] == [range(0, 10) hash], "and hashes by its value", "two equal ranges hash differently");
    charon_check([[NSTextRange class] instancesRespondToSelector:@selector(copyWithZone:)] == NO,
                 "a range is not copied", "it has a copyWithZone:");
    charon_check([[NSTextRange class] respondsToSelector:@selector(supportsSecureCoding)] == NO,
                 "and does not say it supports secure coding", "it says it does");
}

static void check_selections(void)
{
    NSTextSelection *one = [[NSTextSelection alloc] initWithRange:range(0, 5)
                                                        affinity:NSTextSelectionAffinityDownstream
                                                     granularity:NSTextSelectionGranularityCharacter];
    charon_check(one.textRanges.count == 1 && one.affinity == NSTextSelectionAffinityDownstream &&
                     one.granularity == NSTextSelectionGranularityCharacter && !one.isTransient &&
                     one.anchorPositionOffset == 0 && one.isLogical && one.secondarySelectionLocation == nil,
                 "a selection keeps what it was made with", "one of the answers differs");
    charon_check(one.typingAttributes == nil, "and answers nil for typing attributes it was never given", "it does not");
    id none = nil;
    [one setTypingAttributes:none];
    charon_check(one.typingAttributes != nil && one.typingAttributes.count == 0,
                 "an empty dictionary once the setter has been called at all", "it answers nil");
    [one setSecondarySelectionLocation:at(8)];
    charon_check(!one.isLogical, "a secondary location makes a selection not logical", "it is still logical");
    [one setLogical:YES];
    charon_check(one.isLogical, "and the flag can be set back", "it cannot");

    NSTextSelection *messy = [[NSTextSelection alloc] initWithRanges:@[ range(20, 25), range(0, 10), range(5, 15) ]
                                                            affinity:NSTextSelectionAffinityUpstream
                                                         granularity:NSTextSelectionGranularityWord];
    charon_check(messy.textRanges.count == 3, "three ranges in, three ranges out", "a side merged or dropped one");
    charon_check([[messy.textRanges objectAtIndex:0] description] == @"20...25" &&
                     [[messy.textRanges objectAtIndex:2] description] == @"5...15",
                 @"and the order they went in is the order they came out in", "the order differs");
    NSTextSelection *cursor = [[NSTextSelection alloc] initWithLocation:at(4)
                                                              affinity:NSTextSelectionAffinityDownstream];
    charon_check(cursor.granularity == NSTextSelectionGranularityCharacter && cursor.textRanges.count == 1 &&
                     [[[cursor textRanges] firstObject] description] == @"4...4",
                 "a cursor is one 0-length range of a character granularity", "it is not");
    NSTextSelection *none2 = [[NSTextSelection alloc] initWithRanges:@[]
                                                            affinity:NSTextSelectionAffinityDownstream
                                                         granularity:NSTextSelectionGranularityCharacter];
    charon_check(none2.textRanges.count == 0, "a selection of no ranges is empty", "it is not");

    NSTextSelection *copy = [one textSelectionWithTextRanges:@[ range(1, 2) ]];
    charon_check(copy.textRanges.count == 1 && copy.affinity == one.affinity && copy.isLogical &&
                     [copy.secondarySelectionLocation isEqual:at(8)] && copy.typingAttributes != nil &&
                     one.textRanges.count == 1,
                 @"a copy carries the affinity, the logical flag, the secondary location and the typing attributes",
                 "one of the answers differs");
    charon_check([one isEqual:[one textSelectionWithTextRanges:one.textRanges]] == NO ||
                     [one isEqual:[[NSTextSelection alloc] initWithRange:range(0, 5)
                                                                 affinity:NSTextSelectionAffinityDownstream
                                                              granularity:NSTextSelectionGranularityCharacter]] ==
                         [one isEqual:[[NSTextSelection alloc] initWithRange:range(0, 5)
                                                                     affinity:NSTextSelectionAffinityDownstream
                                                                  granularity:NSTextSelectionGranularityCharacter]] == NO,
                 @"a selection is a value: two over the same state are -isEqual:", "the rule differs");
    NSTextSelection *equal = [[NSTextSelection alloc] initWithRange:range(0, 5)
                                                           affinity:NSTextSelectionAffinityDownstream
                                                        granularity:NSTextSelectionGranularityCharacter];
    charon_check([[NSSet setWithObjects:one, equal, nil] count] == 2,
                 @"two selections differing in one key are not equal", "a set holds one");
    charon_check([[NSTextSelection class] supportsSecureCoding], "a selection says it supports secure coding",
                 "it says it does not");
    charon_check([described(one) rangeOfString:@"NSTextSelection:<"].location != NSNotFound &&
                     [described(one) rangeOfString:@"granularity=character"].location != NSNotFound,
                 @"and describes itself the host's way", described(one));
    charon_check(messy.description != nil && none2.description != nil && cursor.description != nil,
                 "every selection describes itself", "one does not");
}

static void check_elements(void)
{
    NSTextParagraph *plain = [[NSTextParagraph alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:@"Hello"]];
    charon_check(plain.attributedString.length == 5, "a paragraph keeps the string it was given", "it does not");
    charon_check(plain.isRepresentedElement, "and is a represented element", "it is not");
    charon_check(plain.childElements.count == 0 && plain.parentElement == nil,
                 "with no children and no parent", "it has some");
    charon_check(plain.textContentManager == nil, "and no content manager", "it has one");
    plain.elementRange = range(0, 5);
    charon_check([[plain.elementRange description] isEqualToString:@"0...5"], "and the range it keeps", "it differs");
    // The content manager is not carried by this port yet, so the two derived ranges are nil: the host's own
    // answer in the same state, and what the check holds.
    for (NSString *text in @[ @"Hello", @"Hello\n", @"Hello\r\n", @"\n" ]) {
        NSTextParagraph *paragraph = [[NSTextParagraph alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:text]];
        paragraph.elementRange = range(0, (NSInteger)text.length);
        charon_check(paragraph.paragraphContentRange == nil && paragraph.paragraphSeparatorRange == nil,
                     NAMED(@"%@ derives no range with no content manager", text), "one side derives one");
    }
    NSTextElement *element = [[NSTextElement alloc] initWithTextContentManager:nil];
    charon_check(element.isRepresentedElement && element.childElements.count == 0 && element.parentElement == nil,
                 "a bare element is a represented element with no children and no parent", "it is not");
    charon_check([element isEqual:element] && ![element isEqual:[[NSTextElement alloc] initWithTextContentManager:nil]],
                 "and is equal to itself and to no other element", "the rule differs");
    charon_check([[NSTextElement alloc] init] != nil, "an element made with -init is one with no manager", "it is nil");
    charon_check([described(element) rangeOfString:@"<NSTextElement:"].location != NSNotFound &&
                     [described(plain) rangeOfString:@"\"Hello\""].location != NSNotFound,
                 @"and both describe themselves the host's way", described(plain));
    NSTextParagraph *noString = [[NSTextParagraph alloc] initWithAttributedString:nil];
    charon_check(noString.attributedString == nil && [described(noString) rangeOfString:@"(null)"].location != NSNotFound,
                 @"a paragraph over no string keeps none and says so", described(noString));
}

// The navigation object against a data source of the test's own, so the movement code runs rather than only the
// answers it gives with no data source at all.
static void check_navigation(void)
{
    CallTestSource *source = [[CallTestSource alloc] initWithLength:10];
    NSTextSelectionNavigation *navigation = [[NSTextSelectionNavigation alloc] initWithDataSource:source];
    charon_check(navigation != nil, "a navigation object is made with a data source", "it is not");
    charon_check(navigation.textSelectionDataSource == source, "and holds it", "it does not");
    charon_check(navigation.allowsNonContiguousRanges && !navigation.rotatesCoordinateSystemForLayoutOrientation,
                 @"and starts with the host's own two flags", "one differs");
    [navigation setAllowsNonContiguousRanges:NO];
    [navigation setRotatesCoordinateSystemForLayoutOrientation:YES];
    charon_check(!navigation.allowsNonContiguousRanges && navigation.rotatesCoordinateSystemForLayoutOrientation,
                 "and both are settable", "one did not take the value");
    [navigation flushLayoutCache];
    charon_check(YES, "flushing the cache answers nothing", "something answered");

    NSTextSelection *cursor = [[NSTextSelection alloc] initWithLocation:at(4)
                                                              affinity:NSTextSelectionAffinityDownstream];
    // Forward over one character from 4 is 5, backward is 3, and to the document's ends are 0 and 10.
    charon_check([[[navigation destinationSelectionForTextSelection:cursor
                                                          direction:NSTextSelectionNavigationDirectionForward
                                                        destination:NSTextSelectionNavigationDestinationCharacter
                                                         extending:NO
                                                           confined:NO].textRanges firstObject] description] == @"4...5",
                 @"a move forward over a character is the character it lands on", "it is not");
    charon_check([[[navigation destinationSelectionForTextSelection:cursor
                                                          direction:NSTextSelectionNavigationDirectionBackward
                                                        destination:NSTextSelectionNavigationDestinationCharacter
                                                         extending:NO
                                                           confined:NO].textRanges firstObject] description] == @"3...4",
                 @"and backward is the one before", "it is not");
    charon_check([[[navigation destinationSelectionForTextSelection:cursor
                                                          direction:NSTextSelectionNavigationDirectionForward
                                                        destination:NSTextSelectionNavigationDestinationDocument
                                                         extending:NO
                                                           confined:NO].textRanges firstObject] description] == @"4...10",
                 @"and a move to the document's end lands there", "it is not");
    // A destination the data source has no boundary for answers nil, which is what the header says.
    charon_check([navigation destinationSelectionForTextSelection:cursor
                                                          direction:NSTextSelectionNavigationDirectionForward
                                                        destination:NSTextSelectionNavigationDestinationContainer
                                                         extending:NO
                                                           confined:NO] == nil,
                 "a move to a container boundary with none to move to answers nil", "it answered something");
    // Extending keeps the first location and moves the end, in both directions.
    charon_check([[[navigation destinationSelectionForTextSelection:cursor
                                                          direction:NSTextSelectionNavigationDirectionForward
                                                        destination:NSTextSelectionNavigationDestinationCharacter
                                                         extending:YES
                                                           confined:NO].textRanges firstObject] description] == @"4...5" &&
                     [[[navigation destinationSelectionForTextSelection:cursor
                                                             direction:NSTextSelectionNavigationDirectionBackward
                                                           destination:NSTextSelectionNavigationDestinationCharacter
                                                            extending:YES
                                                              confined:NO].textRanges firstObject] description] == @"3...4",
                 @"extending keeps the first location and moves only the end", "it does not");
    // A granularity the data source encloses a location in.
    NSTextSelection *word = [navigation textSelectionForSelectionGranularity:NSTextSelectionGranularityWord
                                                            enclosingTextSelection:cursor];
    charon_check(word != nil && word.granularity == NSTextSelectionGranularityWord && word.textRanges.count == 1,
                 "a selection is expanded to the word around it", "it was not");
    charon_check([navigation textSelectionForSelectionGranularity:NSTextSelectionGranularityWord
                                                  enclosingPoint:CGPointMake(1, 1)
                                        inContainerAtLocation:at(0)] != nil,
                 "and a point is enclosed in one too", "there was none");
    charon_check([navigation textSelectionsInteractingAtPoint:CGPointMake(1, 1)
                                     inContainerAtLocation:at(0)
                                                  anchors:@[ cursor ]
                                                modifiers:NSTextSelectionNavigationModifierExtend
                                                selecting:YES
                                                    bounds:CGRectMake(0, 0, 10, 10)].count == 1,
                 "a point with a line under it interacts with one selection", "it did not");
    // The insertion location is the secondary location of a selection that is not logical.
    charon_check([navigation resolvedInsertionLocationForTextSelection:cursor
                                                     writingDirection:NSTextSelectionNavigationWritingDirectionLeftToRight] == nil,
                 "a logical selection has no insertion location", "it has one");
    [cursor setSecondarySelectionLocation:at(4)];
    charon_check([[navigation resolvedInsertionLocationForTextSelection:cursor
                                                       writingDirection:NSTextSelectionNavigationWritingDirectionLeftToRight] description] == @"4",
                 @"and a selection that is not logical inserts at its secondary location", "it does not");
    // A delete of a selection with contents is that selection; of a cursor, what a move over the same place is.
    NSTextSelection *withContents = [[NSTextSelection alloc] initWithRange:range(2, 5)
                                                                  affinity:NSTextSelectionAffinityDownstream
                                                               granularity:NSTextSelectionGranularityCharacter];
    charon_check([[[navigation deletionRangesForTextSelection:withContents
                                                      direction:NSTextSelectionNavigationDirectionForward
                                                    destination:NSTextSelectionNavigationDestinationDocument
                                              allowsDecomposition:NO] firstObject] description] == @"2...5",
                 @"a delete of a selection with contents removes it", "it does not");
    charon_check([[[navigation deletionRangesForTextSelection:cursor
                                                      direction:NSTextSelectionNavigationDirectionBackward
                                                    destination:NSTextSelectionNavigationDestinationCharacter
                                              allowsDecomposition:YES] firstObject] description] == @"3...4",
                 @"and a delete at a cursor removes what a move over one character would have selected", "it does not");
    NSTextSelectionNavigation *bare = [[NSTextSelectionNavigation alloc] initWithDataSource:nil];
    charon_check(bare != nil && bare.textSelectionDataSource == nil &&
                     [bare deletionRangesForTextSelection:cursor
                                                direction:NSTextSelectionNavigationDirectionForward
                                              destination:NSTextSelectionNavigationDestinationCharacter
                                        allowsDecomposition:NO].count == 1,
                 "and one with no data source answers the header's own way", "it did not");
    charon_check([described(navigation) rangeOfString:@"<NSTextSelectionNavigation:"].location != NSNotFound,
                 @"a navigation object describes itself the host's way", described(navigation));
}

int main(void)
{
    @autoreleasepool {
        check_unavailable();
        check_ranges();
        check_selections();
        check_elements();
        check_navigation();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return 0;
}
