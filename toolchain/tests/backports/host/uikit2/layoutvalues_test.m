#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"
#import "compositional-cases.h"

static CompositionalKit K;

static CompositionalKit value_kit(NSString *prefix)
{
    Class (^named)(NSString *) = ^Class(NSString *name) { return NSClassFromString([prefix stringByAppendingString:name]); };
    CompositionalKit kit = {named(@"NSCollectionLayoutDimension"), named(@"NSCollectionLayoutSize"), named(@"NSCollectionLayoutSpacing"), named(@"NSCollectionLayoutEdgeSpacing"),
                            named(@"NSCollectionLayoutAnchor"), named(@"NSCollectionLayoutItem"), named(@"NSCollectionLayoutGroup"), named(@"NSCollectionLayoutGroupCustomItem"),
                            named(@"NSCollectionLayoutSupplementaryItem"), named(@"NSCollectionLayoutBoundarySupplementaryItem"), named(@"NSCollectionLayoutDecorationItem"),
                            named(@"NSCollectionLayoutSection"), named(@"UICollectionViewCompositionalLayoutConfiguration"), named(@"UICollectionViewCompositionalLayout")};
    return kit;
}

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    text = [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
    NSRegularExpression *uuid = [NSRegularExpression regularExpressionWithPattern:@"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" options:0 error:nil];
    text = [uuid stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"UUID"];
    return [[text componentsSeparatedByString:@"\n"] componentsJoinedByString:@" / "];
}

static NSString *guarded(id (^block)(void), BOOL nameOnly)
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return nameOnly ? [NSString stringWithFormat:@"raised %@", exception.name] : [NSString stringWithFormat:@"raised %@ %@", exception.name, norm(exception.reason)];
    }
}

static NSCollectionLayoutDimension *FW(double v) { return [(id)K.dimension fractionalWidthDimension:v]; }
static NSCollectionLayoutDimension *FH(double v) { return [(id)K.dimension fractionalHeightDimension:v]; }
static NSCollectionLayoutDimension *AB(double v) { return [(id)K.dimension absoluteDimension:v]; }
static NSCollectionLayoutDimension *ES(double v) { return [(id)K.dimension estimatedDimension:v]; }
static NSCollectionLayoutSize *SZ(NSCollectionLayoutDimension *w, NSCollectionLayoutDimension *h) { return [(id)K.size sizeWithWidthDimension:w heightDimension:h]; }
static NSCollectionLayoutItem *IT(NSCollectionLayoutDimension *w, NSCollectionLayoutDimension *h) { return [(id)K.item itemWithLayoutSize:SZ(w, h)]; }
static NSCollectionLayoutSpacing *FIXED(double v) { return [(id)K.spacing fixedSpacing:v]; }
static NSCollectionLayoutSpacing *FLEX(double v) { return [(id)K.spacing flexibleSpacing:v]; }
static NSCollectionLayoutGroup *HG(NSCollectionLayoutSize *size, NSArray *items) { return [(id)K.group horizontalGroupWithLayoutSize:size subitems:items]; }
static NSCollectionLayoutGroup *VG(NSCollectionLayoutSize *size, NSArray *items) { return [(id)K.group verticalGroupWithLayoutSize:size subitems:items]; }
static NSCollectionLayoutAnchor *ANCHOR(NSDirectionalRectEdge edges) { return [(id)K.anchor layoutAnchorWithEdges:edges]; }
static NSCollectionLayoutBoundarySupplementaryItem *BND(NSCollectionLayoutSize *size, NSRectAlignment alignment)
{
    return [(id)K.boundary boundarySupplementaryItemWithLayoutSize:size elementKind:@"h" alignment:alignment];
}

