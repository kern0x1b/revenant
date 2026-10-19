#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"

@interface SizedView : UIView
@property (nonatomic) CGSize size;
@end

@implementation SizedView
- (CGSize)intrinsicContentSize
{
    return self.size;
}
@end

static SizedView *sized(CGFloat height)
{
    SizedView *view = [[SizedView alloc] initWithFrame:CGRectZero];
    view.size = CGSizeMake(100, height);
    return view;
}

static UIStackView *build(BOOL system, NSArray<UIView *> *arranged, UIView * __strong *held)
{
    Class stack_class = system ? [UIStackView class] : NSClassFromString(@"CharonHostUIStackView");
    UIStackView *stack = [[stack_class alloc] initWithArrangedSubviews:arranged];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    [root addSubview:stack];
    [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:100]];
    *held = root;
    return stack;
}

static NSArray<NSNumber *> *gaps(UIStackView *stack)
{
    UIView *root = stack.superview;
    [root setNeedsLayout];
    [root layoutIfNeeded];
    NSMutableArray<NSNumber *> *found = [NSMutableArray array];
    UIView *previous = nil;
    for (UIView *view in stack.arrangedSubviews) {
        if (view.hidden)
            continue;
        if (previous)
            [found addObject:@(CGRectGetMinY(view.frame) - CGRectGetMaxY(previous.frame))];
        previous = view;
    }
    return found;
}

static NSNumber *spacing_after(UIStackView *stack, UIView *view)
{
    return @([stack customSpacingAfterView:view]);
}

static NSString *describe(id value)
{
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for (NSNumber *number in value)
            [parts addObject:describe(number)];
        return [parts componentsJoinedByString:@" "];
    }
    CGFloat number = [value doubleValue];
    if (number == UIStackViewSpacingUseDefault)
        return @"default";
    if (number == UIStackViewSpacingUseSystem)
        return @"system";
    return [NSString stringWithFormat:@"%.1f", number];
}

static BOOL same(id one, id other)
{
    if ([one isKindOfClass:[NSArray class]] != [other isKindOfClass:[NSArray class]])
        return NO;
    if ([one isKindOfClass:[NSArray class]]) {
        if ([one count] != [other count])
            return NO;
        for (NSUInteger index = 0; index < [one count]; index++)
            if (!same([one objectAtIndex:index], [other objectAtIndex:index]))
                return NO;
        return YES;
    }
    CGFloat a = [one doubleValue], b = [other doubleValue];
    return a == b || fabs(a - b) <= 1.01;
}

static void record(NSMutableArray *into, const char *step, id value)
{
    [into addObject:@[@(step), value]];
}

static void script(BOOL system, NSMutableArray *into)
{
    NSArray<UIView *> *views = @[sized(10), sized(20), sized(30), sized(40)];
    UIView *root = nil;
    UIStackView *stack = build(system, views, &root);

    record(into, "the gaps a plain stack leaves", gaps(stack));
    record(into, "what a view nothing was set for answers", spacing_after(stack, views[0]));

    [stack setCustomSpacing:20 afterView:views[0]];
    record(into, "a custom spacing replaces the first gap", gaps(stack));
    record(into, "and the view answers it", spacing_after(stack, views[0]));
    record(into, "while its neighbour still answers default", spacing_after(stack, views[1]));

    [stack setCustomSpacing:0 afterView:views[1]];
    record(into, "a custom zero closes its own gap", gaps(stack));

    [stack setCustomSpacing:UIStackViewSpacingUseDefault afterView:views[0]];
    record(into, "the default token gives the gap back to spacing", gaps(stack));
    record(into, "and the view answers default again", spacing_after(stack, views[0]));

    [stack setCustomSpacing:UIStackViewSpacingUseSystem afterView:views[2]];
    record(into, "the system token spaces one gap on its own", gaps(stack));
    record(into, "and the view answers the token, not a number", spacing_after(stack, views[2]));

    stack.spacing = 30;
    record(into, "a larger spacing leaves the custom gaps alone", gaps(stack));
    stack.spacing = 10;

    views[1].hidden = YES;
    record(into, "a hidden view leaves the spacing of the view before it", gaps(stack));
    views[1].hidden = NO;
    record(into, "and showing it again restores the gaps", gaps(stack));

    [stack setCustomSpacing:25 afterView:views[1]];
    [stack removeArrangedSubview:views[1]];
    [stack insertArrangedSubview:views[1] atIndex:1];
    record(into, "what a view answers after leaving and coming back", spacing_after(stack, views[1]));
    record(into, "and the gaps around it", gaps(stack));

    [stack setCustomSpacing:15 afterView:views[3]];
    [stack insertArrangedSubview:views[3] atIndex:0];
    record(into, "a custom spacing travels with the view it follows", gaps(stack));
    record(into, "and the view keeps answering it", spacing_after(stack, views[3]));
    [stack setCustomSpacing:UIStackViewSpacingUseDefault afterView:views[3]];
    [stack insertArrangedSubview:views[3] atIndex:3];

    UIView *stranger = sized(11);
    [stack setCustomSpacing:50 afterView:stranger];
    record(into, "a view that is not arranged is ignored", spacing_after(stack, stranger));
    record(into, "and the gaps do not move for it", gaps(stack));

    stack.spacing = UIStackViewSpacingUseSystem;
    record(into, "the system token as the whole spacing", gaps(stack));
    stack.spacing = UIStackViewSpacingUseDefault;
    record(into, "the default token as the whole spacing closes every gap", gaps(stack));
    record(into, "and spacing answers the token it was given", @(stack.spacing));
}

