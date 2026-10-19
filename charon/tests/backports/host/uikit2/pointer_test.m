#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
#pragma clang diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
#pragma clang diagnostic ignored "-Wcompare-distinct-pointer-types"

extern NSString *const CharonHostUIKeyInputHome, *const CharonHostUIKeyInputEnd, *const CharonHostUIKeyInputF1, *const CharonHostUIKeyInputF2, *const CharonHostUIKeyInputF3,
    *const CharonHostUIKeyInputF4, *const CharonHostUIKeyInputF5, *const CharonHostUIKeyInputF6, *const CharonHostUIKeyInputF7, *const CharonHostUIKeyInputF8,
    *const CharonHostUIKeyInputF9, *const CharonHostUIKeyInputF10, *const CharonHostUIKeyInputF11, *const CharonHostUIKeyInputF12;

@interface CharonRecorder : NSCoder
@property (nonatomic, strong) NSMutableArray *rows;
@end

@implementation CharonRecorder

- (instancetype)init
{
    if ((self = [super init]))
        self.rows = [NSMutableArray array];
    return self;
}

- (BOOL)allowsKeyedCoding
{
    return YES;
}

- (void)encodeObject:(id)object forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"object %@ %@", key, object]];
}

- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"integer %@ %ld", key, (long)value]];
}

- (void)encodeInt:(int)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"int %@ %d", key, value]];
}

- (void)encodeInt32:(int32_t)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"int32 %@ %d", key, value]];
}

- (void)encodeInt64:(int64_t)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"int64 %@ %lld", key, value]];
}

- (void)encodeBool:(BOOL)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"bool %@ %d", key, value]];
}

@end

void charon_windowed_run(UIWindow *window);

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
}

static NSString *raised(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@ %@", exception.name, norm(exception.reason)];
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

static NSString *line(NSString *label, id value)
{
    return [NSString stringWithFormat:@"%@ %@", label, norm(value)];
}

static NSString *yes(BOOL value)
{
    return value ? @"YES" : @"NO";
}


static NSArray *region_lines(Class region)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIPointerRegion *(^make)(CGFloat, CGFloat, CGFloat, CGFloat, id) = ^UIPointerRegion *(CGFloat x, CGFloat y, CGFloat w, CGFloat h, id identifier) {
        return [region regionWithRect:CGRectMake(x, y, w, h) identifier:identifier];
    };
    [lines addObject:line(@"plain", make(1, 2, 3, 4, @"x"))];
    [lines addObject:line(@"fractions", make(1.5, -2.25, 3.125, 1e10, @5))];
    [lines addObject:line(@"nil identifier", make(0.5, 0.25, 0.125, 0.75, nil))];
    [lines addObject:line(@"url identifier", make(1e-5, 1234567.5, 3, 4, [NSURL URLWithString:@"http://x"]))];
    [lines addObject:line(@"array identifier", make(1, 2, 3, 4, @[@1]))];
    [lines addObject:line(@"null", [region regionWithRect:CGRectNull identifier:nil])];
    [lines addObject:line(@"infinite", [region regionWithRect:CGRectInfinite identifier:nil])];
    UIPointerRegion *axes = make(1, 2, 3, 4, nil);
    for (int value = 0; value < 8; value++) {
        axes.latchingAxes = (UIAxis)value;
        [lines addObject:[NSString stringWithFormat:@"axes %d %ld %@", value, (long)axes.latchingAxes, norm(axes)]];
    }
    UIPointerRegion *a = make(1, 2, 3, 4, @"x"), *b = make(1, 2, 3, 4, @"x"), *c = make(1, 2, 3, 4, @"y"), *d = make(1, 2, 3, 5, @"x"), *e = make(1, 2, 3, 4, nil), *f = make(1, 2, 3, 4, @"x");
    f.latchingAxes = UIAxisVertical;
    NSArray *all = @[a, b, c, d, e, f];
    for (UIPointerRegion *one in all) {
        NSMutableString *row = [NSMutableString string];
        for (UIPointerRegion *other in all)
            [row appendFormat:@"%@ ", yes([one isEqual:other])];
        [lines addObject:[NSString stringWithFormat:@"equal %@hash %lu", row, (unsigned long)one.hash]];
    }
    [lines addObject:line(@"equal to others", @[yes([a isEqual:@1]), yes([a isEqual:nil]), yes([a isEqual:a])])];
    for (UIPointerRegion *odd in @[make(1.5, 2.5, 3.5, 4.5, nil), make(-1, -2, 3, 4, nil), make(1e20, 0, 0, 0, nil), make(0, 0, 0, 0, @0), make(0, 0, 0, 0, nil)])
        [lines addObject:[NSString stringWithFormat:@"hash %lu", (unsigned long)odd.hash]];
    UIPointerRegion *copy = [f copy];
    [lines addObject:line(@"copy", @[copy, yes(copy != f), yes([copy isEqual:f]), yes([copy class] == [f class]), @(copy.latchingAxes)])];
    NSMutableString *mutable = [NSMutableString stringWithString:@"q"];
    UIPointerRegion *held = make(1, 2, 3, 4, mutable);
    [mutable appendString:@"z"];
    [lines addObject:line(@"identifier is kept as it is", @[held.identifier, yes(held.identifier == mutable)])];
    [lines addObject:raised(^id { return [[region alloc] performSelector:NSSelectorFromString(@"init")]; })];
    [lines addObject:raised(^id { return [region performSelector:NSSelectorFromString(@"new")]; })];
    [lines addObject:line(@"responds", @[yes([region instancesRespondToSelector:@selector(defaultRegion)]), yes([region instancesRespondToSelector:@selector(copyWithZone:)])])];
    return lines;
}

