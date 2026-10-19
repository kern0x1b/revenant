#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@interface RangeLayerLocation : NSObject <NSTextLocation>
@property (nonatomic, readonly) NSInteger rangeOffset;
- (instancetype)initWithRangeOffset:(NSInteger)offset;
@end

@implementation RangeLayerLocation

@synthesize rangeOffset = _rangeOffset;

- (instancetype)initWithRangeOffset:(NSInteger)offset
{
    if ((self = [super init]))
        _rangeOffset = offset;
    return self;
}

- (NSComparisonResult)compare:(id<NSTextLocation>)location
{
    NSInteger other = location ? [(RangeLayerLocation *)location rangeOffset] : 0;
    return _rangeOffset == other ? NSOrderedSame : (_rangeOffset < other ? NSOrderedAscending : NSOrderedDescending);
}

- (BOOL)isEqual:(id)object
{
    return object == self || ([object isKindOfClass:[RangeLayerLocation class]] && [object rangeOffset] == _rangeOffset);
}

- (NSUInteger)hash { return (NSUInteger)_rangeOffset; }
- (NSString *)description { return [NSString stringWithFormat:@"%ld", (long)_rangeOffset]; }

@end

static id<NSTextLocation> at(NSInteger offset)
{
    return [[RangeLayerLocation alloc] initWithRangeOffset:offset];
}

@interface RevenantHostNSTextRange : NSObject
- (instancetype)initWithLocation:(id<NSTextLocation>)location;
- (instancetype)initWithLocation:(id<NSTextLocation>)location endLocation:(id<NSTextLocation>)endLocation;
- (instancetype)init;
@property (readonly, getter=isEmpty) BOOL empty;
@property (strong, readonly) id<NSTextLocation> location;
@property (strong, readonly) id<NSTextLocation> endLocation;
- (BOOL)isEqualToTextRange:(id)textRange;
- (BOOL)containsLocation:(id<NSTextLocation>)location;
- (BOOL)containsRange:(id)textRange;
- (BOOL)intersectsWithTextRange:(id)textRange;
- (instancetype)textRangeByIntersectingWithTextRange:(id)textRange;
- (instancetype)textRangeByFormingUnionWithTextRange:(id)textRange;
@end

@interface RevenantHostNSTextSelection : NSObject
- (instancetype)initWithRange:(id)range
                     affinity:(NSTextSelectionAffinity)affinity
                  granularity:(NSTextSelectionGranularity)granularity;
- (instancetype)initWithRanges:(NSArray *)textRanges
                      affinity:(NSTextSelectionAffinity)affinity
                   granularity:(NSTextSelectionGranularity)granularity;
- (instancetype)initWithLocation:(id<NSTextLocation>)location affinity:(NSTextSelectionAffinity)affinity;
- (instancetype)init;
@property (copy, readonly) NSArray *textRanges;
@property (readonly) NSTextSelectionGranularity granularity;
@property (readonly) NSTextSelectionAffinity affinity;
@property (readonly, getter=isTransient) BOOL transient;
@property CGFloat anchorPositionOffset;
@property (getter=isLogical) BOOL logical;
@property (strong, nullable) id<NSTextLocation> secondarySelectionLocation;
@property (copy) NSDictionary *typingAttributes;
- (instancetype)textSelectionWithTextRanges:(NSArray *)textRanges;
- (BOOL)isEqual:(id)object;
+ (BOOL)supportsSecureCoding;
@end

@interface RevenantHostNSTextElement : NSObject
- (instancetype)initWithTextContentManager:(id)textContentManager;
@property (nullable, weak) id textContentManager;
@property (nullable, strong) NSTextRange *elementRange;
@property (readonly, copy) NSArray *childElements;
@property (nullable, readonly, weak) NSTextElement *parentElement;
@property (readonly) BOOL isRepresentedElement;
- (NSString *)description;
@end

@interface RevenantHostNSTextParagraph : RevenantHostNSTextElement
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString;
@property (strong, readonly) NSAttributedString *attributedString;
@property (nullable, strong, readonly) NSTextRange *paragraphContentRange;
@property (nullable, strong, readonly) NSTextRange *paragraphSeparatorRange;
@end

@interface RevenantHostNSTextSelectionNavigation : NSObject
- (instancetype)initWithDataSource:(id)dataSource;
- (instancetype)init;
@property (readonly, weak) id textSelectionDataSource;
@property BOOL allowsNonContiguousRanges;
@property BOOL rotatesCoordinateSystemForLayoutOrientation;
- (void)flushLayoutCache;
- (nullable id)destinationSelectionForTextSelection:(id)textSelection
                                                         direction:(NSTextSelectionNavigationDirection)direction
                                                       destination:(NSTextSelectionNavigationDestination)destination
                                                        extending:(BOOL)extending
                                                          confined:(BOOL)confined;
- (nullable id<NSTextLocation>)resolvedInsertionLocationForTextSelection:(id)textSelection
                                                        writingDirection:(NSTextSelectionNavigationWritingDirection)direction;
- (NSArray<NSTextRange *> *)deletionRangesForTextSelection:(id)textSelection
                                                   direction:(NSTextSelectionNavigationDirection)direction
                                                 destination:(NSTextSelectionNavigationDestination)destination
                                           allowsDecomposition:(BOOL)allowsDecomposition;
