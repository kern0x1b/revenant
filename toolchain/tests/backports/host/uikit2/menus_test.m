#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"

@interface CharonHostUIContextMenuInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(id)delegate;
- (id)delegate;
- (CGPoint)locationInView:(UIView *)view;
- (void)dismissMenu;
- (NSInteger)menuAppearance;
- (void)updateVisibleMenuWithBlock:(id (^)(id menu))block;
- (void)charon_beginAtLocation:(CGPoint)location;
@end

@interface CharonHostUIContextMenuConfiguration : NSObject
+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier previewProvider:(id)previewProvider actionProvider:(id)actionProvider;
- (id<NSCopying>)identifier;
@end

@interface CharonHostUIMenuSystem : NSObject
+ (instancetype)mainSystem;
+ (instancetype)contextSystem;
- (void)setNeedsRebuild;
- (void)setNeedsRevalidate;
@end

@interface CharonHostUIPreviewParameters : NSObject <NSCopying>
- (instancetype)initWithTextLineRects:(NSArray *)rects;
- (UIBezierPath *)shadowPath;
- (void)setShadowPath:(UIBezierPath *)path;
@end

@interface CharonHostUIPreviewTarget : NSObject <NSCopying>
- (instancetype)initWithContainer:(UIView *)container center:(CGPoint)center transform:(CGAffineTransform)transform;
- (instancetype)initWithContainer:(UIView *)container center:(CGPoint)center;
- (UIView *)container;
- (CGPoint)center;
- (CGAffineTransform)transform;
@end

@interface CharonHostUITargetedPreview : NSObject <NSCopying>
- (instancetype)initWithView:(UIView *)view parameters:(id)parameters target:(id)target;
- (instancetype)initWithView:(UIView *)view parameters:(id)parameters;
- (instancetype)initWithView:(UIView *)view;
- (id)target;
- (UIView *)view;
- (id)parameters;
- (CGSize)size;
- (id)retargetedPreviewWithTarget:(id)target;
@end

#define NAMES(X) X(Application) X(File) X(Edit) X(View) X(Window) X(Help) X(About) X(Preferences) X(Services) X(Hide) X(Quit) X(NewScene) \
    X(OpenRecent) X(Close) X(Print) X(UndoRedo) X(StandardEdit) X(Find) X(Replace) X(Share) X(TextStyle) X(Spelling) X(SpellingPanel) \
    X(SpellingOptions) X(Substitutions) X(SubstitutionsPanel) X(SubstitutionOptions) X(Transformations) X(Speech) X(Lookup) X(Learn) X(Format) \
    X(Font) X(TextSize) X(TextColor) X(TextStylePasteboard) X(Text) X(WritingDirection) X(Alignment) X(Toolbar) X(Fullscreen) X(MinimizeAndZoom) \
    X(BringAllToFront) X(Root) X(Open)

#define DECLARE(name) extern NSString *const CharonHostUIMenu##name;
NAMES(DECLARE)

void charon_windowed_run(UIWindow *window);

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    text = [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
    NSRegularExpression *uuid = [NSRegularExpression regularExpressionWithPattern:@"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" options:0 error:nil];
    text = [uuid stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"UUID"];
    return [text stringByReplacingOccurrencesOfString:@"; currentSelection = <NSArray: PTR>" withString:@""];
}

static NSString *raised(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@ %@", exception.name, norm(exception.reason)];
    }
}

static NSString *raised_name(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@", exception.name];
    }
}

static void agree(NSString *name, NSArray *ours, NSArray *system)
{
    NSMutableString *detail = [NSMutableString string];
    for (NSUInteger index = 0; index < MAX(ours.count, system.count); index++) {
        NSString *a = index < ours.count ? ours[index] : @"<none>", *b = index < system.count ? system[index] : @"<none>";
        if (![a isEqual:b])
            [detail appendFormat:@"\n    port   %@\n    system %@", a, b];
    }
    charon_check(detail.length == 0, name.UTF8String, detail);
}

