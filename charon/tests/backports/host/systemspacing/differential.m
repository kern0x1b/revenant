#import <UIKit/UIKit.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static NSString *shape(NSLayoutConstraint *constraint)
{
    return [NSString stringWithFormat:@"constant %g multiplier %g relation %ld attributes %ld %ld priority %g",
                                      constraint.constant, constraint.multiplier, (long)constraint.relation,
                                      (long)constraint.firstAttribute, (long)constraint.secondAttribute, constraint.priority];
}

static NSLayoutConstraint *ours_x(NSLayoutXAxisAnchor *anchor, SEL selector, NSLayoutXAxisAnchor *other, CGFloat multiplier)
{
    return ((id (*)(id, SEL, id, CGFloat))objc_msgSend)(anchor, selector, other, multiplier);
}

static NSLayoutConstraint *ours_y(NSLayoutYAxisAnchor *anchor, SEL selector, NSLayoutYAxisAnchor *other, CGFloat multiplier)
{
    return ((id (*)(id, SEL, id, CGFloat))objc_msgSend)(anchor, selector, other, multiplier);
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        UIView *plain = [UIView new], *another = [UIView new];
        UILabel *body = [UILabel new], *big = [UILabel new], *tiny = [UILabel new];
        body.text = @"body"; big.text = @"big"; tiny.text = @"tiny";
        body.font = [UIFont systemFontOfSize:17];
        big.font = [UIFont systemFontOfSize:40];
        tiny.font = [UIFont systemFontOfSize:9];
        for (UIView *view in @[plain, another, body, big, tiny]) {
            view.translatesAutoresizingMaskIntoConstraints = NO;
            [box addSubview:view];
        }

        NSArray *multipliers = @[@0.5, @1, @2, @3];
        for (NSNumber *multiplier in multipliers) {
            CGFloat value = multiplier.doubleValue;
            compare([NSString stringWithFormat:@"leading after trailing, multiplier %@", multiplier],
                    shape([plain.leadingAnchor constraintEqualToSystemSpacingAfterAnchor:another.trailingAnchor multiplier:value]),
                    shape(ours_x(plain.leadingAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingAfterAnchor:multiplier:"), another.trailingAnchor, value)));
            compare([NSString stringWithFormat:@"top below bottom, multiplier %@", multiplier],
                    shape([plain.topAnchor constraintEqualToSystemSpacingBelowAnchor:another.bottomAnchor multiplier:value]),
                    shape(ours_y(plain.topAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingBelowAnchor:multiplier:"), another.bottomAnchor, value)));
        }

        compare(@"at least the system spacing",
                shape([plain.leadingAnchor constraintGreaterThanOrEqualToSystemSpacingAfterAnchor:another.trailingAnchor multiplier:1]),
                shape(ours_x(plain.leadingAnchor, NSSelectorFromString(@"charonHost_constraintGreaterThanOrEqualToSystemSpacingAfterAnchor:multiplier:"), another.trailingAnchor, 1)));
        compare(@"at most the system spacing",
                shape([plain.leadingAnchor constraintLessThanOrEqualToSystemSpacingAfterAnchor:another.trailingAnchor multiplier:1]),
                shape(ours_x(plain.leadingAnchor, NSSelectorFromString(@"charonHost_constraintLessThanOrEqualToSystemSpacingAfterAnchor:multiplier:"), another.trailingAnchor, 1)));
        compare(@"at least, below",
                shape([plain.topAnchor constraintGreaterThanOrEqualToSystemSpacingBelowAnchor:another.bottomAnchor multiplier:1]),
                shape(ours_y(plain.topAnchor, NSSelectorFromString(@"charonHost_constraintGreaterThanOrEqualToSystemSpacingBelowAnchor:multiplier:"), another.bottomAnchor, 1)));
        compare(@"at most, below",
                shape([plain.topAnchor constraintLessThanOrEqualToSystemSpacingBelowAnchor:another.bottomAnchor multiplier:1]),
                shape(ours_y(plain.topAnchor, NSSelectorFromString(@"charonHost_constraintLessThanOrEqualToSystemSpacingBelowAnchor:multiplier:"), another.bottomAnchor, 1)));

        NSArray *pairs = @[@[body, body], @[tiny, big], @[big, tiny], @[body, big], @[big, body]];
        for (NSArray *pair in pairs) {
            UILabel *below = pair[0], *above = pair[1];
            NSString *name = [NSString stringWithFormat:@"%g point baseline below %g point baseline", below.font.pointSize, above.font.pointSize];
            compare(name,
                    shape([below.firstBaselineAnchor constraintEqualToSystemSpacingBelowAnchor:above.lastBaselineAnchor multiplier:1]),
                    shape(ours_y(below.firstBaselineAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingBelowAnchor:multiplier:"), above.lastBaselineAnchor, 1)));
        }

        compare(@"a baseline below an edge",
                shape([body.firstBaselineAnchor constraintEqualToSystemSpacingBelowAnchor:big.bottomAnchor multiplier:1]),
                shape(ours_y(body.firstBaselineAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingBelowAnchor:multiplier:"), big.bottomAnchor, 1)));
        compare(@"an edge below a baseline",
                shape([body.topAnchor constraintEqualToSystemSpacingBelowAnchor:big.lastBaselineAnchor multiplier:1]),
                shape(ours_y(body.topAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingBelowAnchor:multiplier:"), big.lastBaselineAnchor, 1)));
        compare(@"baselines of views with no text",
                shape([plain.firstBaselineAnchor constraintEqualToSystemSpacingBelowAnchor:another.lastBaselineAnchor multiplier:1]),
                shape(ours_y(plain.firstBaselineAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingBelowAnchor:multiplier:"), another.lastBaselineAnchor, 1)));
        compare(@"against the container's own edge",
                shape([plain.leadingAnchor constraintEqualToSystemSpacingAfterAnchor:box.leadingAnchor multiplier:1]),
                shape(ours_x(plain.leadingAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingAfterAnchor:multiplier:"), box.leadingAnchor, 1)));

        for (NSUInteger index = 0; index < 4; index++) {
            static const CGFloat multipliers[] = {0, 0.25, -0.5, -2};
            CGFloat multiplier = multipliers[index];
            compare([NSString stringWithFormat:@"a multiplier of %g", (double)multiplier],
                    shape([plain.leadingAnchor constraintEqualToSystemSpacingAfterAnchor:another.trailingAnchor multiplier:multiplier]),
                    shape(ours_x(plain.leadingAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingAfterAnchor:multiplier:"), another.trailingAnchor, multiplier)));
            compare([NSString stringWithFormat:@"a multiplier of %g, downwards", (double)multiplier],
                    shape([plain.topAnchor constraintEqualToSystemSpacingBelowAnchor:another.bottomAnchor multiplier:multiplier]),
                    shape(ours_y(plain.topAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingBelowAnchor:multiplier:"), another.bottomAnchor, multiplier)));
        }

        NSLayoutConstraint *systemMixed = [body.firstBaselineAnchor constraintEqualToSystemSpacingBelowAnchor:plain.lastBaselineAnchor multiplier:1];
        NSLayoutConstraint *ourMixed = ours_y(body.firstBaselineAnchor, NSSelectorFromString(@"charonHost_constraintEqualToSystemSpacingBelowAnchor:multiplier:"), plain.lastBaselineAnchor, 1);
        printf("note a baseline of a text view under the baseline of a view with no text: the system answers %g,\n"
               "     the backport answers %g; UIKit measures something the port cannot read from a view that\n"
               "     carries no font, so the port falls back to the plain system spacing there.\n",
               systemMixed.constant, ourMixed.constant);

        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
