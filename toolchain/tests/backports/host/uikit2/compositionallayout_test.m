#import <UIKit/UIKit.h>
#import "check.h"
#import "compositional-cases.m"

void charon_windowed_run(UIWindow *window);

static void record_expectations(NSArray *answers)
{
    const char *path = getenv("CHARON_COMPOSITIONAL_EXPECTATIONS");
    if (!path)
        return;
    NSMutableString *out = [NSMutableString stringWithString:@"static const char *const compositional_expectations[] = {\n"];
    for (NSString *answer in answers) {
        NSString *text = [answer stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        text = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        [out appendFormat:@"    \"%@\",\n", text];
    }
    [out appendString:@"};\n"];
    [out writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static NSString *first_difference(NSString *port, NSString *system)
{
    NSArray *a = [port componentsSeparatedByString:@"\n"], *b = [system componentsSeparatedByString:@"\n"];
    NSMutableString *detail = [NSMutableString string];
    for (NSUInteger index = 0; index < MAX(a.count, b.count) && index < 400; index++) {
        NSString *left = index < a.count ? a[index] : @"<none>", *right = index < b.count ? b[index] : @"<none>";
        if (![left isEqual:right])
            [detail appendFormat:@"\n    port   %@\n    system %@", left, right];
    }
    return detail;
}


static uint64_t rng_state;
static unsigned fuzz_mask = 0xffffu;
enum { FeatInsets = 1, FeatGroupInsets = 2, FeatItemInsets = 4, FeatEdges = 8, FeatEstimated = 16, FeatBoundary = 32, FeatSupplementary = 64, FeatDecoration = 128, FeatNested = 256,
       FeatCounted = 512, FeatConfig = 1024, FeatSideways = 2048, FeatProvider = 4096, FeatSpacing = 8192, FeatCustomSizes = 16384, FeatGroupSpacing = 32768, FeatSane = 65536 };
static BOOL feat(unsigned flag) { return (fuzz_mask & flag) != 0; }

static double next_random(void)
{
    rng_state = rng_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(rng_state >> 11) / (double)(1ULL << 53);
}

static NSInteger pick(NSInteger count)
{
    return (NSInteger)(next_random() * count) % count;
}

static BOOL chance(double probability)
{
    return next_random() < probability;
}

static NSCollectionLayoutDimension *random_dimension(BOOL allowEstimated)
{
    if (feat(FeatSane)) {
        double fractions[] = {0.2, 0.25, 1.0 / 3, 0.5, 1};
        double absolutes[] = {20, 44, 50, 100};
        NSInteger kind = pick(allowEstimated && feat(FeatEstimated) ? 5 : 4);
        return kind == 0 ? FW(fractions[pick(5)]) : kind == 1 ? FH(fractions[pick(5)]) : kind == 4 ? ES(absolutes[pick(4)]) : AB(absolutes[pick(4)]);
    }
    double fractions[] = {0.1, 0.2, 0.25, 0.3, 1.0 / 3, 0.4, 0.5, 0.6, 0.75, 1, 1, 1};
    double absolutes[] = {10, 20, 33, 50, 100};
    NSInteger kind = pick(allowEstimated && feat(FeatEstimated) && chance(0.15) ? 5 : 4);
    if (kind == 0 || kind == 1)
        return kind == 0 ? FW(fractions[pick(12)]) : FH(fractions[pick(12)]);
    if (kind == 4)
        return ES(absolutes[pick(5)]);
    return AB(absolutes[pick(5)]);
}

static NSCollectionLayoutDimension *random_flow_dimension(BOOL horizontalFlow)
{
    if (feat(FeatSane)) {
        double fractions[] = {0.2, 0.25, 1.0 / 3, 0.5, 1};
        return horizontalFlow ? FW(fractions[pick(5)]) : FH(fractions[pick(5)]);
    }
    double fractions[] = {0.1, 0.2, 0.25, 0.3, 1.0 / 3, 0.4, 0.5, 0.6, 0.75, 1, 1, 1};
    double absolutes[] = {10, 20, 33, 50, 100};
    NSInteger kind = pick(feat(FeatEstimated) && chance(0.15) ? 3 : 2);
    if (kind == 0)
        return horizontalFlow ? FW(fractions[pick(12)]) : FH(fractions[pick(12)]);
    return kind == 1 ? AB(absolutes[pick(5)]) : ES(absolutes[pick(5)]);
}

static NSCollectionLayoutSpacing *random_spacing(BOOL allowNil)
{
    if (!feat(FeatSpacing))
        return nil;
    double values[] = {0, 1, 4, 10};
    NSInteger kind = pick(allowNil ? 3 : 2);
    if (kind == 2)
        return nil;
    return kind == 0 ? FIXED(values[pick(4)]) : FLEX(values[pick(4)]);
}

static NSCollectionLayoutEdgeSpacing *random_edges(void)
{
    if (!feat(FeatEdges) || !chance(0.25))
        return nil;
    return EDGES(random_spacing(YES), random_spacing(YES), random_spacing(YES), random_spacing(YES));
}

static NSDirectionalEdgeInsets random_insets_for(unsigned flag, double probability)
{
    if (!feat(flag) || !chance(probability))
        return NSDirectionalEdgeInsetsZero;
    return EI(pick(8), pick(8), pick(8), pick(8));
}

static NSDirectionalEdgeInsets random_insets(double probability)
{
    return random_insets_for(FeatInsets, probability);
}

static int fuzz_serial;

static NSString *fresh_kind(void)
{
    return [NSString stringWithFormat:@"k%d", fuzz_serial++ % 40];
}

static NSCollectionLayoutSupplementaryItem *random_supplementary(void)
{
    NSDirectionalRectEdge edges[] = {NSDirectionalRectEdgeTop, NSDirectionalRectEdgeBottom | NSDirectionalRectEdgeTrailing, NSDirectionalRectEdgeLeading, NSDirectionalRectEdgeTop | NSDirectionalRectEdgeLeading, 0};
    NSCollectionLayoutAnchor *anchor = chance(0.4) ? ANCHOR_ABS(edges[pick(5)], pick(9) - 4, pick(9) - 4) : ANCHOR_FRAC(edges[pick(5)], pick(3) * 0.5, pick(3) * 0.5 - 0.5);
    NSCollectionLayoutDimension *width = random_dimension(YES), *height = random_dimension(YES);
    return SUP(fresh_kind(), width, height, anchor, chance(0.4) ? ANCHOR(edges[pick(5)]) : nil);
}

static NSCollectionLayoutItem *random_item(BOOL horizontalFlow, int depth)
{
    NSCollectionLayoutItem *item;
    if (depth < 1 && feat(FeatNested) && chance(0.2)) {
        BOOL inner = chance(0.5);
        NSMutableArray *subitems = [NSMutableArray array];
        for (NSInteger count = 1 + pick(2); count > 0; count--)
            [subitems addObject:random_item(inner, depth + 1)];
        item = inner ? (id)HG(horizontalFlow ? random_flow_dimension(YES) : random_dimension(NO), horizontalFlow ? random_dimension(NO) : random_flow_dimension(NO), subitems)
                     : (id)VG(horizontalFlow ? random_flow_dimension(YES) : random_dimension(NO), horizontalFlow ? random_dimension(NO) : random_flow_dimension(NO), subitems);
        ((NSCollectionLayoutGroup *)item).interItemSpacing = random_spacing(YES);
        if (feat(FeatSupplementary) && chance(0.15))
            ((NSCollectionLayoutGroup *)item).supplementaryItems = @[random_supplementary()];
    } else if (feat(FeatSupplementary) && chance(0.15)) {
        item = [(id)K.item itemWithLayoutSize:SZ(horizontalFlow ? random_flow_dimension(YES) : random_dimension(YES), horizontalFlow ? random_dimension(YES) : random_flow_dimension(NO)) supplementaryItems:@[random_supplementary()]];
    } else {
        item = IT(horizontalFlow ? random_flow_dimension(YES) : random_dimension(YES), horizontalFlow ? random_dimension(YES) : random_flow_dimension(NO));
    }
    item.contentInsets = random_insets_for(FeatItemInsets, 0.3);
    NSCollectionLayoutEdgeSpacing *edges = random_edges();
    if (edges)
        item.edgeSpacing = edges;
    return item;
}


static NSString *describe_dimension(NSCollectionLayoutDimension *d)
{
    return d.isFractionalWidth ? [NSString stringWithFormat:@"fw%g", d.dimension] : d.isFractionalHeight ? [NSString stringWithFormat:@"fh%g", d.dimension] : d.isAbsolute ? [NSString stringWithFormat:@"ab%g", d.dimension] : [NSString stringWithFormat:@"es%g", d.dimension];
}

static NSString *describe_item(NSCollectionLayoutItem *item)
{
    NSMutableString *text = [NSMutableString string];
    if ([item isKindOfClass:[NSCollectionLayoutGroup class]]) {
        NSCollectionLayoutGroup *group = (id)item;
        [text appendFormat:@"%@(", [[group description] containsString:@"layoutDirection=.horizontal"] ? @"H" : @"V"];
        [text appendFormat:@"%@x%@", describe_dimension(group.layoutSize.widthDimension), describe_dimension(group.layoutSize.heightDimension)];
        [text appendFormat:@" sp=%g%@", group.interItemSpacing ? group.interItemSpacing.spacing : 0, group.interItemSpacing.isFlexibleSpacing ? @"flex" : @""];
        [text appendString:@" ["];
        for (NSCollectionLayoutItem *sub in group.subitems)
            [text appendFormat:@"%@ ", describe_item(sub)];
        [text appendString:@"])"];
    } else {
        [text appendFormat:@"i(%@x%@)", describe_dimension(item.layoutSize.widthDimension), describe_dimension(item.layoutSize.heightDimension)];
    }
    NSDirectionalEdgeInsets in = item.contentInsets;
    if (in.top || in.leading || in.bottom || in.trailing)
        [text appendFormat:@"ins(%g,%g,%g,%g)", in.top, in.leading, in.bottom, in.trailing];
    NSCollectionLayoutEdgeSpacing *e = item.edgeSpacing;
    if (e && (e.leading.spacing || e.top.spacing || e.trailing.spacing || e.bottom.spacing))
        [text appendString:@"edges"];
    return text;
}

static NSString *fuzz_text;

static CompositionalCase *fuzz_case(uint64_t seed)
{
    fuzz_text = nil;
    rng_state = seed * 2862933555777941757ULL + 3037000493ULL;
    for (int warm = 0; warm < 4; warm++)
        next_random();
    CGSize sizes[] = {{320, 480}, {301, 433}, {375, 667}, {200, 300}};
    CGSize size = sizes[pick(4)];
    BOOL sideways = feat(FeatSideways) && chance(0.35);
    NSMutableArray *kinds = [NSMutableArray array], *decorations = [NSMutableArray array], *counts = [NSMutableArray array];
    for (int index = 0; index < 40; index++)
        [kinds addObject:[NSString stringWithFormat:@"k%d", index]];
    for (int index = 0; index < 10; index++)
        [decorations addObject:[NSString stringWithFormat:@"d%d", index]];
    fuzz_serial = 0;
    NSInteger sections = 1 + pick(3);
    for (NSInteger index = 0; index < sections; index++)
        [counts addObject:@(chance(0.15) ? 0 : 1 + pick(14))];
    NSCollectionLayoutSection *(^make_section)(NSInteger) = ^NSCollectionLayoutSection *(NSInteger index) {
        NSMutableArray *subitems = [NSMutableArray array];
        NSInteger type = feat(FeatCounted) ? pick(9) : pick(7);
        BOOL horizontalGroup = type <= 3 || type == 7;
        for (NSInteger count = 1 + pick(3); count > 0; count--)
            [subitems addObject:random_item(horizontalGroup, 0)];
        NSCollectionLayoutGroup *group;
        if (type <= 3)
            group = HG(random_dimension(NO), random_dimension(NO), subitems);
        else if (type <= 6)
            group = VG(random_dimension(NO), random_dimension(NO), subitems);
        else if (type == 7)
            group = [(id)K.group horizontalGroupWithLayoutSize:SZ(random_dimension(NO), random_dimension(NO)) subitem:subitems[0] count:1 + pick(4)];
        else
            group = [(id)K.group verticalGroupWithLayoutSize:SZ(random_dimension(NO), random_dimension(NO)) subitem:subitems[0] count:1 + pick(4)];
        group.interItemSpacing = random_spacing(YES);
        group.contentInsets = random_insets_for(FeatGroupInsets, 0.3);
        NSCollectionLayoutEdgeSpacing *edges = random_edges();
        if (edges)
            group.edgeSpacing = edges;
        NSCollectionLayoutSection *section = SEC(group);
        fuzz_text = [NSString stringWithFormat:@"%@ %@", fuzz_text ?: @"", describe_item(group)];
        section.contentInsets = random_insets(0.5);
        fuzz_text = [fuzz_text stringByAppendingFormat:@" secIns(%g,%g,%g,%g)", section.contentInsets.top, section.contentInsets.leading, section.contentInsets.bottom, section.contentInsets.trailing];
        section.interGroupSpacing = feat(FeatGroupSpacing) && chance(0.4) ? pick(10) : 0;
        if (feat(FeatBoundary) && chance(0.5)) {
            NSMutableArray *boundaries = [NSMutableArray array];
            NSRectAlignment alignments[] = {NSRectAlignmentTop, NSRectAlignmentBottom, NSRectAlignmentLeading, NSRectAlignmentTrailing, NSRectAlignmentTopLeading, NSRectAlignmentTopTrailing,
                                            NSRectAlignmentBottomLeading, NSRectAlignmentBottomTrailing};
            for (NSInteger count = 1 + pick(2); count > 0; count--) {
                NSString *kind = fresh_kind();
                [boundaries addObject:BND(kind, random_dimension(NO), random_dimension(YES), alignments[pick(8)], chance(0.3) ? pick(9) - 4 : 0, chance(0.3) ? pick(9) - 4 : 0, chance(0.7), NO)];
            }
            section.boundarySupplementaryItems = boundaries;
            section.supplementariesFollowContentInsets = chance(0.6);
            for (NSCollectionLayoutBoundarySupplementaryItem *b in boundaries)
                fuzz_text = [fuzz_text stringByAppendingFormat:@" B[%@ %@x%@ a%ld off(%g,%g) ext%d follow%d]", b.elementKind, describe_dimension(b.layoutSize.widthDimension), describe_dimension(b.layoutSize.heightDimension), (long)b.alignment, b.offset.x, b.offset.y, b.extendsBoundary, section.supplementariesFollowContentInsets];
        }
        if (feat(FeatDecoration) && chance(0.3)) {
            NSString *kind = [NSString stringWithFormat:@"d%d", (int)pick(10)];
            NSCollectionLayoutDecorationItem *decoration = [(id)K.decoration backgroundDecorationItemWithElementKind:kind];
            decoration.contentInsets = random_insets(0.5);
            decoration.zIndex = pick(5) - 2;
            section.decorationItems = @[decoration];
        }
        if (feat(FeatSupplementary) && chance(0.25))
            group.supplementaryItems = @[random_supplementary()];
        return section;
    };
    UICollectionViewCompositionalLayoutConfiguration *configuration = CFG(sideways ? HORIZONTAL : VERTICAL, feat(FeatConfig) && chance(0.4) ? pick(10) : 0, nil);
    if (feat(FeatConfig) && chance(0.25)) {
        NSString *kind = fresh_kind(), *other = fresh_kind();
        NSRectAlignment alignments[] = {NSRectAlignmentTop, NSRectAlignmentBottom, NSRectAlignmentLeading, NSRectAlignmentTrailing};
        configuration.boundarySupplementaryItems = @[BND(kind, random_dimension(NO), random_dimension(NO), alignments[pick(4)], 0, 0, chance(0.8), NO), BND(other, random_dimension(NO), random_dimension(NO), alignments[pick(4)], 0, 0, chance(0.8), NO)];
        for (NSCollectionLayoutBoundarySupplementaryItem *b in configuration.boundarySupplementaryItems)
            fuzz_text = [fuzz_text stringByAppendingFormat:@" CFG[%@ %@x%@ a%ld ext%d]", b.elementKind, describe_dimension(b.layoutSize.widthDimension), describe_dimension(b.layoutSize.heightDimension), (long)b.alignment, b.extendsBoundary];
    }
    UICollectionViewLayout *layout;
    if (feat(FeatProvider) && chance(0.5)) {
        layout = [[(id)K.layout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index, id environment) {
            rng_state = seed * 7919 + (uint64_t)index * 104729 + 12345;
            fuzz_serial = (int)index * 13;
            return make_section(index);
        } configuration:configuration];
    } else {
        layout = [[(id)K.layout alloc] initWithSection:make_section(0) configuration:configuration];
    }
    CompositionalCase *built = make(layout, counts, kinds, decorations, size);
    return built;
}


static NSArray *environment_answers(CompositionalKit kit, UIWindow *window)
{
    K = kit;
    NSMutableArray *seen = [NSMutableArray array];
    __block NSString *customSeen = nil;
    UICollectionViewCompositionalLayout *layout = [[(id)kit.layout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index, id<NSCollectionLayoutEnvironment> environment) {
        id<NSCollectionLayoutContainer> container = environment.container;
        [seen addObject:[NSString stringWithFormat:@"%ld %g %g %g %g %d", (long)index, container.contentSize.width, container.contentSize.height, container.effectiveContentSize.width,
                                                   container.effectiveContentSize.height, environment.traitCollection != nil]];
        NSCollectionLayoutGroup *group = [(id)K.group customGroupWithLayoutSize:SZ(FW(1), AB(80)) itemProvider:^NSArray *(id<NSCollectionLayoutEnvironment> inner) {
            id<NSCollectionLayoutContainer> box = inner.container;
            customSeen = [NSString stringWithFormat:@"%g %g %g %g %g %g", box.contentSize.width, box.contentSize.height, box.effectiveContentSize.width, box.effectiveContentSize.height,
                                                    box.contentInsets.leading, box.effectiveContentInsets.top];
            return @[[(id)K.customItem customItemWithFrame:CGRectMake(1, 2, 30, 40)]];
        }];
        group.contentInsets = EI(1, 2, 3, 4);
        return SEC(group);
    }];
    CompositionalCase *built = make(layout, @[@2, @1], @[], @[], CGSizeMake(320, 480));
    NSString *dump = compositional_dump(built, window);
    NSCollectionLayoutSection *section = SEC(HG(FW(1), AB(40), @[IT(FW(0.5), FH(1))]));
    __block int handled = 0;
    section.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging;
    section.visibleItemsInvalidationHandler = ^(NSArray *items, CGPoint offset, id<NSCollectionLayoutEnvironment> environment) {
        handled++;
    };
    NSString *flat = compositional_dump(make(LAYOUT(section, nil), @[@3], @[], @[], CGSizeMake(320, 480)), window);
    return @[seen.count == 2 ? seen[0] : @"", seen.count == 2 ? seen[1] : @"", customSeen ?: @"", @([dump rangeOfString:@"0 - 0.0 1 2 30 40"].location != NSNotFound),
             @([flat rangeOfString:@"0 - 0.2 0 40 160 40"].location != NSNotFound), @(handled)];
}

void charon_windowed_run(UIWindow *window)
{
    CompositionalKit system = compositional_kit(@""), port = compositional_kit(@"CharonHost");
    CHECK(port.layout != nil && port.section != nil && port.layout != system.layout, "the port's classes are linked under their host names");
    NSArray *portEnvironment = environment_answers(port, window), *systemEnvironment = environment_answers(system, window);
    NSString *(^head)(NSArray *) = ^NSString *(NSArray *answers) { return [[answers subarrayWithRange:NSMakeRange(0, 4)] componentsJoinedByString:@"|"]; };
    CHECK_EQUAL(head(systemEnvironment), @"0 320 480 320 480 1|1 320 480 320 480 1|320 80 314 76 2 1|1", "the system gives the environments the device test expects");
    CHECK_EQUAL(head(portEnvironment), head(systemEnvironment), "the port gives the same environments");
    CHECK_EQUAL([[portEnvironment subarrayWithRange:NSMakeRange(4, 2)] componentsJoinedByString:@"|"], @"0|1", "the port nests a section that scrolls the other way and calls its handler");
    CHECK_EQUAL([[systemEnvironment subarrayWithRange:NSMakeRange(4, 2)] componentsJoinedByString:@"|"], @"0|1", "the system nests such a section and calls the handler");
    NSMutableArray *answers = [NSMutableArray array];
    BOOL all = YES;
    for (NSUInteger index = 0; index < compositional_case_count(); index++) {
        NSString *expected = compositional_case_dump(system, index, window);
        NSString *actual = compositional_case_dump(port, index, window);
        [answers addObject:expected];
        NSString *name = [NSString stringWithFormat:@"layout %@", compositional_case_name(index)];
        BOOL same = [actual isEqual:expected];
        all = all && same;
        charon_check(same, name.UTF8String, first_difference(actual, expected));
    }
    if (getenv("CHARON_FUZZ_MASK"))
        fuzz_mask = (unsigned)strtoul(getenv("CHARON_FUZZ_MASK"), NULL, 0);
    NSUInteger fuzz = getenv("CHARON_FUZZ_ROUNDS") ? (NSUInteger)atoi(getenv("CHARON_FUZZ_ROUNDS")) : 0;
    NSUInteger only = getenv("CHARON_FUZZ_ONLY") ? (NSUInteger)atoi(getenv("CHARON_FUZZ_ONLY")) : 0;
    for (NSUInteger round = only ? only - 1 : 0; round < (only ? only : fuzz); round++) {
        K = system;
        NSString *expected = nil, *actual = nil;
        @try {
            expected = compositional_dump(fuzz_case(round + 1), window);
        } @catch (NSException *exception) {
            expected = [NSString stringWithFormat:@"raised %@ %@", exception.name, exception.reason];
        }
        K = port;
        @try {
            actual = compositional_dump(fuzz_case(round + 1), window);
        } @catch (NSException *exception) {
            actual = [NSString stringWithFormat:@"raised %@ %@", exception.name, exception.reason];
        }
        BOOL same = [actual isEqual:expected];
        if (only)
            printf("SYSTEM\n%s\nPORT\n%s\n", expected.UTF8String, actual.UTF8String);
        NSString *name = [NSString stringWithFormat:@"random layout %lu", (unsigned long)round + 1];
        if (!same) {
            K = system;
            compositional_dump(fuzz_case(round + 1), window);
            name = [NSString stringWithFormat:@"%@ %@ sizes %@ counts %@", name, fuzz_text, NSStringFromCGSize(fuzz_case(round + 1).size), [fuzz_case(round + 1).counts componentsJoinedByString:@","]];
        }
        charon_check(same, name.UTF8String, first_difference(actual, expected));
    }
    if (all)
        record_expectations(answers);
}
