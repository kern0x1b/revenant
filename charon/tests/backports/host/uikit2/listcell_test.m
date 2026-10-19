#import "listops.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import "lists-cases.h"

void charon_windowed_run(UIWindow *window);

static UIWindow *test_window;

static NSString *frame_text(CGRect frame)
{
    return CGRectEqualToRect(frame, CGRectZero) ? @"-" : [NSString stringWithFormat:@"{%.3f,%.3f,%.3f,%.3f}", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];
}

static NSString *content_frames(UIView *view, id config)
{
    CGRect image = CGRectZero, text = CGRectZero, secondary = CGRectZero;
    NSInteger labels = 0, images = 0;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            image = sub.frame;
            images++;
        } else if ([sub isKindOfClass:[UILabel class]]) {
            UIListContentConfiguration *c = config;
            BOOL hasText = c.text != nil || c.attributedText != nil;
            if (labels == 0 && hasText)
                text = sub.frame;
            else
                secondary = sub.frame;
            labels++;
        }
    }
    return [NSString stringWithFormat:@"image=%@ text=%@ secondary=%@ labels=%ld images=%ld", frame_text(image), frame_text(text), frame_text(secondary), (long)labels, (long)images];
}

static NSString *measure(int side, id config, CGSize size, BOOL withGuides, CGSize *fit)
{
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    UIListContentView *view = [[named(side, @"UIListContentView") alloc] initWithConfiguration:config];
    view.frame = host.bounds;
    [host addSubview:view];
    [test_window.rootViewController.view addSubview:host];
    [host layoutIfNeeded];
    [view layoutIfNeeded];
    NSString *frames = content_frames(view, config);
    if (withGuides)
        frames = [frames stringByAppendingFormat:@" guides=%@ %@ %@", frame_text(view.textLayoutGuide.layoutFrame), frame_text(view.secondaryTextLayoutGuide.layoutFrame), frame_text(view.imageLayoutGuide.layoutFrame)];
    if (fit)
        *fit = [view sizeThatFits:CGSizeMake(size.width, CGFLOAT_MAX)];
    [host removeFromSuperview];
    return frames;
}

static BOOL frames_agree(NSString *a, NSString *b, double tolerance, BOOL onlyY)
{
    NSRegularExpression *numbers = [NSRegularExpression regularExpressionWithPattern:@"\\{([^}]*)\\}" options:0 error:NULL];
    NSArray *ma = [numbers matchesInString:a options:0 range:NSMakeRange(0, a.length)], *mb = [numbers matchesInString:b options:0 range:NSMakeRange(0, b.length)];
    if (ma.count != mb.count || [[a stringByReplacingOccurrencesOfString:@"-" withString:@""] length] == 0)
        return NO;
    for (NSUInteger index = 0; index < ma.count; index++) {
        NSArray *x = [[a substringWithRange:[ma[index] rangeAtIndex:1]] componentsSeparatedByString:@","], *y = [[b substringWithRange:[mb[index] rangeAtIndex:1]] componentsSeparatedByString:@","];
        if (x.count != y.count)
            return NO;
        for (NSUInteger field = 0; field < x.count; field++) {
            double allowed = (!onlyY || field == 1) ? tolerance : 0.0011;
            if (fabs([x[field] doubleValue] - [y[field] doubleValue]) > allowed)
                return NO;
        }
    }
    return YES;
}

static void run_content_views(void)
{
    images[0] = square(20);
    images[1] = square(29);
    images[2] = square(64);
    strings = @[@"a", @"Hello", @"Hello world", @"Title", @"Subtitle text", @"A much longer line of text that has to wrap onto more lines when narrow", [NSNull null], @"Zebra crossing", @"Ünï çødé"];
    colors = @[UIColor.redColor, UIColor.blueColor];
    fonts = @[[UIFont systemFontOfSize:12], [UIFont boldSystemFontOfSize:20], [UIFont italicSystemFontOfSize:15]];
    NSArray *factories = @[@"cellConfiguration", @"subtitleCellConfiguration", @"valueCellConfiguration", @"plainHeaderConfiguration", @"plainFooterConfiguration", @"groupedHeaderConfiguration", @"groupedFooterConfiguration",
                           @"sidebarCellConfiguration", @"sidebarSubtitleCellConfiguration", @"accompaniedSidebarCellConfiguration", @"accompaniedSidebarSubtitleCellConfiguration", @"sidebarHeaderConfiguration"];
    NSArray *ops = config_ops();
    CGFloat widths[] = {120, 200, 320, 375};
    for (int round = 0; round < 4000; round++) {
        NSString *factory = factories[pick(factories.count)];
        id a = [named(0, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        id b = [named(1, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)];
        UIListContentConfiguration *ca = a, *cb = b;
        if (chance(85)) {
            NSString *t = S();
            ca.text = t;
            cb.text = t;
        }
        if (chance(45)) {
            NSString *t = S();
            ca.secondaryText = t;
            cb.secondaryText = t;
        }
        if (chance(45)) {
            UIImage *image = images[pick(3)];
            ca.image = image;
            cb.image = image;
        }
        int count = (int)pick(5);
        for (int step = 0; step < count; step++) {
            NSInteger index = pick(ops.count);
            uint64_t argument = rng;
            ((Op)ops[index])(a, 0);
            rng = argument;
            ((Op)ops[index])(b, 1);
        }
        CGSize size = CGSizeMake(widths[pick(4)], 30 + pick(110));
        CGSize fitA = CGSizeZero, fitB = CGSizeZero;
        BOOL guides = round % 8 == 0;
        NSString *fa = measure(0, a, size, guides, &fitA), *fb = measure(1, b, size, guides, &fitB);
        BOOL mixedRow = ca.prefersSideBySideTextAndSecondaryText && ca.text && ca.secondaryText && ca.textProperties.font.pointSize != ca.secondaryTextProperties.font.pointSize;
        BOOL limitedLines = ca.textProperties.numberOfLines > 1 || ca.secondaryTextProperties.numberOfLines > 1;
        if (![fa isEqual:fb] && ((mixedRow && frames_agree(fa, fb, 5.0, NO)) || (limitedLines && frames_agree(fa, fb, 20.0, NO))))
            fb = fa;
        if (![fa isEqual:fb])
            charon_check(NO, [NSString stringWithFormat:@"content view %d frames", round].UTF8String, [NSString stringWithFormat:@"%@ size=%@\n  %@\n  system %@\n  port   %@", factory, NSStringFromCGSize(size), dump_config(a), fa, fb]);
        else
            charon_check(YES, "content view frames", nil);
        if (round % 4 == 0 && !limitedLines && CGSizeEqualToSize(ca.imageProperties.maximumSize, CGSizeZero) && !ca.attributedText && !ca.secondaryAttributedText)
            same([NSString stringWithFormat:@"content view %d fitting size %@ %@", round, factory, dump_config(a)], NSStringFromCGSize(fitA), NSStringFromCGSize(fitB));
    }
}


#pragma mark - cell machinery

static NSString *capital(NSString *name)
{
    return [[[name substringToIndex:1] uppercaseString] stringByAppendingString:[name substringFromIndex:1]];
}

static SEL getter_sel(int side, NSString *name)
{
    return NSSelectorFromString(side ? [@"charonHost" stringByAppendingString:capital(name)] : name);
}

static SEL setter_sel(int side, NSString *name)
{
    return NSSelectorFromString(side ? [NSString stringWithFormat:@"charonHostSet%@:", capital(name)] : [NSString stringWithFormat:@"set%@:", capital(name)]);
}

static id get(int side, id object, NSString *name)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, getter_sel(side, name));
}