static NSArray *action_lines(Class cls)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIImage *image = [[UIImage alloc] init];
    UIAction *plain = [cls actionWithTitle:@"T" image:nil identifier:nil handler:^(UIAction *action) {}];
    [lines addObject:norm(plain)];
    [lines addObject:[NSString stringWithFormat:@"defaults %lu %ld %@ %@ %@", (unsigned long)plain.attributes, (long)plain.state, plain.discoverabilityTitle, plain.image, plain.sender]];
    [lines addObject:[NSString stringWithFormat:@"generated %d", [plain.identifier hasPrefix:@"com.apple.action.dynamic."]]];
    UIAction *bare = [cls actionWithHandler:^(UIAction *action) {}];
    [lines addObject:[NSString stringWithFormat:@"handler-only [%@] %@ %d", bare.title, norm(bare), [bare.identifier hasPrefix:@"com.apple.action.dynamic."]]];
    UIAction *set = [cls actionWithTitle:@"S" image:image identifier:@"com.x" handler:^(UIAction *action) {}];
    [lines addObject:[NSString stringWithFormat:@"kept %@ %d", set.identifier, set.image == image]];
    set.discoverabilityTitle = @"D";
    [lines addObject:[NSString stringWithFormat:@"discoverability %@ %@", set.discoverabilityTitle, norm(set)]];
    for (NSNumber *attributes in @[@1, @3, @2, @4, @6, @7, @8, @15]) {
        set.attributes = (UIMenuElementAttributes)attributes.unsignedIntegerValue;
        set.state = UIMenuElementStateMixed;
        [lines addObject:[NSString stringWithFormat:@"attributes %@ %@ %ld", attributes, norm(set), (long)set.state]];
    }
    UIAction *first = [cls actionWithTitle:@"A" image:nil identifier:@"same" handler:^(UIAction *action) {}];
    UIAction *second = [cls actionWithTitle:@"B" image:image identifier:@"same" handler:nil];
    second.state = UIMenuElementStateOn;
    second.attributes = UIMenuElementAttributesDisabled;
    UIAction *third = [cls actionWithTitle:@"A" image:nil identifier:@"other" handler:^(UIAction *action) {}];
    [lines addObject:[NSString stringWithFormat:@"equality %d %d %d %d %d %d %d", [first isEqual:second], first.hash == second.hash, [first isEqual:third],
                                                [first isEqual:first], [first isEqual:nil], [first isEqual:@"same"], first.hash == [@"same" hash]]];
    UIAction *copy = [second copy];
    [lines addObject:[NSString stringWithFormat:@"copy %d %d %d %d %ld %lu %d %@", copy != second, [copy isEqual:second], copy.image == image, [copy.title isEqual:second.title],
                                                (long)copy.state, (unsigned long)copy.attributes, [copy.identifier isEqual:second.identifier], copy.sender]];
    copy.title = @"changed";
    [lines addObject:[NSString stringWithFormat:@"copy independent %@ %@", second.title, copy.title]];
    NSMutableString *pending = [NSMutableString stringWithString:@"abc"];
    UIAction *titled = [cls actionWithTitle:pending image:nil identifier:nil handler:nil];
    [pending appendString:@"d"];
    [lines addObject:[NSString stringWithFormat:@"title copied %@", titled.title]];
    titled.title = nil;
    [lines addObject:[NSString stringWithFormat:@"title nil [%@] %@", titled.title, norm(titled)]];
    [lines addObject:[NSString stringWithFormat:@"empty identifier [%@]", ((UIAction *)[cls actionWithTitle:@"a" image:nil identifier:@"" handler:nil]).identifier]];
    [lines addObject:[NSString stringWithFormat:@"nil title [%@]", ((UIAction *)[cls actionWithTitle:nil image:nil identifier:nil handler:nil]).title]];
    [lines addObject:[NSString stringWithFormat:@"class %d %d %d", [cls conformsToProtocol:@protocol(NSCopying)], [cls conformsToProtocol:@protocol(NSSecureCoding)],
                                                [cls supportsSecureCoding]]];
    return lines;
}