- (NSArray<NSTextSelection *> *)textSelectionsInteractingAtPoint:(CGPoint)point
                                            inContainerAtLocation:(id<NSTextLocation>)containerLocation
                                                         anchors:(NSArray *)anchors
                                                       modifiers:(NSTextSelectionNavigationModifier)modifiers
                                                       selecting:(BOOL)selecting
                                                           bounds:(CGRect)bounds;
- (nullable id)textSelectionForSelectionGranularity:(NSTextSelectionGranularity)granularity
                                     enclosingPoint:(CGPoint)point
                           inContainerAtLocation:(id<NSTextLocation>)location;
- (nullable id)textSelectionForSelectionGranularity:(NSTextSelectionGranularity)granularity
                                enclosingTextSelection:(id)textSelection;
- (NSString *)description;
@end

static Class system_range_class(void) { return NSClassFromString(@"NSTextRange"); }
static Class port_range_class(void) { return NSClassFromString(@"RevenantHostNSTextRange"); }
static Class port_selection_class(void) { return NSClassFromString(@"RevenantHostNSTextSelection"); }
static Class port_element_class(void) { return NSClassFromString(@"RevenantHostNSTextElement"); }
static Class port_paragraph_class(void) { return NSClassFromString(@"RevenantHostNSTextParagraph"); }
static Class port_navigation_class(void) { return NSClassFromString(@"RevenantHostNSTextSelectionNavigation"); }

static RevenantHostNSTextRange *port_range(NSInteger from, NSInteger to)
{
    if (to < 0)
        return [[RevenantHostNSTextRange alloc] initWithLocation:at(from)];
    return [[RevenantHostNSTextRange alloc] initWithLocation:at(from) endLocation:at(to)];
}

static NSTextRange *system_range(NSInteger from, NSInteger to)
{
    if (to < 0)
        return [[NSTextRange alloc] initWithLocation:at(from)];
    return [[NSTextRange alloc] initWithLocation:at(from) endLocation:at(to)];
}

static NSTextSelection *system_pair(NSInteger from, NSInteger to, NSTextSelectionAffinity affinity,
                                    NSTextSelectionGranularity granularity)
{
    return [[NSTextSelection alloc] initWithRange:system_range(from, to) affinity:affinity granularity:granularity];
}

static RevenantHostNSTextSelection *port_pair(NSInteger from, NSInteger to, NSTextSelectionAffinity affinity,
                                            NSTextSelectionGranularity granularity)
{
    return [[RevenantHostNSTextSelection alloc] initWithRange:port_range(from, to) affinity:affinity granularity:granularity];
}

static NSString *described(id object)
{
    if (!object)
        return @"(nil)";
    NSString *text = [[object description] stringByReplacingOccurrencesOfString:@"RevenantHost" withString:@""];
    NSRegularExpression *addresses = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-fA-F]+"
                                                                              options:0
                                                                                error:NULL];
    return [addresses stringByReplacingMatchesInString:text
                                               options:0
                                                 range:NSMakeRange(0, text.length)
                                          withTemplate:@"0xX"];
}

static void compare_text(NSString *system, NSString *port, NSString *name)
{
    revenant_check([system isEqualToString:port], name.UTF8String,
                 [NSString stringWithFormat:@"system %@ != port %@", described(system), described(port)]);
}

