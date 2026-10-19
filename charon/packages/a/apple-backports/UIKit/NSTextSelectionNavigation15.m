#import <UIKit/UIKit.h>

@implementation NSTextSelectionNavigation

@synthesize textSelectionDataSource = _textSelectionDataSource;
@synthesize allowsNonContiguousRanges = _allowsNonContiguousRanges;
@synthesize rotatesCoordinateSystemForLayoutOrientation = _rotatesCoordinateSystemForLayoutOrientation;

- (instancetype)initWithDataSource:(id<NSTextSelectionDataSource>)dataSource
{
    if ((self = [super init])) {
        _textSelectionDataSource = dataSource;
        _allowsNonContiguousRanges = YES;
    }
    return self;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ cannot be made without a data source: use -initWithDataSource:",
                       NSStringFromClass([self class])];
    return nil;
}

- (void)flushLayoutCache
{
}

- (NSTextRange *)charon_range_enclosing:(NSTextSelectionGranularity)granularity at:(id<NSTextLocation>)location
{
    id<NSTextSelectionDataSource> dataSource = _textSelectionDataSource;
    if (!dataSource)
        return nil;
    return [dataSource textRangeForSelectionGranularity:granularity enclosingLocation:location];
}

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
    if (!dataSource)
        return nil;
    NSTextRange *document = dataSource.documentRange;
    if (!document || document.isEmpty)
        return nil;
    id<NSTextLocation> from = [self charon_location_after:textSelection];
    id<NSTextLocation> target = nil;
    switch (destination) {
    case NSTextSelectionNavigationDestinationCharacter:
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
        return nil;
    }
    if (!target)
        return nil;
    NSTextRange *moved = [from compare:target] == NSOrderedAscending
                             ? [[NSTextRange alloc] initWithLocation:from endLocation:target]
                             : [[NSTextRange alloc] initWithLocation:target endLocation:from];
    if (!extending)
        return [[NSTextSelection alloc] initWithRange:moved
                                             affinity:textSelection.affinity
                                          granularity:textSelection.granularity];
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
    if (selecting && (modifiers & NSTextSelectionNavigationModifierExtend) && [anchors count])
        selection = [anchors lastObject];
    return @[ selection ];
}

- (NSTextSelection *)textSelectionForSelectionGranularity:(NSTextSelectionGranularity)selectionGranularity
                                     enclosingTextSelection:(NSTextSelection *)textSelection
{
    if (!textSelection)
        return nil;
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
    if ([textSelection.textRanges count])
        return [textSelection.textRanges copy];
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
    return [NSString stringWithFormat:@"<%@: %p>", [self class], self];
}

@end
