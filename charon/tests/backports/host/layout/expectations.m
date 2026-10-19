#import <UIKit/UIKit.h>

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

static Class stackClass;

static void collect(UIView *view, NSMutableArray *views)
{
    [views addObject:view];
    if ([view isKindOfClass:stackClass]) {
        for (UIView *arranged in [(UIStackView *)view arrangedSubviews])
            collect(arranged, views);
    }
}

static void mark(UIView *view)
{
    [view setNeedsLayout];
    for (UIView *subview in view.subviews)
        mark(subview);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        stackClass = argc > 1 ? NSClassFromString(@(argv[1])) : [UIStackView class];
        NSInteger alignments[] = {UIStackViewAlignmentFill, UIStackViewAlignmentLeading, UIStackViewAlignmentCenter, UIStackViewAlignmentTrailing};
        printf("static const struct charon_stack_case charon_stack_cases[] = {\n");
        for (NSInteger nested = 0; nested < 2; nested++)
        for (NSInteger margins = 0; margins < 2; margins++)
        for (NSInteger axis = 0; axis < 2; axis++)
        for (NSInteger distribution = 0; distribution < 5; distribution++)
        for (NSInteger alignmentIndex = 0; alignmentIndex < 4; alignmentIndex++)
        for (NSInteger hidden = 0; hidden < 3; hidden++)
        for (NSInteger size = 0; size < 2; size++) {
            if ((nested || margins) && hidden == 2)
                continue;
            if (nested && margins)
                continue;
            @autoreleasepool {
                UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
                NSArray *arranged;
                if (nested) {
                    UIStackView *inner = [[stackClass alloc] initWithArrangedSubviews:@[sized(15, 10), sized(30, 12)]];
                    inner.axis = axis == 0 ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
                    inner.alignment = UIStackViewAlignmentCenter;
                    inner.spacing = 2;
                    arranged = @[sized(40, 20), inner, sized(10, 50)];
                } else {
                    arranged = @[sized(40, 20), sized(60, 30), sized(10, 50), sized(25, 25)];
                }
                UIStackView *stack = [[stackClass alloc] initWithArrangedSubviews:arranged];
                stack.axis = axis;
                stack.distribution = distribution;
                stack.alignment = alignments[alignmentIndex];
                stack.spacing = 5;
                if (margins) {
                    stack.layoutMarginsRelativeArrangement = YES;
                    stack.layoutMargins = UIEdgeInsetsMake(3, 5, 7, 11);
                    SEL renamed = NSSelectorFromString(@"setCharonHostLayoutMargins:");
                    if ([stack respondsToSelector:renamed])
                        ((void (*)(id, SEL, UIEdgeInsets))[stack methodForSelector:renamed])(stack, renamed, UIEdgeInsetsMake(3, 5, 7, 11));
                }
                stack.translatesAutoresizingMaskIntoConstraints = NO;
                [root addSubview:stack];
                [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeLeft multiplier:1 constant:10]];
                [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:root attribute:NSLayoutAttributeTop multiplier:1 constant:20]];
                if (size) {
                    [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:400]];
                    [root addConstraint:[NSLayoutConstraint constraintWithItem:stack attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:300]];
                }
                [root layoutIfNeeded];
                if (hidden)
                    [arranged[hidden == 1 ? 1 : 0] setHidden:YES];
                mark(root);
                [root layoutIfNeeded];
                NSMutableArray *views = [NSMutableArray array];
                collect(stack, views);
                printf("    {%ld, %ld, %ld, %ld, %ld, %ld, %ld, %lu, {", (long)nested, (long)margins, (long)axis, (long)distribution, (long)alignments[alignmentIndex], (long)hidden, (long)size, (unsigned long)views.count);
                for (UIView *view in views) {
                    CGRect rect = [view convertRect:view.bounds toView:root];
                    printf("%g, %g, %g, %g, ", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
                }
                printf("}},\n");
            }
        }
        printf("};\n");
    }
    return 0;
}