static void compare_ranges(void)
{
    NSTextRange *systemEmpty = system_range(3, -1);
    RevenantHostNSTextRange *portEmpty = port_range(3, -1);
    revenant_check([systemEmpty isEmpty] == [portEmpty isEmpty], "a range with no end is empty on both sides",
                 @"one side is not empty");
    revenant_check([systemEmpty.endLocation isEqual:systemEmpty.location] == [portEmpty.endLocation isEqual:portEmpty.location],
                 "a range with no end answers its start as its end", @"one side does not");
    compare_text(described(systemEmpty), described(portEmpty), @"an empty range, described");

    NSTextRange *systemA = system_range(0, 10);
    RevenantHostNSTextRange *portA = port_range(0, 10);
    NSTextRange *systemB = system_range(5, 15);
    RevenantHostNSTextRange *portB = port_range(5, 15);
    compare_text(described(systemA), described(portA), @"a range, described");

    for (NSInteger where = 0; where <= 11; where++) {
        revenant_check([systemA containsLocation:at(where)] == [portA containsLocation:at(where)],
                     NAMED(@"0...10 contains location %ld", (long)where), @"the two sides disagree");
    }
    revenant_check([systemEmpty containsLocation:at(3)] == [portEmpty containsLocation:at(3)],
                 "an empty range contains its own start, or neither does", @"the two sides disagree");

    NSArray *bounds = @[ @0, @5, @10, @15, @20, @25 ];
    for (NSNumber *outerFrom in bounds) {
        for (NSNumber *outerTo in bounds) {
            for (NSNumber *innerFrom in bounds) {
                for (NSNumber *innerTo in bounds) {
                    if (outerTo < outerFrom || innerTo < innerFrom)
                        continue;
                    NSTextRange *systemOuter = system_range(outerFrom.integerValue, outerTo.integerValue);
                    RevenantHostNSTextRange *portOuter = port_range(outerFrom.integerValue, outerTo.integerValue);
                    NSTextRange *systemInner = system_range(innerFrom.integerValue, innerTo.integerValue);
                    RevenantHostNSTextRange *portInner = port_range(innerFrom.integerValue, innerTo.integerValue);
                    NSString *pair = [NSString stringWithFormat:@"%@ contains %@", described(systemOuter),
                                                described(systemInner)];
                    revenant_check([systemOuter containsRange:systemInner] == [portOuter containsRange:portInner],
                                 NAMED(@"%@", pair), @"the two sides disagree");
                    pair = [NSString stringWithFormat:@"%@ intersects %@", described(systemOuter), described(systemInner)];
                    revenant_check([systemOuter intersectsWithTextRange:systemInner] ==
                                     [portOuter intersectsWithTextRange:portInner],
                                 NAMED(@"%@", pair), @"the two sides disagree");
                    compare_text(described([systemOuter textRangeByFormingUnionWithTextRange:systemInner]),
                                 described([portOuter textRangeByFormingUnionWithTextRange:portInner]),
                                 [pair stringByReplacingOccurrencesOfString:@"intersects" withString:@"union of"]);
                    compare_text(described([systemOuter textRangeByIntersectingWithTextRange:systemInner]),
                                 described([portOuter textRangeByIntersectingWithTextRange:portInner]),
                                 [pair stringByReplacingOccurrencesOfString:@"intersects" withString:@"intersection of"]);
                }
            }
        }
    }
    compare_text(described([systemA textRangeByFormingUnionWithTextRange:systemEmpty]),
                 described([portA textRangeByFormingUnionWithTextRange:portEmpty]),
                 @"0...10 with an empty range, unioned");
    NSTextRange *systemFar = system_range(40, 40);
    RevenantHostNSTextRange *portFar = port_range(40, 40);
    compare_text(described([systemEmpty textRangeByFormingUnionWithTextRange:systemFar]),
                 described([portEmpty textRangeByFormingUnionWithTextRange:portFar]),
                 @"two empty ranges at different places, unioned");

    for (NSArray *pair in @[ @[ systemA, portA ], @[ systemB, portB ] ]) {
        NSTextRange *system = pair[0];
        RevenantHostNSTextRange *port = pair[1];
        revenant_check([systemA isEqualToTextRange:system] == [portA isEqualToTextRange:port],
                     NAMED(@"0...10 isEqualToTextRange %@", described(system)), @"the two sides disagree");
    }
    id nothing = nil;
    revenant_check([systemA isEqualToTextRange:nothing] == [portA isEqualToTextRange:nothing],
                 "isEqualToTextRange: nil is NO on both sides", @"one side says YES");
    revenant_check([systemA isEqual:systemA] == [portA isEqual:portA], "a range is equal to itself", @"one side is not");
    revenant_check([systemA isEqual:system_range(0, 10)] == [portA isEqual:port_range(0, 10)],
                 "two ranges over the same locations are equal", @"one side is not");
    revenant_check([systemA respondsToSelector:@selector(copyWithZone:)] == [portA respondsToSelector:@selector(copyWithZone:)],
                 "neither side copies a range", @"one side has a copyWithZone:");
    revenant_check([systemA isKindOfClass:[NSTextRange class]] && [portA isKindOfClass:port_range_class()],
                 "both sides are an NSTextRange", @"one side is not");
    revenant_check([systemA superclass] == [NSObject class] && [portA superclass] == [NSObject class],
                 "both sides derive from NSObject", @"one side does not");
    revenant_check([systemA hash] != [system_range(0, 10) hash], "the host still hashes two equal ranges differently",
                 @"the host's hash is now by value");
    revenant_check([portA hash] == [port_range(0, 10) hash], "the port hashes a range by its value",
                 @"two equal ranges on the port hash differently");
    revenant_check(![systemA respondsToSelector:@selector(initWithCoder:)] && ![portA respondsToSelector:@selector(initWithCoder:)],
                 "neither side decodes a range", @"one side has an initWithCoder:");
    revenant_check(![system_range_class() respondsToSelector:@selector(supportsSecureCoding)] &&
                     ![port_range_class() respondsToSelector:@selector(supportsSecureCoding)],
                 "neither range class says it supports secure coding", @"one side does");
}



