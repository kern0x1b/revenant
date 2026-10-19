// NSTextSelectionNavigation: what a selection moved does. The class holds no logic of its own beyond its own
// storage, because every answer it gives is a question for the data source it was made with - the range the
// document spans, the segments at a location, the range a granularity encloses, a location an offset from, a
// line fragment under a point. That is what the header for NSTextSelectionNavigation says of each method, and
// it is why this class is small: the navigation object is the protocol's client, and the work is the data
// source's. The host's own answers for this class need a live text container, so there is none to compare
// against, and the two answers that are more than a pass-through are written from the header and say so.
//
// A selection moved by a destination, with a direction and whether it extends, is the range between where the
// selection was and the location the movement reaches; extending keeps the selection's first location and
// moves only its end. And the ranges a deletion removes are the selection's own when it has contents, and
// otherwise the range the movement would produce, because what a delete removes is what a move over would have
// selected, which is what the header for
// deletionRangesForTextSelection:direction:destination:allowsDecomposition: says.

#import <UIKit/UIKit.h>

@implementation NSTextSelectionNavigation

@synthesize textSelectionDataSource = _textSelectionDataSource;
@synthesize allowsNonContiguousRanges = _allowsNonContiguousRanges;
@synthesize rotatesCoordinateSystemForLayoutOrientation = _rotatesCoordinateSystemForLayoutOrientation;

- (instancetype)initWithDataSource:(id<NSTextSelectionDataSource>)dataSource
{
    if ((self = [super init])) {
        _textSelectionDataSource = dataSource;
        // The host's own default, measured: a navigation object is allowed to produce selections with several
        // disjoint ranges unless it is told otherwise (M10). It is a stored flag and the port stores the value
        // the host gives it.
        _allowsNonContiguousRanges = YES;
    }
    return self;
}

- (instancetype)init
{
    // The header marks this one unavailable: every answer this class gives is a question for a data source, and
    // a navigation object with none has nothing to ask (M9).
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ cannot be made without a data source: use -initWithDataSource:",
                       NSStringFromClass([self class])];
    return nil;
}

- (void)flushLayoutCache
{
    // The port asks its data source for everything each time, so there is nothing cached and nothing to flush;
    // the method is there because the header declares it and an application calls it after changing the
    // document's contents.
}

- (NSTextRange *)charon_range_enclosing:(NSTextSelectionGranularity)granularity at:(id<NSTextLocation>)location
{
    id<NSTextSelectionDataSource> dataSource = _textSelectionDataSource;
    if (!dataSource)
        return nil;
    return [dataSource textRangeForSelectionGranularity:granularity enclosingLocation:location];
}

// The location a movement from a selection ends at: for a selection with contents, the end of its last range,
// and for a cursor, the cursor's own location. Everything the navigation does starts there.
- (id<NSTextLocation>)charon_location_after:(NSTextSelection *)textSelection
{
    NSTextRange *last = [textSelection.textRanges lastObject];
    return last.endLocation ? last.endLocation : last.location;
}

