#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

@interface NSObject (CharonHostLayoutGuideView)
- (UIView *)charon_view;
@end

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static BOOL legacy;
static int skipped_ambiguous;
static int degenerate;

static NSString *renamed(NSString *selector)
{
    NSString *prefix = @"charonHost";
    NSString *rest = selector;
    if ([selector hasPrefix:@"set"] && selector.length > 3 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[selector characterAtIndex:3]]) {
        prefix = @"setCharonHost";
        rest = [selector substringFromIndex:3];
    } else if ([selector hasPrefix:@"is"] && selector.length > 2 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[selector characterAtIndex:2]]) {
        prefix = @"isCharonHost";
        rest = [selector substringFromIndex:2];
    }
    return [prefix stringByAppendingFormat:@"%@%@", [[rest substringToIndex:1] uppercaseString], [rest substringFromIndex:1]];
}

static SEL nine(NSString *selector)
{
    return NSSelectorFromString(renamed(selector));
}

static SEL eight(NSString *selector)
{
    return legacy ? NSSelectorFromString(renamed(selector)) : NSSelectorFromString(selector);
}

static id send(id target, SEL selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static void send_object(id target, SEL selector, id argument)
{
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
}

static BOOL close_enough(CGFloat a, CGFloat b)
{
    return fabs(a - b) <= 1.01;
}

static BOOL rects_close(CGRect a, CGRect b)
{
    return close_enough(a.origin.x, b.origin.x) && close_enough(a.origin.y, b.origin.y) && close_enough(a.size.width, b.size.width) && close_enough(a.size.height, b.size.height);
}

@interface SizedView : UIView
@property (nonatomic) CGSize size;
@end

@implementation SizedView
- (CGSize)intrinsicContentSize
{
    return self.size;
}
@end

static SizedView *sized(CGFloat width, CGFloat height)
{
    SizedView *view = [[SizedView alloc] initWithFrame:CGRectZero];
    view.size = CGSizeMake(width, height);
    return view;
}

static UILabel *label(NSString *text, CGFloat size)
{
    UILabel *view = [[UILabel alloc] initWithFrame:CGRectZero];
    view.text = text;
    view.font = [UIFont systemFontOfSize:size];
    return view;
}

@interface Flavor : NSObject
@property (nonatomic) BOOL system;
@end

@implementation Flavor

- (Class)stackClass
{
    return self.system ? [UIStackView class] : NSClassFromString(@"CharonHostUIStackView");
}

- (Class)guideClass
{
    return self.system ? [UILayoutGuide class] : NSClassFromString(@"CharonHostUILayoutGuide");
}

- (id)anchor:(id)item named:(NSString *)name
{
    return send(item, self.system ? NSSelectorFromString(name) : nine(name));
}

- (id)marginsGuide:(UIView *)view
{
    return send(view, self.system ? @selector(layoutMarginsGuide) : nine(@"layoutMarginsGuide"));
}

- (id)readableGuide:(UIView *)view
{
    return send(view, self.system ? @selector(readableContentGuide) : nine(@"readableContentGuide"));
}

- (void)addGuide:(id)guide to:(UIView *)view
{
    send_object(view, self.system ? @selector(addLayoutGuide:) : nine(@"addLayoutGuide:"), guide);
}

- (void)removeGuide:(id)guide from:(UIView *)view
{
    send_object(view, self.system ? @selector(removeLayoutGuide:) : nine(@"removeLayoutGuide:"), guide);
}

- (NSArray *)guidesOf:(UIView *)view
{
    return send(view, self.system ? @selector(layoutGuides) : nine(@"layoutGuides"));
}

- (void)activate:(NSArray *)constraints
{
    send_object([NSLayoutConstraint class], self.system ? @selector(activateConstraints:) : eight(@"activateConstraints:"), constraints);
}

- (void)deactivate:(NSArray *)constraints
{
    send_object([NSLayoutConstraint class], self.system ? @selector(deactivateConstraints:) : eight(@"deactivateConstraints:"), constraints);
}

- (BOOL)isActive:(NSLayoutConstraint *)constraint
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(constraint, self.system ? @selector(isActive) : eight(@"isActive"));
}

- (void)setActive:(BOOL)active constraint:(NSLayoutConstraint *)constraint
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(constraint, self.system ? @selector(setActive:) : eight(@"setActive:"), active);
}

- (UIEdgeInsets)margins:(UIView *)view
{
    return ((UIEdgeInsets (*)(id, SEL))objc_msgSend)(view, self.system ? @selector(layoutMargins) : eight(@"layoutMargins"));
}

- (void)setMargins:(UIEdgeInsets)margins view:(UIView *)view
{
    ((void (*)(id, SEL, UIEdgeInsets))objc_msgSend)(view, self.system ? @selector(setLayoutMargins:) : eight(@"setLayoutMargins:"), margins);
}

- (void)setPreserves:(BOOL)preserves view:(UIView *)view
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(view, self.system ? @selector(setPreservesSuperviewLayoutMargins:) : eight(@"setPreservesSuperviewLayoutMargins:"), preserves);
}

@end

typedef struct {
    NSInteger axis;
    NSInteger distribution;
    NSInteger alignment;
    CGFloat spacing;
    NSInteger hidden;
    BOOL margins;
    NSInteger size;
    NSInteger content;
    BOOL baseline;
} StackConfig;

static NSString *describe(StackConfig c)
{
    return [NSString stringWithFormat:@"axis=%ld distribution=%ld alignment=%ld spacing=%g hidden=%ld margins=%d size=%ld content=%ld", (long)c.axis, (long)c.distribution, (long)c.alignment, c.spacing, (long)c.hidden, c.margins, (long)c.size, (long)c.content];
}

static NSArray *content(Flavor *flavor, NSInteger kind)
{
    switch (kind) {
    case 0:
        return @[sized(40, 20), sized(60, 30), sized(10, 50), sized(25, 25)];
    case 1:
        return @[label(@"Hello", 30), sized(10, 10), label(@"World", 12), label(@"Stack", 17)];
    case 2: {
        UIStackView *inner = [[[flavor stackClass] alloc] initWithArrangedSubviews:@[sized(5, 5), label(@"Inner", 20)]];
        inner.axis = UILayoutConstraintAxisVertical;
        inner.alignment = UIStackViewAlignmentCenter;
        inner.spacing = 2;
        UIStackView *row = [[[flavor stackClass] alloc] initWithArrangedSubviews:@[label(@"a", 9), sized(8, 16)]];
        row.alignment = UIStackViewAlignmentLastBaseline;
        return @[label(@"Outer", 24), inner, sized(12, 40), row];
    }
    default: {
        SizedView *low = sized(50, 20), *high = sized(70, 35), *mid = sized(30, 45);
        [low setContentHuggingPriority:200 forAxis:UILayoutConstraintAxisHorizontal];
        [low setContentHuggingPriority:200 forAxis:UILayoutConstraintAxisVertical];
        [low setContentCompressionResistancePriority:700 forAxis:UILayoutConstraintAxisHorizontal];
        [low setContentCompressionResistancePriority:700 forAxis:UILayoutConstraintAxisVertical];
        [high setContentHuggingPriority:300 forAxis:UILayoutConstraintAxisHorizontal];
        [high setContentHuggingPriority:300 forAxis:UILayoutConstraintAxisVertical];
        [mid setContentCompressionResistancePriority:800 forAxis:UILayoutConstraintAxisHorizontal];
        [mid setContentCompressionResistancePriority:800 forAxis:UILayoutConstraintAxisVertical];
        return @[low, high, mid];
    }
    }
}