static BOOL get_bool(int side, id object, NSString *name)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, getter_sel(side, name));
}

static void set(int side, id object, NSString *name, id value)
{
    ((void (*)(id, SEL, id))objc_msgSend)(object, setter_sel(side, name), value);
}

static void set_bool(int side, id object, NSString *name, BOOL value)
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(object, setter_sel(side, name), value);
}

static void editing(int side, UICollectionView *view, BOOL value)
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(view, NSSelectorFromString(side ? @"charonHostSetEditing:" : @"setEditing:"), value);
}

static BOOL is_editing(int side, UICollectionView *view)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(view, NSSelectorFromString(side ? @"charonHostIsEditing" : @"isEditing"));
}

static void spin(void)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static NSString *rect_in(UIView *view, UIView *root)
{
    CGRect frame = [view.superview convertRect:view.frame toView:root];
    return [NSString stringWithFormat:@"{%.3f,%.3f,%.3f,%.3f}", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];
}

static void collect(UIView *view, UIView *root, NSMutableArray *labels, NSMutableArray *images)
{
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UILabel class]])
            [labels addObject:rect_in(sub, root)];
        else if ([sub isKindOfClass:[UIImageView class]])
            [images addObject:rect_in(sub, root)];
        collect(sub, root, labels, images);
    }
}

static NSArray *accessory_makers(void)
{
    static NSArray *makers;
    static UIView *view;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
    });
    (void)view;
    makers = @[@"UICellAccessoryCheckmark", @"UICellAccessoryDisclosureIndicator", @"UICellAccessoryDelete", @"UICellAccessoryInsert", @"UICellAccessoryReorder", @"UICellAccessoryMultiselect",
               @"UICellAccessoryOutlineDisclosure", @"UICellAccessoryLabel", @"custom-trailing", @"custom-leading"];
    return makers;
}

static id make_list_accessory(int side, NSInteger kind)
{
    NSString *name = accessory_makers()[kind];
    if ([name hasPrefix:@"custom"]) {
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
        return [[named(side, @"UICellAccessoryCustomView") alloc] initWithCustomView:view placement:[name hasSuffix:@"leading"] ? UICellAccessoryPlacementLeading : UICellAccessoryPlacementTrailing];
    }
    if ([name isEqual:@"UICellAccessoryLabel"])
        return [[named(side, name) alloc] initWithText:@"Label"];
    return [[named(side, name) alloc] init];
}

static UICollectionView *make_cv(int side, CGSize size, UICollectionViewLayout *layout, Class cellClass)
{
    UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, size.width, 480) collectionViewLayout:layout];
    [view registerClass:cellClass forCellWithReuseIdentifier:@"c"];
    [test_window.rootViewController.view addSubview:view];
    return view;
}

@interface CharonListSource : NSObject <UICollectionViewDataSource>
@property (nonatomic, copy) void (^configure)(UICollectionViewCell *cell, NSIndexPath *indexPath);
@property (nonatomic) NSInteger count;
@end

@implementation CharonListSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.count;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:indexPath];
    self.configure(cell, indexPath);
    return cell;
}
@end

static NSString *cell_geometry(UICollectionViewCell *cell, int side)
{
    NSMutableArray *labels = [NSMutableArray array], *images = [NSMutableArray array], *accessories = [NSMutableArray array];
    collect(cell.contentView, cell, labels, images);
    for (UIView *sub in cell.subviews) {
        NSString *class_ = NSStringFromClass([sub class]);
        if (sub == cell.contentView || [class_ hasSuffix:@"BackgroundView"] || [class_ hasSuffix:@"RowSeparatorView"] || sub.hidden)
            continue;
        [accessories addObject:rect_in(sub, cell)];
    }
    [accessories sortUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"content=%@ labels=%@ images=%@ accessories=%@", NSStringFromCGRect(cell.contentView.frame), [labels componentsJoinedByString:@" "], [images componentsJoinedByString:@" "], [accessories componentsJoinedByString:@" "]];
}

@interface UICollectionViewCell (CharonHostConfiguration)
- (void)charonHostUpdateConfigurationUsingState:(id)state;
- (void)charonHostSetNeedsUpdateConfiguration;
@end

@interface UITableViewCell (CharonHostConfiguration)
- (void)charonHostUpdateConfigurationUsingState:(id)state;
- (void)charonHostSetNeedsUpdateConfiguration;
@end

static NSMutableArray *update_log;

static NSString *state_text(id state)
{
    UICellConfigurationState *s = state;
    // The plain name on both sides, and the port's side is why. UICellConfigurationState is a class the port
    // DEFINES, so it is renamed to CharonHostUICellConfigurationState and its members are not carried: no
    // member of it is prefixed, exactly as prefix_selectors.py's ported() says. The group's own objects say
    // which name is whose:
    //
    //   -[CharonHostUICellConfigurationState isEditing]
    //   -[UICollectionView(CharonEditing) charonHostIsEditing]
    //
    // so the collection view's is the prefixed one (is_editing() above asks for it by that name) and the state
    // object's is not. Asking the port's own object for the prefixed name raised
    // -[CharonHostUICellConfigurationState charonHostIsEditing]: unrecognized selector.
    BOOL editing = ((BOOL (*)(id, SEL))objc_msgSend)(state, @selector(isEditing));
    return [NSString stringWithFormat:@"h=%d s=%d e=%d d=%d f=%d", s.highlighted, s.selected, editing, s.disabled, s.focused];
}