static NSArray *request_lines(Class request, id (^make)(Class, CGPoint, NSInteger))
{
    NSMutableArray *lines = [NSMutableArray array];
    for (NSValue *point in @[[NSValue valueWithCGPoint:CGPointMake(1.5, 2)], [NSValue valueWithCGPoint:CGPointMake(-3, 0.25)], [NSValue valueWithCGPoint:CGPointZero]]) {
        UIPointerRegionRequest *made = make(request, point.CGPointValue, UIKeyModifierShift | UIKeyModifierCommand);
        [lines addObject:line(@"request", @[made, NSStringFromCGPoint(made.location), @(made.modifiers)])];
    }
    UIPointerRegionRequest *blank = [[request alloc] performSelector:NSSelectorFromString(@"init")];
    [lines addObject:line(@"blank", @[blank, NSStringFromCGPoint(blank.location), @(blank.modifiers)])];
    [lines addObject:line(@"copies", yes([request instancesRespondToSelector:@selector(copyWithZone:)]))];
    return lines;
}

static NSArray *shape_lines(Class shape, UIBezierPath *(^path_of)(id))
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *shapes = @[[shape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4)], [shape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4) cornerRadius:5], [shape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4) cornerRadius:0],
                        [shape shapeWithRoundedRect:CGRectMake(1.5, 2, 3, 4) cornerRadius:-1], [shape shapeWithRoundedRect:CGRectNull cornerRadius:2.5], [shape shapeWithRoundedRect:CGRectZero],
                        [shape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4) cornerRadius:0.001], [shape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4) cornerRadius:100],
                        [shape beamWithPreferredLength:10 axis:UIAxisVertical], [shape beamWithPreferredLength:10 axis:UIAxisHorizontal], [shape beamWithPreferredLength:10 axis:(UIAxis)3],
                        [shape beamWithPreferredLength:10 axis:(UIAxis)0], [shape beamWithPreferredLength:-1 axis:UIAxisVertical], [shape beamWithPreferredLength:11 axis:UIAxisVertical],
                        [shape shapeWithPath:[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 5, 6)]], [shape shapeWithPath:[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 5, 6)]],
                        [shape shapeWithPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 5, 6)]], [shape shapeWithPath:nil], [[shape alloc] performSelector:NSSelectorFromString(@"init")]];
    for (id one in shapes)
        [lines addObject:line(@"describes", one)];
    for (NSUInteger index = 0; index < shapes.count; index++) {
        NSMutableString *row = [NSMutableString string];
        for (id other in shapes)
            [row appendFormat:@"%@ ", yes([shapes[index] isEqual:other])];
        BOOL rounded = index < 8 || index == 18;
        BOOL beam = index >= 8 && index < 14;
        [lines addObject:[NSString stringWithFormat:@"equal %lu %@%@", (unsigned long)index, row, rounded || beam ? [NSString stringWithFormat:@"hash %lu", (unsigned long)[shapes[index] hash]] : @""]];
    }
    [lines addObject:line(@"equal to others", @[yes([shapes[0] isEqual:nil]), yes([shapes[0] isEqual:@1])])];
    UIBezierPath *original = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 5, 6)];
    id held = [shape shapeWithPath:original];
    [original addLineToPoint:CGPointMake(9, 9)];
    UIBezierPath *kept = path_of(held);
    [lines addObject:line(@"the path is a copy", @[yes(kept != original), yes(![kept isEqual:original]), yes(CGRectEqualToRect(kept.bounds, CGRectMake(0, 0, 5, 6)))])];
    for (id one in @[shapes[0], shapes[1], shapes[8], held]) {
        id copy = [one copy];
        [lines addObject:line(@"copy", @[yes(copy != one), yes([copy isEqual:one]), yes([copy class] == [one class]), copy])];
    }
    UIBezierPath *first = path_of(held), *second = path_of([held copy]);
    [lines addObject:line(@"copied path", @[yes(first != second), yes(CGPathEqualToPath(first.CGPath, second.CGPath))])];
    return lines;
}