static void collect(UIView *view, NSMutableArray *views)
{
    [views addObject:view];
    if ([view isKindOfClass:[UIStackView class]] || [view isKindOfClass:NSClassFromString(@"CharonHostUIStackView")]) {
        for (UIView *arranged in [(UIStackView *)view arrangedSubviews])
            collect(arranged, views);
    }
}

static void mark_needs_layout(UIView *view)
{
    [view setNeedsLayout];
    for (UIView *subview in view.subviews)
        mark_needs_layout(subview);
}

static void layout_tree(UIView *root)
{
    mark_needs_layout(root);
    [root layoutIfNeeded];
}

static UIView *build_stack(Flavor *flavor, StackConfig c, NSMutableArray *views)
{
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    NSArray *arranged = content(flavor, c.content);
    UIStackView *stack = [[[flavor stackClass] alloc] initWithArrangedSubviews:arranged];
    stack.axis = c.axis;
    stack.distribution = c.distribution;
    stack.alignment = c.alignment;
    stack.spacing = c.spacing;
    stack.baselineRelativeArrangement = c.baseline;
    if (c.margins) {
        stack.layoutMarginsRelativeArrangement = YES;
        [flavor setMargins:UIEdgeInsetsMake(3, 5, 7, 11) view:stack];
    }
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:stack];
    [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeLeft multiplier:1 constant:10]];
    [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeTop multiplier:1 constant:20]];
    if (c.size) {
        CGSize size = c.size == 1 ? CGSizeMake(400, 300) : CGSizeMake(60, 15);
        [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:size.width]];
        [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:size.height]];
    }
    [root layoutIfNeeded];
    NSArray *all = arranged;
    if (c.hidden == 1)
        [all[1] setHidden:YES];
    else if (c.hidden == 2)
        [all[0] setHidden:YES];
    else if (c.hidden == 3)
        for (UIView *view in all)
            view.hidden = YES;
    else if (c.hidden == 4) {
        [all[all.count - 1] setHidden:YES];
        [all[all.count - 2] setHidden:YES];
    }
    layout_tree(root);
    collect(stack, views);
    return root;
}

static BOOL ambiguous(NSArray *views)
{
    for (UIView *view in views) {
        if ([view hasAmbiguousLayout])
            return YES;
    }
    return NO;
}

static NSString *frames(UIView *root, NSArray *views)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (UIView *view in views)
        [parts addObject:NSStringFromCGRect([view convertRect:view.bounds toView:root])];
    return [parts componentsJoinedByString:@" "];
}

static BOOL same_layout(UIView *systemRoot, NSArray *systemViews, UIView *ourRoot, NSArray *ourViews)
{
    BOOL same = systemViews.count == ourViews.count;
    for (NSUInteger index = 0; same && index < systemViews.count; index++) {
        UIView *a = systemViews[index], *b = ourViews[index];
        same = rects_close([a convertRect:a.bounds toView:systemRoot], [b convertRect:b.bounds toView:ourRoot]);
    }
    return same;
}

static void compare_layouts(NSString *name, UIView *systemRoot, NSArray *systemViews, UIView *ourRoot, NSArray *ourViews)
{
    charon_check(same_layout(systemRoot, systemViews, ourRoot, ourViews), name.UTF8String, [NSString stringWithFormat:@"\n  system %@\n  ours   %@", frames(systemRoot, systemViews), frames(ourRoot, ourViews)]);
}

static CGFloat edge(CGRect rect, UILayoutConstraintAxis axis, int which)
{
    CGFloat origin = axis == UILayoutConstraintAxisHorizontal ? rect.origin.x : rect.origin.y;
    CGFloat length = axis == UILayoutConstraintAxisHorizontal ? rect.size.width : rect.size.height;
    return which == 0 ? origin : which == 1 ? origin + length : which == 2 ? origin + length / 2 : length;
}

static BOOL satisfies_required(UIStackView *stack, StackConfig c)
{
    CGRect canvas = stack.bounds;
    if (c.margins)
        canvas = UIEdgeInsetsInsetRect(canvas, UIEdgeInsetsMake(3, 5, 7, 11));
    UILayoutConstraintAxis axis = c.axis, across = axis == UILayoutConstraintAxisHorizontal ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    NSMutableArray *visible = [NSMutableArray array];
    for (UIView *view in stack.arrangedSubviews) {
        if (!view.hidden)
            [visible addObject:view];
    }
    if (!visible.count)
        return YES;
    NSMutableArray *rects = [NSMutableArray array];
    for (UIView *view in visible) {
        CGRect rect = view.frame;
        if (edge(rect, axis, 3) < -1 || edge(rect, across, 3) < -1)
            return NO;
        [rects addObject:[NSValue valueWithCGRect:rect]];
    }
    if (!close_enough(edge([rects[0] CGRectValue], axis, 0), edge(canvas, axis, 0)) || !close_enough(edge([rects.lastObject CGRectValue], axis, 1), edge(canvas, axis, 1)))
        return NO;
    BOOL spreading = c.distribution >= UIStackViewDistributionEqualSpacing;
    for (NSUInteger index = 1; index < rects.count; index++) {
        CGFloat gap = edge([rects[index] CGRectValue], axis, 0) - edge([rects[index - 1] CGRectValue], axis, 1);
        if (spreading ? gap < c.spacing - 1.01 : !close_enough(gap, c.spacing))
            return NO;
        if (c.distribution == UIStackViewDistributionFillEqually && !close_enough(edge([rects[index] CGRectValue], axis, 3), edge([rects[0] CGRectValue], axis, 3)))
            return NO;
    }
    CGRect first = [stack.arrangedSubviews[0] frame];
    for (NSValue *value in rects) {
        CGRect rect = value.CGRectValue;
        switch (c.alignment) {
        case UIStackViewAlignmentFill:
            if (!close_enough(edge(rect, across, 0), edge(first, across, 0)) || !close_enough(edge(rect, across, 1), edge(first, across, 1)))
                return NO;
            break;
        case UIStackViewAlignmentLeading:
            if (!close_enough(edge(rect, across, 0), edge(first, across, 0)))
                return NO;
            break;
        case UIStackViewAlignmentTrailing:
            if (!close_enough(edge(rect, across, 1), edge(first, across, 1)))
                return NO;
            break;
        case UIStackViewAlignmentCenter:
            if (!close_enough(edge(rect, across, 2), edge(first, across, 2)))
                return NO;
            break;
        }
    }
    return YES;
}

static BOOL stretched_label(NSArray *views)
{
    for (UIView *view in views) {
        if ([view isKindOfClass:[UILabel class]] && CGRectGetHeight(view.frame) > view.intrinsicContentSize.height + 1.01)
            return YES;
    }
    return NO;
}