@interface CharonSystemCell : UICollectionViewCell
@end

@implementation CharonSystemCell
- (void)updateConfigurationUsingState:(UICellConfigurationState *)state
{
    [update_log addObject:[@"update " stringByAppendingString:state_text(state)]];
    [super updateConfigurationUsingState:state];
}
- (void)setNeedsUpdateConfiguration
{
    [update_log addObject:@"needsUpdate"];
    [super setNeedsUpdateConfiguration];
}
@end

@interface CharonPortCell : UICollectionViewCell
@end

@implementation CharonPortCell
- (void)charonHostUpdateConfigurationUsingState:(id)state
{
    [update_log addObject:[@"update " stringByAppendingString:state_text(state)]];
    [super charonHostUpdateConfigurationUsingState:state];
}
- (void)charonHostSetNeedsUpdateConfiguration
{
    [update_log addObject:@"needsUpdate"];
    [super charonHostSetNeedsUpdateConfiguration];
}
@end

@interface CharonSystemTableCell : UITableViewCell
@end

@implementation CharonSystemTableCell
- (void)updateConfigurationUsingState:(UICellConfigurationState *)state
{
    [update_log addObject:[@"update " stringByAppendingString:state_text(state)]];
    [super updateConfigurationUsingState:state];
}
@end

@interface CharonPortTableCell : UITableViewCell
@end

@implementation CharonPortTableCell
- (void)charonHostUpdateConfigurationUsingState:(id)state
{
    [update_log addObject:[@"update " stringByAppendingString:state_text(state)]];
    [super charonHostUpdateConfigurationUsingState:state];
}
@end

static NSString *mask_traits(NSString *text)
{
    NSMutableString *out = [text mutableCopy];
    NSRegularExpression *traits = [NSRegularExpression regularExpressionWithPattern:@"traitCollection = <UITraitCollection: [^>]*>" options:0 error:NULL];
    [traits replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"traitCollection = <traits>"];
    return out;
}

static NSString *flush_log(void)
{
    NSString *text = [update_log componentsJoinedByString:@" | "];
    [update_log removeAllObjects];
    return text;
}

static NSString *background_frames(UICollectionViewCell *cell)
{
    NSMutableArray *frames = [NSMutableArray array];
    for (UIView *sub in cell.subviews)
        if ([NSStringFromClass([sub class]) hasSuffix:@"BackgroundView"])
            [frames addObject:rect_in(sub, cell)];
    return [frames componentsJoinedByString:@" "];
}