- (NSTextSelection *)destinationSelectionForTextSelection:(NSTextSelection *)textSelection
                                                direction:(NSTextSelectionNavigationDirection)direction
                                              destination:(NSTextSelectionNavigationDestination)destination
                                               extending:(BOOL)extending
                                                 confined:(BOOL)confined
{
    if (!textSelection)
        return nil;
    id<NSTextSelectionDataSource> dataSource = _textSelectionDataSource;
    // With no data source there is no document, and every answer of this method is a place in a document: the
    // header says a movement that produces no logically valid result answers nil, and that is the answer here.
    // The host hands back the selection it was given instead (M10), but the host's navigation object is never
    // made without a data source, so that is not an answer about a movement - and returning a selection that did
    // not move would say a movement happened. The divergence is recorded rather than copied.
    if (!dataSource)
        return nil;
    NSTextRange *document = dataSource.documentRange;
    if (!document || document.isEmpty)
        return nil;
    id<NSTextLocation> from = [self charon_location_after:textSelection];
    id<NSTextLocation> target = nil;
    switch (destination) {
    case NSTextSelectionNavigationDestinationCharacter:
        // A character is one composed character sequence, which is a grapheme cluster, and the data source is
        // what knows where the next one is.
        target = [dataSource locationFromLocation:from
                                       withOffset:direction == NSTextSelectionNavigationDirectionBackward ? -1 : 1];
        break;
    case NSTextSelectionNavigationDestinationWord:
    case NSTextSelectionNavigationDestinationSentence:
    case NSTextSelectionNavigationDestinationParagraph:
    case NSTextSelectionNavigationDestinationLine: {
        NSTextSelectionGranularity granularity = NSTextSelectionGranularityCharacter;
        if (destination == NSTextSelectionNavigationDestinationWord)
            granularity = NSTextSelectionGranularityWord;
        else if (destination == NSTextSelectionNavigationDestinationSentence)
            granularity = NSTextSelectionGranularitySentence;
        else if (destination == NSTextSelectionNavigationDestinationParagraph)
            granularity = NSTextSelectionGranularityParagraph;
        else
            granularity = NSTextSelectionGranularityLine;
        NSTextRange *enclosing = [self charon_range_enclosing:granularity at:from];
        if (enclosing)
            target = direction == NSTextSelectionNavigationDirectionBackward ? enclosing.location : enclosing.endLocation;
        break;
    }
    case NSTextSelectionNavigationDestinationDocument:
        target = direction == NSTextSelectionNavigationDirectionBackward ? document.location : document.endLocation;
        break;
    default:
        // A container boundary needs a data source that enumerates container boundaries; one that does not
        // has no boundary to move to, and the header says a move that produces no logically valid result
        // answers nil.
        return nil;
    }
    if (!target)
        return nil;
    // The movement's own range, ordered whichever way it was made, so a range is a range.
    NSTextRange *moved = [from compare:target] == NSOrderedAscending
                             ? [[NSTextRange alloc] initWithLocation:from endLocation:target]
                             : [[NSTextRange alloc] initWithLocation:target endLocation:from];
    if (!extending)
        return [[NSTextSelection alloc] initWithRange:moved
                                             affinity:textSelection.affinity
                                          granularity:textSelection.granularity];
    // Extending keeps the selection's first location and moves only its end, which is the header's rule and is
    // what makes a backward extension reach behind the cursor: the end that moved is the location the movement
    // reached, not the one it came from.
    NSTextRange *anchor = [textSelection.textRanges firstObject];
    NSTextRange *extended = [anchor.location compare:target] == NSOrderedAscending
                                ? [[NSTextRange alloc] initWithLocation:anchor.location endLocation:target]
                                : [[NSTextRange alloc] initWithLocation:target endLocation:anchor.location];
    return [[NSTextSelection alloc] initWithRange:extended
                                        affinity:textSelection.affinity
                                     granularity:textSelection.granularity];
}

- (NSArray<NSTextSelection *> *)textSelectionsInteractingAtPoint:(CGPoint)point
                                            inContainerAtLocation:(id<NSTextLocation>)containerLocation
                                                         anchors:(NSArray<NSTextSelection *> *)anchors
                                                       modifiers:(NSTextSelectionNavigationModifier)modifiers
                                                       selecting:(BOOL)selecting
                                                           bounds:(CGRect)bounds
{
    id<NSTextSelectionDataSource> dataSource = _textSelectionDataSource;
    if (!dataSource)
        return @[];
    NSTextRange *line = [dataSource lineFragmentRangeForPoint:point inContainerAtLocation:containerLocation];
    if (!line)
        return @[];
    NSTextSelection *selection = [[NSTextSelection alloc] initWithRange:line
                                                                affinity:NSTextSelectionAffinityDownstream
                                                             granularity:NSTextSelectionGranularityLine];
    // A drag that extends from an anchor keeps the anchor's selection, which is the modifier's own rule: the
    // anchor is the selection the drag started from and a line that is being dragged over does not replace it.
    if (selecting && (modifiers & NSTextSelectionNavigationModifierExtend) && [anchors count])
        selection = [anchors lastObject];
    return @[ selection ];
}