static NSArray *effect_lines(Class base, Class highlight, Class lift, Class hover, UITargetedPreview *preview, UITargetedPreview *other)
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *made = @[[base effectWithPreview:preview], [highlight effectWithPreview:preview], [lift effectWithPreview:preview], [hover effectWithPreview:preview], [base effectWithPreview:other],
                      [base effectWithPreview:nil], [hover effectWithPreview:nil]];
    for (id one in made)
        [lines addObject:line(@"made", @[one, yes([one preview] == preview), @([one hash] == [preview hash] ? 1 : 0), yes([[one class] isSubclassOfClass:base]), yes([one respondsToSelector:@selector(copyWithZone:)])])];
    for (NSUInteger index = 0; index < made.count; index++) {
        NSMutableString *row = [NSMutableString string];
        for (id other in made)
            [row appendFormat:@"%@ ", yes([made[index] isEqual:other])];
        [lines addObject:[NSString stringWithFormat:@"equal %lu %@", (unsigned long)index, row]];
    }
    id one = made[0], copy = [one copy];
    [lines addObject:line(@"copy", @[yes(copy != one), yes([copy isEqual:one]), yes([copy preview] == preview), yes([copy class] == [one class])])];
    UIPointerHoverEffect *fresh = made[3];
    [lines addObject:line(@"hover defaults", @[@(fresh.preferredTintMode), yes(fresh.prefersShadow), yes(fresh.prefersScaledContent)])];
    NSMutableArray *hashes = [NSMutableArray array];
    for (int tint = 0; tint < 3; tint++) {
        for (int shadow = 0; shadow < 2; shadow++) {
            for (int scaled = 0; scaled < 2; scaled++) {
                UIPointerHoverEffect *changed = [hover effectWithPreview:preview];
                changed.preferredTintMode = (UIPointerEffectTintMode)tint;
                changed.prefersShadow = shadow;
                changed.prefersScaledContent = scaled;
                [hashes addObject:[NSString stringWithFormat:@"%d%d%d:%@:%ld", tint, shadow, scaled, yes([changed isEqual:fresh]), (long)([changed hash] ^ [preview hash])]];
                UIPointerHoverEffect *twin = [changed copy];
                [hashes addObject:[NSString stringWithFormat:@"copy %@ %ld %d %d", yes([twin isEqual:changed]), (long)twin.preferredTintMode, twin.prefersShadow, twin.prefersScaledContent]];
            }
        }
    }
    [lines addObjectsFromArray:hashes];
    fresh = [hover effectWithPreview:preview];
    fresh.preferredTintMode = (UIPointerEffectTintMode)9;
    [lines addObject:line(@"tint mode is kept", @(fresh.preferredTintMode))];
    [lines addObject:raised(^id { return [[base alloc] performSelector:NSSelectorFromString(@"init")]; })];
    [lines addObject:raised(^id { return [[hover alloc] performSelector:NSSelectorFromString(@"init")]; })];
    return lines;
}