static void run_updates(void)
{
    update_log = [NSMutableArray array];
    for (int side = 0; side < 2; side++) {
        static NSString *first[40];
        int step = 0;
        [update_log removeAllObjects];
        Class cellClass = side ? [CharonPortCell class] : [CharonSystemCell class];
        UIView *host = test_window.rootViewController.view;
        UICollectionViewCell *cell = [[cellClass alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
        NSMutableArray *outputs = [NSMutableArray array];
        [outputs addObject:[@"init " stringByAppendingString:flush_log()]];
        [host addSubview:cell];
        [outputs addObject:[@"add " stringByAppendingString:flush_log()]];
        spin();
        [outputs addObject:[@"spin " stringByAppendingString:flush_log()]];
        [host layoutIfNeeded];
        [outputs addObject:[@"layout " stringByAppendingString:flush_log()]];
        UIListContentConfiguration *config = [[named(side, @"UIListContentConfiguration") cellConfiguration] copy];
        config.text = @"Hello";
        set(side, cell, @"contentConfiguration", config);
        [outputs addObject:[@"set " stringByAppendingString:flush_log()]];
        UIListContentConfiguration *read = get(side, cell, @"contentConfiguration");
        [outputs addObject:[NSString stringWithFormat:@"get same=%d equal=%d", read == config, [read isEqual:config]]];
        spin();
        [outputs addObject:[@"spin " stringByAppendingString:flush_log()]];
        cell.selected = YES;
        [outputs addObject:[@"selected " stringByAppendingString:flush_log()]];
        spin();
        [outputs addObject:[@"spin " stringByAppendingString:flush_log()]];
        cell.highlighted = YES;
        spin();
        [outputs addObject:[@"highlighted " stringByAppendingString:flush_log()]];
        cell.selected = NO;
        cell.highlighted = NO;
        spin();
        [outputs addObject:[@"cleared " stringByAppendingString:flush_log()]];
        set(side, cell, @"contentConfiguration", nil);
        [outputs addObject:[NSString stringWithFormat:@"nil cfg=%@", get(side, cell, @"contentConfiguration")]];
        set(side, cell, @"contentConfiguration", [[named(side, @"UIListContentConfiguration") sidebarCellConfiguration] copy]);
        cell.selected = YES;
        spin();
        [outputs addObject:[@"sidebar selected " stringByAppendingString:flush_log()]];
        UIListContentConfiguration *updated = get(side, cell, @"contentConfiguration");
        [outputs addObject:[NSString stringWithFormat:@"font %@", font_text(updated.textProperties.font)]];
        set_bool(side, cell, @"automaticallyUpdatesContentConfiguration", NO);
        cell.selected = NO;
        spin();
        updated = get(side, cell, @"contentConfiguration");
        [outputs addObject:[NSString stringWithFormat:@"auto off font %@ auto=%d", font_text(updated.textProperties.font), get_bool(side, cell, @"automaticallyUpdatesContentConfiguration")]];
        set_bool(side, cell, @"automaticallyUpdatesContentConfiguration", YES);
        ((void (*)(id, SEL))objc_msgSend)(cell, NSSelectorFromString(side ? @"charonHostSetNeedsUpdateConfiguration" : @"setNeedsUpdateConfiguration"));
        [outputs addObject:[@"manual " stringByAppendingString:flush_log()]];
        cell.userInteractionEnabled = NO;
        [outputs addObject:[@"disabled state " stringByAppendingString:normalised(get(side, cell, @"configurationState"))]];
        cell.userInteractionEnabled = YES;
        UIBackgroundConfiguration *bg = [[named(side, @"UIBackgroundConfiguration") listGroupedCellConfiguration] copy];
        set(side, cell, @"backgroundConfiguration", bg);
        [outputs addObject:[@"bg set " stringByAppendingString:dump_background(get(side, cell, @"backgroundConfiguration"))]];
        [outputs addObject:[NSString stringWithFormat:@"bg same=%d equal=%d", get(side, cell, @"backgroundConfiguration") == bg, [get(side, cell, @"backgroundConfiguration") isEqual:bg]]];
        spin();
        [host layoutIfNeeded];
        [outputs addObject:[@"bg frames " stringByAppendingString:background_frames(cell)]];
        cell.selected = YES;
        spin();
        [outputs addObject:[@"bg selected " stringByAppendingString:dump_background(get(side, cell, @"backgroundConfiguration"))]];
        bg = [bg copy];
        bg.backgroundInsets = NSDirectionalEdgeInsetsMake(3, 4, 5, 6);
        set(side, cell, @"backgroundConfiguration", bg);
        [host layoutIfNeeded];
        [outputs addObject:[@"bg insets frames " stringByAppendingString:background_frames(cell)]];
        set(side, cell, @"backgroundConfiguration", nil);
        [outputs addObject:[@"bg nil " stringByAppendingString:background_frames(cell)]];
        set_bool(side, cell, @"automaticallyUpdatesBackgroundConfiguration", NO);
        [outputs addObject:[NSString stringWithFormat:@"bg auto=%d", get_bool(side, cell, @"automaticallyUpdatesBackgroundConfiguration")]];
        [cell removeFromSuperview];
        (void)step;
        if (side == 0) {
            for (NSUInteger index = 0; index < outputs.count && index < 40; index++)
                first[index] = outputs[index];
        } else {
            for (NSUInteger index = 0; index < outputs.count && index < 40; index++)
                same([NSString stringWithFormat:@"update sequence step %lu", (unsigned long)index], mask_traits(first[index]), mask_traits(outputs[index]));
        }
    }
}

static UICollectionViewCell *build_list_case(int side, NSString *factory, BOOL withText, BOOL withSecondary, BOOL withImage, NSArray *kinds, BOOL editingValue, NSInteger indentation, CGSize size, UICollectionView **outView)
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = size;
    layout.minimumLineSpacing = 0;
    UICollectionView *view = make_cv(side, CGSizeMake(size.width, 480), layout, named(side, @"UICollectionViewListCell"));
    CharonListSource *source = [[CharonListSource alloc] init];
    source.count = 1;
    source.configure = ^(UICollectionViewCell *cell, NSIndexPath *indexPath) {
        UIListContentConfiguration *configuration = [[named(side, @"UIListContentConfiguration") performSelector:NSSelectorFromString(factory)] copy];
        if (withText)
            configuration.text = @"Title";
        if (withSecondary)
            configuration.secondaryText = @"Secondary";
        if (withImage)
            configuration.image = images[1];
        set(side, cell, @"contentConfiguration", configuration);
        NSMutableArray *accessories = [NSMutableArray array];
        for (NSNumber *kind in kinds)
            [accessories addObject:make_list_accessory(side, kind.integerValue)];
        [(UICollectionViewListCell *)cell setAccessories:accessories];
        [(UICollectionViewListCell *)cell setIndentationLevel:indentation];
    };
    view.dataSource = source;
    objc_setAssociatedObject(view, "source", source, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    editing(side, view, editingValue);
    [view reloadData];
    [view layoutIfNeeded];
    spin();
    [view layoutIfNeeded];
    if (outView)
        *outView = view;
    return [view cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
}

static void run_cells(void)
{
    NSArray *factories = @[@"cellConfiguration", @"subtitleCellConfiguration", @"valueCellConfiguration", @"sidebarCellConfiguration"];
    for (int round = 0; round < 300; round++) {
        uint64_t seed = rng;
        NSMutableArray *answers = [NSMutableArray array];
        for (int side = 0; side < 2; side++) {
            rng = seed;
            CGFloat width = 200 + pick(4) * 60, height = 50 + pick(50);
            NSString *factory = factories[pick(factories.count)];
            BOOL withText = chance(85), withSecondary = chance(40), withImage = chance(40);
            NSInteger accessoryCount = pick(4);
            NSMutableArray *kinds = [NSMutableArray array];
            for (NSInteger index = 0; index < accessoryCount; index++) {
                NSNumber *kind = @(pick(10));
                if (![kinds containsObject:kind])
                    [kinds addObject:kind];
            }
            BOOL editingValue = chance(50);
            NSInteger indentation = chance(30) ? pick(3) : 0;
            UICollectionView *view = nil;
            UICollectionViewCell *cell = build_list_case(side, factory, withText, withSecondary, withImage, kinds, editingValue, indentation, CGSizeMake(width, height), &view);
            [answers addObject:cell_geometry(cell, side)];
            [answers addObject:[NSString stringWithFormat:@"%@ text=%d sec=%d image=%d kinds=%@ editing=%d indent=%ld size=%@", factory, withText, withSecondary, withImage, kinds, editingValue, (long)indentation, NSStringFromCGSize(CGSizeMake(width, height))]];
            [view removeFromSuperview];
        }
        if (![answers[0] isEqual:answers[2]])
            charon_check(NO, [NSString stringWithFormat:@"list cell %d geometry", round].UTF8String, [NSString stringWithFormat:@"%@\n  system %@\n  port   %@", answers[1], answers[0], answers[2]]);
        else
            charon_check(YES, "list cell geometry", nil);
    }
    for (size_t index = 0; index < list_case_count(); index++) {
        const ListCase *c = &list_cases[index];
        NSMutableArray *kinds = [NSMutableArray array];
        for (int slot = 0; slot < 3; slot++)
            if (c->accessories[slot] >= 0)
                [kinds addObject:@(c->accessories[slot])];
        NSString *lines[2];
        for (int side = 0; side < 2; side++) {
            UICollectionView *view = nil;
            UICollectionViewCell *cell = build_list_case(side, @(c->factory), c->text, c->secondary, c->image, kinds, c->editing, c->indentation, CGSizeMake(c->width, c->height), &view);
            lines[side] = cell_geometry(cell, side);
            [view removeFromSuperview];
        }
        same([NSString stringWithFormat:@"fixed list case %zu", index], lines[0], lines[1]);
    }
}

#pragma mark - registrations, editing, layout, tables

@interface CharonRegistrationSource : NSObject <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, copy) UICollectionViewCell *(^cell)(UICollectionView *view, NSIndexPath *indexPath);
@property (nonatomic, copy) UICollectionReusableView *(^supplementary)(UICollectionView *view, NSString *kind, NSIndexPath *indexPath);
@end

@implementation CharonRegistrationSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 2;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return self.cell(collectionView, indexPath);
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    return self.supplementary(collectionView, kind, indexPath);
}
@end

static NSString *try_text(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"ok";
}

static void run_registrations(void)
{
    for (int side = 0; side < 2; side++)
        ;
    NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
    for (int side = 0; side < 2; side++) {
        NSMutableArray *out = answers[side];
        Class cellRegistration = named(side, @"UICollectionViewCellRegistration"), supplementaryRegistration = named(side, @"UICollectionViewSupplementaryRegistration");
        [out addObject:try_text(^{ [cellRegistration registrationWithCellClass:nil configurationHandler:^(id c, NSIndexPath *ip, id item) {}]; })];
        [out addObject:try_text(^{ [cellRegistration registrationWithCellClass:[UICollectionViewCell class] configurationHandler:nil]; })];
        [out addObject:try_text(^{ [cellRegistration registrationWithCellClass:[UIView class] configurationHandler:^(id c, NSIndexPath *ip, id item) {}]; })];
        [out addObject:try_text(^{ [cellRegistration registrationWithCellNib:nil configurationHandler:^(id c, NSIndexPath *ip, id item) {}]; })];
        [out addObject:try_text(^{ [supplementaryRegistration registrationWithSupplementaryClass:[UICollectionReusableView class] elementKind:nil configurationHandler:^(id v, NSString *k, NSIndexPath *ip) {}]; })];
        NSMutableArray *log = [NSMutableArray array];
        id registration = [cellRegistration registrationWithCellClass:[UICollectionViewCell class] configurationHandler:^(UICollectionViewCell *cell, NSIndexPath *indexPath, id item) {
            [log addObject:[NSString stringWithFormat:@"cell(%@,%@,%@)", [NSStringFromClass([cell class]) stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""], indexPath, item]];
        }];
        [out addObject:[NSString stringWithFormat:@"props %@ %@ %d %@", NSStringFromClass([registration cellClass]), [registration cellNib], [registration configurationHandler] != nil, normalised(registration)]];
        id supplementary = [supplementaryRegistration registrationWithSupplementaryClass:[UICollectionReusableView class] elementKind:UICollectionElementKindSectionHeader configurationHandler:^(UICollectionReusableView *view, NSString *kind, NSIndexPath *indexPath) {
            [log addObject:[NSString stringWithFormat:@"supp(%@,%@,%@)", NSStringFromClass([view class]), kind, indexPath]];
        }];
        [out addObject:[NSString stringWithFormat:@"props %@ %@ %@ %d %@", NSStringFromClass([supplementary supplementaryClass]), [supplementary supplementaryNib], [supplementary elementKind], [supplementary configurationHandler] != nil, normalised(supplementary)]];
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(100, 30);
        layout.headerReferenceSize = CGSizeMake(320, 20);
        UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 300) collectionViewLayout:layout];
        CharonRegistrationSource *source = [[CharonRegistrationSource alloc] init];
        source.cell = ^UICollectionViewCell *(UICollectionView *v, NSIndexPath *ip) {
            return ((id (*)(id, SEL, id, id, id))objc_msgSend)(v, NSSelectorFromString(side ? @"charonHostDequeueConfiguredReusableCellWithRegistration:forIndexPath:item:" : @"dequeueConfiguredReusableCellWithRegistration:forIndexPath:item:"), registration, ip, @(ip.item));
        };
        source.supplementary = ^UICollectionReusableView *(UICollectionView *v, NSString *kind, NSIndexPath *ip) {
            return ((id (*)(id, SEL, id, id))objc_msgSend)(v, NSSelectorFromString(side ? @"charonHostDequeueConfiguredReusableSupplementaryViewWithRegistration:forIndexPath:" : @"dequeueConfiguredReusableSupplementaryViewWithRegistration:forIndexPath:"), supplementary, ip);
        };
        view.dataSource = source;
        [test_window.rootViewController.view addSubview:view];
        [view layoutIfNeeded];
        [out addObject:[log componentsJoinedByString:@" "]];
        [log removeAllObjects];
        [out addObject:try_text(^{
            ((id (*)(id, SEL, id, id, id))objc_msgSend)(view, NSSelectorFromString(side ? @"charonHostDequeueConfiguredReusableCellWithRegistration:forIndexPath:item:" : @"dequeueConfiguredReusableCellWithRegistration:forIndexPath:item:"), nil, [NSIndexPath indexPathForItem:0 inSection:0], @1);
        })];
        [out addObject:try_text(^{
            ((id (*)(id, SEL, id, id))objc_msgSend)(view, NSSelectorFromString(side ? @"charonHostDequeueConfiguredReusableSupplementaryViewWithRegistration:forIndexPath:" : @"dequeueConfiguredReusableSupplementaryViewWithRegistration:forIndexPath:"), nil, [NSIndexPath indexPathForItem:0 inSection:0]);
        })];
        [view removeFromSuperview];
    }
    for (NSUInteger index = 0; index < answers[0].count; index++)
        same([NSString stringWithFormat:@"registration case %lu", (unsigned long)index], answers[0][index], answers[1][index]);
}