static void test_baseline_relative_matrix(void)
{
    Flavor *system = [Flavor new], *ours = [Flavor new];
    system.system = YES;
    int compared = 0, known = 0, degenerateBaseline = 0;
    for (NSInteger contentKind = 0; contentKind < 3; contentKind++)
    for (NSInteger distribution = 0; distribution < 5; distribution++)
    for (NSInteger alignment = 0; alignment < 6; alignment++)
    for (NSInteger hidden = 0; hidden < 5; hidden++)
    for (NSInteger size = 0; size < 3; size++)
    for (NSInteger spacing = 0; spacing < 2; spacing++) {
        if (alignment == UIStackViewAlignmentFirstBaseline || alignment == UIStackViewAlignmentLastBaseline)
            continue;
        StackConfig config = {UILayoutConstraintAxisVertical, distribution, alignment, spacing ? 7.5 : 0, hidden, NO, size, contentKind, YES};
        @autoreleasepool {
            NSMutableArray *systemViews = [NSMutableArray array], *ourViews = [NSMutableArray array];
            UIView *roots[2];
            for (NSInteger index = 0; index < 2; index++) {
                NSMutableArray *views = index ? ourViews : systemViews;
                roots[index] = build_stack(index ? ours : system, config, views);
            }
            NSString *name = [@"baseline-relative stack frames " stringByAppendingString:describe(config)];
            compared++;
            if (same_layout(roots[0], systemViews, roots[1], ourViews)) {
                charon_check(YES, name.UTF8String, nil);
                continue;
            }
            if (legacy && stretched_label(systemViews)) {
                known++;
                printf("known %s (a label taller than its text: iOS 6 has one baseline)\n", name.UTF8String);
                continue;
            }
            if (size == 2 || distribution == UIStackViewDistributionFillProportionally) {
                degenerateBaseline++;
                printf("info %s\n  system %s\n  ours   %s\n", name.UTF8String, frames(roots[0], systemViews).UTF8String, frames(roots[1], ourViews).UTF8String);
                charon_check(satisfies_required(ourViews[0], config) || !satisfies_required(systemViews[0], config), [@"degenerate: " stringByAppendingString:name].UTF8String, nil);
                continue;
            }
            compare_layouts(name, roots[0], systemViews, roots[1], ourViews);
        }
    }
    printf("baseline-relative matrix: compared=%d known-legacy-limit=%d degenerate=%d\n", compared, known, degenerateBaseline);
}

static void test_stack_matrix(void)
{
    Flavor *system = [Flavor new], *ours = [Flavor new];
    system.system = YES;
    int compared = 0;
    for (NSInteger contentKind = 0; contentKind < 4; contentKind++)
    for (NSInteger axis = 0; axis < 2; axis++)
    for (NSInteger distribution = 0; distribution < 5; distribution++)
    for (NSInteger alignment = 0; alignment < 6; alignment++)
    for (NSInteger hidden = 0; hidden < 5; hidden++)
    for (NSInteger size = 0; size < 3; size++)
    for (NSInteger margins = 0; margins < 2; margins++)
    for (NSInteger spacing = 0; spacing < 2; spacing++) {
        StackConfig config = {axis, distribution, alignment, spacing ? 7.5 : 0, hidden, margins, size, contentKind};
        if (axis == UILayoutConstraintAxisVertical && (alignment == UIStackViewAlignmentFirstBaseline || alignment == UIStackViewAlignmentLastBaseline))
            continue;
        @autoreleasepool {
            NSMutableArray *systemViews = [NSMutableArray array], *ourViews = [NSMutableArray array];
            UIView *systemRoot = build_stack(system, config, systemViews);
            if (ambiguous(systemViews)) {
                skipped_ambiguous++;
                continue;
            }
            UIView *ourRoot = build_stack(ours, config, ourViews);
            NSString *name = [@"stack frames " stringByAppendingString:describe(config)];
            compared++;
            if ((config.size == 2 || config.distribution == UIStackViewDistributionFillProportionally) && !same_layout(systemRoot, systemViews, ourRoot, ourViews) && satisfies_required(systemViews[0], config)) {
                degenerate++;
                printf("info %s\n  system %s\n  ours   %s\n", name.UTF8String, frames(systemRoot, systemViews).UTF8String, frames(ourRoot, ourViews).UTF8String);
                charon_check(satisfies_required(ourViews[0], config), [@"degenerate: both satisfy required constraints, " stringByAppendingString:name].UTF8String, [NSString stringWithFormat:@"\n  system %@\n  ours   %@", frames(systemRoot, systemViews), frames(ourRoot, ourViews)]);
                continue;
            }
            compare_layouts(name, systemRoot, systemViews, ourRoot, ourViews);
        }
    }
    printf("stack matrix: compared=%d exact=%d degenerate=%d skipped-ambiguous=%d\n", compared, compared - degenerate, degenerate, skipped_ambiguous);
}

static NSArray *anchor_names(void)
{
    return @[@"leadingAnchor", @"trailingAnchor", @"leftAnchor", @"rightAnchor", @"topAnchor", @"bottomAnchor", @"centerXAnchor", @"centerYAnchor", @"widthAnchor", @"heightAnchor", @"firstBaselineAnchor", @"lastBaselineAnchor"];
}

static NSInteger anchor_kind(NSString *name)
{
    if ([name hasPrefix:@"width"] || [name hasPrefix:@"height"])
        return 2;
    if ([name hasPrefix:@"top"] || [name hasPrefix:@"bottom"] || [name hasPrefix:@"centerY"] || [name hasSuffix:@"BaselineAnchor"])
        return 1;
    return 0;
}

static BOOL shows_text(id item)
{
    return [item isKindOfClass:[UILabel class]];
}

static NSLayoutAttribute expected_attribute(NSLayoutAttribute attribute, id item)
{
    if (!legacy)
        return attribute;
    if (attribute == NSLayoutAttributeFirstBaseline)
        return shows_text(item) ? NSLayoutAttributeLastBaseline : NSLayoutAttributeTop;
    if (attribute == NSLayoutAttributeLastBaseline)
        return shows_text(item) ? NSLayoutAttributeLastBaseline : NSLayoutAttributeBottom;
    return attribute;
}

static NSLayoutConstraint *make_constraint(id anchor, NSInteger method, id other, CGFloat multiplier, CGFloat constant)
{
    switch (method) {
    case 0: return [anchor constraintEqualToAnchor:other];
    case 1: return [anchor constraintGreaterThanOrEqualToAnchor:other];
    case 2: return [anchor constraintLessThanOrEqualToAnchor:other];
    case 3: return [anchor constraintEqualToAnchor:other constant:constant];
    case 4: return [anchor constraintGreaterThanOrEqualToAnchor:other constant:constant];
    case 5: return [anchor constraintLessThanOrEqualToAnchor:other constant:constant];
    case 6: return [anchor constraintEqualToConstant:constant];
    case 7: return [anchor constraintGreaterThanOrEqualToConstant:constant];
    case 8: return [anchor constraintLessThanOrEqualToConstant:constant];
    case 9: return [anchor constraintEqualToAnchor:other multiplier:multiplier];
    case 10: return [anchor constraintGreaterThanOrEqualToAnchor:other multiplier:multiplier];
    case 11: return [anchor constraintLessThanOrEqualToAnchor:other multiplier:multiplier];
    case 12: return [anchor constraintEqualToAnchor:other multiplier:multiplier constant:constant];
    case 13: return [anchor constraintGreaterThanOrEqualToAnchor:other multiplier:multiplier constant:constant];
    default: return [anchor constraintLessThanOrEqualToAnchor:other multiplier:multiplier constant:constant];
    }
}