static void compare_unavailable_initializers(void)
{
    @try {
        (void)[[port_range_class() alloc] init];
        revenant_check(NO, "a port range refuses a bare -init", @"it made one");
    } @catch (NSException *exception) {
        revenant_check([exception.name isEqualToString:NSInternalInconsistencyException] &&
                         [[exception reason] rangeOfString:@"initWithLocation"].location != NSNotFound,
                     "a port range refuses a bare -init and says which initialiser to use",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    @try {
        (void)[[port_selection_class() alloc] init];
        revenant_check(NO, "a port selection refuses a bare -init", @"it made one");
    } @catch (NSException *exception) {
        revenant_check([exception.name isEqualToString:NSInternalInconsistencyException] &&
                         [[exception reason] rangeOfString:@"initWithRanges"].location != NSNotFound,
                     "a port selection refuses a bare -init and says which initialiser to use",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    @try {
        (void)[[port_navigation_class() alloc] init];
        revenant_check(NO, "a port navigation object refuses a bare -init", @"it made one");
    } @catch (NSException *exception) {
        revenant_check([exception.name isEqualToString:NSInternalInconsistencyException] &&
                         [[exception reason] rangeOfString:@"initWithDataSource"].location != NSNotFound,
                     "a port navigation object refuses a bare -init and says which initialiser to use",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    @try {
        (void)[port_range_class() new];
        revenant_check(NO, "a port range refuses +new", @"it made one");
    } @catch (NSException *exception) {
        revenant_check([exception.name isEqualToString:NSInternalInconsistencyException], "a port range refuses +new",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    @try {
        (void)[port_navigation_class() new];
        revenant_check(NO, "a port navigation object refuses +new", @"it made one");
    } @catch (NSException *exception) {
        revenant_check([exception.name isEqualToString:NSInternalInconsistencyException],
                     "a port navigation object refuses +new",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
}

static void compare_selections(void)
{
    NSTextSelection *systemOne = [[NSTextSelection alloc] initWithRange:system_range(0, 5)
                                                                affinity:NSTextSelectionAffinityDownstream
                                                             granularity:NSTextSelectionGranularityCharacter];
    RevenantHostNSTextSelection *portOne = [[RevenantHostNSTextSelection alloc] initWithRange:port_range(0, 5)
                                                                                 affinity:NSTextSelectionAffinityDownstream
                                                                              granularity:NSTextSelectionGranularityCharacter];
    compare_text(described(systemOne), described(portOne), @"a selection, described");
    revenant_check([systemOne.textRanges count] == [portOne textRanges].count, "one range either way",
                 @"the two sides disagree on the count");
    revenant_check([systemOne affinity] == [portOne affinity] && [systemOne granularity] == [portOne granularity],
                 "the affinity and the granularity are kept", @"one side differs");
    revenant_check([systemOne isTransient] == [portOne isTransient], "neither side is transient", @"one side is");
    revenant_check([systemOne isLogical] == [portOne isLogical], "neither side is logical to begin with", @"one side is");
    revenant_check([systemOne anchorPositionOffset] == [portOne anchorPositionOffset], "the anchor offset starts at zero",
                 @"one side does not");
    revenant_check(systemOne.typingAttributes == nil && [portOne typingAttributes] == nil,
                 "a selection with no typing attributes answers nil on both sides", @"one side answers a dictionary");
    id noAttributes = nil;
    [systemOne setTypingAttributes:noAttributes];
    [portOne setTypingAttributes:noAttributes];
    revenant_check(systemOne.typingAttributes != nil && [portOne typingAttributes] != nil &&
                     systemOne.typingAttributes.count == 0 && [portOne typingAttributes].count == 0,
                 "and a setter handed nil leaves an empty dictionary on both sides", @"one side answers nil");

    NSArray *messy = @[ system_range(20, 25), system_range(0, 10), system_range(5, 15) ];
    NSArray *portMessy = @[ port_range(20, 25), port_range(0, 10), port_range(5, 15) ];
    NSTextSelection *systemUntidy = [[NSTextSelection alloc] initWithRanges:messy
                                                                   affinity:NSTextSelectionAffinityUpstream
                                                                granularity:NSTextSelectionGranularityWord];
    RevenantHostNSTextSelection *portUntidy = [[RevenantHostNSTextSelection alloc] initWithRanges:portMessy
                                                                                     affinity:NSTextSelectionAffinityUpstream
                                                                                  granularity:NSTextSelectionGranularityWord];
    compare_text(described(systemUntidy), described(portUntidy),
                 @"a selection handed overlapping ranges out of order, described");
    revenant_check(systemUntidy.textRanges.count == 3 && [portUntidy textRanges].count == 3,
                 "three ranges in, three ranges out", @"a side merged or dropped one");

    NSTextSelection *systemTouching = [[NSTextSelection alloc] initWithRanges:@[ system_range(0, 5), system_range(5, 10) ]
                                                                     affinity:NSTextSelectionAffinityUpstream
                                                                  granularity:NSTextSelectionGranularityWord];
    RevenantHostNSTextSelection *portTouching = [[RevenantHostNSTextSelection alloc] initWithRanges:@[ port_range(0, 5), port_range(5, 10) ]
                                                                                     affinity:NSTextSelectionAffinityUpstream
                                                                                  granularity:NSTextSelectionGranularityWord];
    compare_text(described(systemTouching), described(portTouching),
                 @"a selection handed two touching ranges, described");

    NSTextSelection *systemNone = [[NSTextSelection alloc] initWithRanges:@[]
                                                                  affinity:NSTextSelectionAffinityDownstream
                                                               granularity:NSTextSelectionGranularityCharacter];
    RevenantHostNSTextSelection *portNone = [[RevenantHostNSTextSelection alloc] initWithRanges:@[]
                                                                                  affinity:NSTextSelectionAffinityDownstream
                                                                               granularity:NSTextSelectionGranularityCharacter];
    revenant_check(systemNone.textRanges.count == 0 && [portNone textRanges].count == 0,
                 "a selection of no ranges is empty on either side", @"one side is not");

    NSTextSelection *systemCursor = [[NSTextSelection alloc] initWithLocation:at(4)
                                                                     affinity:NSTextSelectionAffinityDownstream];
    RevenantHostNSTextSelection *portCursor = [[RevenantHostNSTextSelection alloc] initWithLocation:at(4)
                                                                                      affinity:NSTextSelectionAffinityDownstream];
    compare_text(described(systemCursor), described(portCursor), @"a selection of one location, described");
    revenant_check(systemCursor.granularity == [portCursor granularity], "a cursor is a character granularity",
                 @"one side differs");

    [systemOne setSecondarySelectionLocation:at(8)];
    [portOne setSecondarySelectionLocation:at(8)];
    revenant_check([systemOne isLogical] == [portOne isLogical] && ![systemOne isLogical] && ![portOne isLogical],
                 "a secondary location makes a selection not logical on both sides", @"one side is logical");
    [systemOne setLogical:YES];
    [portOne setLogical:YES];
    revenant_check([systemOne isLogical] == [portOne isLogical] && [systemOne isLogical],
                 "logical can be set back on both sides", @"one side cannot");

    NSTextSelection *systemOther = [systemOne textSelectionWithTextRanges:@[ system_range(1, 2) ]];
    RevenantHostNSTextSelection *portOther = [portOne textSelectionWithTextRanges:@[ port_range(1, 2) ]];
    compare_text(described(systemOther), described(portOther), @"a selection with new ranges, described");
    revenant_check(systemOther.isLogical == [portOther isLogical] && systemOther.isLogical,
                 "a copy of a logical selection with a secondary location is still logical", @"one side differs");
    revenant_check([systemOther secondarySelectionLocation] != nil && [[portOther secondarySelectionLocation] isEqual:at(8)],
                 "a copy carries the secondary location", @"one side lost it");
    revenant_check(systemOther.typingAttributes != nil && [portOther typingAttributes] != nil &&
                     systemOther.typingAttributes.count == 0 && [portOther typingAttributes].count == 0,
                 "a copy of a selection with no typing attributes has an empty dictionary", @"one side answers nil");
    revenant_check(systemOther.affinity == [portOther affinity] && systemOther.anchorPositionOffset == [portOther anchorPositionOffset],
                 "a copy keeps the affinity and the anchor offset", @"one side differs");
    compare_text(described(systemOne), described(portOne), @"and the selection it was made from is unchanged");

    [systemOne setAnchorPositionOffset:1.5];
    [portOne setAnchorPositionOffset:1.5];
    [systemOne setTypingAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:12] }];
    [portOne setTypingAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:12] }];
    revenant_check(systemOne.anchorPositionOffset == [portOne anchorPositionOffset], "the anchor offset is kept",
                 @"one side differs");
    revenant_check([systemOne.typingAttributes count] == [[portOne typingAttributes] count] && systemOne.typingAttributes.count == 1,
                 "the typing attributes are kept", @"one side differs");
    revenant_check([[[systemOne typingAttributes] objectForKey:NSFontAttributeName] isEqual:[[portOne typingAttributes] objectForKey:NSFontAttributeName]],
                 "and are the same attributes on both sides", @"one side differs");
    NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithObject:[UIFont systemFontOfSize:12]
                                                                      forKey:NSFontAttributeName];
    NSTextSelection *systemCopied = [[NSTextSelection alloc] initWithRange:system_range(0, 5)
                                                                  affinity:NSTextSelectionAffinityDownstream
                                                               granularity:NSTextSelectionGranularityCharacter];
    RevenantHostNSTextSelection *portCopied = [[RevenantHostNSTextSelection alloc] initWithRange:port_range(0, 5)
                                                                                   affinity:NSTextSelectionAffinityDownstream
                                                                                granularity:NSTextSelectionGranularityCharacter];
    [systemCopied setTypingAttributes:mutable];
    [portCopied setTypingAttributes:mutable];
    [mutable removeAllObjects];
    revenant_check([systemCopied.typingAttributes count] == [[portCopied typingAttributes] count] &&
                     systemCopied.typingAttributes.count == 1,
                 "the typing attributes are copied, not held", @"one side holds the caller's dictionary");

    NSTextSelection *systemEqual = system_pair(0, 5, NSTextSelectionAffinityDownstream,
                                               NSTextSelectionGranularityCharacter);
    RevenantHostNSTextSelection *portEqual = port_pair(0, 5, NSTextSelectionAffinityDownstream,
                                                     NSTextSelectionGranularityCharacter);
    revenant_check([systemEqual isEqual:systemEqual] == [portEqual isEqual:portEqual], "a selection equals itself",
                 @"one side does not");
    revenant_check([systemEqual isEqual:system_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter)] ==
                     [portEqual isEqual:port_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter)],
                 "two separately made selections over the same state are equal", @"one side is not");
    revenant_check([system_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) hash] ==
                     [system_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) hash] &&
                     [port_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) hash] ==
                         [port_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) hash],
                 "and they hash alike on both sides", @"one side hashes by identity");
    revenant_check([NSSet setWithObjects:systemEqual,
                                            system_pair(0, 5, NSTextSelectionAffinityDownstream,
                                                        NSTextSelectionGranularityCharacter),
                                            nil].count == 1 &&
                     [NSSet setWithObjects:portEqual,
                                             port_pair(0, 5, NSTextSelectionAffinityDownstream,
                                                       NSTextSelectionGranularityCharacter),
                                             nil].count == 1,
                 "a set of two equal selections holds one on both sides", @"one side holds two");
    struct { const char *key; NSTextSelection *system; RevenantHostNSTextSelection *port; } differing[] = {
        { "the ranges", system_pair(1, 6, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter),
          port_pair(1, 6, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) },
        { "the affinity", system_pair(0, 5, NSTextSelectionAffinityUpstream, NSTextSelectionGranularityCharacter),
          port_pair(0, 5, NSTextSelectionAffinityUpstream, NSTextSelectionGranularityCharacter) },
        { "the granularity", system_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityWord),
          port_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityWord) },
        { "the anchor offset", system_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter),
          port_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) },
        { "the typing attributes", system_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter),
          port_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) },
        { "the logical flag", system_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter),
          port_pair(0, 5, NSTextSelectionAffinityDownstream, NSTextSelectionGranularityCharacter) },
    };
    differing[3].system.anchorPositionOffset = 2;
    differing[3].port.anchorPositionOffset = 2;
    [differing[4].system setTypingAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:12] }];
    [differing[4].port setTypingAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:12] }];
    [differing[5].system setLogical:YES];
    [differing[5].port setLogical:YES];
    for (size_t index = 0; index < sizeof(differing) / sizeof(differing[0]); index++) {
        revenant_check(![systemEqual isEqual:differing[index].system] && ![portEqual isEqual:differing[index].port],
                     NAMED(@"two selections differing in %s are not equal", differing[index].key), @"one side says they are");
    }

    NSTextSelection *systemForeign = nil;
    RevenantHostNSTextSelection *portForeign = nil;
    @try {
        systemForeign = [[NSTextSelection alloc] initWithRanges:(NSArray *)@[ @"not a range" ]
                                                       affinity:NSTextSelectionAffinityDownstream
                                                    granularity:NSTextSelectionGranularityCharacter];
    } @catch (NSException *exception) {
        revenant_check(NO, "the host takes a range that is not an NSTextRange", exception.name);
    }
    @try {
        portForeign = [[RevenantHostNSTextSelection alloc] initWithRanges:(NSArray *)@[ @"not a range" ]
                                                               affinity:NSTextSelectionAffinityDownstream
                                                            granularity:NSTextSelectionGranularityCharacter];
    } @catch (NSException *exception) {
        revenant_check(NO, "the port takes a range that is not an NSTextRange", exception.name);
    }
    revenant_check((systemForeign != nil) == (portForeign != nil), "both sides take a range that is not an NSTextRange",
                 @"one side refuses it");
    revenant_check([[NSTextSelection class] supportsSecureCoding] == [port_selection_class() supportsSecureCoding],
                 "both sides say the selection supports secure coding", @"one side does not");
}