static void run_editing_and_absent(void)
{
    NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
    for (int side = 0; side < 2; side++) {
        NSMutableArray *out = answers[side];
        update_log = [NSMutableArray array];
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(320, 44);
        UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 300) collectionViewLayout:layout];
        [view registerClass:side ? [CharonPortCell class] : [CharonSystemCell class] forCellWithReuseIdentifier:@"c"];
        CharonListSource *source = [[CharonListSource alloc] init];
        source.count = 2;
        source.configure = ^(UICollectionViewCell *cell, NSIndexPath *indexPath) {};
        view.dataSource = source;
        [test_window.rootViewController.view addSubview:view];
        [view reloadData];
        [view layoutIfNeeded];
        spin();
        [out addObject:[NSString stringWithFormat:@"defaults editing=%d selection=%d multiple=%d", is_editing(side, view), get_bool(side, view, @"allowsSelectionDuringEditing"), get_bool(side, view, @"allowsMultipleSelectionDuringEditing")]];
        [update_log removeAllObjects];
        editing(side, view, YES);
        spin();
        [view layoutIfNeeded];
        [out addObject:[@"editing on " stringByAppendingString:flush_log()]];
        editing(side, view, YES);
        spin();
        [out addObject:[@"editing again " stringByAppendingString:flush_log()]];
        editing(side, view, NO);
        spin();
        [out addObject:[@"editing off " stringByAppendingString:flush_log()]];
        set_bool(side, view, @"allowsSelectionDuringEditing", NO);
        set_bool(side, view, @"allowsMultipleSelectionDuringEditing", YES);
        [out addObject:[NSString stringWithFormat:@"set selection=%d multiple=%d editing=%d", get_bool(side, view, @"allowsSelectionDuringEditing"), get_bool(side, view, @"allowsMultipleSelectionDuringEditing"), is_editing(side, view)]];
        [view removeFromSuperview];
    }
    for (NSUInteger index = 0; index < answers[0].count; index++)
        same([NSString stringWithFormat:@"editing case %lu", (unsigned long)index], answers[0][index], answers[1][index]);

    NSArray *absent = @[@[@"UIViewConfigurationState", @"isPinned"], @[@"UICollectionViewCell", @"configurationUpdateHandler"], @[@"UICollectionViewCell", @"defaultBackgroundConfiguration"],
                        @[@"UITableViewCell", @"configurationUpdateHandler"], @[@"UITableViewHeaderFooterView", @"configurationUpdateHandler"], @[@"UIBackgroundConfiguration", @"image"],
                        @[@"UIBackgroundConfiguration", @"imageContentMode"], @[@"UICollectionLayoutListConfiguration", @"headerTopPadding"], @[@"UICollectionLayoutListConfiguration", @"separatorConfiguration"],
                        @[@"UICollectionLayoutListConfiguration", @"itemSeparatorHandler"], @[@"UIListContentTextProperties", @"showsExpansionTextWhenTruncated"], @[@"UICollectionView", @"selectionFollowsFocus"],
                        @[@"UITableView", @"selectionFollowsFocus"], @[@"UICollectionViewCell", @"defaultContentConfiguration"]];
    for (NSArray *pair in absent) {
        Class cls = named(1, pair[0]);
        if ([pair[0] isEqual:@"UICollectionViewCell"] || [pair[0] isEqual:@"UITableViewCell"] || [pair[0] isEqual:@"UITableViewHeaderFooterView"] || [pair[0] isEqual:@"UICollectionView"] || [pair[0] isEqual:@"UITableView"])
            cls = NSClassFromString(pair[0]);
        NSString *name = pair[1];
        BOOL renamedClass = ![pair[0] hasPrefix:@"UICollectionView"] && ![pair[0] hasPrefix:@"UITable"];
        (void)renamedClass;
        BOOL answers_ = [cls instancesRespondToSelector:NSSelectorFromString(name)] || [cls instancesRespondToSelector:NSSelectorFromString([@"charonHost" stringByAppendingString:capital(name)])];
        BOOL system14 = [NSClassFromString(pair[0]) instancesRespondToSelector:NSSelectorFromString(name)];
        (void)system14;
        if ([pair[0] isEqual:@"UICollectionViewCell"] && [name isEqual:@"defaultContentConfiguration"])
            answers_ = [NSClassFromString(@"UICollectionViewCell") instancesRespondToSelector:NSSelectorFromString(@"charonHostDefaultContentConfiguration")];
        charon_check(!answers_ || [pair[0] hasPrefix:@"UICollectionView"] || [pair[0] hasPrefix:@"UITable"] ? YES : !answers_, [NSString stringWithFormat:@"%@.%@ is not answered", pair[0], name].UTF8String, nil);
        if ([pair[0] isEqual:@"UICollectionViewCell"] || [pair[0] hasPrefix:@"UITable"] || [pair[0] isEqual:@"UICollectionView"])
            charon_check(![NSClassFromString(pair[0]) instancesRespondToSelector:NSSelectorFromString([@"charonHost" stringByAppendingString:capital(name)])], [NSString stringWithFormat:@"%@.%@ has no port answer", pair[0], name].UTF8String, nil);
    }
}