static void test_anchors(void)
{
    Flavor *system = [Flavor new], *ours = [Flavor new];
    system.system = YES;
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    UIView *plain = [[UIView alloc] initWithFrame:CGRectZero];
    UILabel *text = label(@"Anchor", 17);
    [root addSubview:plain];
    [root addSubview:text];
    NSDictionary *classes = @{@0: @"CharonHostNSLayoutXAxisAnchor", @1: @"CharonHostNSLayoutYAxisAnchor", @2: @"CharonHostNSLayoutDimension"};
    for (NSString *name in anchor_names()) {
        id first = [ours anchor:plain named:name];
        CHECK(first == [ours anchor:plain named:name], NAMED(@"%@ is cached on the view", name));
        CHECK([first isKindOfClass:NSClassFromString(classes[@(anchor_kind(name))])], NAMED(@"%@ has the axis class", name));
        CHECK([first isKindOfClass:NSClassFromString(@"CharonHostNSLayoutAnchor")], NAMED(@"%@ is an NSLayoutAnchor", name));
        CHECK(first != [ours anchor:text named:name], NAMED(@"%@ differs between views", name));
        CHECK([[first description] containsString:@"UIView"], NAMED(@"%@ description names its item", name));
    }
    int compared = 0, mismatched = 0;
    for (NSString *name in anchor_names()) {
        for (NSString *otherName in anchor_names()) {
            for (NSArray *items in @[@[plain, root], @[text, plain], @[plain, text], @[text, text]]) {
                for (NSInteger method = 0; method < 15; method++) {
                    BOOL dimension = anchor_kind(name) == 2 && anchor_kind(otherName) == 2;
                    if (anchor_kind(name) != 2 && method >= 6)
                        continue;
                    if (!dimension && anchor_kind(otherName) == 2 && method >= 6)
                        continue;
                    NSLayoutConstraint *a = nil, *b = nil;
                    NSString *systemException = nil, *ourException = nil;
                    @try { a = make_constraint([system anchor:items[0] named:name], method, [system anchor:items[1] named:otherName], 0.5, 12.5); } @catch (NSException *exception) { systemException = exception.name; }
                    @try { b = make_constraint([ours anchor:items[0] named:name], method, [ours anchor:items[1] named:otherName], 0.5, 12.5); } @catch (NSException *exception) { ourException = exception.name; }
                    if (systemException || ourException) {
                        compared++;
                        if (![systemException isEqual:ourException]) {
                            mismatched++;
                            printf("anchor exception mismatch %s -> %s: system %s ours %s\n", name.UTF8String, otherName.UTF8String, systemException.UTF8String, ourException.UTF8String);
                        }
                        continue;
                    }
                    BOOL constant = method >= 6 && method <= 8;
                    BOOL same = a.firstItem == b.firstItem && a.secondItem == b.secondItem
                        && b.firstAttribute == expected_attribute(a.firstAttribute, b.firstItem)
                        && b.secondAttribute == (constant ? NSLayoutAttributeNotAnAttribute : expected_attribute(a.secondAttribute, b.secondItem))
                        && a.relation == b.relation && a.multiplier == b.multiplier && a.constant == b.constant && a.priority == b.priority
                        && ![system isActive:b];
                    compared++;
                    if (!same) {
                        mismatched++;
                        printf("anchor mismatch %s.%s method %ld: system %s ours %s\n", NSStringFromClass([items[0] class]).UTF8String, name.UTF8String, (long)method, a.description.UTF8String, b.description.UTF8String);
                    }
                }
            }
        }
    }
    printf("anchor constraints compared=%d\n", compared);
    CHECK(compared > 1000 && mismatched == 0, "anchor constraints match the system's items, attributes, relation, multiplier, constant and priority");

    for (NSInteger round = 0; round < 2; round++) {
        NSMutableArray *systemViews = [NSMutableArray array], *ourViews = [NSMutableArray array];
        UIView *roots[2];
        for (NSInteger flavorIndex = 0; flavorIndex < 2; flavorIndex++) {
            Flavor *flavor = flavorIndex ? ours : system;
            UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
            UILabel *big = label(@"Big", 30), *small = label(@"small", 11);
            SizedView *box = sized(30, 30);
            UIView *filler = [[UIView alloc] initWithFrame:CGRectZero];
            for (UIView *view in @[big, small, box, filler]) {
                view.translatesAutoresizingMaskIntoConstraints = NO;
                [container addSubview:view];
            }
            NSArray *constraints = @[
                [[flavor anchor:big named:@"leadingAnchor"] constraintEqualToAnchor:[flavor anchor:container named:@"leadingAnchor"] constant:10],
                [[flavor anchor:big named:@"topAnchor"] constraintEqualToAnchor:[flavor anchor:container named:@"topAnchor"] constant:20],
                [[flavor anchor:small named:@"leadingAnchor"] constraintEqualToAnchor:[flavor anchor:big named:@"trailingAnchor"] constant:4],
                round ? [[flavor anchor:small named:@"lastBaselineAnchor"] constraintEqualToAnchor:[flavor anchor:big named:@"lastBaselineAnchor"]] : [[flavor anchor:small named:@"firstBaselineAnchor"] constraintEqualToAnchor:[flavor anchor:big named:@"firstBaselineAnchor"]],
                [[flavor anchor:box named:@"firstBaselineAnchor"] constraintEqualToAnchor:[flavor anchor:small named:@"lastBaselineAnchor"] constant:2],
                [[flavor anchor:box named:@"leftAnchor"] constraintGreaterThanOrEqualToAnchor:[flavor anchor:small named:@"rightAnchor"] constant:3],
                [[flavor anchor:filler named:@"centerXAnchor"] constraintEqualToAnchor:[flavor anchor:container named:@"centerXAnchor"]],
                [[flavor anchor:filler named:@"centerYAnchor"] constraintEqualToAnchor:[flavor anchor:box named:@"bottomAnchor"] constant:40],
                [[flavor anchor:filler named:@"widthAnchor"] constraintEqualToAnchor:[flavor anchor:container named:@"widthAnchor"] multiplier:0.25 constant:7],
                [[flavor anchor:filler named:@"heightAnchor"] constraintLessThanOrEqualToConstant:45],
                [[flavor anchor:filler named:@"heightAnchor"] constraintGreaterThanOrEqualToAnchor:[flavor anchor:box named:@"widthAnchor"] multiplier:1.5]
            ];
            [NSLayoutConstraint activateConstraints:constraints];
            [container layoutIfNeeded];
            roots[flavorIndex] = container;
            [flavorIndex ? ourViews : systemViews addObjectsFromArray:@[big, small, box, filler]];
        }
        compare_layouts(round ? @"layout from anchor constraints with last baselines" : @"layout from anchor constraints with first baselines", roots[0], systemViews, roots[1], ourViews);
    }
}