static NSArray *style_lines(Class style, Class shape, Class hover, UITargetedPreview *preview, UIPointerEffect *(^effect_of)(id), UIPointerShape *(^shape_of)(id), NSInteger (^axes_of)(id))
{
    NSMutableArray *lines = [NSMutableArray array];
    id effect = [hover effectWithPreview:preview], rect = [shape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4)];
    NSArray *made = @[[style styleWithEffect:effect shape:rect], [style styleWithEffect:effect shape:rect], [style styleWithEffect:effect shape:nil], [style styleWithEffect:nil shape:nil],
                      [style styleWithShape:rect constrainedAxes:UIAxisHorizontal], [style styleWithShape:rect constrainedAxes:UIAxisVertical],
                      [style styleWithShape:[shape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4)] constrainedAxes:UIAxisHorizontal], [style styleWithShape:nil constrainedAxes:UIAxisVertical],
                      [style styleWithShape:rect constrainedAxes:(UIAxis)7], [style styleWithEffect:[hover effectWithPreview:preview] shape:rect], [style hiddenPointerStyle], [style hiddenPointerStyle]];
    for (id one in made)
        [lines addObject:line(@"made", @[one, yes(effect_of(one) == effect), yes(shape_of(one) == rect), @(axes_of(one))])];
    for (NSUInteger index = 0; index < made.count; index++) {
        NSMutableString *row = [NSMutableString string];
        for (id other in made)
            [row appendFormat:@"%@ ", yes([made[index] isEqual:other])];
        [lines addObject:[NSString stringWithFormat:@"equal %lu %@", (unsigned long)index, row]];
    }
    NSMutableString *hashes = [NSMutableString string];
    for (NSUInteger index = 0; index < made.count; index++) {
        for (NSUInteger other = index + 1; other < made.count; other++) {
            if ([made[index] isEqual:made[other]] && [made[index] hash] != [made[other] hash])
                [hashes appendFormat:@"%lu:%lu ", (unsigned long)index, (unsigned long)other];
        }
    }
    [lines addObject:line(@"equal styles hash alike, unlike pairs", hashes.length ? hashes : @"none")];
    [lines addObject:line(@"hidden is not shared", yes(made[10] != made[11]))];
    for (id one in @[made[0], made[4], made[10]]) {
        id copy = [one copy];
        [lines addObject:line(@"copy", @[yes(copy != one), yes([copy isEqual:one]), yes([copy class] == [one class]), yes(effect_of(copy) == effect_of(one)), yes(shape_of(copy) == shape_of(one)),
                                          yes(effect_of(one) == nil || [effect_of(copy) isEqual:effect_of(one)]), @(axes_of(copy)), copy])];
    }
    [lines addObject:line(@"equal to others", @[yes([made[0] isEqual:nil]), yes([made[0] isEqual:@1])])];
    return lines;
}

static NSArray *interaction_lines(Class interaction, UIView *view)
{
    NSMutableArray *lines = [NSMutableArray array];
    id delegate = [[NSObject alloc] init];
    UIPointerInteraction *made = [[interaction alloc] initWithDelegate:delegate];
    [lines addObject:line(@"made", @[made, yes(made.delegate == delegate), yes(made.enabled), made.view ?: @"no view"])];
    UIPointerInteraction *bare = [[interaction alloc] initWithDelegate:nil];
    [lines addObject:line(@"bare", @[bare, bare.delegate ?: @"no delegate", yes(bare.enabled)])];
    [lines addObject:line(@"init", @[yes([(UIPointerInteraction *)[[interaction alloc] performSelector:NSSelectorFromString(@"init")] isEnabled]), [[[interaction alloc] performSelector:NSSelectorFromString(@"init")] delegate] ?: @"no delegate"])];
    UIPointerInteraction *weak;
    @autoreleasepool {
        NSObject *brief = [[NSObject alloc] init];
        weak = [[interaction alloc] initWithDelegate:brief];
        [lines addObject:line(@"delegate while alive", yes(weak.delegate == brief))];
    }
    [lines addObject:line(@"delegate is weak", weak.delegate ?: @"gone")];
    made.enabled = NO;
    [lines addObject:line(@"enabled set", yes(made.enabled))];
    [made invalidate];
    [lines addObject:line(@"invalidate keeps enabled", yes(made.enabled))];
    made.enabled = YES;
    NSUInteger before = view.interactions.count;
    [view addInteraction:made];
    [lines addObject:line(@"added", @[yes(made.view == view), @(view.interactions.count - before), yes([view.interactions containsObject:made])])];
    UIView *other = [[UIView alloc] init];
    [other addInteraction:made];
    [lines addObject:line(@"moved", @[yes(made.view == other), @(view.interactions.count - before), @(other.interactions.count)])];
    [other removeInteraction:made];
    [lines addObject:line(@"removed", @[made.view ?: @"no view", @(other.interactions.count)])];
    return lines;
}