- (NSTextSelection *)textSelectionForSelectionGranularity:(NSTextSelectionGranularity)selectionGranularity
                                     enclosingTextSelection:(NSTextSelection *)textSelection
{
    if (!textSelection)
        return nil;
    // One enclosing range per range of the selection, in the order they were given, and a granularity of the
    // selection asked for: that is what the header says the answer is, and a range the data source cannot
    // enclose is left out rather than answered with something that is not around it.
    NSMutableArray *ranges = [NSMutableArray array];
    for (NSTextRange *range in textSelection.textRanges) {
        NSTextRange *enclosing = [self charon_range_enclosing:selectionGranularity at:range.location];
        if (enclosing)
            [ranges addObject:enclosing];
    }
    if (![ranges count])
        return nil;
    return [[NSTextSelection alloc] initWithRanges:ranges
                                          affinity:textSelection.affinity
                                       granularity:selectionGranularity];
}

- (NSTextSelection *)textSelectionForSelectionGranularity:(NSTextSelectionGranularity)selectionGranularity
                                          enclosingPoint:(CGPoint)point
                                    inContainerAtLocation:(id<NSTextLocation>)location
{
    id<NSTextSelectionDataSource> dataSource = _textSelectionDataSource;
    if (!dataSource)
        return nil;
    NSTextRange *line = [dataSource lineFragmentRangeForPoint:point inContainerAtLocation:location];
    if (!line)
        return nil;
    NSTextRange *enclosing = [self charon_range_enclosing:selectionGranularity at:line.location];
    if (!enclosing)
        return nil;
    return [[NSTextSelection alloc] initWithRange:enclosing
                                         affinity:NSTextSelectionAffinityDownstream
                                      granularity:selectionGranularity];
}

- (id<NSTextLocation>)resolvedInsertionLocationForTextSelection:(NSTextSelection *)textSelection
                                                writingDirection:(NSTextSelectionNavigationWritingDirection)writingDirection
{
    // The header's own rule, which is the whole of it: the answer is the secondary location of a selection
    // that is not logical and has one, and nil for anything else, so that the caller types at the selection's
    // own location instead. A secondary location is a location and not a range, so there are not two ends of it
    // for the writing direction to choose between and the direction does not enter into the answer.
    if (!textSelection || textSelection.isLogical || !textSelection.secondarySelectionLocation)
        return nil;
    return textSelection.secondarySelectionLocation;
}

- (NSArray<NSTextRange *> *)deletionRangesForTextSelection:(NSTextSelection *)textSelection
                                                   direction:(NSTextSelectionNavigationDirection)direction
                                                 destination:(NSTextSelectionNavigationDestination)destination
                                           allowsDecomposition:(BOOL)allowsDecomposition
{
    if (!textSelection)
        return @[];
    // A selection with contents deletes itself, and the destination is ignored: that is the header's own rule
    // for this method, which is what makes a delete of a selection independent of where the caret is.
    if ([textSelection.textRanges count])
        return [textSelection.textRanges copy];
    // A cursor has no contents, so a delete removes what a move over the same destination would have selected.
    // With no data source a move produces nothing, so what a delete removes is nothing and the range that comes
    // back is the cursor's own empty range at its own location - which is what the header asks the selection
    // left after a deletion to be, an empty range where the first range that was going to be removed began,
    // and what the host answers in the same state (M10). allowsDecomposition only applies to a backward move over one character, and a decomposed
    // grapheme cluster is not a different destination, so the destination asked for is the one the header names.
    if (!_textSelectionDataSource)
        return [textSelection.textRanges copy];
    NSTextSelection *moved = [self destinationSelectionForTextSelection:textSelection
                                                                direction:direction
                                                              destination:destination
                                                               extending:NO
                                                                 confined:NO];
    if (!moved)
        return @[];
    return [moved.textRanges copy];
}

- (NSString *)description
{
    // The host's own text, which is the class and the address and nothing else - a navigation object with no
    // data source is no different from one with a data source, and the data source's own description is its
    // business.
    return [NSString stringWithFormat:@"<%@: %p>", [self class], self];
}

@end