static NSArray *menu_lines(Class cls, Class actionClass)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIImage *image = [[UIImage alloc] init];
    UIAction *one = [actionClass actionWithTitle:@"One" image:nil identifier:@"one" handler:^(UIAction *action) {}];
    UIAction *two = [actionClass actionWithTitle:@"Two" image:nil identifier:@"two" handler:^(UIAction *action) {}];
    UIMenu *titled = [cls menuWithTitle:@"M" children:@[one, two]];
    [lines addObject:norm(titled)];
    [lines addObject:[NSString stringWithFormat:@"defaults %lu %d %lu %@", (unsigned long)titled.options, [titled.identifier hasPrefix:@"com.apple.menu.dynamic."],
                                                (unsigned long)titled.children.count, titled.image]];
    UIMenu *bare = [cls menuWithChildren:@[one]];
    [lines addObject:[NSString stringWithFormat:@"children-only [%@] %@", bare.title, norm(bare)]];
    for (NSNumber *options in @[@0, @1, @2, @3, @32, @35]) {
        UIMenu *full = [cls menuWithTitle:@"X" image:image identifier:@"com.m" options:options.unsignedIntegerValue children:@[titled, one]];
        [lines addObject:[NSString stringWithFormat:@"full %@ %@ %d %d %lu", options, norm(full), full.image == image, [full.children[0] isEqual:titled],
                                                    (unsigned long)full.options]];
    }
    UIMenu *full = [cls menuWithTitle:@"X" image:image identifier:@"com.m" options:3 children:@[titled, one]];
    UIMenu *same = [cls menuWithTitle:@"Y" image:nil identifier:@"com.m" options:0 children:@[]];
    UIMenu *other = [cls menuWithTitle:@"X" image:image identifier:@"com.n" options:3 children:@[titled, one]];
    [lines addObject:[NSString stringWithFormat:@"equality %d %d %d %d %d %d", [full isEqual:same], full.hash == same.hash, [full isEqual:other], [full isEqual:nil],
                                                [full isEqual:@"com.m"], full.hash == [@"com.m" hash]]];
    [lines addObject:[NSString stringWithFormat:@"action with the same identifier %d", [full isEqual:[actionClass actionWithTitle:@"X" image:nil identifier:@"com.m" handler:nil]]]];
    UIMenu *copy = [full copy];
    [lines addObject:[NSString stringWithFormat:@"copy %d %d %d %d %d %d", copy != full, [copy isEqual:full], copy.children[0] != titled, [copy.children[0] isEqual:titled],
                                                copy.children[1] != one, copy.image == image]];
    UIMenu *replaced = [full menuByReplacingChildren:@[one]];
    [lines addObject:[NSString stringWithFormat:@"replaced %@ %d %d", norm(replaced), replaced.children[0] == one, replaced != full]];
    [lines addObject:[NSString stringWithFormat:@"replaced with nil %lu", (unsigned long)[full menuByReplacingChildren:nil].children.count]];
    NSMutableArray *pending = [NSMutableArray arrayWithObject:one];
    UIMenu *held = [cls menuWithTitle:@"a" children:pending];
    [pending removeAllObjects];
    [lines addObject:[NSString stringWithFormat:@"children copied %lu", (unsigned long)held.children.count]];
    [lines addObject:[NSString stringWithFormat:@"nil children %lu %@", (unsigned long)[cls menuWithTitle:@"a" children:nil].children.count, norm([cls menuWithTitle:@"a" children:nil])]];
    [lines addObject:[NSString stringWithFormat:@"nil title [%@] %@", [cls menuWithTitle:nil children:@[]].title, norm([cls menuWithTitle:nil children:@[]])]];
    [lines addObject:raised_name(^{ return [cls menuWithTitle:@"a" children:@[@"x"]]; })];
    [lines addObject:raised_name(^{ return [full menuByReplacingChildren:@[@"x"]]; })];
    [lines addObject:[NSString stringWithFormat:@"class %d %d", [cls conformsToProtocol:@protocol(NSCopying)], [cls supportsSecureCoding]]];
    return lines;
}

static NSArray *deferred_lines(Class cls, Class menuClass)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIDeferredMenuElement *first = [cls elementWithProvider:^(void (^completion)(NSArray *elements)) {}];
    UIDeferredMenuElement *second = [cls elementWithProvider:^(void (^completion)(NSArray *elements)) {}];
    [lines addObject:[NSString stringWithFormat:@"%@ [%@] %@", norm(first), first.title, first.image]];
    [lines addObject:[NSString stringWithFormat:@"equality %d %d %d %d", [first isEqual:first], [first isEqual:second], first.hash == second.hash, [first isEqual:[first copy]]]];
    [lines addObject:[NSString stringWithFormat:@"copy %d", [first copy] == first]];
    [lines addObject:[NSString stringWithFormat:@"nil provider %@", norm([cls elementWithProvider:nil])]];
    [lines addObject:[NSString stringWithFormat:@"class %d", [cls supportsSecureCoding]]];
    return lines;
}

static NSData *archived(id object)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    if (!data)
        fprintf(stderr, "archive of %s failed: %s\n", object_getClassName(object), error.description.UTF8String);
    return data;
}