static void compare_elements(void)
{
    NSTextParagraph *systemPlain = [[NSTextParagraph alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:@"Hello"]];
    RevenantHostNSTextParagraph *portPlain = [[RevenantHostNSTextParagraph alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:@"Hello"]];
    revenant_check(systemPlain.attributedString.length == [portPlain attributedString].length,
                 "a paragraph keeps the string it was given", @"one side does not");
    revenant_check([systemPlain isRepresentedElement] == [portPlain isRepresentedElement],
                 "a paragraph is a represented element on both sides", @"one side is not");
    revenant_check(systemPlain.childElements.count == [portPlain childElements].count,
                 "a paragraph has no children on either side", @"one side has some");
    revenant_check(systemPlain.parentElement == nil && [portPlain parentElement] == nil,
                 "a paragraph has no parent on either side", @"one side has one");
    compare_text(described(systemPlain), described(portPlain), @"a paragraph, described");
    NSTextParagraph *systemNone = [[NSTextParagraph alloc] initWithAttributedString:nil];
    RevenantHostNSTextParagraph *portNone = [[RevenantHostNSTextParagraph alloc] initWithAttributedString:nil];
    compare_text(described(systemNone), described(portNone), @"a paragraph over no string, described");
    revenant_check(systemNone.attributedString == nil && [portNone attributedString] == nil,
                 "a paragraph made with no string keeps none on either side", @"one side has one");

    for (NSString *text in @[ @"Hello", @"Hello\n", @"Hello\r\n", @"\n", @"a\nb" ]) {
        NSString *spelled = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<CR><LF>"];
        spelled = [spelled stringByReplacingOccurrencesOfString:@"\n" withString:@"<LF>"];
        NSTextParagraph *system = [[NSTextParagraph alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:text]];
        RevenantHostNSTextParagraph *port = [[RevenantHostNSTextParagraph alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:text]];
        revenant_check(system.paragraphContentRange == nil && system.paragraphSeparatorRange == nil &&
                          [port paragraphContentRange] == nil && [port paragraphSeparatorRange] == nil,
                     NAMED(@"%@ derives no range with no content manager", spelled), @"one side derives one");
        id systemPlace = system_range(100, 100 + (NSInteger)text.length);
        id portPlace = port_range(100, 100 + (NSInteger)text.length);
        [system setElementRange:systemPlace];
        [port setElementRange:portPlace];
        revenant_check(system.paragraphContentRange == nil && system.paragraphSeparatorRange == nil &&
                          [port paragraphContentRange] == nil && [port paragraphSeparatorRange] == nil,
                     NAMED(@"%@ derives no range even with an element range", spelled), @"one side derives one");
    }

    NSTextElement *systemElement = [[NSTextElement alloc] initWithTextContentManager:nil];
    RevenantHostNSTextElement *portElement = [[RevenantHostNSTextElement alloc] initWithTextContentManager:nil];
    revenant_check([systemElement isRepresentedElement] == [portElement isRepresentedElement],
                 "the base element is a represented element on both sides", @"one side is not");
    revenant_check(systemElement.childElements.count == [portElement childElements].count,
                 "the base element has no children on either side", @"one side has some");
    revenant_check(systemElement.parentElement == nil && [portElement parentElement] == nil,
                 "the base element has no parent on either side", @"one side has one");
    revenant_check([systemElement isKindOfClass:[NSTextElement class]] && [portElement isKindOfClass:port_element_class()],
                 "both sides are an NSTextElement", @"one side is not");
    revenant_check([systemPlain isKindOfClass:[NSTextElement class]] && [portPlain isKindOfClass:port_paragraph_class()],
                 "and a paragraph is one on both sides", @"one side is not");
    id systemElementRange = system_range(0, 6);
    id portElementRange = port_range(0, 6);
    [systemElement setElementRange:systemElementRange];
    [portElement setElementRange:portElementRange];
    compare_text(described(systemElement.elementRange), described([portElement elementRange]),
                 @"the range an element keeps");
    compare_text(described(systemElement), described(portElement), @"an element, described");
    revenant_check(systemElement.textContentManager == nil && [portElement textContentManager] == nil,
                 "an element with no manager keeps none on either side", @"one side has one");
    revenant_check([systemElement isEqual:systemElement] && ![systemElement isEqual:[[NSTextElement alloc] initWithTextContentManager:nil]] &&
                     [portElement isEqual:portElement] && ![portElement isEqual:[[RevenantHostNSTextElement alloc] initWithTextContentManager:nil]],
                 "an element is equal to itself and to no other element", @"one side is not");
}