static NSArray *value_lines(CompositionalKit kit)
{
    K = kit;
    NSMutableArray *lines = [NSMutableArray array];
    void (^L)(NSString *, id (^)(void)) = ^(NSString *label, id (^block)(void)) {
        [lines addObject:[NSString stringWithFormat:@"%@ => %@", label, guarded(block, NO)]];
    };
    void (^N)(NSString *, id (^)(void)) = ^(NSString *label, id (^block)(void)) {
        [lines addObject:[NSString stringWithFormat:@"%@ => %@", label, guarded(block, YES)]];
    };
    NSCollectionLayoutDimension *fw = FW(0.5), *fh = FH(0.25), *ab = AB(20), *es = ES(30);
    for (NSNumber *bad in @[@(NAN), @(INFINITY), @(-INFINITY)]) {
        L([NSString stringWithFormat:@"fractional width %@", bad], ^{ return FW(bad.doubleValue); });
        L([NSString stringWithFormat:@"fractional height %@", bad], ^{ return FH(bad.doubleValue); });
        L([NSString stringWithFormat:@"absolute %@", bad], ^{ return AB(bad.doubleValue); });
        L([NSString stringWithFormat:@"estimated %@", bad], ^{ return ES(bad.doubleValue); });
    }
    for (NSNumber *odd in @[@(-1), @2, @0])
        L([NSString stringWithFormat:@"dimensions of %@ raise nothing", odd], ^{ return @[@(FW(odd.doubleValue).dimension), @(FH(odd.doubleValue).dimension), @(AB(odd.doubleValue).dimension), @(ES(odd.doubleValue).dimension)]; });
    for (NSCollectionLayoutDimension *dimension in @[fw, fh, ab, es])
        L(@"dimension kinds", ^{ return @[@(dimension.isFractionalWidth), @(dimension.isFractionalHeight), @(dimension.isAbsolute), @(dimension.isEstimated), @(dimension.dimension)]; });
    L(@"dimension description", ^{ return fw; });
    L(@"dimension equality", ^{ return @[@([fw isEqual:FW(0.5)]), @([fw isEqual:FH(0.5)]), @([fw isEqual:AB(0.5)]), @([ab isEqual:ES(20)]), @([fw isEqual:nil]), @([fw isEqual:@"x"]), @([fw copy] == fw)]; });
    L(@"dimension protocols", ^{ return @[@([fw conformsToProtocol:@protocol(NSSecureCoding)]), @([fw conformsToProtocol:@protocol(NSCoding)]), @([fw conformsToProtocol:@protocol(NSCopying)])]; });
    L(@"dimension new", ^{ return [(id)K.dimension new]; });

    NSCollectionLayoutSize *size = SZ(fw, fh);
    L(@"size description", ^{ return size; });
    L(@"size of every kind", ^{
        NSMutableArray *all = [NSMutableArray array];
        for (NSCollectionLayoutDimension *a in @[fw, fh, ab, es, FW(1), AB(-4.5)])
            for (NSCollectionLayoutDimension *b in @[fw, fh, ab, es])
                [all addObject:[SZ(a, b) description]];
        return all;
    });
    L(@"size copy and equality", ^{ return @[@([size copy] == size), @([size isEqual:SZ(FW(0.5), FH(0.25))]), @([size isEqual:SZ(FW(0.5), FH(0.5))]), @(size.widthDimension == fw), @(size.heightDimension == fh)]; });
    L(@"size with nil", ^{ return @[SZ(nil, fh), SZ(fw, nil), [(id)K.size new]]; });

    NSCollectionLayoutSpacing *fixed = FIXED(4), *flexible = FLEX(5);
    L(@"spacing", ^{ return @[fixed, flexible, @(fixed.spacing), @(fixed.isFixedSpacing), @(fixed.isFlexibleSpacing), @(flexible.spacing), @(flexible.isFixedSpacing), @(flexible.isFlexibleSpacing)]; });
    L(@"spacing odd values", ^{ return @[FIXED(-1), FLEX(-1), FIXED(NAN), FLEX(INFINITY)]; });
    L(@"spacing equality", ^{ return @[@([fixed isEqual:FIXED(4)]), @([fixed isEqual:FLEX(4)]), @([fixed isEqual:FIXED(5)]), @([fixed copy] == fixed), @([[fixed copy] isEqual:fixed])]; });
    NSCollectionLayoutEdgeSpacing *edges = [(id)K.edgeSpacing spacingForLeading:fixed top:nil trailing:flexible bottom:nil];
    L(@"edge spacing", ^{ return @[edges, edges.leading ?: @"nil", edges.top ?: @"nil", edges.trailing ?: @"nil", edges.bottom ?: @"nil"]; });
    L(@"edge spacing outsets", ^{
        return @[[(id)K.edgeSpacing spacingForLeading:FIXED(1) top:FIXED(2) trailing:FLEX(3) bottom:FLEX(4)], [(id)K.edgeSpacing spacingForLeading:FLEX(3) top:FLEX(4) trailing:FIXED(1) bottom:FIXED(2)],
                 [(id)K.edgeSpacing spacingForLeading:nil top:nil trailing:nil bottom:nil]];
    });
    L(@"edge spacing equality", ^{ return @[@([edges isEqual:[(id)K.edgeSpacing spacingForLeading:fixed top:nil trailing:flexible bottom:nil]]), @([edges isEqual:[(id)K.edgeSpacing spacingForLeading:fixed top:nil trailing:fixed bottom:nil]]), @([edges copy] == edges), @([[edges copy] isEqual:edges])]; });

    NSCollectionLayoutAnchor *anchor = ANCHOR(NSDirectionalRectEdgeTop | NSDirectionalRectEdgeLeading);
    L(@"anchor", ^{ return @[anchor, @(anchor.edges), @(anchor.offset.x), @(anchor.offset.y), @(anchor.isAbsoluteOffset), @(anchor.isFractionalOffset)]; });
    L(@"anchors with offsets", ^{
        NSCollectionLayoutAnchor *absolute = [(id)K.anchor layoutAnchorWithEdges:NSDirectionalRectEdgeTop absoluteOffset:CGPointMake(3, 4)];
        NSCollectionLayoutAnchor *fractional = [(id)K.anchor layoutAnchorWithEdges:NSDirectionalRectEdgeBottom fractionalOffset:CGPointMake(0.5, 0.25)];
        return @[absolute, fractional, @(absolute.isAbsoluteOffset), @(absolute.isFractionalOffset), @(fractional.isAbsoluteOffset), @(fractional.isFractionalOffset), @(fractional.offset.x)];
    });
    for (NSNumber *edges in @[@0, @1, @2, @3, @4, @6, @8, @9, @12, @15, @99])
        L([NSString stringWithFormat:@"anchor of edges %@", edges], ^{ return ANCHOR((NSDirectionalRectEdge)edges.unsignedIntegerValue); });
    L(@"anchor odd offsets", ^{ return @[[(id)K.anchor layoutAnchorWithEdges:1 absoluteOffset:CGPointMake(NAN, 0)], [(id)K.anchor layoutAnchorWithEdges:1 fractionalOffset:CGPointMake(INFINITY, 0)]]; });
    L(@"anchor equality", ^{ return @[@([anchor isEqual:ANCHOR(NSDirectionalRectEdgeTop | NSDirectionalRectEdgeLeading)]), @([anchor isEqual:ANCHOR(NSDirectionalRectEdgeTop)]), @([anchor copy] == anchor), @([[anchor copy] isEqual:anchor])]; });

    NSCollectionLayoutItem *item = IT(fw, fh);
    L(@"item", ^{ return item; });
    L(@"item defaults", ^{ return @[@(item.contentInsets.top), item.edgeSpacing ?: @"nil", item.layoutSize, item.supplementaryItems]; });
    L(@"item copies", ^{ return @[@([item copy] == item), @([item isEqual:[item copy]]), @([item isEqual:IT(FW(0.5), FH(0.25))]), @([[item copy] layoutSize] == item.layoutSize), @([item isEqual:IT(FW(0.5), FH(0.5))])]; });
    L(@"item with insets and spacing", ^{
        NSCollectionLayoutItem *set = [item copy];
        set.contentInsets = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
        set.edgeSpacing = edges;
        NSCollectionLayoutItem *other = [item copy];
        return @[set, @([set copy] == set), @([[set copy] edgeSpacing] == edges), @([[set copy] edgeSpacing] == set.edgeSpacing), @([set isEqual:other]), @([set isEqual:[set copy]])];
    });
    L(@"item edge spacing cleared", ^{ NSCollectionLayoutItem *set = [item copy]; set.edgeSpacing = nil; return @[set.edgeSpacing ?: @"nil"]; });
    L(@"item equality by inset and spacing", ^{
        NSCollectionLayoutItem *a = IT(FW(1), FH(1)), *b = IT(FW(1), FH(1));
        NSMutableArray *answers = [NSMutableArray array];
        b.contentInsets = NSDirectionalEdgeInsetsMake(1, 0, 0, 0);
        [answers addObject:@([a isEqual:b])];
        b.contentInsets = NSDirectionalEdgeInsetsZero;
        [answers addObject:@([a isEqual:b])];
        b.edgeSpacing = [(id)K.edgeSpacing spacingForLeading:FIXED(2) top:nil trailing:nil bottom:nil];
        [answers addObject:@([a isEqual:b])];
        return answers;
    });
    L(@"item with nil arguments", ^{ return @[[(id)K.item itemWithLayoutSize:nil], [(id)K.item itemWithLayoutSize:size supplementaryItems:nil], [(id)K.item itemWithLayoutSize:size supplementaryItems:@[@"x"]]]; });
    L(@"item new", ^{ return [(id)K.item new]; });
    L(@"item setters", ^{ return @[@([K.item instancesRespondToSelector:@selector(setLayoutSize:)]), @([K.item instancesRespondToSelector:NSSelectorFromString(@"initWithLayoutSize:")])]; });

    NSCollectionLayoutSupplementaryItem *supplement = [(id)K.supplementary supplementaryItemWithLayoutSize:size elementKind:@"k" containerAnchor:anchor];
    L(@"supplementary item", ^{ return @[supplement, @(supplement.zIndex), supplement.elementKind, supplement.containerAnchor, supplement.itemAnchor ?: @"nil", supplement.layoutSize, supplement.supplementaryItems]; });
    L(@"supplementary item with an item anchor", ^{ return [(id)K.supplementary supplementaryItemWithLayoutSize:size elementKind:@"k" containerAnchor:anchor itemAnchor:ANCHOR(NSDirectionalRectEdgeBottom)]; });
    L(@"supplementary item with nil arguments", ^{
        return @[[(id)K.supplementary supplementaryItemWithLayoutSize:size elementKind:nil containerAnchor:anchor], [(id)K.supplementary supplementaryItemWithLayoutSize:size elementKind:@"k" containerAnchor:nil],
                 [(id)K.supplementary supplementaryItemWithLayoutSize:nil elementKind:@"k" containerAnchor:anchor]];
    });
    L(@"supplementary item copies", ^{ return @[@([supplement copy] == supplement), @([supplement isEqual:[supplement copy]]), @([[supplement copy] containerAnchor] == anchor)]; });
    L(@"supplementary item equality", ^{
        NSCollectionLayoutSupplementaryItem *other = [(id)K.supplementary supplementaryItemWithLayoutSize:size elementKind:@"j" containerAnchor:anchor];
        NSCollectionLayoutSupplementaryItem *third = [(id)K.supplementary supplementaryItemWithLayoutSize:size elementKind:@"k" containerAnchor:ANCHOR(NSDirectionalRectEdgeBottom)];
        NSCollectionLayoutSupplementaryItem *fourth = [(id)K.supplementary supplementaryItemWithLayoutSize:size elementKind:@"k" containerAnchor:anchor];
        fourth.zIndex = 7;
        return @[@([supplement isEqual:other]), @([supplement isEqual:third]), @([supplement isEqual:fourth])];
    });
    L(@"item holding supplementary items", ^{
        NSCollectionLayoutItem *holder = [(id)K.item itemWithLayoutSize:size supplementaryItems:@[supplement]];
        NSCollectionLayoutItem *copy = [holder copy];
        return @[holder, holder.supplementaryItems, @([copy.supplementaryItems.firstObject isEqual:supplement]), @(copy.supplementaryItems.firstObject == supplement), @([holder isEqual:copy])];
    });

    NSCollectionLayoutBoundarySupplementaryItem *boundary = BND(size, NSRectAlignmentTop);
    L(@"boundary item", ^{ return @[boundary, @(boundary.extendsBoundary), @(boundary.pinToVisibleBounds), @(boundary.alignment), @(boundary.offset.x), @(boundary.offset.y), @(boundary.zIndex), boundary.elementKind, boundary.itemAnchor ?: @"nil"]; });
    L(@"boundary item container anchor", ^{ return boundary.containerAnchor ?: @"nil"; });
    L(@"boundary item with an offset", ^{
        NSCollectionLayoutBoundarySupplementaryItem *shifted = [(id)K.boundary boundarySupplementaryItemWithLayoutSize:size elementKind:@"h" alignment:NSRectAlignmentBottomTrailing absoluteOffset:CGPointMake(3, 4)];
        return @[shifted, @(shifted.alignment), @(shifted.offset.x), @(shifted.offset.y), @(shifted.extendsBoundary)];
    });
    for (NSNumber *alignment in @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @-1])
        L([NSString stringWithFormat:@"boundary item alignment %@", alignment], ^{ return @(BND(size, (NSRectAlignment)alignment.integerValue).alignment); });
    L(@"boundary item without a kind", ^{ return [(id)K.boundary boundarySupplementaryItemWithLayoutSize:size elementKind:nil alignment:NSRectAlignmentTop]; });
    L(@"boundary item changed and copied", ^{
        NSCollectionLayoutBoundarySupplementaryItem *set = BND(size, NSRectAlignmentTop);
        set.pinToVisibleBounds = YES;
        set.extendsBoundary = NO;
        set.zIndex = 9;
        NSCollectionLayoutBoundarySupplementaryItem *copy = [set copy];
        return @[@(copy.pinToVisibleBounds), @(copy.extendsBoundary), @(copy.zIndex), @(copy.alignment), @([copy isEqual:set]), @(copy == set), @([set isEqual:boundary])];
    });
    L(@"boundary item equality", ^{
        NSCollectionLayoutBoundarySupplementaryItem *a = BND(size, NSRectAlignmentTop), *b = BND(size, NSRectAlignmentTop);
        NSMutableArray *answers = [NSMutableArray arrayWithObject:@([a isEqual:b])];
        b.pinToVisibleBounds = YES;
        [answers addObject:@([a isEqual:b])];
        [answers addObject:@([a isEqual:BND(size, NSRectAlignmentBottom)])];
        b = [(id)K.boundary boundarySupplementaryItemWithLayoutSize:size elementKind:@"h" alignment:NSRectAlignmentTop absoluteOffset:CGPointMake(1, 0)];
        [answers addObject:@([a isEqual:b])];
        b = BND(size, NSRectAlignmentTop);
        b.extendsBoundary = NO;
        [answers addObject:@([a isEqual:b])];
        [answers addObject:@([a isEqual:IT(fw, fh)])];
        return answers;
    });

    NSCollectionLayoutDecorationItem *decoration = [(id)K.decoration backgroundDecorationItemWithElementKind:@"bg"];
    L(@"decoration item", ^{ return @[decoration, @(decoration.zIndex), decoration.elementKind, decoration.layoutSize, @(decoration.contentInsets.top), decoration.supplementaryItems, decoration.edgeSpacing ?: @"nil"]; });
    L(@"decoration item without a kind", ^{ return [(id)K.decoration backgroundDecorationItemWithElementKind:nil]; });
    L(@"decoration item equality", ^{
        NSCollectionLayoutDecorationItem *other = [(id)K.decoration backgroundDecorationItemWithElementKind:@"c"], *same = [(id)K.decoration backgroundDecorationItemWithElementKind:@"bg"];
        NSMutableArray *answers = [NSMutableArray arrayWithObjects:@([decoration isEqual:other]), @([decoration isEqual:same]), @([decoration copy] == decoration), nil];
        same.zIndex = 3;
        [answers addObject:@([decoration isEqual:same])];
        same.zIndex = 0;
        same.contentInsets = NSDirectionalEdgeInsetsMake(1, 1, 1, 1);
        [answers addObject:@([decoration isEqual:same])];
        return answers;
    });

    NSCollectionLayoutGroup *horizontal = HG(size, @[IT(fw, fh)]);
    L(@"horizontal group", ^{ return horizontal; });
    L(@"group defaults", ^{ return @[horizontal.subitems, horizontal.interItemSpacing ?: @"nil", horizontal.supplementaryItems, horizontal.layoutSize, horizontal.edgeSpacing ?: @"nil"]; });
    L(@"vertical groups", ^{ return @[VG(size, @[IT(fw, fh), IT(fw, fh)]), VG(size, @[IT(fw, fh), horizontal])]; });
    L(@"group without subitems", ^{ return HG(size, @[]); });
    N(@"group with nil subitems", ^{ return [(id)K.group horizontalGroupWithLayoutSize:size subitems:nil]; });
    L(@"group without a size", ^{ return [(id)K.group horizontalGroupWithLayoutSize:nil subitems:@[item]]; });
    L(@"vertical group without a size", ^{ return [(id)K.group verticalGroupWithLayoutSize:nil subitems:@[item]]; });
    L(@"group of something else", ^{ return HG(size, @[@"x"]); });
    L(@"repeated item groups", ^{
        NSCollectionLayoutGroup *repeated = [(id)K.group horizontalGroupWithLayoutSize:size subitem:item count:3];
        NSCollectionLayoutGroup *repeatedVertically = [(id)K.group verticalGroupWithLayoutSize:size subitem:item count:2];
        return @[repeated, repeated.subitems, repeatedVertically, repeatedVertically.subitems];
    });
    for (NSNumber *count in @[@0, @-1, @1, @7]) {
        L([NSString stringWithFormat:@"repeated horizontal group of %@", count], ^{ NSCollectionLayoutGroup *made = [(id)K.group horizontalGroupWithLayoutSize:size subitem:item count:count.integerValue]; return made.subitems.firstObject.layoutSize; });
        L([NSString stringWithFormat:@"repeated vertical group of %@", count], ^{ NSCollectionLayoutGroup *made = [(id)K.group verticalGroupWithLayoutSize:size subitem:item count:count.integerValue]; return made.subitems.firstObject.layoutSize; });
    }
    L(@"repeated nested group", ^{
        NSCollectionLayoutGroup *inner = VG(SZ(FW(0.5), FH(1)), @[IT(FW(1), FH(0.5))]);
        NSCollectionLayoutGroup *repeated = [(id)K.group horizontalGroupWithLayoutSize:size subitem:inner count:2];
        return @[repeated.subitems.firstObject];
    });
    N(@"repeated nil item", ^{ return [(id)K.group horizontalGroupWithLayoutSize:size subitem:nil count:2]; });
    L(@"custom group", ^{
        NSCollectionLayoutGroup *custom = [(id)K.group customGroupWithLayoutSize:size itemProvider:^NSArray *(id environment) { return @[]; }];
        return @[custom, custom.subitems, @([custom isEqual:[custom copy]])];
    });
    L(@"custom group without a provider", ^{ return [(id)K.group customGroupWithLayoutSize:size itemProvider:nil]; });
    L(@"custom group without a size", ^{ return [(id)K.group customGroupWithLayoutSize:nil itemProvider:^NSArray *(id environment) { return @[]; }]; });
    L(@"group copies and equality", ^{
        NSCollectionLayoutGroup *copy = [horizontal copy];
        NSMutableArray *answers = [NSMutableArray arrayWithObjects:@(copy == horizontal), @([copy isEqual:horizontal]), @(copy.subitems.firstObject == horizontal.subitems.firstObject),
                                                                    @([horizontal isEqual:HG(size, @[IT(fw, fh)])]), @([horizontal isEqual:VG(size, @[IT(fw, fh)])]), @([horizontal isEqual:HG(size, @[IT(fw, fh), IT(fw, fh)])]), nil];
        NSCollectionLayoutGroup *spaced = HG(size, @[IT(fw, fh)]);
        spaced.interItemSpacing = FIXED(1);
        [answers addObject:@([horizontal isEqual:spaced])];
        spaced.interItemSpacing = horizontal.interItemSpacing;
        [answers addObject:@([horizontal isEqual:spaced])];
        return answers;
    });
    L(@"group spacing and supplementary items", ^{
        NSCollectionLayoutGroup *set = HG(size, @[IT(fw, fh)]);
        set.interItemSpacing = fixed;
        set.supplementaryItems = @[supplement];
        NSCollectionLayoutGroup *copy = [set copy];
        return @[set, @(copy.interItemSpacing == fixed), @([copy.interItemSpacing isEqual:fixed]), @([copy.supplementaryItems.firstObject isEqual:supplement])];
    });
    L(@"group properties cleared", ^{
        NSCollectionLayoutGroup *set = HG(size, @[IT(fw, fh)]);
        set.supplementaryItems = nil;
        set.edgeSpacing = nil;
        set.interItemSpacing = nil;
        return @[set.supplementaryItems ?: @"nil", set.edgeSpacing ?: @"nil", set.interItemSpacing ?: @"nil", set];
    });
    L(@"group of groups", ^{ return @[HG(size, @[horizontal]), @(HG(size, @[horizontal]).subitems.firstObject == horizontal)]; });
    L(@"group setters", ^{ return @[@([K.group instancesRespondToSelector:@selector(setSupplementaryItems:)])]; });

    NSCollectionLayoutGroupCustomItem *custom = [(id)K.customItem customItemWithFrame:CGRectMake(1, 2, 3, 4)];
    L(@"custom item", ^{ return @[custom, @(custom.frame.origin.y), @(custom.zIndex)]; });
    L(@"custom item with a z index", ^{ return [(id)K.customItem customItemWithFrame:CGRectMake(1, 2, 3, 4) zIndex:6]; });
    L(@"custom item copies", ^{ return @[@([custom copy] == custom), @([custom isEqual:[(id)K.customItem customItemWithFrame:CGRectMake(1, 2, 3, 4)]]), @([custom isEqual:custom])]; });
    L(@"custom item odd frames", ^{ return @[[(id)K.customItem customItemWithFrame:CGRectMake(1, 2, -3, 4)], @([(NSCollectionLayoutGroupCustomItem *)[(id)K.customItem customItemWithFrame:CGRectNull] frame].size.width)]; });

    NSCollectionLayoutSection *section = [(id)K.section sectionWithGroup:horizontal];
    L(@"section", ^{ return section; });
    L(@"section defaults", ^{
        return @[@(section.contentInsets.top), @(section.interGroupSpacing), @(section.orthogonalScrollingBehavior), section.boundarySupplementaryItems, section.decorationItems, @(section.visibleItemsInvalidationHandler != nil),
                 @(section.supplementariesFollowContentInsets)];
    });
    L(@"section without a group", ^{ return [(id)K.section sectionWithGroup:nil]; });
    L(@"section new", ^{ return [(id)K.section new]; });
    L(@"section copies and equality", ^{ return @[@([section copy] == section), @([section isEqual:[section copy]]), @([section isEqual:[(id)K.section sectionWithGroup:horizontal]]), @([[section copy] isEqual:section])]; });
    L(@"section set", ^{
        NSCollectionLayoutSection *set = [(id)K.section sectionWithGroup:horizontal];
        set.contentInsets = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
        set.interGroupSpacing = 7;
        set.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging;
        set.boundarySupplementaryItems = @[boundary];
        set.decorationItems = @[decoration];
        set.supplementariesFollowContentInsets = NO;
        NSCollectionLayoutSection *copy = [set copy];
        return @[set, copy, @(copy.boundarySupplementaryItems.firstObject == boundary), @(copy.contentInsets.top), @(copy.supplementariesFollowContentInsets), @(copy.decorationItems.firstObject == decoration),
                 @(copy.orthogonalScrollingBehavior), @([copy isEqual:set])];
    });
    for (NSNumber *behavior in @[@0, @1, @2, @3, @4, @5, @6, @7]) {
        L([NSString stringWithFormat:@"section description with behavior %@", behavior], ^{
            NSCollectionLayoutSection *set = [(id)K.section sectionWithGroup:horizontal];
            set.orthogonalScrollingBehavior = (UICollectionLayoutSectionOrthogonalScrollingBehavior)behavior.integerValue;
            return set;
        });
    }
    L(@"section description of each part", ^{
        NSMutableArray *all = [NSMutableArray array];
        NSCollectionLayoutSection *set = [(id)K.section sectionWithGroup:horizontal];
        set.contentInsets = NSDirectionalEdgeInsetsMake(1, 0, 0, 0);
        [all addObject:[set description]];
        set.contentInsets = NSDirectionalEdgeInsetsZero;
        set.interGroupSpacing = 3;
        [all addObject:[set description]];
        set.interGroupSpacing = 0;
        set.boundarySupplementaryItems = @[boundary];
        [all addObject:[set description]];
        set.boundarySupplementaryItems = @[];
        set.decorationItems = @[decoration];
        [all addObject:[set description]];
        set.decorationItems = @[];
        set.supplementariesFollowContentInsets = NO;
        [all addObject:[set description]];
        set.visibleItemsInvalidationHandler = ^(NSArray *items, CGPoint offset, id environment) {};
        [all addObject:[set description]];
        return all;
    });
    L(@"section properties cleared", ^{
        NSCollectionLayoutSection *set = [(id)K.section sectionWithGroup:horizontal];
        set.boundarySupplementaryItems = nil;
        set.decorationItems = nil;
        return @[set.boundarySupplementaryItems ?: @"nil", set.decorationItems ?: @"nil", [set description]];
    });
    L(@"section equality by part", ^{
        NSCollectionLayoutSection *a = [(id)K.section sectionWithGroup:horizontal], *b = [(id)K.section sectionWithGroup:horizontal];
        NSMutableArray *answers = [NSMutableArray array];
        b.interGroupSpacing = 1;
        [answers addObject:@([a isEqual:b])];
        b.interGroupSpacing = 0;
        b.contentInsets = NSDirectionalEdgeInsetsMake(1, 0, 0, 0);
        [answers addObject:@([a isEqual:b])];
        b.contentInsets = NSDirectionalEdgeInsetsZero;
        b.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuous;
        [answers addObject:@([a isEqual:b])];
        b.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
        b.boundarySupplementaryItems = @[boundary];
        [answers addObject:@([a isEqual:b])];
        b.boundarySupplementaryItems = @[];
        b.decorationItems = @[decoration];
        [answers addObject:@([a isEqual:b])];
        b.decorationItems = @[];
        b.supplementariesFollowContentInsets = NO;
        [answers addObject:@([a isEqual:b])];
        b.supplementariesFollowContentInsets = YES;
        [answers addObject:@([a isEqual:[(id)K.section sectionWithGroup:VG(size, @[IT(fw, fh)])]])];
        [answers addObject:@([a isEqual:b])];
        return answers;
    });
    L(@"section content insets reference", ^{
        NSCollectionLayoutSection *set = [(id)K.section sectionWithGroup:horizontal];
        NSInteger before = (NSInteger)set.contentInsetsReference;
        set.contentInsetsReference = UIContentInsetsReferenceLayoutMargins;
        NSCollectionLayoutSection *copy = [set copy];
        return @[@(before), @(set.contentInsetsReference), @(copy.contentInsetsReference), @([set isEqual:copy])];
    });
    L(@"section coding", ^{ return @[@([K.section instancesRespondToSelector:@selector(initWithCoder:)])]; });

    UICollectionViewCompositionalLayoutConfiguration *configuration = [[(id)K.configuration alloc] init];
    L(@"configuration", ^{ return @[configuration, @(configuration.scrollDirection), @(configuration.interSectionSpacing), configuration.boundarySupplementaryItems, @(configuration.contentInsetsReference)]; });
    L(@"configuration set and copied", ^{
        UICollectionViewCompositionalLayoutConfiguration *set = [[(id)K.configuration alloc] init];
        set.interSectionSpacing = 5;
        set.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        set.boundarySupplementaryItems = @[boundary];
        set.contentInsetsReference = UIContentInsetsReferenceNone;
        UICollectionViewCompositionalLayoutConfiguration *copy = [set copy];
        return @[copy, @(copy == set), @(copy.boundarySupplementaryItems.firstObject == boundary), @([copy isEqual:set]), @(copy.scrollDirection), @(copy.interSectionSpacing), @(copy.contentInsetsReference)];
    });
    UICollectionViewCompositionalLayout *layout = [[(id)K.layout alloc] initWithSection:section];
    L(@"layout", ^{ return layout; });
    L(@"layout with nothing", ^{ return @[[[(id)K.layout alloc] initWithSection:nil], [[(id)K.layout alloc] initWithSectionProvider:nil], [(id)K.layout new], [[(id)K.layout alloc] init]]; });
    L(@"layout configuration", ^{
        UICollectionViewCompositionalLayoutConfiguration *given = [[(id)K.configuration alloc] init];
        UICollectionViewCompositionalLayout *made = [[(id)K.layout alloc] initWithSection:section configuration:given];
        UICollectionViewCompositionalLayout *plain = [[(id)K.layout alloc] initWithSection:section configuration:nil];
        NSMutableArray *answers = [NSMutableArray arrayWithObjects:@(made.configuration == given), @(plain.configuration != nil), @(plain.configuration.scrollDirection), nil];
        made.configuration = given;
        [answers addObject:@(made.configuration == given)];
        return answers;
    });
    L(@"layout classes", ^{
        return @[@([K.layout layoutAttributesClass] == [UICollectionViewLayoutAttributes class]), NSStringFromClass([K.layout superclass]), NSStringFromClass([K.group superclass]), NSStringFromClass([K.supplementary superclass]),
                 NSStringFromClass([K.boundary superclass]), NSStringFromClass([K.decoration superclass]), NSStringFromClass([K.section superclass]), NSStringFromClass([K.dimension superclass])];
    });
    return lines;
}

int main(void)
{
    @autoreleasepool {
        NSArray *system = value_lines(value_kit(@"")), *port = value_lines(value_kit(@"CharonHost"));
        CHECK(system.count > 100 && system.count == port.count, "the same statements ran against the port and the system");
        NSMutableString *detail = [NSMutableString string];
        NSUInteger differences = 0;
        for (NSUInteger index = 0; index < MIN(system.count, port.count); index++) {
            NSString *a = port[index], *b = system[index];
            if ([a isEqual:b])
                continue;
            differences++;
            NSUInteger at = 0;
            while (at < a.length && at < b.length && [a characterAtIndex:at] == [b characterAtIndex:at])
                at++;
            NSUInteger from = at > 60 ? at - 60 : 0;
            [detail appendFormat:@"\n    port   ...%@\n    system ...%@", [a substringWithRange:NSMakeRange(from, MIN(160, a.length - from))], [b substringWithRange:NSMakeRange(from, MIN(160, b.length - from))]];
        }
        charon_check(differences == 0, "the value classes answer as the system's do", detail);
        printf("statements=%lu checks=%d failures=%d\n", (unsigned long)system.count, charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