static id unarchived(NSData *data, Class root, NSDictionary<NSString *, Class> *names)
{
    NSError *error = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    unarchiver.requiresSecureCoding = YES;
    for (NSString *name in names)
        [unarchiver setClass:names[name] forClassName:name];
    id object = [unarchiver decodeObjectOfClass:root forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    return object ?: (id)[NSString stringWithFormat:@"failed %@", error.localizedDescription];
}

static NSArray *archive_lines(Class actionClass, Class menuClass, Class deferredClass, Class elementClass, NSDictionary *names, Class decodedAction, Class decodedDeferred)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIAction *action = [actionClass actionWithTitle:@"T" image:nil identifier:@"com.x" handler:^(UIAction *item) {}];
    action.discoverabilityTitle = @"D";
    action.attributes = UIMenuElementAttributesDestructive | UIMenuElementAttributesDisabled;
    action.state = UIMenuElementStateOn;
    UIAction *plain = [actionClass actionWithTitle:@"P" image:nil identifier:@"com.p" handler:nil];
    UIMenu *inner = [menuClass menuWithTitle:@"Inner" image:nil identifier:@"com.inner" options:UIMenuOptionsDisplayInline children:@[plain]];
    UIMenu *menu = [menuClass menuWithTitle:@"Outer" image:nil identifier:@"com.outer" options:UIMenuOptionsDestructive children:@[action, inner]];
    id first = unarchived(archived(action), elementClass, names);
    if ([first isKindOfClass:[NSString class]])
        return @[first];
    UIAction *back = first;
    [lines addObject:[NSString stringWithFormat:@"action %@ %@ %@ %lu %ld %@", norm(back), back.identifier, back.discoverabilityTitle, (unsigned long)back.attributes,
                                                (long)back.state, back.sender]];
    id second = unarchived(archived(menu), elementClass, names);
    if ([second isKindOfClass:[NSString class]])
        return @[second];
    UIMenu *round = second;
    UIMenu *child = (UIMenu *)round.children.lastObject;
    [lines addObject:[NSString stringWithFormat:@"menu %@ %lu %d %@ %lu %d", norm(round), (unsigned long)round.options, [round.identifier isEqual:menu.identifier], norm(round.children.firstObject),
                                                (unsigned long)round.children.count, [child.children.firstObject isKindOfClass:decodedAction]]];
    [lines addObject:[NSString stringWithFormat:@"inner %@ %lu", norm(child), (unsigned long)child.options]];
    UIDeferredMenuElement *deferred = [deferredClass elementWithProvider:^(void (^completion)(NSArray *elements)) {}];
    id third = unarchived(archived(deferred), elementClass, names);
    if ([third isKindOfClass:[NSString class]])
        return @[third];
    UIDeferredMenuElement *decoded = third;
    [lines addObject:[NSString stringWithFormat:@"deferred %@ [%@] %d", norm(decoded), decoded.title, [decoded isKindOfClass:decodedDeferred]]];
    NSError *error = nil;
    NSData *insecure = [NSKeyedArchiver archivedDataWithRootObject:action requiringSecureCoding:NO error:&error];
    [lines addObject:[NSString stringWithFormat:@"insecure archive %d", insecure.length > 0]];
    return lines;
}

@interface Recipient : NSObject <UIContextMenuInteractionDelegate>
@property (nonatomic) NSMutableArray *log;
@property (nonatomic) id configuration;
@end

@implementation Recipient

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    [self.log addObject:[NSString stringWithFormat:@"asked at %g %g", (double)location.x, (double)location.y]];
    return self.configuration;
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.log addObject:@"will display"];
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.log addObject:@"will end"];
}

@end

static NSArray *interaction_lines(Class cls, Class configurationClass, Class actionClass, Class menuClass, UIView *view)
{
    NSMutableArray *lines = [NSMutableArray array];
    Recipient *recipient = [[Recipient alloc] init];
    recipient.log = [NSMutableArray array];
    id interaction = [[cls alloc] initWithDelegate:recipient];
    [lines addObject:[NSString stringWithFormat:@"fresh %d %@ %g %g", [interaction delegate] == recipient, [interaction view],
                                                (double)[interaction locationInView:nil].x, (double)[interaction locationInView:view].y]];
    [interaction dismissMenu];
    __block int called = 0;
    [interaction updateVisibleMenuWithBlock:^UIMenu *(UIMenu *menu) {
        called++;
        return menu;
    }];
    [lines addObject:[NSString stringWithFormat:@"update called %d", called]];
    [lines addObject:[NSString stringWithFormat:@"nil delegate %d", [[[cls alloc] initWithDelegate:nil] delegate] == nil]];
    [lines addObject:[NSString stringWithFormat:@"delegate weak %d", ^{
        id transient = [[Recipient alloc] init];
        id held = [[cls alloc] initWithDelegate:transient];
        transient = nil;
        return [held delegate] == nil;
    }()]];
    return lines;
}