static NSArray *hover_lines(Class hover, UIView *view)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIHoverGestureRecognizer *made = [[hover alloc] initWithTarget:nil action:NULL];
    [lines addObject:line(@"fresh", @[@(made.state), yes(made.enabled), made.view ?: @"no view", @(made.numberOfTouches), yes(made.cancelsTouchesInView), yes(made.delaysTouchesBegan),
                                       yes(made.delaysTouchesEnded), made.delegate ?: @"no delegate", @([made locationInView:view].x)])];
    NSString *text = [norm(made) stringByReplacingOccurrencesOfString:@"baseClass = UIGestureRecognizer; " withString:@""];
    text = [text stringByReplacingOccurrencesOfString:@"[0-9]+" withString:@"N" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)];
    [lines addObject:line(@"description", text)];
    id target = [[NSObject alloc] init];
    UIHoverGestureRecognizer *another = [[hover alloc] initWithTarget:target action:@selector(description)];
    NSUInteger before = view.gestureRecognizers.count;
    [view addGestureRecognizer:another];
    [lines addObject:line(@"added", @[yes(another.view == view), @(view.gestureRecognizers.count - before), yes([view.gestureRecognizers containsObject:another]), @(another.state)])];
    another.enabled = NO;
    [lines addObject:line(@"disabled", yes(another.enabled))];
    [view removeGestureRecognizer:another];
    [lines addObject:line(@"removed", @[another.view ?: @"no view", @(view.gestureRecognizers.count - before)])];
    [lines addObject:line(@"init", @[@([[[hover alloc] init] state])])];
    [lines addObject:line(@"superclass", NSStringFromClass(class_getSuperclass(hover)))];
    return lines;
}

static NSArray *key_lines(Class key, id (^make)(Class, NSString *, NSString *, NSInteger, NSInteger), NSArray *(^archived)(id))
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *keys = @[make(key, @"A", @"a", 4, UIKeyModifierShift), make(key, @"A", @"a", 4, UIKeyModifierShift), make(key, @"b", @"b", 4, UIKeyModifierShift), make(key, @"A", @"a", 5, UIKeyModifierShift),
                      make(key, @"A", @"a", 4, UIKeyModifierControl), make(key, @"X", @"a", 4, UIKeyModifierShift), make(key, @"A", @"z", 4, UIKeyModifierShift), make(key, @"A", @"a", 4, 0),
                      make(key, @"A", @"a", 4, UIKeyModifierAlphaShift), make(key, @"é", @"e", 0x2a, UIKeyModifierAlternate | UIKeyModifierCommand)];
    for (UIKey *one in keys)
        [lines addObject:line(@"key", @[one, one.characters, one.charactersIgnoringModifiers, @(one.keyCode), @(one.modifierFlags), @(one.hash)])];
    for (NSUInteger index = 0; index < keys.count; index++) {
        NSMutableString *row = [NSMutableString string];
        for (id other in keys)
            [row appendFormat:@"%@ ", yes([keys[index] isEqual:other])];
        [lines addObject:[NSString stringWithFormat:@"equal %lu %@", (unsigned long)index, row]];
    }
    [lines addObject:line(@"equal to others", @[yes([keys[0] isEqual:nil]), yes([keys[0] isEqual:@"x"]), yes([keys[0] isEqual:keys[0]])])];
    UIKey *copy = [keys[0] copy];
    [lines addObject:line(@"copy", @[yes(copy != keys[0]), yes([copy isEqual:keys[0]]), copy.characters, copy.charactersIgnoringModifiers, @(copy.keyCode), @(copy.modifierFlags)])];
    [lines addObject:line(@"archive", archived(keys[9]))];
    [lines addObject:line(@"conforms", @[yes([key conformsToProtocol:@protocol(NSCopying)]), yes([key conformsToProtocol:@protocol(NSCoding)]), yes([key conformsToProtocol:@protocol(NSSecureCoding)])])];
    UIKey *blank = [[key alloc] init];
    [lines addObject:line(@"blank", @[blank.characters ?: @"nil", blank.charactersIgnoringModifiers ?: @"nil", @(blank.keyCode), @(blank.modifierFlags)])];
    return lines;
}

