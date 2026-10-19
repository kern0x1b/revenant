#import "listops.h"

extern UICellAccessoryPosition CharonHostUICellAccessoryPositionBeforeAccessoryOfClass(Class accessoryClass);
extern UICellAccessoryPosition CharonHostUICellAccessoryPositionAfterAccessoryOfClass(Class accessoryClass);
extern const CGFloat CharonHostUICellAccessoryStandardDimension;
extern const CGFloat CharonHostUIListContentImageStandardDimension;

static id make_state(int side, NSString *name, UITraitCollection *traits)
{
    return [[named(side, name) alloc] initWithTraitCollection:traits];
}

static void randomise_state(id state, BOOL cell)
{
    UICellConfigurationState *s = state;
    s.disabled = chance(30);
    s.highlighted = chance(30);
    s.selected = chance(30);
    s.focused = chance(30);
    if (!cell)
        return;
    s.editing = chance(30);
    s.expanded = chance(30);
    s.swiped = chance(30);
    s.reordering = chance(30) && reordering_allowed;
    s.cellDragState = (UICellConfigurationDragState)pick(3);
    s.cellDropState = (UICellConfigurationDropState)pick(3);
}

static NSString *dump_state(id state)
{
    UICellConfigurationState *s = state;
    NSMutableString *text = [NSMutableString stringWithFormat:@"d=%d h=%d s=%d f=%d", s.disabled, s.highlighted, s.selected, s.focused];
    if ([s isKindOfClass:named(0, @"UICellConfigurationState")] || [s isKindOfClass:named(1, @"UICellConfigurationState")])
        [text appendFormat:@" e=%d x=%d w=%d r=%d drag=%ld drop=%ld", s.editing, s.expanded, s.swiped, s.reordering, (long)s.cellDragState, (long)s.cellDropState];
    return text;
}