static NSArray *configuration_lines(Class cls)
{
    NSMutableArray *lines = [NSMutableArray array];
    id generated = [cls configurationWithIdentifier:nil previewProvider:nil actionProvider:nil];
    [lines addObject:[NSString stringWithFormat:@"generated %@ %@", norm(generated), NSStringFromClass([[generated identifier] class])]];
    id named = [cls configurationWithIdentifier:@"x" previewProvider:nil actionProvider:nil];
    id other = [cls configurationWithIdentifier:@"x" previewProvider:nil actionProvider:nil];
    [lines addObject:[NSString stringWithFormat:@"named %@ %d %d %d", [named identifier], [named isEqual:named], [named isEqual:other], [named conformsToProtocol:@protocol(NSCopying)]]];
    NSMutableString *pending = [NSMutableString stringWithString:@"m"];
    id copied = [cls configurationWithIdentifier:(id)pending previewProvider:nil actionProvider:nil];
    [pending appendString:@"x"];
    [lines addObject:[NSString stringWithFormat:@"identifier copied %@", [copied identifier]]];
    [lines addObject:[NSString stringWithFormat:@"init %@", NSStringFromClass([[[[cls alloc] init] identifier] class])]];
    return lines;
}


static void gather(void *info, const CGPathElement *element)
{
    static const int counts[] = {1, 1, 2, 3, 0};
    NSMutableString *text = (__bridge NSMutableString *)info;
    [text appendFormat:@"%d", element->type];
    for (int index = 0; index < counts[element->type]; index++)
        [text appendFormat:@" %.4f,%.4f", (double)element->points[index].x, (double)element->points[index].y];
    [text appendString:@"\n"];
}

static NSString *elements(UIBezierPath *path)
{
    if (!path)
        return @"nil";
    NSMutableString *text = [NSMutableString string];
    CGPathApply(path.CGPath, (__bridge void *)text, gather);
    return text;
}

static NSString *rect_text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.3f %.3f %.3f %.3f", (double)rect.origin.x, (double)rect.origin.y, (double)rect.size.width, (double)rect.size.height];
}

static NSValue *line(CGFloat x, CGFloat y, CGFloat width, CGFloat height)
{
    return [NSValue valueWithCGRect:CGRectMake(x, y, width, height)];
}

static NSArray *parameters_lines(Class cls)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIPreviewParameters *plain = [[cls alloc] init];
    UIPreviewParameters *other = [[cls alloc] init];
    [lines addObject:norm(plain)];
    [lines addObject:[NSString stringWithFormat:@"defaults %@ %@ %d", plain.visiblePath, plain.shadowPath, [plain.backgroundColor isEqual:other.backgroundColor]]];
    plain.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.6 alpha:0.8];
    [lines addObject:norm(plain)];
    plain.backgroundColor = nil;
    [lines addObject:[NSString stringWithFormat:@"reset %@", norm(plain)]];
    plain.backgroundColor = [UIColor clearColor];
    [lines addObject:[NSString stringWithFormat:@"clear %@", norm(plain)]];
    plain.visiblePath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 5, 5)];
    plain.shadowPath = [UIBezierPath bezierPathWithRect:CGRectMake(1, 1, 5, 5)];
    [lines addObject:norm(plain)];
    UIPreviewParameters *copy = [plain copy];
    [lines addObject:[NSString stringWithFormat:@"copy %d %@ %d %d %@ %@", copy != plain, copy.backgroundColor, copy.visiblePath != plain.visiblePath, copy.shadowPath != plain.shadowPath,
                                                elements(copy.visiblePath), elements(copy.shadowPath)]];
    [lines addObject:[NSString stringWithFormat:@"other %d %d", [plain isEqual:other], [plain isEqual:nil]]];
    [lines addObject:[NSString stringWithFormat:@"protocols %d %d", [cls conformsToProtocol:@protocol(NSCopying)], [cls conformsToProtocol:@protocol(NSSecureCoding)]]];
    for (NSArray *rects in @[@[line(0, 0, 10, 10)], @[line(0, 0, 100, 40)], @[line(1, 2, 30.5, 10)], @[line(1.4, 2.6, 30.5, 9.5)], @[line(-0.5, -0.5, 0.2, 0.2)], @[line(0, 0, 100, 10), line(200, 0, 50, 10)], @[line(0, 0, 100, 10), line(300, 40, 20, 10)]]) {
        UIPreviewParameters *text = [[cls alloc] initWithTextLineRects:rects];
        [lines addObject:[NSString stringWithFormat:@"text %@ %@ %@ %@", rect_text(text.visiblePath.bounds), elements(text.visiblePath), text.shadowPath, rect_text(text.visiblePath.bounds)]];
    }
    [lines addObject:[NSString stringWithFormat:@"stacked bounds %@", rect_text(((UIPreviewParameters *)[[cls alloc] initWithTextLineRects:@[line(0, 0, 100, 10), line(0, 30, 50, 10)]]).visiblePath.bounds)]];
    [lines addObject:[NSString stringWithFormat:@"empty %@", ((UIPreviewParameters *)[[cls alloc] initWithTextLineRects:@[]]).visiblePath]];
    return lines;
}