static void facts_of_the_system(NSMutableArray *system)
{
    NSDictionary *found = ({
        NSMutableDictionary *pairs = [NSMutableDictionary dictionary];
        for (NSArray *entry in system)
            pairs[entry[0]] = entry[1];
        pairs;
    });
    CHECK(same(found[@"the gaps a plain stack leaves"], @[@10, @10, @10]), "the system leaves the spacing in every gap");
    CHECK([describe(found[@"what a view nothing was set for answers"]) isEqual:@"default"], "the system answers the default token for a view nothing was set for");
    CHECK(same(found[@"a custom spacing replaces the first gap"], @[@20, @10, @10]), "a custom spacing replaces that gap and no other");
    CHECK(same(found[@"a custom zero closes its own gap"], @[@20, @0, @10]), "a custom zero closes its own gap");
    CHECK(same(found[@"the default token gives the gap back to spacing"], @[@10, @0, @10]), "the default token gives the gap back to spacing");
    CHECK([describe(found[@"and the view answers the token, not a number"]) isEqual:@"system"], "the system token is answered back as the token");
    CHECK([[found[@"the system token spaces one gap on its own"] lastObject] doubleValue] > 0, "the system token leaves a gap of its own");
    NSArray<NSNumber *> *closed = found[@"the default token as the whole spacing closes every gap"];
    CHECK(closed.count == 3 && same(closed[0], @0) && same(closed[1], @0), "the default token as the spacing closes every gap it is asked for");
    CHECK(same(closed.lastObject, found[@"the system token as the whole spacing"][0]), "and leaves the one gap a custom system token holds");
    CHECK([describe(found[@"a view that is not arranged is ignored"]) isEqual:@"default"], "a spacing set after a view that is not arranged is ignored");
}

int main(void)
{
    @autoreleasepool {
        NSMutableArray *system = [NSMutableArray array], *ours = [NSMutableArray array];
        script(YES, system);
        for (NSArray *entry in system)
            printf("  system %s: %s\n", [entry[0] UTF8String], describe(entry[1]).UTF8String);
        facts_of_the_system(system);

        Class ported = NSClassFromString(@"CharonHostUIStackView");
        BOOL carried = ported != Nil
            && [ported instancesRespondToSelector:@selector(setCustomSpacing:afterView:)]
            && [ported instancesRespondToSelector:@selector(customSpacingAfterView:)];
        CHECK(carried, "the port carries the custom spacing of a stack view");
        if (carried) {
            script(NO, ours);
            for (NSArray *entry in ours)
                printf("  ours %s: %s\n", [entry[0] UTF8String], describe(entry[1]).UTF8String);
            for (NSUInteger index = 0; index < system.count; index++) {
                NSArray *mine = index < ours.count ? ours[index] : nil;
                id expected = system[index][1], actual = mine ? mine[1] : nil;
                charon_check(mine != nil && same(expected, actual), [system[index][0] UTF8String],
                             [NSString stringWithFormat:@"%@ != %@", actual ? describe(actual) : @"nothing", describe(expected)]);
            }
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