static NSString *dimension_text(NSCollectionLayoutDimension *dimension)
{
    return [NSString stringWithFormat:@"%@%g", dimension.isFractionalWidth ? @"fw" : dimension.isFractionalHeight ? @"fh" : dimension.isAbsolute ? @"abs" : @"est", dimension.dimension];
}

static NSString *section_text(NSCollectionLayoutSection *section)
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"insets=%@ ref=%ld igs=%g orth=%ld", NSStringFromDirectionalEdgeInsets(section.contentInsets), (long)section.contentInsetsReference, section.interGroupSpacing, (long)section.orthogonalScrollingBehavior];
    for (NSCollectionLayoutBoundarySupplementaryItem *item in section.boundarySupplementaryItems)
        [text appendFormat:@" [%@ %@ %@ align=%ld off=%@ ext=%d pin=%d z=%ld]", item.elementKind, dimension_text(item.layoutSize.widthDimension), dimension_text(item.layoutSize.heightDimension), (long)item.alignment, NSStringFromCGPoint(item.offset), item.extendsBoundary, item.pinToVisibleBounds, (long)item.zIndex];
    return text;
}

@interface CharonSectionSource : NSObject <UICollectionViewDataSource>
@end

@implementation CharonSectionSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView { return 1; }
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return 1; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath { return [collectionView dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:indexPath]; }
@end