static NSArray *target_lines(Class cls, UIView *container, UIView *loose, UIWindow *window)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIPreviewTarget *plain = [[cls alloc] initWithContainer:container center:CGPointMake(5, 6)];
    [lines addObject:[NSString stringWithFormat:@"%@ %d %@ %@", norm(plain), plain.container == container, NSStringFromCGPoint(plain.center), NSStringFromCGAffineTransform(plain.transform)]];
    UIPreviewTarget *turned = [[cls alloc] initWithContainer:container center:CGPointMake(1.5, 2.25) transform:CGAffineTransformMake(1, 2, 3, 4, 5.5, 6)];
    [lines addObject:norm(turned)];
    [lines addObject:norm([[cls alloc] initWithContainer:container center:CGPointMake(100000.5, -0.125)])];
    UIPreviewTarget *again = [[cls alloc] initWithContainer:container center:CGPointMake(5, 6)];
    [lines addObject:[NSString stringWithFormat:@"equality %d %d %d %d %d", [plain isEqual:again], [plain isEqual:turned], [plain isEqual:plain], [plain isEqual:nil], [plain isEqual:@"x"]]];
    [lines addObject:[NSString stringWithFormat:@"copy %d", [plain copy] == plain]];
    [lines addObject:norm([[cls alloc] initWithContainer:window center:CGPointMake(2, 3)])];
    [lines addObject:raised(^{ return [[cls alloc] initWithContainer:nil center:CGPointZero]; })];
    [lines addObject:raised(^{ return [[cls alloc] initWithContainer:loose center:CGPointZero]; })];
    [lines addObject:[NSString stringWithFormat:@"protocols %d", [cls conformsToProtocol:@protocol(NSCopying)]]];
    return lines;
}

static NSArray *preview_lines(Class cls, Class parametersClass, Class targetClass, UIView *container, UIView *loose, UIWindow *window)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 30)];
    [container addSubview:view];
    view.center = CGPointMake(70, 80);
    view.transform = CGAffineTransformMakeScale(2, 2);
    UITargetedPreview *automatic = [[cls alloc] initWithView:view];
    [lines addObject:[NSString stringWithFormat:@"automatic %@ %@ %d %d", norm(automatic), NSStringFromCGSize(automatic.size), automatic.view == view, automatic.target.container == container]];
    [lines addObject:[NSString stringWithFormat:@"automatic target %@ %@ %@", NSStringFromCGPoint(automatic.target.center), NSStringFromCGAffineTransform(automatic.target.transform), norm(automatic.parameters)]];
    UIPreviewParameters *parameters = [[parametersClass alloc] init];
    parameters.backgroundColor = [UIColor redColor];
    UITargetedPreview *given = [[cls alloc] initWithView:view parameters:parameters];
    [lines addObject:[NSString stringWithFormat:@"given %d %d %@", given.parameters == parameters, given.target.container == container, norm(given.parameters)]];
    UIPreviewTarget *target = [[targetClass alloc] initWithContainer:container center:CGPointMake(1, 2)];
    UITargetedPreview *explicit = [[cls alloc] initWithView:view parameters:parameters target:target];
    [lines addObject:[NSString stringWithFormat:@"explicit %d %d %d %@ %@", explicit.parameters == parameters, explicit.target == target, explicit.view == view, NSStringFromCGSize(explicit.size), norm(explicit)]];
    UIPreviewTarget *moved = [[targetClass alloc] initWithContainer:container center:CGPointMake(9, 9)];
    UITargetedPreview *retargeted = [explicit retargetedPreviewWithTarget:moved];
    [lines addObject:[NSString stringWithFormat:@"retargeted %d %d %d %d", retargeted.view == view, retargeted.parameters == parameters, retargeted.target == moved, retargeted != explicit]];
    [lines addObject:[NSString stringWithFormat:@"copy %d", [explicit copy] == explicit]];
    [lines addObject:[NSString stringWithFormat:@"other %d %d", [explicit isEqual:retargeted], [explicit isEqual:nil]]];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:loose]; })];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:loose parameters:parameters]; })];
    [lines addObject:norm([[cls alloc] initWithView:loose parameters:parameters target:target])];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:nil]; })];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:nil parameters:parameters target:target]; })];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:view parameters:nil target:target]; })];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:view parameters:nil]; })];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:view parameters:parameters target:nil]; })];
    [lines addObject:raised(^{ return [explicit retargetedPreviewWithTarget:nil]; })];
    [lines addObject:raised(^{ return [[cls alloc] initWithView:window]; })];
    [lines addObject:[NSString stringWithFormat:@"protocols %d", [cls conformsToProtocol:@protocol(NSCopying)]]];
    return lines;
}