void charon_run_listvalues(void)
{
    images[0] = square(20);
    images[1] = square(29);
    images[2] = square(64);
    strings = @[@"", @"a", @"ab", @"abc", @"Hello", @"A much longer line of text that wraps", [NSNull null], @"é ü 中"];
    colors = @[UIColor.redColor, UIColor.blueColor, UIColor.clearColor, UIColor.whiteColor, [UIColor colorWithRed:0.1 green:0.2 blue:0.3 alpha:0.4], UIColor.labelColor];
    fonts = @[[UIFont systemFontOfSize:12], [UIFont boldSystemFontOfSize:20], [UIFont italicSystemFontOfSize:15]];

    UITraitCollection *traits = [UITraitCollection traitCollectionWithTraitsFromCollections:@[[UITraitCollection traitCollectionWithDisplayScale:2], [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]]];
    NSArray *factories = @[@"cellConfiguration", @"subtitleCellConfiguration", @"valueCellConfiguration", @"plainHeaderConfiguration", @"plainFooterConfiguration", @"groupedHeaderConfiguration", @"groupedFooterConfiguration",
                           @"sidebarCellConfiguration", @"sidebarSubtitleCellConfiguration", @"accompaniedSidebarCellConfiguration", @"accompaniedSidebarSubtitleCellConfiguration", @"sidebarHeaderConfiguration"];
    NSArray *ops = config_ops();

    {
        id a = [named(0, @"UIListContentConfiguration") performSelector:NSSelectorFromString(@"new")], b = [named(1, @"UIListContentConfiguration") performSelector:NSSelectorFromString(@"new")];
        same(@"config new values", dump_config(a), dump_config(b));
        same(@"config new description", normalised(a), normalised(b));
        a = [named(0, @"UIBackgroundConfiguration") performSelector:NSSelectorFromString(@"new")];
        b = [named(1, @"UIBackgroundConfiguration") performSelector:NSSelectorFromString(@"new")];
        same(@"background new values", dump_background(a), dump_background(b));
        same(@"background new description", normalised(a), normalised(b));
        a = [[named(0, @"UIListContentTextProperties") alloc] init];
        b = [[named(1, @"UIListContentTextProperties") alloc] init];
        same(@"text properties init", dump_text_properties(a), dump_text_properties(b));
        same(@"text properties init description", normalised(a), normalised(b));
        a = [[named(0, @"UIListContentImageProperties") alloc] init];
        b = [[named(1, @"UIListContentImageProperties") alloc] init];
        same(@"image properties init", dump_image_properties(a), dump_image_properties(b));
        same(@"image properties init description", normalised(a), normalised(b));
    }
    for (NSString *factory in factories) {
        id a = [named(0, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        id b = [named(1, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        same([NSString stringWithFormat:@"config %@ values", factory], dump_config(a), dump_config(b));
        same([NSString stringWithFormat:@"config %@ description", factory], normalised(a), normalised(b));
        a = [named(0, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
    }

    for (int round = 0; round < 1500; round++) {
        NSString *factory = factories[pick(factories.count)];
        id a = [named(0, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        id b = [named(1, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        NSMutableString *history = [NSMutableString stringWithString:factory];
        int count = 1 + (int)pick(8);
        for (int step = 0; step < count; step++) {
            NSInteger index = pick(ops.count);
            [history appendFormat:@" op%ld", (long)index];
            uint64_t argument = rng;
            ((Op)ops[index])(a, 0);
            rng = argument;
            ((Op)ops[index])(b, 1);
            if (chance(15)) {
                a = [a copy];
                b = [b copy];
            }
        }
        NSString *da = dump_config(a), *db = dump_config(b);
        if (![da isEqual:db]) {
            charon_check(NO, [NSString stringWithFormat:@"config fuzz %d values", round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", history, da, db]);
        } else if (![normalised(a) isEqual:normalised(b)]) {
            charon_check(NO, [NSString stringWithFormat:@"config fuzz %d description", round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", history, normalised(a), normalised(b)]);
        } else {
            charon_check(YES, "config fuzz", nil);
        }
        id ac = [a copy], bc = [b copy];
        same(@"config copy equal", [NSString stringWithFormat:@"%d %d", [ac isEqual:a], [ac hash] == [a hash]], [NSString stringWithFormat:@"%d %d", [bc isEqual:b], [bc hash] == [b hash]]);
        same(@"config copy is deep", [NSString stringWithFormat:@"%d %d", [ac textProperties] != [a textProperties], [ac imageProperties] != [a imageProperties]],
             [NSString stringWithFormat:@"%d %d", [bc textProperties] != [b textProperties], [bc imageProperties] != [b imageProperties]]);
        id other = [named(0, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factories[pick(factories.count)])];
        id otherPort = [named(1, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factories[pick(factories.count)])];
        (void)other;
        (void)otherPort;
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:b requiringSecureCoding:YES error:&error];
        id decoded = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:named(1, @"UIListContentConfiguration") fromData:data error:&error] : nil;
        UIListContentConfiguration *plainB = b;
        BOOL transformers = plainB.textProperties.colorTransformer || plainB.secondaryTextProperties.colorTransformer || plainB.imageProperties.tintColorTransformer;
        if (round % 25 == 0 && !transformers)
            charon_check(decoded != nil && [dump_config(decoded) isEqual:dump_config(b)], "config coding round trip", [NSString stringWithFormat:@"%@\n%@\n%@", error, decoded ? dump_config(decoded) : nil, dump_config(b)]);
    }

    for (int round = 0; round < 3000; round++) {
        NSString *factory = factories[pick(factories.count)];
        id a = [named(0, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        id b = [named(1, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        int count = (int)pick(4);
        for (int step = 0; step < count; step++) {
            NSInteger index = pick(ops.count);
            uint64_t argument = rng;
            ((Op)ops[index])(a, 0);
            rng = argument;
            ((Op)ops[index])(b, 1);
        }
        BOOL cell = chance(80);
        uint64_t stateSeed = rng;
        id sa = make_state(0, cell ? @"UICellConfigurationState" : @"UIViewConfigurationState", traits);
        randomise_state(sa, cell);
        rng = stateSeed;
        id sb = make_state(1, cell ? @"UICellConfigurationState" : @"UIViewConfigurationState", traits);
        randomise_state(sb, cell);
        id ua = [a updatedConfigurationForState:sa], ub = [b updatedConfigurationForState:sb];
        NSString *da = dump_config(ua), *db = dump_config(ub);
        if (![da isEqual:db])
            charon_check(NO, [NSString stringWithFormat:@"config update %@ %d values", factory, round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", dump_state(sa), da, db]);
        else if (![normalised(ua) isEqual:normalised(ub)])
            charon_check(NO, [NSString stringWithFormat:@"config update %@ %d description", factory, round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", dump_state(sa), normalised(ua), normalised(ub)]);
        else
            charon_check(YES, "config update", nil);
        same([NSString stringWithFormat:@"config update equals %@ %@", factory, dump_state(sa)], [NSString stringWithFormat:@"%d %d", [ua isEqual:a], [ua isEqual:[a updatedConfigurationForState:sa]]], [NSString stringWithFormat:@"%d %d", [ub isEqual:b], [ub isEqual:[b updatedConfigurationForState:sb]]]);
    }

    NSArray *backgrounds = @[@"clearConfiguration", @"listPlainCellConfiguration", @"listPlainHeaderFooterConfiguration", @"listGroupedCellConfiguration", @"listGroupedHeaderFooterConfiguration",
                             @"listSidebarHeaderConfiguration", @"listSidebarCellConfiguration", @"listAccompaniedSidebarCellConfiguration"];
    NSArray *bops = background_ops();
    reordering_allowed = NO;
    for (NSString *factory in backgrounds) {
        id a = [named(0, @"UIBackgroundConfiguration") performSelector:NSSelectorFromString(factory)];
        id b = [named(1, @"UIBackgroundConfiguration") performSelector:NSSelectorFromString(factory)];
        same([NSString stringWithFormat:@"background %@ values", factory], dump_background(a), dump_background(b));
        same([NSString stringWithFormat:@"background %@ description", factory], normalised(a), normalised(b));
    }
    for (int round = 0; round < 3000; round++) {
        NSString *factory = backgrounds[pick(backgrounds.count)];
        id a = [named(0, @"UIBackgroundConfiguration") performSelector:NSSelectorFromString(factory)];
        id b = [named(1, @"UIBackgroundConfiguration") performSelector:NSSelectorFromString(factory)];
        int count = (int)pick(5);
        for (int step = 0; step < count; step++) {
            NSInteger index = pick(bops.count);
            uint64_t argument = rng;
            ((Op)bops[index])(a, 0);
            rng = argument;
            ((Op)bops[index])(b, 1);
            if (chance(15)) {
                a = [a copy];
                b = [b copy];
            }
        }
        NSString *da = dump_background(a), *db = dump_background(b);
        if (![da isEqual:db])
            charon_check(NO, [NSString stringWithFormat:@"background fuzz %d values", round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", factory, da, db]);
        else if (![normalised(a) isEqual:normalised(b)])
            charon_check(NO, [NSString stringWithFormat:@"background fuzz %d description", round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", factory, normalised(a), normalised(b)]);
        else
            charon_check(YES, "background fuzz", nil);
        id ac = [a copy], bc = [b copy];
        same(@"background copy equal", [NSString stringWithFormat:@"%d %d", [ac isEqual:a], [ac hash] == [a hash]], [NSString stringWithFormat:@"%d %d", [bc isEqual:b], [bc hash] == [b hash]]);
        BOOL cell = chance(80);
        uint64_t stateSeed = rng;
        id sa = make_state(0, cell ? @"UICellConfigurationState" : @"UIViewConfigurationState", traits);
        randomise_state(sa, cell);
        rng = stateSeed;
        id sb = make_state(1, cell ? @"UICellConfigurationState" : @"UIViewConfigurationState", traits);
        randomise_state(sb, cell);
        id ua = [a updatedConfigurationForState:sa], ub = [b updatedConfigurationForState:sb];
        da = dump_background(ua);
        db = dump_background(ub);
        if (![da isEqual:db])
            charon_check(NO, [NSString stringWithFormat:@"background update %@ %d values", factory, round].UTF8String, [NSString stringWithFormat:@"%@\n  before %@\n  system %@\n  port   %@", dump_state(sa), dump_background(a), da, db]);
        else if (![normalised(ua) isEqual:normalised(ub)])
            charon_check(NO, [NSString stringWithFormat:@"background update %@ %d description", factory, round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", dump_state(sa), normalised(ua), normalised(ub)]);
        else
            charon_check(YES, "background update", nil);
        same([NSString stringWithFormat:@"background update equals %@ %@", factory, dump_state(sa)], [NSString stringWithFormat:@"%d", [ua isEqual:a]], [NSString stringWithFormat:@"%d", [ub isEqual:b]]);
    }

    reordering_allowed = YES;
    for (int round = 0; round < 1500; round++) {
        BOOL cell = chance(60);
        NSString *class_ = cell ? @"UICellConfigurationState" : @"UIViewConfigurationState";
        UITraitCollection *t = chance(50) ? traits : [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];
        uint64_t seed = rng;
        id a = make_state(0, class_, t);
        randomise_state(a, cell);
        rng = seed;
        id b = make_state(1, class_, t);
        randomise_state(b, cell);
        if (chance(30)) {
            [a setObject:@"v" forKeyedSubscript:@"k"];
            [b setObject:@"v" forKeyedSubscript:@"k"];
        }
        if (chance(15)) {
            [a setCustomState:@1 forKey:@"n"];
            [b setCustomState:@1 forKey:@"n"];
        }
        if (chance(10)) {
            [a setCustomState:nil forKey:@"k"];
            [b setCustomState:nil forKey:@"k"];
        }
        same(@"state description", normalised(a), normalised(b));
        id ac = [a copy], bc = [b copy];
        same(@"state copy", [NSString stringWithFormat:@"%d %d %@ %d", [ac isEqual:a], [ac hash] == [a hash], NSStringFromClass([ac class]), ac != a], [NSString stringWithFormat:@"%d %d %@ %d", [bc isEqual:b], [bc hash] == [b hash], [NSStringFromClass([bc class]) stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""], bc != b]);
        [ac setSelected:![ac isSelected]];
        [bc setSelected:![bc isSelected]];
        same(@"state copy differs", [NSString stringWithFormat:@"%d", [ac isEqual:a]], [NSString stringWithFormat:@"%d", [bc isEqual:b]]);
        id x = make_state(0, class_, traits), y = make_state(1, class_, traits);
        same([NSString stringWithFormat:@"state equality of two %@", normalised(a)], [NSString stringWithFormat:@"%d", [a isEqual:x]], [NSString stringWithFormat:@"%d", [b isEqual:y]]);
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:b requiringSecureCoding:YES error:&error];
        id decoded = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:named(1, class_) fromData:data error:&error] : nil;
        charon_check(decoded && [decoded isEqual:b], "state coding round trip", [NSString stringWithFormat:@"%@ | %@ | %@", error, normalised(b), normalised(decoded)]);
        same(@"state custom lookup", [NSString stringWithFormat:@"%@ %@", [a customStateForKey:@"k"], a[@"n"]], [NSString stringWithFormat:@"%@ %@", [b customStateForKey:@"k"], b[@"n"]]);
    }
    id v1 = make_state(0, @"UIViewConfigurationState", traits), v2 = make_state(1, @"UIViewConfigurationState", traits);
    id c1 = make_state(0, @"UICellConfigurationState", traits), c2 = make_state(1, @"UICellConfigurationState", traits);
    same(@"state cross equality", [NSString stringWithFormat:@"%d %d", [c1 isEqual:v1], [v1 isEqual:c1]], [NSString stringWithFormat:@"%d %d", [c2 isEqual:v2], [v2 isEqual:c2]]);
    for (int side = 0; side < 2; side++) {
        NSString *reason = @"none";
        @try {
            (void)[[named(side, @"UIViewConfigurationState") alloc] initWithTraitCollection:nil];
        } @catch (NSException *e) {
            reason = [NSString stringWithFormat:@"%@ %@", e.name, e.reason];
        }
        static NSString *first;
        if (side == 0)
            first = reason;
        else
            same(@"state nil trait collection", first, reason);
    }
    CHECK(![named(1, @"UIViewConfigurationState") instancesRespondToSelector:@selector(isPinned)], "state pinned is 15.0 and not answered");
}


static id make_accessory(int side, NSInteger kind, UIView *view)
{
    NSArray *names = @[@"UICellAccessoryCheckmark", @"UICellAccessoryDisclosureIndicator", @"UICellAccessoryDelete", @"UICellAccessoryInsert", @"UICellAccessoryReorder", @"UICellAccessoryMultiselect",
                       @"UICellAccessoryOutlineDisclosure", @"UICellAccessoryLabel", @"UICellAccessoryCustomView"];
    Class cls = named(side, names[kind]);
    if (kind == 7)
        return [[cls alloc] initWithText:@"Text"];
    if (kind == 8)
        return [[cls alloc] initWithCustomView:view placement:UICellAccessoryPlacementLeading];
    return [[cls alloc] init];
}

static NSString *dump_accessory(id a, NSArray *sample)
{
    UICellAccessory *x = a;
    NSMutableString *text = [NSMutableString stringWithFormat:@"%ld %d %g %@", (long)x.displayedState, x.hidden, x.reservedLayoutWidth, rgb(x.tintColor)];
    if ([a isKindOfClass:named(0, @"UICellAccessoryDelete")] || [a isKindOfClass:named(1, @"UICellAccessoryDelete")] || [a isKindOfClass:named(0, @"UICellAccessoryInsert")] || [a isKindOfClass:named(1, @"UICellAccessoryInsert")] ||
        [a isKindOfClass:named(0, @"UICellAccessoryMultiselect")] || [a isKindOfClass:named(1, @"UICellAccessoryMultiselect")])
        [text appendFormat:@" bg=%@", rgb([(UICellAccessoryDelete *)a backgroundColor])];
    if ([a respondsToSelector:@selector(actionHandler)])
        [text appendFormat:@" handler=%d", [(UICellAccessoryDelete *)a actionHandler] != nil];
    if ([a respondsToSelector:@selector(showsVerticalSeparator)])
        [text appendFormat:@" sep=%d", [(UICellAccessoryReorder *)a showsVerticalSeparator]];
    if ([a respondsToSelector:@selector(style)])
        [text appendFormat:@" style=%ld", (long)[(UICellAccessoryOutlineDisclosure *)a style]];
    if ([a respondsToSelector:@selector(text)])
        [text appendFormat:@" text=%@ font=%@ adj=%d", [(UICellAccessoryLabel *)a text], font_text([(UICellAccessoryLabel *)a font]), [(UICellAccessoryLabel *)a adjustsFontForContentSizeCategory]];
    if ([a respondsToSelector:@selector(placement)])
        [text appendFormat:@" placement=%ld fixed=%d pos=%lu", (long)[(UICellAccessoryCustomView *)a placement], [(UICellAccessoryCustomView *)a maintainsFixedSize], (unsigned long)[(UICellAccessoryCustomView *)a position](sample)];
    return text;
}

static void accessory_checks(void)
{
    UIView *view = [[UIView alloc] init];
    for (int round = 0; round < 800; round++) {
        NSInteger kind = round % 9;
        uint64_t seed = rng;
        id a = make_accessory(0, kind, view);
        id b = make_accessory(1, kind, nil);
        b = make_accessory(1, kind, view);
        for (int step = 0; step < 4; step++) {
            NSInteger op = pick(9);
            uint64_t argument = rng;
            for (int side = 0; side < 2; side++) {
                rng = argument;
                id x = side ? b : a;
                UICellAccessory *acc = x;
                switch (op) {
                case 0: acc.displayedState = (UICellAccessoryDisplayedState)pick(3); break;
                case 1: acc.hidden = chance(50); break;
                case 2: acc.reservedLayoutWidth = pick(3) * 10; break;
                case 3: acc.tintColor = chance(60) ? UIColor.redColor : nil; break;
                case 4: if ([x respondsToSelector:@selector(setBackgroundColor:)]) [(UICellAccessoryDelete *)x setBackgroundColor:chance(60) ? UIColor.blueColor : nil]; break;
                case 5: if ([x respondsToSelector:@selector(setActionHandler:)]) [(UICellAccessoryDelete *)x setActionHandler:chance(60) ? ^{} : nil]; break;
                case 6: if ([x respondsToSelector:@selector(setShowsVerticalSeparator:)]) [(UICellAccessoryReorder *)x setShowsVerticalSeparator:chance(50)]; break;
                case 7: if ([x respondsToSelector:@selector(setStyle:)]) [(UICellAccessoryOutlineDisclosure *)x setStyle:(UICellAccessoryOutlineDisclosureStyle)pick(3)]; break;
                case 8:
                    if ([x respondsToSelector:@selector(setFont:)]) {
                        [(UICellAccessoryLabel *)x setFont:fonts[pick(fonts.count)]];
                        [(UICellAccessoryLabel *)x setAdjustsFontForContentSizeCategory:chance(50)];
                    }
                    if ([x respondsToSelector:@selector(setMaintainsFixedSize:)]) {
                        [(UICellAccessoryCustomView *)x setMaintainsFixedSize:chance(50)];
                        [(UICellAccessoryCustomView *)x setPosition:chance(50) ? UICellAccessoryPositionBeforeAccessoryOfClass([UICellAccessoryLabel class]) : nil];
                    }
                    break;
                }
            }
        }
        (void)seed;
        NSArray *sample = @[make_accessory(0, 0, view), make_accessory(0, 7, view)];
        same([NSString stringWithFormat:@"accessory %ld values", (long)kind], dump_accessory(a, sample), dump_accessory(b, sample));
        same([NSString stringWithFormat:@"accessory %ld description", (long)kind], normalised(a), normalised(b));
        id ac = [a copy], bc = [b copy];
        same([NSString stringWithFormat:@"accessory %ld copy %@", (long)kind, dump_accessory(a, sample)], [NSString stringWithFormat:@"%d %d %d %d", [ac isEqual:a], [ac hash] == [a hash], ac != a, kind == 7 ? 0 : [ac isEqual:make_accessory(0, kind, view)]],
             [NSString stringWithFormat:@"%d %d %d %d", [bc isEqual:b], [bc hash] == [b hash], bc != b, kind == 7 ? 0 : [bc isEqual:make_accessory(1, kind, view)]]);
        same([NSString stringWithFormat:@"accessory %ld equality of two", (long)kind], [NSString stringWithFormat:@"%d %d", [make_accessory(0, kind, view) isEqual:make_accessory(0, kind, view)], [make_accessory(0, kind, view) isEqual:make_accessory(0, (kind + 1) % 9, view)]],
             [NSString stringWithFormat:@"%d %d", [make_accessory(1, kind, view) isEqual:make_accessory(1, kind, view)], [make_accessory(1, kind, view) isEqual:make_accessory(1, (kind + 1) % 9, view)]]);
        if (kind != 8) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:b requiringSecureCoding:YES error:NULL];
            id decoded = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:named(1, NSStringFromClass([[make_accessory(0, kind, view) class] class])) fromData:data error:NULL] : nil;
            NSString *expected = [dump_accessory(b, sample) stringByReplacingOccurrencesOfString:@" handler=1" withString:@" handler=0"];
            charon_check(decoded && [dump_accessory(decoded, sample) isEqual:expected], "accessory coding round trip", [NSString stringWithFormat:@"%ld %@ %@", (long)kind, expected, decoded ? dump_accessory(decoded, sample) : @"nil"]);
        }
    }
    NSArray *classes = @[@"UICellAccessoryCheckmark", @"UICellAccessoryDelete", @"UICellAccessoryLabel", @"UICellAccessoryOutlineDisclosure"];
    NSMutableArray *ports[2] = {[NSMutableArray array], [NSMutableArray array]};
    for (int side = 0; side < 2; side++)
        for (NSInteger index = 0; index < 9; index++)
            [ports[side] addObject:make_accessory(side, index, view)];
    for (NSString *className in classes) {
        NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
        for (int side = 0; side < 2; side++) {
            Class cls = side ? named(1, className) : NSClassFromString(className);
            UICellAccessoryPosition (*before)(Class) = side ? (UICellAccessoryPosition (*)(Class))NULL : NULL;
            (void)before;
            (void)cls;
        }
        (void)answers;
    }
    for (int index = 0; index < 4; index++) {
        NSArray *pool = @[@[ports[0][0], ports[0][1], ports[0][7]], @[], @[ports[0][7], ports[0][0]], @[ports[0][2], ports[0][3], ports[0][2]]];
        NSArray *portPool = @[@[ports[1][0], ports[1][1], ports[1][7]], @[], @[ports[1][7], ports[1][0]], @[ports[1][2], ports[1][3], ports[1][2]]];
        NSArray *names = @[@"UICellAccessoryCheckmark", @"UICellAccessoryDelete", @"UICellAccessoryLabel", @"UICellAccessoryOutlineDisclosure"];
        NSMutableString *system = [NSMutableString string], *port = [NSMutableString string];
        for (NSString *name in names) {
            [system appendFormat:@"%lu %lu ", (unsigned long)UICellAccessoryPositionBeforeAccessoryOfClass(NSClassFromString(name))(pool[index]), (unsigned long)UICellAccessoryPositionAfterAccessoryOfClass(NSClassFromString(name))(pool[index])];
            [port appendFormat:@"%lu %lu ", (unsigned long)CharonHostUICellAccessoryPositionBeforeAccessoryOfClass(named(1, name))(portPool[index]), (unsigned long)CharonHostUICellAccessoryPositionAfterAccessoryOfClass(named(1, name))(portPool[index])];
        }
        same(@"accessory position blocks", system, port);
    }
    for (int side = 0; side < 2; side++) {
        NSString *reason = @"none";
        @try {
            (void)[[named(side, @"UICellAccessoryLabel") alloc] initWithText:nil];
        } @catch (NSException *e) {
            reason = [NSString stringWithFormat:@"%@ %@", e.name, e.reason];
        }
        static NSString *first;
        if (side == 0)
            first = reason;
        else
            same(@"accessory label nil text", first, reason);
    }
    same(@"accessory standard dimension", [NSString stringWithFormat:@"%g", UICellAccessoryStandardDimension], [NSString stringWithFormat:@"%g", CharonHostUICellAccessoryStandardDimension]);
    same(@"list image standard dimension", [NSString stringWithFormat:@"%g", UIListContentImageStandardDimension], [NSString stringWithFormat:@"%g", CharonHostUIListContentImageStandardDimension]);
}

int main(void)
{
    @autoreleasepool {
        charon_run_listvalues();
        accessory_checks();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