static void compare_navigation(void)
{
    id noDataSource = nil;
    NSTextSelectionNavigation *system = [[NSTextSelectionNavigation alloc] initWithDataSource:noDataSource];
    RevenantHostNSTextSelectionNavigation *port = [[RevenantHostNSTextSelectionNavigation alloc] initWithDataSource:noDataSource];
    revenant_check(system != nil && port != nil, "a navigation object is made with no data source", @"one side is not");
    revenant_check(system.textSelectionDataSource == nil && [port textSelectionDataSource] == nil, "and it holds none",
                 @"one side has one");
    revenant_check([system allowsNonContiguousRanges] && [port allowsNonContiguousRanges],
                 "both sides allow non-contiguous ranges to begin with", @"one side does not");
    revenant_check(!system.rotatesCoordinateSystemForLayoutOrientation &&
                     ![port rotatesCoordinateSystemForLayoutOrientation],
                 "and neither rotates the coordinate system", @"one side does");
    [port setAllowsNonContiguousRanges:NO];
    [port setRotatesCoordinateSystemForLayoutOrientation:YES];
    revenant_check(![port allowsNonContiguousRanges] && [port rotatesCoordinateSystemForLayoutOrientation],
                 "and both are settable on the port", @"one side did not take the value");
    compare_text(described(system), described(port), @"a navigation object, described");
    [port flushLayoutCache];
    [system flushLayoutCache];
    revenant_check(YES, "flushing the cache answers nothing on either side", @"one side answered something");

    NSTextSelection *systemCursor = [[NSTextSelection alloc] initWithLocation:at(4)
                                                                     affinity:NSTextSelectionAffinityDownstream];
    RevenantHostNSTextSelection *portCursor = [[RevenantHostNSTextSelection alloc] initWithLocation:at(4)
                                                                                      affinity:NSTextSelectionAffinityDownstream];
    for (NSInteger destination = 0; destination < 7; destination++) {
        for (NSInteger direction = 0; direction < 6; direction++) {
            NSTextSelectionNavigationDestination where = (NSTextSelectionNavigationDestination)destination;
            NSTextSelectionNavigationDirection how = (NSTextSelectionNavigationDirection)direction;
            id systemMoved = [system destinationSelectionForTextSelection:systemCursor
                                                                 direction:how
                                                               destination:where
                                                                extending:NO
                                                                  confined:NO];
            id portMoved = [port destinationSelectionForTextSelection:portCursor
                                                            direction:how
                                                          destination:where
                                                           extending:NO
                                                             confined:NO];
            revenant_check(portMoved == nil,
                         NAMED(@"a movement over destination %ld in direction %ld is nil with no data source",
                               (long)destination, (long)direction),
                         @"the port answered a movement it could not make");
            revenant_check(systemMoved == systemCursor,
                         NAMED(@"the host still hands destination %ld direction %ld the selection back",
                               (long)destination, (long)direction),
                         @"the host now answers something else");
            NSArray *systemDeleted = [system deletionRangesForTextSelection:systemCursor
                                                                   direction:how
                                                                 destination:where
                                                       allowsDecomposition:YES];
            NSArray *portDeleted = [port deletionRangesForTextSelection:portCursor
                                                               direction:how
                                                             destination:where
                                                   allowsDecomposition:YES];
            revenant_check(portDeleted.count == 1 && systemDeleted.count == 1,
                         NAMED(@"a deletion over destination %ld in direction %ld removes the cursor's own range",
                               (long)destination, (long)direction),
                         @"one side answered something else");
        }
    }
    NSTextSelection *systemWith = system_pair(0, 5, NSTextSelectionAffinityDownstream,
                                              NSTextSelectionGranularityCharacter);
    RevenantHostNSTextSelection *portWith = port_pair(0, 5, NSTextSelectionAffinityDownstream,
                                                    NSTextSelectionGranularityCharacter);
    compare_text(described([system deletionRangesForTextSelection:systemWith
                                                          direction:NSTextSelectionNavigationDirectionForward
                                                        destination:NSTextSelectionNavigationDestinationDocument
                                                  allowsDecomposition:NO]),
                 described([port deletionRangesForTextSelection:portWith
                                                      direction:NSTextSelectionNavigationDirectionForward
                                                    destination:NSTextSelectionNavigationDestinationDocument
                                              allowsDecomposition:NO]),
                 @"what a deletion of a selection with contents removes");
    revenant_check([system textSelectionsInteractingAtPoint:CGPointMake(1, 1)
                                    inContainerAtLocation:at(0)
                                                 anchors:@[]
                                               modifiers:0
                                               selecting:NO
                                                   bounds:CGRectZero].count == 0 &&
                     [[port textSelectionsInteractingAtPoint:CGPointMake(1, 1)
                                       inContainerAtLocation:at(0)
                                                    anchors:@[]
                                                  modifiers:0
                                                  selecting:NO
                                                      bounds:CGRectZero] count] == 0,
                 "a point with no line under it interacts with nothing on either side", @"one side found something");
    NSTextSelection *systemEnclosingPoint = [system textSelectionForSelectionGranularity:NSTextSelectionGranularityWord
                                                                           enclosingPoint:CGPointMake(1, 1)
                                                                 inContainerAtLocation:at(0)];
    NSTextSelection *portEnclosingPoint = [port textSelectionForSelectionGranularity:NSTextSelectionGranularityWord
                                                                      enclosingPoint:CGPointMake(1, 1)
                                                            inContainerAtLocation:at(0)];
    revenant_check(systemEnclosingPoint == nil && portEnclosingPoint == nil, "and there is no word to enclose it in",
                 @"one side found one");
    id systemEnclosingSelection =
        [system textSelectionForSelectionGranularity:NSTextSelectionGranularityWord enclosingTextSelection:systemCursor];
    id portEnclosingSelection =
        [port textSelectionForSelectionGranularity:NSTextSelectionGranularityWord enclosingTextSelection:portCursor];
    revenant_check(portEnclosingSelection == nil, "the port encloses nothing around a selection with no data source",
                 @"the port claimed a range it could not expand to");
    revenant_check(systemEnclosingSelection == systemCursor, "the host still answers the selection unexpanded",
                 @"the host now expands it");
    for (NSInteger writing = 0; writing < 2; writing++) {
        id<NSTextLocation> systemBefore = [system resolvedInsertionLocationForTextSelection:systemCursor
                                                                          writingDirection:(NSTextSelectionNavigationWritingDirection)writing];
        id<NSTextLocation> portBefore = [port resolvedInsertionLocationForTextSelection:portCursor
                                                                        writingDirection:(NSTextSelectionNavigationWritingDirection)writing];
        revenant_check(portBefore == nil,
                     NAMED(@"a logical selection has no insertion location in writing direction %ld on the port",
                           (long)writing),
                     @"the port answered one");
        id expected = writing == 0 ? at(4) : nil;
        revenant_check((systemBefore == nil) == (expected == nil) && (expected == nil || [systemBefore isEqual:expected]),
                     NAMED(@"and the host still answers %@ in writing direction %ld",
                           expected ? @"the selection's own location" : @"nil", (long)writing),
                     @"the host now answers something else");
    }
    [systemCursor setSecondarySelectionLocation:at(4)];
    [portCursor setSecondarySelectionLocation:at(4)];
    for (NSInteger writing = 0; writing < 2; writing++) {
        id<NSTextLocation> systemAfter = [system resolvedInsertionLocationForTextSelection:systemCursor
                                                                         writingDirection:(NSTextSelectionNavigationWritingDirection)writing];
        id<NSTextLocation> portAfter = [port resolvedInsertionLocationForTextSelection:portCursor
                                                                       writingDirection:(NSTextSelectionNavigationWritingDirection)writing];
        revenant_check([portAfter isEqual:at(4)], NAMED(@"a selection that is not logical inserts at its secondary "
                                                      @"location in writing direction %ld",
                                                      (long)writing),
                     @"the port answered somewhere else");
        revenant_check((systemAfter == nil) == ([portAfter isEqual:at(4)] == NO),
                     NAMED(@"writing direction %ld: one side has a location and the other has not", (long)writing),
                     @"both sides now answer the same");
    }
    revenant_check([system isKindOfClass:[NSTextSelectionNavigation class]] &&
                     [port isKindOfClass:port_navigation_class()],
                 "both sides are an NSTextSelectionNavigation", @"one side is not");
}

int main(void)
{
    @autoreleasepool {
        compare_ranges();
        compare_unavailable_initializers();
        compare_selections();
        compare_elements();
        compare_navigation();
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures;
}