static void preview_checks(UIWindow *window)
{
    Class ourParameters = NSClassFromString(@"CharonHostUIPreviewParameters"), ourTarget = NSClassFromString(@"CharonHostUIPreviewTarget"), ourPreview = NSClassFromString(@"CharonHostUITargetedPreview");
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    [window addSubview:container];
    UIView *loose = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    agree(@"preview parameters", parameters_lines(ourParameters), parameters_lines([UIPreviewParameters class]));
    agree(@"preview target", target_lines(ourTarget, container, loose, window), target_lines([UIPreviewTarget class], container, loose, window));
    agree(@"targeted preview", preview_lines(ourPreview, ourParameters, ourTarget, container, loose, window), preview_lines([UITargetedPreview class], [UIPreviewParameters class], [UIPreviewTarget class], container, loose, window));
    charon_check([[ourParameters new] isEqual:[ourParameters new]] == NO, "two preview parameters are two objects", @"they are equal");
    UIView *anchor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    [window addSubview:anchor];
    UIPreviewTarget *first = [[ourTarget alloc] initWithContainer:anchor center:CGPointMake(3, 4)];
    UIPreviewTarget *second = [[ourTarget alloc] initWithContainer:anchor center:CGPointMake(3, 4)];
    charon_check([first isEqual:second] && first.hash == second.hash, "equal preview targets hash alike, which the system's do not", @"the hashes differ");
    UIPreviewParameters *held = [[ourParameters alloc] init];
    charon_check([held isEqual:held], "preview parameters equal themselves, which the system's answer to itself does not", @"they are not");
}