static void test_activation(void)
{
    if (!legacy)
        return;
    Flavor *system = [Flavor new], *ours = [Flavor new];
    system.system = YES;
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    UIView *left = [UIView new], *right = [UIView new], *leftChild = [UIView new], *rightChild = [UIView new], *loner = [UIView new];
    [root addSubview:left];
    [root addSubview:right];
    [left addSubview:leftChild];
    [right addSubview:rightChild];
    NSArray *pairs = @[@[leftChild, rightChild], @[leftChild, left], @[left, leftChild], @[leftChild, root], @[left, right], @[rightChild, [NSNull null]]];
    for (NSArray *pair in pairs) {
        id second = pair[1] == [NSNull null] ? nil : pair[1];
        NSLayoutConstraint *mine = [NSLayoutConstraint constraintWithItem:pair[0] attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:second attribute:second ? NSLayoutAttributeWidth : NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
        NSLayoutConstraint *theirs = [NSLayoutConstraint constraintWithItem:pair[0] attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:second attribute:second ? NSLayoutAttributeWidth : NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
        CHECK(![ours isActive:mine], "new constraint is inactive");
        [ours setActive:YES constraint:mine];
        [system setActive:YES constraint:theirs];
        UIView *mineHolder = nil, *theirsHolder = nil;
        for (UIView *view in @[root, left, right, leftChild, rightChild]) {
            if ([view.constraints indexOfObjectIdenticalTo:mine] != NSNotFound)
                mineHolder = view;
            if ([view.constraints indexOfObjectIdenticalTo:theirs] != NSNotFound)
                theirsHolder = view;
        }
        CHECK(mineHolder && mineHolder == theirsHolder, "activation installs the constraint on the same view as the system");
        CHECK([ours isActive:mine] && [system isActive:mine], "activated constraint is active for both implementations");
        CHECK([ours isActive:theirs], "system-activated constraint is active for ours");
        [ours setActive:YES constraint:mine];
        NSUInteger installed = 0;
        for (NSLayoutConstraint *constraint in mineHolder.constraints)
            installed += constraint == mine;
        CHECK(installed == 1, "activating twice installs once");
        [ours setActive:NO constraint:mine];
        [ours setActive:NO constraint:theirs];
        CHECK(![system isActive:mine] && ![system isActive:theirs] && [mineHolder.constraints indexOfObjectIdenticalTo:mine] == NSNotFound, "deactivation removes the constraint");
    }
    NSLayoutConstraint *a = [NSLayoutConstraint constraintWithItem:leftChild attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:rightChild attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
    NSLayoutConstraint *b = [NSLayoutConstraint constraintWithItem:left attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeTop multiplier:1 constant:0];
    [ours activate:@[a, b]];
    CHECK([system isActive:a] && [system isActive:b], "activateConstraints activates every constraint");
    [ours deactivate:@[a, b]];
    CHECK(![system isActive:a] && ![system isActive:b], "deactivateConstraints deactivates every constraint");
    NSString *systemException = nil, *ourException = nil;
    NSLayoutConstraint *orphan = [NSLayoutConstraint constraintWithItem:loner attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
    @try { [system setActive:YES constraint:orphan]; } @catch (NSException *exception) { systemException = exception.name; }
    @try { [ours setActive:YES constraint:orphan]; } @catch (NSException *exception) { ourException = exception.name; }
    CHECK_EQUAL(ourException, systemException, "activating without a common ancestor raises the same exception");
    CHECK(![ours isActive:orphan], "failed activation leaves the constraint inactive");
    NSMutableArray *records[2] = {[NSMutableArray array], [NSMutableArray array]};
    for (int index = 0; index < 2; index++) {
        Flavor *flavor = index ? ours : system;
        NSMutableArray *record = records[index];
        UIView *top = [UIView new], *first = [UIView new], *second = [UIView new], *child = [UIView new];
        [top addSubview:first];
        [top addSubview:second];
        [first addSubview:child];
        NSArray *names = @[@"top", @"first", @"second", @"child"];
        NSArray *views = @[top, first, second, child];
        NSString * (^holder)(NSLayoutConstraint *) = ^NSString *(NSLayoutConstraint *constraint) {
            for (NSUInteger position = 0; position < views.count; position++)
                if ([[views[position] constraints] indexOfObjectIdenticalTo:constraint] != NSNotFound)
                    return names[position];
            return @"none";
        };
        NSLayoutConstraint *size = [NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
        [flavor setActive:YES constraint:size];
        [record addObject:[@"a size constraint is held by " stringByAppendingString:holder(size)]];
        UIView *loneView = [UIView new];
        NSLayoutConstraint *lone = [NSLayoutConstraint constraintWithItem:loneView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
        [flavor setActive:YES constraint:lone];
        [record addObject:[NSString stringWithFormat:@"a view without a superview holds its own size constraint %d", [loneView.constraints indexOfObjectIdenticalTo:(id)lone] != NSNotFound]];
        NSLayoutConstraint *ancestor = [NSLayoutConstraint constraintWithItem:first attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:child attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
        [flavor setActive:YES constraint:ancestor];
        [record addObject:[@"a constraint between a view and its descendant is held by " stringByAppendingString:holder(ancestor)]];
        NSLayoutConstraint *leaving = [NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:second attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
        [flavor setActive:YES constraint:leaving];
        [second removeFromSuperview];
        [record addObject:[NSString stringWithFormat:@"a constraint outlives its view's removal: active %d held by %@", [flavor isActive:leaving], holder(leaving)]];
        NSLayoutConstraint *added = [NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
        [top addConstraint:added];
        [record addObject:[NSString stringWithFormat:@"a constraint added by hand is active %d", [flavor isActive:added]]];
        [flavor setActive:YES constraint:added];
        [record addObject:[@"activating it again leaves it on " stringByAppendingString:holder(added)]];
        [top removeConstraint:added];
        [record addObject:[NSString stringWithFormat:@"removing it by hand makes it inactive %d", ![flavor isActive:added]]];
        NSLayoutConstraint *never = [NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:9];
        [flavor setActive:NO constraint:never];
        [record addObject:@"deactivating a constraint that was never active is quiet"];
        [flavor activate:nil];
        [flavor deactivate:nil];
        [record addObject:@"a nil array of constraints is quiet"];
        UIView *third = [UIView new], *stranger = [UIView new];
        [top addSubview:third];
        NSLayoutConstraint *good = [NSLayoutConstraint constraintWithItem:third attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
        NSLayoutConstraint *bad = [NSLayoutConstraint constraintWithItem:third attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:stranger attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
        NSLayoutConstraint *after = [NSLayoutConstraint constraintWithItem:third attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
        NSString *raised = @"nothing";
        @try { [flavor activate:@[good, bad, after]]; } @catch (NSException *exception) { raised = exception.name; }
        [record addObject:[NSString stringWithFormat:@"a bad constraint in a list raises %@ after the ones before it: %d %d %d", raised, [flavor isActive:good], [flavor isActive:bad], [flavor isActive:after]]];
        NSLayoutConstraint *twice = [NSLayoutConstraint constraintWithItem:third attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:9];
        [flavor activate:@[twice, twice]];
        NSUInteger copies = 0;
        for (NSLayoutConstraint *constraint in third.constraints)
            copies += constraint == twice;
        [record addObject:[NSString stringWithFormat:@"a constraint listed twice is installed %lu time", (unsigned long)copies]];
        id guide = [[flavor guideClass] new];
        NSLayoutConstraint *ownerless = [[flavor anchor:guide named:@"widthAnchor"] constraintEqualToConstant:5];
        raised = @"nothing";
        @try { [flavor setActive:YES constraint:ownerless]; } @catch (NSException *exception) { raised = exception.name; }
        [record addObject:[NSString stringWithFormat:@"a guide without an owner: %@, active %d", raised, [flavor isActive:ownerless]]];
        [flavor addGuide:guide to:top];
        NSLayoutConstraint *guided = [[flavor anchor:guide named:@"leadingAnchor"] constraintEqualToAnchor:[flavor anchor:child named:@"leadingAnchor"]];
        [flavor setActive:YES constraint:guided];
        [record addObject:[@"a guide and a view are held by " stringByAppendingString:holder(guided)]];
        NSLayoutConstraint *guideSize = [[flavor anchor:guide named:@"widthAnchor"] constraintEqualToConstant:5];
        [flavor setActive:YES constraint:guideSize];
        [record addObject:[@"a guide's own size is held by " stringByAppendingString:holder(guideSize)]];
        [flavor removeGuide:guide from:top];
        [record addObject:[NSString stringWithFormat:@"removing a guide takes its constraints with it: %d %d, %lu held", [flavor isActive:guided], [flavor isActive:guideSize], (unsigned long)top.constraints.count]];
        [flavor addGuide:guide to:top];
        [record addObject:[NSString stringWithFormat:@"adding it again does not bring them back: %d %d, %lu held", [flavor isActive:guided], [flavor isActive:guideSize], (unsigned long)top.constraints.count]];
        [flavor setActive:NO constraint:size];
        [record addObject:[NSString stringWithFormat:@"a deactivated constraint keeps its items %d", size.firstItem == child]];
    }
    CHECK(records[0].count == records[1].count, "the activation records are as long");
    for (NSUInteger position = 0; position < records[0].count && position < records[1].count; position++)
        CHECK_EQUAL(records[1][position], records[0][position], NAMED(@"activation record %lu: %@", (unsigned long)position, records[0][position]));
}

@interface MarginsView : UIView
@property (nonatomic) int changes;
@end

@implementation MarginsView
- (void)charonHostLayoutMarginsDidChange
{
    self.changes++;
}
@end

static void test_margins(void)
{
    if (!legacy)
        return;
    Flavor *system = [Flavor new], *ours = [Flavor new];
    system.system = YES;
    UIView *plain = [UIView new];
    CHECK(UIEdgeInsetsEqualToEdgeInsets([ours margins:plain], [system margins:plain]), "default layoutMargins match the system (8 on each side)");
    UIEdgeInsets values = UIEdgeInsetsMake(-5, 100, 0, 0.3);
    [ours setMargins:values view:plain];
    [system setMargins:values view:plain];
    CHECK(UIEdgeInsetsEqualToEdgeInsets([ours margins:plain], [system margins:plain]), "layoutMargins store any value like the system");
    UIView *superview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    UIView *subview = [[UIView alloc] initWithFrame:CGRectMake(5, 50, 180, 145)];
    [superview addSubview:subview];
    for (Flavor *flavor in @[system, ours])
        [flavor setMargins:UIEdgeInsetsMake(20, 30, 40, 50) view:superview];
    for (Flavor *flavor in @[system, ours])
        [flavor setPreserves:YES view:subview];
    CHECK(UIEdgeInsetsEqualToEdgeInsets([ours margins:subview], [system margins:subview]), "preserved superview margins cascade like the system");
    for (Flavor *flavor in @[system, ours])
        [flavor setMargins:UIEdgeInsetsMake(1, 2, 3, 4) view:subview];
    CHECK(UIEdgeInsetsEqualToEdgeInsets([ours margins:subview], [system margins:subview]), "preserved margins keep larger own values like the system");
    subview.frame = CGRectMake(-10, -10, 250, 250);
    CHECK(UIEdgeInsetsEqualToEdgeInsets([ours margins:subview], [system margins:subview]), "preserved margins of a view outside its superview match the system");
    subview.frame = CGRectMake(60, 70, 20, 20);
    CHECK(UIEdgeInsetsEqualToEdgeInsets([ours margins:subview], [system margins:subview]), "preserved margins of a view far from the edges match the system");
    MarginsView *observed = [MarginsView new];
    [ours setMargins:UIEdgeInsetsMake(1, 1, 1, 1) view:observed];
    CHECK(observed.changes == 1, "layoutMarginsDidChange is sent when margins change");
    [ours setMargins:UIEdgeInsetsMake(1, 1, 1, 1) view:observed];
    CHECK(observed.changes == 1, "setting equal margins sends nothing");
    [ours setPreserves:YES view:observed];
    CHECK(observed.changes == 2, "changing preservesSuperviewLayoutMargins sends layoutMarginsDidChange");

    UIView *roots[2];
    NSMutableArray *frames[2];
    for (NSInteger index = 0; index < 2; index++) {
        Flavor *flavor = index ? ours : system;
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
        UIView *child = [[UIView alloc] initWithFrame:CGRectZero];
        child.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:child];
        UILayoutGuide *guide = [flavor marginsGuide:container];
        [NSLayoutConstraint activateConstraints:@[
            [[flavor anchor:child named:@"leadingAnchor"] constraintEqualToAnchor:[flavor anchor:guide named:@"leadingAnchor"]],
            [[flavor anchor:child named:@"trailingAnchor"] constraintEqualToAnchor:[flavor anchor:guide named:@"trailingAnchor"]],
            [[flavor anchor:child named:@"topAnchor"] constraintEqualToAnchor:[flavor anchor:guide named:@"topAnchor"]],
            [[flavor anchor:child named:@"bottomAnchor"] constraintEqualToAnchor:[flavor anchor:guide named:@"bottomAnchor"]]
        ]];
        [container layoutIfNeeded];
        frames[index] = [NSMutableArray arrayWithObjects:[NSValue valueWithCGRect:child.frame], [NSValue valueWithCGRect:guide.layoutFrame], nil];
        [flavor setMargins:UIEdgeInsetsMake(11, 22, 33, 44) view:container];
        layout_tree(container);
        [frames[index] addObject:[NSValue valueWithCGRect:child.frame]];
        [frames[index] addObject:[NSValue valueWithCGRect:guide.layoutFrame]];
        roots[index] = container;
    }
    CHECK_EQUAL(frames[1], frames[0], "layoutMarginsGuide follows margins and their changes like the system");
}

static void test_guides(void)
{
    Flavor *system = [Flavor new], *ours = [Flavor new];
    system.system = YES;
    for (Flavor *flavor in @[system, ours]) {
        NSString *who = flavor.system ? @"system" : @"ours";
        UILayoutGuide *guide = [[flavor guideClass] new];
        CHECK_EQUAL(guide.identifier, @"", [who stringByAppendingString:@" guide identifier defaults to empty"].UTF8String);
        CHECK(CGRectEqualToRect(guide.layoutFrame, CGRectZero) && guide.owningView == nil, [who stringByAppendingString:@" new guide has no frame or owner"].UTF8String);
        UIView *first = [UIView new], *second = [UIView new];
        [flavor addGuide:guide to:first];
        CHECK(guide.owningView == first && [[flavor guidesOf:first] containsObject:guide], [who stringByAppendingString:@" addLayoutGuide sets the owner"].UTF8String);
        [flavor addGuide:guide to:second];
        CHECK(guide.owningView == second && ![[flavor guidesOf:first] containsObject:guide] && [flavor guidesOf:second].count == 1, [who stringByAppendingString:@" adding to another view moves the guide"].UTF8String);
        [flavor removeGuide:guide from:first];
        CHECK(guide.owningView == second, [who stringByAppendingString:@" removing from a view that does not own the guide does nothing"].UTF8String);
        [flavor removeGuide:guide from:second];
        CHECK(guide.owningView == nil && [flavor guidesOf:second].count == 0, [who stringByAppendingString:@" removeLayoutGuide clears the owner"].UTF8String);
        UIView *margins = [UIView new];
        UILayoutGuide *marginsGuide = [flavor marginsGuide:margins];
        CHECK(marginsGuide == [flavor marginsGuide:margins] && [[flavor guidesOf:margins] containsObject:marginsGuide], [who stringByAppendingString:@" layoutMarginsGuide is stable and listed"].UTF8String);
        CHECK_EQUAL(marginsGuide.identifier, @"UIViewLayoutMarginsGuide", [who stringByAppendingString:@" layoutMarginsGuide identifier"].UTF8String);
    }
    UIView *roots[2];
    NSMutableArray *views[2];
    for (NSInteger index = 0; index < 2; index++) {
        Flavor *flavor = index ? ours : system;
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
        UILayoutGuide *gap = [[flavor guideClass] new];
        [flavor addGuide:gap to:container];
        SizedView *a = sized(40, 40), *b = sized(60, 20);
        for (UIView *view in @[a, b]) {
            view.translatesAutoresizingMaskIntoConstraints = NO;
            [container addSubview:view];
        }
        [NSLayoutConstraint activateConstraints:@[
            [[flavor anchor:a named:@"leftAnchor"] constraintEqualToAnchor:[flavor anchor:container named:@"leftAnchor"] constant:10],
            [[flavor anchor:gap named:@"leftAnchor"] constraintEqualToAnchor:[flavor anchor:a named:@"rightAnchor"]],
            [[flavor anchor:gap named:@"widthAnchor"] constraintEqualToAnchor:[flavor anchor:container named:@"widthAnchor"] multiplier:0.25],
            [[flavor anchor:b named:@"leftAnchor"] constraintEqualToAnchor:[flavor anchor:gap named:@"rightAnchor"]],
            [[flavor anchor:gap named:@"topAnchor"] constraintEqualToAnchor:[flavor anchor:a named:@"centerYAnchor"]],
            [[flavor anchor:gap named:@"heightAnchor"] constraintEqualToConstant:30],
            [[flavor anchor:b named:@"topAnchor"] constraintEqualToAnchor:[flavor anchor:gap named:@"bottomAnchor"]],
            [[flavor anchor:a named:@"topAnchor"] constraintEqualToAnchor:[flavor anchor:container named:@"topAnchor"] constant:5]
        ]];
        UILayoutGuide *readable = [flavor readableGuide:container];
        UIView *text = [[UIView alloc] initWithFrame:CGRectZero];
        text.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:text];
        [NSLayoutConstraint activateConstraints:@[
            [[flavor anchor:text named:@"leadingAnchor"] constraintEqualToAnchor:[flavor anchor:readable named:@"leadingAnchor"]],
            [[flavor anchor:text named:@"trailingAnchor"] constraintEqualToAnchor:[flavor anchor:readable named:@"trailingAnchor"]],
            [[flavor anchor:text named:@"bottomAnchor"] constraintEqualToAnchor:[flavor anchor:readable named:@"bottomAnchor"]],
            [[flavor anchor:text named:@"heightAnchor"] constraintEqualToConstant:10]
        ]];
        layout_tree(container);
        views[index] = [NSMutableArray arrayWithObjects:a, b, text, nil];
        roots[index] = container;
        if (index) {
            UIView *helper = [(id)gap charon_view];
            CHECK(helper.superview == container && helper.hidden && !helper.userInteractionEnabled, "our layout guide is backed by a hidden view that ignores touches");
            CHECK([container hitTest:helper.center withEvent:nil] != helper, "hit testing never returns the guide's view");
            CHECK(close_enough(gap.layoutFrame.origin.x, 50) && close_enough(gap.layoutFrame.size.width, 80) && close_enough(gap.layoutFrame.origin.y, 25) && close_enough(gap.layoutFrame.size.height, 30), "layoutFrame reports the guide's rectangle");
        }
    }
    compare_layouts(@"views constrained to a layout guide and readableContentGuide in a narrow view", roots[0], views[0], roots[1], views[1]);
    UIView *wide = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2000, 100)];
    UILayoutGuide *readable = [ours readableGuide:wide];
    layout_tree(wide);
    CHECK(close_enough(readable.layoutFrame.size.width, 672) && close_enough(CGRectGetMidX(readable.layoutFrame), 1000), "readableContentGuide limits width to 672 and centers in a wide view");
    UILayoutGuide *archived = [[ours guideClass] new];
    archived.identifier = @"kept";
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:archived forKey:@"root"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
    unarchiver.requiresSecureCoding = NO;
    CHECK_EQUAL([[unarchiver decodeObjectForKey:@"root"] identifier], @"kept", "layout guide identifier survives archiving");
}

static NSString *index_of(UIView *view, UIView *stack, NSArray *views)
{
    if (view == stack)
        return @"self";
    NSUInteger index = [views indexOfObjectIdenticalTo:view];
    return index == NSNotFound ? NSStringFromClass([view class]) : [NSString stringWithFormat:@"%lu", (unsigned long)index];
}

static void test_stack_api(void)
{
    Flavor *system = [Flavor new], *ours = [Flavor new];
    system.system = YES;
    NSMutableDictionary *results[2];
    for (NSInteger index = 0; index < 2; index++) {
        Flavor *flavor = index ? ours : system;
        NSMutableDictionary *r = results[index] = [NSMutableDictionary dictionary];
        UIStackView *stack = [[[flavor stackClass] alloc] initWithFrame:CGRectZero];
        r[@"defaults"] = [NSString stringWithFormat:@"%ld %ld %ld %g %d %d %@ %@ %@ %d", (long)stack.axis, (long)stack.distribution, (long)stack.alignment, stack.spacing, stack.baselineRelativeArrangement, stack.layoutMarginsRelativeArrangement, NSStringFromUIEdgeInsets([flavor margins:stack]), stack.arrangedSubviews, NSStringFromCGSize(stack.intrinsicContentSize), stack.translatesAutoresizingMaskIntoConstraints];
        UIView *a = [UIView new], *b = [UIView new], *c = [UIView new], *foreign = [UIView new];
        UIStackView *t = [[[flavor stackClass] alloc] initWithArrangedSubviews:@[a, b, c]];
        NSString *(^order)(void) = ^{
            return [NSString stringWithFormat:@"%lu %lu %lu count=%lu", (unsigned long)[t.arrangedSubviews indexOfObject:a], (unsigned long)[t.arrangedSubviews indexOfObject:b], (unsigned long)[t.arrangedSubviews indexOfObject:c], (unsigned long)t.arrangedSubviews.count];
        };
        [t insertArrangedSubview:a atIndex:2];
        r[@"move to 2"] = order();
        [t insertArrangedSubview:a atIndex:3];
        r[@"move to count"] = order();
        [t insertArrangedSubview:c atIndex:0];
        r[@"move to 0"] = order();
        @try { [t insertArrangedSubview:[UIView new] atIndex:5]; r[@"insert past end"] = @"no exception"; } @catch (NSException *exception) { r[@"insert past end"] = exception.name; }
        @try { [t insertArrangedSubview:a atIndex:4]; r[@"move past end"] = @"no exception"; } @catch (NSException *exception) { r[@"move past end"] = exception.name; }
        [t removeArrangedSubview:foreign];
        r[@"remove foreign"] = order();
        [t addSubview:foreign];
        r[@"tamic"] = [NSString stringWithFormat:@"%d %d %d", a.translatesAutoresizingMaskIntoConstraints, foreign.translatesAutoresizingMaskIntoConstraints, t.translatesAutoresizingMaskIntoConstraints];
        [t removeArrangedSubview:b];
        r[@"remove keeps subview"] = [NSString stringWithFormat:@"%@ %d", order(), b.superview == t];
        [c removeFromSuperview];
        r[@"removeFromSuperview"] = order();
        UIStackView *u = [[[flavor stackClass] alloc] initWithFrame:CGRectZero];
        [u addArrangedSubview:a];
        r[@"move between stacks"] = [NSString stringWithFormat:@"%@ %lu %d", order(), (unsigned long)u.arrangedSubviews.count, a.superview == u];
        UIView *existing = [UIView new];
        [u addSubview:existing];
        [u addArrangedSubview:existing];
        r[@"existing subview"] = [NSString stringWithFormat:@"%lu %lu", (unsigned long)[u.subviews indexOfObject:existing], (unsigned long)u.arrangedSubviews.count];
    }
    for (NSString *key in results[0])
        CHECK_EQUAL(results[1][key], results[0][key], [@"stack API: " stringByAppendingString:key].UTF8String);
    CHECK([((UIView *)[[[ours stackClass] alloc] initWithFrame:CGRectZero]).layer isKindOfClass:[CATransformLayer class]], "stack view is non-rendering: its layer is a CATransformLayer as on iOS 9");

    NSArray *configs = @[@[@0, @0], @[@0, @1], @[@0, @2], @[@0, @3], @[@0, @4], @[@0, @5], @[@1, @0], @[@1, @3]];
    for (NSArray *config in configs) {
        NSString *answers[2];
        CGSize fitting[2];
        for (NSInteger index = 0; index < 2; index++) {
            Flavor *flavor = index ? ours : system;
            NSMutableArray *views = [NSMutableArray array];
            StackConfig c = {[config[0] integerValue], 0, [config[1] integerValue], 3, 0, NO, 0, 2};
            UIView *root = build_stack(flavor, c, views);
            UIStackView *stack = views[0];
            answers[index] = [NSString stringWithFormat:@"first=%@ last=%@", index_of(stack.viewForFirstBaselineLayout, stack, views), index_of(stack.viewForLastBaselineLayout, stack, views)];
            fitting[index] = [stack systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
            (void)root;
        }
        CHECK_EQUAL(answers[1], answers[0], NAMED(@"viewForFirst/LastBaselineLayout axis=%@ alignment=%@", config[0], config[1]));
        CHECK(close_enough(fitting[0].width, fitting[1].width) && close_enough(fitting[0].height, fitting[1].height), NAMED(@"systemLayoutSizeFittingSize axis=%@ alignment=%@", config[0], config[1]));
    }

    for (NSInteger axis = 0; axis < 2; axis++) {
        UIView *roots[2];
        NSMutableArray *views[2];
        for (NSInteger index = 0; index < 2; index++) {
            Flavor *flavor = index ? ours : system;
            views[index] = [NSMutableArray array];
            StackConfig c = {axis, UIStackViewDistributionEqualSpacing, UIStackViewAlignmentCenter, 4, 0, YES, 1, 1};
            roots[index] = build_stack(flavor, c, views[index]);
            UIStackView *stack = views[index][0];
            [stack.arrangedSubviews[2] setHidden:YES];
            layout_tree(roots[index]);
            [stack.arrangedSubviews[2] setHidden:NO];
            [stack.arrangedSubviews[0] setHidden:YES];
            layout_tree(roots[index]);
            [stack.arrangedSubviews[0] setHidden:NO];
            stack.spacing = 9;
            stack.alignment = UIStackViewAlignmentTrailing;
            [flavor setMargins:UIEdgeInsetsMake(6, 6, 6, 6) view:stack];
            [stack insertArrangedSubview:sized(33, 33) atIndex:1];
            [stack removeArrangedSubview:stack.arrangedSubviews[3]];
            layout_tree(roots[index]);
            [views[index] setArray:@[]];
            collect(stack, views[index]);
        }
        compare_layouts([NSString stringWithFormat:@"stack after hiding, unhiding and reconfiguring, axis=%ld", (long)axis], roots[0], views[0], roots[1], views[1]);
    }

    UIStackView *original = [[UIStackView alloc] initWithArrangedSubviews:@[sized(20, 20), label(@"coded", 14), sized(30, 10)]];
    original.axis = UILayoutConstraintAxisVertical;
    original.distribution = UIStackViewDistributionEqualSpacing;
    original.alignment = UIStackViewAlignmentTrailing;
    original.spacing = 7;
    original.baselineRelativeArrangement = YES;
    original.layoutMarginsRelativeArrangement = YES;
    original.layoutMargins = UIEdgeInsetsMake(1, 2, 3, 4);
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:original forKey:@"root"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
    unarchiver.requiresSecureCoding = NO;
    [unarchiver setClass:[ours stackClass] forClassName:@"UIStackView"];
    UIStackView *decoded = [unarchiver decodeObjectForKey:@"root"];
    CHECK([decoded isKindOfClass:[ours stackClass]], "initWithCoder decodes a system-archived stack view");
    CHECK(decoded.axis == original.axis && decoded.distribution == original.distribution && decoded.alignment == original.alignment && decoded.spacing == original.spacing && decoded.baselineRelativeArrangement && decoded.layoutMarginsRelativeArrangement, "initWithCoder restores stack properties");
    CHECK(decoded.arrangedSubviews.count == 3 && [decoded.arrangedSubviews[1] isKindOfClass:[UILabel class]] && decoded.arrangedSubviews[1].superview == decoded, "initWithCoder restores arranged subviews");
    CHECK(UIEdgeInsetsEqualToEdgeInsets([ours margins:decoded], UIEdgeInsetsMake(1, 2, 3, 4)), "initWithCoder restores layout margins");
    NSKeyedUnarchiver *systemUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
    systemUnarchiver.requiresSecureCoding = NO;
    original = [systemUnarchiver decodeObjectForKey:@"root"];
    UIView *systemRoot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)], *ourRoot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    [systemRoot addSubview:original];
    [ourRoot addSubview:decoded];
    original.frame = decoded.frame = CGRectMake(10, 10, 200, 200);
    layout_tree(systemRoot);
    layout_tree(ourRoot);
    NSMutableArray *systemViews = [NSMutableArray array], *ourViews = [NSMutableArray array];
    collect(original, systemViews);
    collect(decoded, ourViews);
    compare_layouts(@"decoded stack view lays out like the system one decoded from the same archive", systemRoot, systemViews, ourRoot, ourViews);
    archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:decoded forKey:@"root"];
    [archiver finishEncoding];
    unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
    unarchiver.requiresSecureCoding = NO;
    [unarchiver setClass:[UIStackView class] forClassName:@"CharonHostUIStackView"];
    UIStackView *back = [unarchiver decodeObjectForKey:@"root"];
    CHECK([back isKindOfClass:[UIStackView class]] && back.axis == original.axis && back.distribution == original.distribution && back.alignment == original.alignment && back.spacing == original.spacing && back.arrangedSubviews.count == 3, "encodeWithCoder writes an archive the system stack view decodes");

    Class subclass = objc_allocateClassPair([ours stackClass], "ClientStackView", 0);
    objc_registerClassPair(subclass);
    UIStackView *client = [[subclass alloc] initWithArrangedSubviews:@[sized(1, 1)]];
    CHECK([client isKindOfClass:[ours stackClass]] && client.arrangedSubviews.count == 1, "client subclasses of the stack view work");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        legacy = [UIView instancesRespondToSelector:NSSelectorFromString(@"charonHostLayoutMargins")];
        printf("variant %s\n", legacy ? "legacy" : "native");
        test_anchors();
        test_activation();
        test_margins();
        test_guides();
        test_stack_api();
        test_baseline_relative_matrix();
        test_stack_matrix();
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