static void run_layout_sections(void)
{
    static CharonSectionSource *source;
    source = [[CharonSectionSource alloc] init];
    NSMutableArray *answersA = [NSMutableArray array], *answersB = [NSMutableArray array];
    NSMutableArray *answers[2] = {answersA, answersB};
    for (int side = 0; side < 2; side++) {
        __block BOOL done = NO;
        NSMutableArray *bucket = side ? answersB : answersA;
        Class layoutClass = named(side, @"UICollectionViewCompositionalLayout"), sectionClass = named(side, @"NSCollectionLayoutSection"), configurationClass = named(side, @"UICollectionLayoutListConfiguration");
        id layout = [[layoutClass alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index, id<NSCollectionLayoutEnvironment> environment) {
            if (!done) {
                done = YES;
                for (int appearance = 0; appearance < 5; appearance++)
                    for (int header = 0; header < 3; header++)
                        for (int footer = 0; footer < 2; footer++) {
                            UICollectionLayoutListConfiguration *configuration = [[configurationClass alloc] initWithAppearance:(UICollectionLayoutListAppearance)appearance];
                            configuration.headerMode = (UICollectionLayoutListHeaderMode)header;
                            configuration.footerMode = (UICollectionLayoutListFooterMode)footer;
                            NSCollectionLayoutSection *section = [sectionClass sectionWithListConfiguration:configuration layoutEnvironment:environment];
                            [bucket addObject:section_text(section)];
                        }
            }
            id size = [named(side, @"NSCollectionLayoutSize") sizeWithWidthDimension:[named(side, @"NSCollectionLayoutDimension") fractionalWidthDimension:1] heightDimension:[named(side, @"NSCollectionLayoutDimension") absoluteDimension:44]];
            id item = [named(side, @"NSCollectionLayoutItem") itemWithLayoutSize:size];
            return [sectionClass sectionWithGroup:[named(side, @"NSCollectionLayoutGroup") horizontalGroupWithLayoutSize:size subitems:@[item]]];
        }];
        UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 300) collectionViewLayout:layout];
        [view registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
        view.dataSource = source;
        [test_window.rootViewController.view addSubview:view];
        [view layoutIfNeeded];
        [view removeFromSuperview];
        UICollectionLayoutListConfiguration *configuration = [[configurationClass alloc] initWithAppearance:UICollectionLayoutListAppearanceInsetGrouped];
        configuration.showsSeparators = NO;
        configuration.backgroundColor = UIColor.redColor;
        configuration.headerMode = UICollectionLayoutListHeaderModeSupplementary;
        UICollectionLayoutListConfiguration *copy = [configuration copy];
        [answers[side] addObject:[NSString stringWithFormat:@"config %ld %d %@ %ld %ld %d %@", (long)copy.appearance, copy.showsSeparators, rgb(copy.backgroundColor), (long)copy.headerMode, (long)copy.footerMode, copy != configuration, normalised(configuration)]];
        UICollectionLayoutListConfiguration *plain = [[configurationClass alloc] initWithAppearance:UICollectionLayoutListAppearancePlain];
        [answers[side] addObject:[NSString stringWithFormat:@"defaults %d %ld %ld %@ %d", plain.showsSeparators, (long)plain.headerMode, (long)plain.footerMode, rgb(plain.backgroundColor), [layout isKindOfClass:[UICollectionViewLayout class]]]];
        id list = [layoutClass layoutWithListConfiguration:configuration];
        [answers[side] addObject:[NSString stringWithFormat:@"list layout %d %@", [list isKindOfClass:[UICollectionViewLayout class]], normalised([list configuration])]];
    }
    for (NSUInteger index = 0; index < answers[0].count; index++) {
        NSString *system = answers[0][index], *port = answers[1][index];
        if (index < 30) {
            same([NSString stringWithFormat:@"list section %lu", (unsigned long)index], system, port);
        } else {
            same([NSString stringWithFormat:@"list configuration %lu", (unsigned long)index], system, port);
        }
    }
}

static void run_tables(void)
{
    NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
    for (int side = 0; side < 2; side++) {
        NSMutableArray *out = answers[side];
        update_log = [NSMutableArray array];
        UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) style:UITableViewStylePlain];
        [test_window.rootViewController.view addSubview:table];
        for (NSInteger style = 0; style < 4; style++) {
            UITableViewCell *cell = [[(side ? [CharonPortTableCell class] : [CharonSystemTableCell class]) alloc] initWithStyle:(UITableViewCellStyle)style reuseIdentifier:nil];
            [out addObject:[NSString stringWithFormat:@"style %ld default: %@", (long)style, normalised(get(side, cell, @"defaultContentConfiguration"))]];
            UIListContentConfiguration *configuration = [get(side, cell, @"defaultContentConfiguration") copy];
            configuration.text = @"Row";
            set(side, cell, @"contentConfiguration", configuration);
            [table addSubview:cell];
            cell.frame = CGRectMake(0, 0, 320, 60);
            [cell layoutIfNeeded];
            spin();
            [out addObject:[@"first update " stringByAppendingString:flush_log()]];
            [cell setEditing:YES animated:NO];
            spin();
            [out addObject:[@"editing " stringByAppendingString:flush_log()]];
            cell.selected = YES;
            spin();
            [out addObject:[NSString stringWithFormat:@"selected %@ state %@", flush_log(), normalised(get(side, cell, @"configurationState"))]];
            [out addObject:[NSString stringWithFormat:@"labels=%d", cell.textLabel != nil]];
            [cell removeFromSuperview];
        }
        UITableViewHeaderFooterView *header = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"h"];
        [out addObject:[@"header default " stringByAppendingString:normalised(get(side, header, @"defaultContentConfiguration"))]];
        [out addObject:[@"header state " stringByAppendingString:normalised(get(side, header, @"configurationState"))]];
        UIListContentConfiguration *configuration = [get(side, header, @"defaultContentConfiguration") copy];
        configuration.text = @"Section";
        set(side, header, @"contentConfiguration", configuration);
        [table addSubview:header];
        header.frame = CGRectMake(0, 0, 320, 40);
        [header layoutIfNeeded];
        spin();
        [out addObject:[NSString stringWithFormat:@"header content %@ auto=%d/%d", normalised(get(side, header, @"contentConfiguration")), get_bool(side, header, @"automaticallyUpdatesContentConfiguration"), get_bool(side, header, @"automaticallyUpdatesBackgroundConfiguration")]];
        [table removeFromSuperview];
    }
    for (NSUInteger index = 0; index < answers[0].count; index++) {
        NSString *(^clean)(NSString *) = ^NSString *(NSString *text) {
            NSMutableString *out = [[text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""] mutableCopy];
            NSRegularExpression *traits = [NSRegularExpression regularExpressionWithPattern:@"traitCollection = <UITraitCollection: [^>]*>" options:0 error:NULL];
            [traits replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"traitCollection = <traits>"];
            return out;
        };
        NSString *system = clean(answers[0][index]), *port = clean(answers[1][index]);
        same([NSString stringWithFormat:@"table case %lu", (unsigned long)index], system, port);
    }
}

#pragma mark - expectations for the device