void charon_windowed_run(UIWindow *window)
{
    {
        Class ourElement = NSClassFromString(@"CharonHostUIMenuElement"), ourAction = NSClassFromString(@"CharonHostUIAction"), ourMenu = NSClassFromString(@"CharonHostUIMenu"),
              ourDeferred = NSClassFromString(@"CharonHostUIDeferredMenuElement");
        charon_check(ourAction && ourMenu && ourDeferred && ourElement, "the port's classes are linked under their host names", @"one is missing");
        charon_check(class_getSuperclass(ourAction) == ourElement && class_getSuperclass(ourMenu) == ourElement && class_getSuperclass(ourDeferred) == ourElement
                         && class_getSuperclass(ourElement) == [NSObject class],
                     "the classes descend as the system's do", @"a superclass differs");

        agree(@"action values", action_lines(ourAction), action_lines([UIAction class]));
        agree(@"menu values", menu_lines(ourMenu, ourAction), menu_lines([UIMenu class], [UIAction class]));
        agree(@"deferred element values", deferred_lines(ourDeferred, ourMenu), deferred_lines([UIDeferredMenuElement class], [UIMenu class]));

        NSDictionary *toPort = @{@"UIAction": ourAction, @"UIMenu": ourMenu, @"UIDeferredMenuElement": ourDeferred, @"UIMenuElement": ourElement};
        NSDictionary *toSystem = @{@"CharonHostUIAction": [UIAction class], @"CharonHostUIMenu": [UIMenu class], @"CharonHostUIDeferredMenuElement": [UIDeferredMenuElement class],
                                   @"CharonHostUIMenuElement": [UIMenuElement class]};
        agree(@"archive round trip of the port", archive_lines(ourAction, ourMenu, ourDeferred, [UIMenuElement class], toSystem, [UIAction class], [UIDeferredMenuElement class]), archive_lines([UIAction class], [UIMenu class], [UIDeferredMenuElement class], [UIMenuElement class], @{}, [UIAction class], [UIDeferredMenuElement class]));
        NSArray *system = archive_lines([UIAction class], [UIMenu class], [UIDeferredMenuElement class], [UIMenuElement class], @{}, [UIAction class], [UIDeferredMenuElement class]);
        NSArray *carried = archive_lines(ourAction, ourMenu, ourDeferred, ourElement, @{}, ourAction, ourDeferred);
        agree(@"a port archive read back by the port", carried, system);
        agree(@"a system archive read by the port", archive_lines([UIAction class], [UIMenu class], [UIDeferredMenuElement class], ourElement, toPort, ourAction, ourDeferred), system);

        BOOL constants = YES;
        NSMutableString *wrong = [NSMutableString string];
#define COMPARE(name) if (![CharonHostUIMenu##name isEqualToString:UIMenu##name]) { constants = NO; [wrong appendFormat:@" %s", #name]; }
        NAMES(COMPARE)
        charon_check(constants, "the 45 menu identifiers have the system's strings", wrong);

        Class ourSystem = NSClassFromString(@"CharonHostUIMenuSystem");
        id main = [ourSystem mainSystem], context = [ourSystem contextSystem];
        charon_check(main == [ourSystem mainSystem] && context == [ourSystem contextSystem] && main != context && [UIMenuSystem mainSystem] == [UIMenuSystem mainSystem]
                         && [UIMenuSystem mainSystem] != [UIMenuSystem contextSystem],
                     "the two menu systems are two shared objects", @"they differ");
        [main setNeedsRebuild];
        [main setNeedsRevalidate];
        [context setNeedsRebuild];
        charon_check(YES, "a menu system answers a rebuild and a revalidate", @"");

        Class ourConfiguration = NSClassFromString(@"CharonHostUIContextMenuConfiguration");
        agree(@"context menu configuration", configuration_lines(ourConfiguration), configuration_lines([UIContextMenuConfiguration class]));

        Class ourInteraction = NSClassFromString(@"CharonHostUIContextMenuInteraction");
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [window addSubview:view];
        agree(@"context menu interaction at rest", interaction_lines(ourInteraction, ourConfiguration, ourAction, ourMenu, view),
             interaction_lines([UIContextMenuInteraction class], [UIContextMenuConfiguration class], [UIAction class], [UIMenu class], view));
        id sample = [[ourInteraction alloc] initWithDelegate:nil];
        charon_check([sample menuAppearance] == UIContextMenuInteractionAppearanceCompact && [[[UIContextMenuInteraction alloc] initWithDelegate:nil] menuAppearance] == UIContextMenuInteractionAppearanceRich,
                     "a menu is compact where the system's is rich: the port draws no preview", @"the appearances are not the documented pair");

        NSUInteger before = view.gestureRecognizers.count;
        [view addInteraction:sample];
        NSArray *added = [view.gestureRecognizers subarrayWithRange:NSMakeRange(before, view.gestureRecognizers.count - before)];
        charon_check(added.count == 1 && [added[0] isKindOfClass:[UILongPressGestureRecognizer class]] && [(id)[sample valueForKey:@"view"] isEqual:view],
                     "adding the interaction to a view puts one long press on it", [NSString stringWithFormat:@"%lu added", (unsigned long)added.count]);
        Recipient *recipient = [[Recipient alloc] init];
        recipient.log = [NSMutableArray array];
        id begun = [[ourInteraction alloc] initWithDelegate:recipient];
        [view addInteraction:begun];
        [begun charon_beginAtLocation:CGPointMake(3, 4)];
        charon_check([recipient.log isEqual:@[@"asked at 3 4"]], "a press asks the delegate for a configuration at the touch", recipient.log.description);
        __block NSArray *suggested = nil;
        __block int provided = 0;
        recipient.configuration = [ourConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *actions) {
            suggested = actions;
            provided++;
            UIAction *hidden = [ourAction actionWithTitle:@"Hidden" image:nil identifier:nil handler:nil];
            hidden.attributes = UIMenuElementAttributesHidden;
            UIAction *disabled = [ourAction actionWithTitle:@"Disabled" image:nil identifier:nil handler:nil];
            disabled.attributes = UIMenuElementAttributesDisabled;
            return [ourMenu menuWithTitle:@"" children:@[hidden, disabled]];
        }];
        [recipient.log removeAllObjects];
        [begun charon_beginAtLocation:CGPointMake(5, 6)];
        charon_check(provided == 1 && suggested.count == 0 && [recipient.log isEqual:@[@"asked at 5 6"]],
                     "the action provider is called with no suggested actions, and a menu of only hidden and disabled elements is not shown", recipient.log.description);
        [view removeInteraction:begun];
        preview_checks(window);
        [view removeInteraction:sample];
        charon_check(view.gestureRecognizers.count == before, "removing the interactions takes their gestures off again", [NSString stringWithFormat:@"%lu left", (unsigned long)view.gestureRecognizers.count]);
    }
}