void charon_windowed_run(UIWindow *window)
{
    Class ourRegion = NSClassFromString(@"CharonHostUIPointerRegion"), ourRequest = NSClassFromString(@"CharonHostUIPointerRegionRequest"), ourShape = NSClassFromString(@"CharonHostUIPointerShape"),
          ourEffect = NSClassFromString(@"CharonHostUIPointerEffect"), ourHighlight = NSClassFromString(@"CharonHostUIPointerHighlightEffect"), ourLift = NSClassFromString(@"CharonHostUIPointerLiftEffect"),
          ourHover = NSClassFromString(@"CharonHostUIPointerHoverEffect"), ourStyle = NSClassFromString(@"CharonHostUIPointerStyle"), ourInteraction = NSClassFromString(@"CharonHostUIPointerInteraction"),
          ourRecognizer = NSClassFromString(@"CharonHostUIHoverGestureRecognizer"), ourKey = NSClassFromString(@"CharonHostUIKey");
    charon_check(ourRegion && ourRequest && ourShape && ourEffect && ourHighlight && ourLift && ourHover && ourStyle && ourInteraction && ourRecognizer && ourKey,
                 "the port's classes are linked under their host names", @"one is missing");
    charon_check(class_getSuperclass(ourHighlight) == ourEffect && class_getSuperclass(ourLift) == ourEffect && class_getSuperclass(ourHover) == ourEffect && class_getSuperclass(ourEffect) == [NSObject class]
                     && class_getSuperclass(ourRegion) == [NSObject class] && class_getSuperclass(ourShape) == [NSObject class] && class_getSuperclass(ourRecognizer) == [UIGestureRecognizer class]
                     && class_getSuperclass(ourInteraction) == [NSObject class] && class_getSuperclass(ourKey) == [NSObject class],
                 "the classes descend as the system's do", @"a superclass differs");

    agree(@"pointer region values", region_lines(ourRegion), region_lines([UIPointerRegion class]));
    id (^made_request)(Class, CGPoint, NSInteger) = ^id(Class cls, CGPoint point, NSInteger modifiers) {
        if (cls == [UIPointerRegionRequest class]) {
            id request = [[cls alloc] performSelector:NSSelectorFromString(@"init")];
            [request setValue:[NSValue valueWithCGPoint:point] forKey:@"_location"];
            [request setValue:@(modifiers) forKey:@"modifiers"];
            return request;
        }
        return ((id (*)(id, SEL, CGPoint, NSInteger))objc_msgSend)([cls alloc], NSSelectorFromString(@"initCharonWithLocation:modifiers:"), point, modifiers);
    };
    agree(@"pointer region request values", request_lines(ourRequest, made_request), request_lines([UIPointerRegionRequest class], made_request));
    agree(@"pointer shape values", shape_lines(ourShape, ^UIBezierPath *(id shape) { return ((UIBezierPath * (*)(id, SEL))objc_msgSend)(shape, NSSelectorFromString(@"charon_path")); }),
          shape_lines([UIPointerShape class], ^UIBezierPath *(id shape) { return [shape valueForKey:@"path"]; }));

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    [window addSubview:view];
    UIView *far = [[UIView alloc] initWithFrame:CGRectMake(0, 60, 100, 50)];
    [window addSubview:far];
    UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:view], *other = [[UITargetedPreview alloc] initWithView:far];
    agree(@"pointer effect values", effect_lines(ourEffect, ourHighlight, ourLift, ourHover, preview, other), effect_lines([UIPointerEffect class], [UIPointerHighlightEffect class], [UIPointerLiftEffect class], [UIPointerHoverEffect class], preview, other));
    agree(@"pointer style values",
          style_lines(ourStyle, ourShape, ourHover, preview, ^UIPointerEffect *(id style) { return ((id (*)(id, SEL))objc_msgSend)(style, NSSelectorFromString(@"charon_effect")); },
                      ^UIPointerShape *(id style) { return ((id (*)(id, SEL))objc_msgSend)(style, NSSelectorFromString(@"charon_shape")); },
                      ^NSInteger(id style) { return ((NSInteger (*)(id, SEL))objc_msgSend)(style, NSSelectorFromString(@"charon_axes")); }),
          style_lines([UIPointerStyle class], [UIPointerShape class], [UIPointerHoverEffect class], preview, ^UIPointerEffect *(id style) { return [style valueForKey:@"pointerEffect"]; },
                      ^UIPointerShape *(id style) { return [style valueForKey:@"pointerShape"]; }, ^NSInteger(id style) { return [[style valueForKey:@"constrainedAxes"] integerValue]; }));
    agree(@"pointer interaction", interaction_lines(ourInteraction, view), interaction_lines([UIPointerInteraction class], far));
    agree(@"hover gesture recognizer", hover_lines(ourRecognizer, view), hover_lines([UIHoverGestureRecognizer class], far));
    // What the port answers of the members that arrived after the class did. zOffset (16.1),
    // altitudeAngle and the two azimuth methods (16.4) are carried by UIHoverGestureRecognizer+Hover16.m
    // and answer what the header documents for a device that cannot hover, which is what the host's own
    // class answers too - measured, and the check that says so is the hover16 group. rollAngle is 17.5
    // and stays with the release.
    charon_check([ourRecognizer instancesRespondToSelector:@selector(zOffset)] && [ourRecognizer instancesRespondToSelector:@selector(altitudeAngle)] &&
                     ![ourRecognizer instancesRespondToSelector:NSSelectorFromString(@"rollAngle")],
                 "the hover recognizer answers the members of 16.1 and 16.4 and leaves rollAngle of 17.5 to the release",
                 @"one is answered when it should not be, or is not when it should");
    charon_check(![ourStyle instancesRespondToSelector:@selector(accessories)] && [UIPointerStyle instancesRespondToSelector:@selector(accessories)], "the pointer style leaves the accessories of iOS 15 to the release", @"it answers them");

    id (^made_key)(Class, NSString *, NSString *, NSInteger, NSInteger) = ^id(Class cls, NSString *characters, NSString *unmodified, NSInteger code, NSInteger flags) {
        if (cls == [UIKey class]) {
            UIKey *made = [[cls alloc] init];
            ((void (*)(id, SEL, NSInteger))objc_msgSend)(made, NSSelectorFromString(@"_setKeyCode:"), code);
            [made performSelector:NSSelectorFromString(@"_setModifiedInput:") withObject:characters];
            [made performSelector:NSSelectorFromString(@"_setUnmodifiedInput:") withObject:unmodified];
            ((void (*)(id, SEL, NSInteger))objc_msgSend)(made, NSSelectorFromString(@"_setModifierFlags:"), flags);
            return made;
        }
        return ((id (*)(id, SEL, NSString *, NSString *, NSInteger, NSInteger))objc_msgSend)([cls alloc], NSSelectorFromString(@"initCharonWithCharacters:unmodified:keyCode:modifierFlags:"), characters, unmodified, code, flags);
    };
    NSArray *(^archived)(id) = ^NSArray *(id made) {
        CharonRecorder *recorder = [[CharonRecorder alloc] init];
        [made encodeWithCoder:recorder];
        NSMutableArray *rows = [NSMutableArray arrayWithArray:[recorder.rows sortedArrayUsingSelector:@selector(compare:)]];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:made requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        reader.requiresSecureCoding = NO;
        id back = [reader decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        [rows addObjectsFromArray:@[back ? [back characters] : @"nil", back ? [back charactersIgnoringModifiers] : @"nil", @([back keyCode]), @([back modifierFlags]), yes([back isEqual:made])]];
        return rows;
    };
    agree(@"key values", key_lines(ourKey, made_key, archived), key_lines([UIKey class], made_key, archived));

    BOOL constants = YES;
    NSMutableString *wrong = [NSMutableString string];
#define COMPARE(name) if (![CharonHostUIKeyInput##name isEqualToString:UIKeyInput##name]) { constants = NO; [wrong appendFormat:@" %s", #name]; }
    COMPARE(Home) COMPARE(End) COMPARE(F1) COMPARE(F2) COMPARE(F3) COMPARE(F4) COMPARE(F5) COMPARE(F6) COMPARE(F7) COMPARE(F8) COMPARE(F9) COMPARE(F10) COMPARE(F11) COMPARE(F12)
    charon_check(constants, "the 14 key input strings are the system's", wrong);

}