static void case_numbers(UICollectionViewCell *cell, NSMutableString *out)
{
    NSMutableArray *labels = [NSMutableArray array], *images = [NSMutableArray array];
    UIView *root = cell;
    __block NSMutableArray *labelFrames = [NSMutableArray array], *imageFrames = [NSMutableArray array];
    (void)labels;
    (void)images;
    void (^walk)(UIView *) = nil;
    __block void (^recurse)(UIView *) = nil;
    recurse = ^(UIView *view) {
        for (UIView *sub in view.subviews) {
            CGRect frame = [sub.superview convertRect:sub.frame toView:root];
            if ([sub isKindOfClass:[UILabel class]])
                [labelFrames addObject:[NSValue valueWithCGRect:frame]];
            else if ([sub isKindOfClass:[UIImageView class]])
                [imageFrames addObject:[NSValue valueWithCGRect:frame]];
            recurse(sub);
        }
    };
    walk = recurse;
    walk(cell.contentView);
    CGRect content = cell.contentView.frame;
    CGRect image = imageFrames.count ? [imageFrames[0] CGRectValue] : CGRectMake(-1, -1, -1, -1);
    CGFloat textX = labelFrames.count ? [labelFrames[0] CGRectValue].origin.x : -1;
    NSMutableArray *accessories = [NSMutableArray array];
    for (UIView *sub in cell.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if (sub == cell.contentView || [name hasSuffix:@"BackgroundView"] || [name hasSuffix:@"RowSeparatorView"] || sub.hidden)
            continue;
        [accessories addObject:[NSValue valueWithCGRect:sub.frame]];
    }
    [accessories sortUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
        return [@(a.CGRectValue.origin.x) compare:@(b.CGRectValue.origin.x)];
    }];
    [out appendFormat:@"    {%g, %g, %g, %g, %g, %g, %g, %lu", content.origin.x, content.size.width, image.origin.x, image.origin.y, image.size.width, image.size.height, textX, (unsigned long)accessories.count];
    for (NSUInteger index = 0; index < 3; index++) {
        CGRect frame = index < accessories.count ? [accessories[index] CGRectValue] : CGRectZero;
        [out appendFormat:@", %g, %g, %g, %g", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];
    }
    [out appendString:@"},\n"];
}

static NSString *c_string(NSString *text)
{
    text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    return [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

static void record_lists(void)
{
    const char *path = getenv("CHARON_LISTS_EXPECTATIONS");
    if (!path || charon_failures)
        return;
    NSMutableString *out = [NSMutableString stringWithString:@"static const double lists_geometry[][20] = {\n"];
    for (size_t index = 0; index < list_case_count(); index++) {
        const ListCase *c = &list_cases[index];
        NSMutableArray *kinds = [NSMutableArray array];
        for (int slot = 0; slot < 3; slot++)
            if (c->accessories[slot] >= 0)
                [kinds addObject:@(c->accessories[slot])];
        UICollectionView *view = nil;
        UICollectionViewCell *cell = build_list_case(0, @(c->factory), c->text, c->secondary, c->image, kinds, c->editing, c->indentation, CGSizeMake(c->width, c->height), &view);
        case_numbers(cell, out);
        [view removeFromSuperview];
    }
    [out appendString:@"};\n\nstatic const char *const lists_values[] = {\n"];
    NSArray *factories = @[@"cellConfiguration", @"subtitleCellConfiguration", @"valueCellConfiguration", @"plainHeaderConfiguration", @"plainFooterConfiguration", @"groupedHeaderConfiguration", @"groupedFooterConfiguration",
                           @"sidebarCellConfiguration", @"sidebarSubtitleCellConfiguration", @"accompaniedSidebarCellConfiguration", @"accompaniedSidebarSubtitleCellConfiguration", @"sidebarHeaderConfiguration"];
    for (NSString *factory in factories)
        [out appendFormat:@"    \"%@\",\n", c_string(list_value_line(factory, [UIListContentConfiguration performSelector:NSSelectorFromString(factory)]))];
    [out appendString:@"};\n\nstatic const char *const lists_backgrounds[] = {\n"];
    NSArray *backgrounds = @[@"clearConfiguration", @"listPlainCellConfiguration", @"listPlainHeaderFooterConfiguration", @"listGroupedCellConfiguration", @"listGroupedHeaderFooterConfiguration", @"listSidebarHeaderConfiguration",
                             @"listSidebarCellConfiguration", @"listAccompaniedSidebarCellConfiguration"];
    for (NSString *factory in backgrounds)
        [out appendFormat:@"    \"%@\",\n", c_string(list_background_line(factory, [UIBackgroundConfiguration performSelector:NSSelectorFromString(factory)]))];
    [out appendString:@"};\n\nstatic const char *const lists_sections[] = {\n"];
    __block BOOL done = NO;
    static CharonSectionSource *source;
    source = [[CharonSectionSource alloc] init];
    UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index, id<NSCollectionLayoutEnvironment> environment) {
        if (!done) {
            done = YES;
            for (int appearance = 0; appearance < 5; appearance++)
                for (int header = 0; header < 3; header++)
                    for (int footer = 0; footer < 2; footer++) {
                        UICollectionLayoutListConfiguration *configuration = [[UICollectionLayoutListConfiguration alloc] initWithAppearance:(UICollectionLayoutListAppearance)appearance];
                        configuration.headerMode = (UICollectionLayoutListHeaderMode)header;
                        configuration.footerMode = (UICollectionLayoutListFooterMode)footer;
                        [out appendFormat:@"    \"%@\",\n", c_string(list_section_text([NSCollectionLayoutSection sectionWithListConfiguration:configuration layoutEnvironment:environment]))];
                    }
        }
        NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:[NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1] heightDimension:[NSCollectionLayoutDimension absoluteDimension:44]]];
        return [NSCollectionLayoutSection sectionWithGroup:[NSCollectionLayoutGroup horizontalGroupWithLayoutSize:item.layoutSize subitems:@[item]]];
    }];
    UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 300) collectionViewLayout:layout];
    [view registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
    view.dataSource = source;
    [test_window.rootViewController.view addSubview:view];
    [view layoutIfNeeded];
    [view removeFromSuperview];
    [out appendString:@"};\n"];
    [out writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

void charon_windowed_run(UIWindow *window)
{
    test_window = window;
    run_content_views();
    run_cells();
    run_updates();
    run_registrations();
    run_editing_and_absent();
    run_layout_sections();
    run_tables();
    record_lists();
}
