#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UIView (CharonHostTintColor)
- (UIColor *)charonHostTintColor;
- (void)charonHostSetTintColor:(UIColor *)tintColor;
- (UIViewTintAdjustmentMode)charonHostTintAdjustmentMode;
- (void)charonHostSetTintAdjustmentMode:(UIViewTintAdjustmentMode)mode;
- (void)charonHostTintColorDidChange;
@end

@interface CountingView : UIView
@property (nonatomic) NSInteger changes;
@end

@implementation CountingView

- (void)charonHostTintColorDidChange
{
    self.changes++;
}

@end

static NSString *components_of(UIColor *color)
{
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"%.3f %.3f %.3f %.3f", red, green, blue, alpha];
}

int main(void)
{
    @autoreleasepool {
        CountingView *root = [[CountingView alloc] init];
        CountingView *middle = [[CountingView alloc] init];
        CountingView *leaf = [[CountingView alloc] init];
        CountingView *ownColour = [[CountingView alloc] init];
        [root addSubview:middle];
        [middle addSubview:leaf];
        [middle addSubview:ownColour];

        charon_check([components_of([root charonHostTintColor]) isEqualToString:components_of([UIColor colorWithRed:0 green:122 / 255.0 blue:1 alpha:1])],
                     "the default tint colour", components_of([root charonHostTintColor]));
        charon_check([components_of([leaf charonHostTintColor]) isEqualToString:components_of([root charonHostTintColor])], "the default reaches every view", @"the leaf sees another colour");
        charon_check([root charonHostTintAdjustmentMode] == UIViewTintAdjustmentModeNormal, "the default adjustment mode", @"the default mode is not normal");

        [ownColour charonHostSetTintColor:[UIColor greenColor]];
        root.changes = middle.changes = leaf.changes = ownColour.changes = 0;
        [root charonHostSetTintColor:[UIColor redColor]];
        charon_check([components_of([leaf charonHostTintColor]) isEqualToString:components_of([UIColor redColor])], "a set colour is inherited", components_of([leaf charonHostTintColor]));
        charon_check([components_of([ownColour charonHostTintColor]) isEqualToString:components_of([UIColor greenColor])], "a view with its own colour keeps it", components_of([ownColour charonHostTintColor]));
        charon_check(root.changes == 1 && middle.changes == 1 && leaf.changes == 1, "setting the colour reaches the views that inherit it",
                     [NSString stringWithFormat:@"%ld %ld %ld", (long)root.changes, (long)middle.changes, (long)leaf.changes]);
        charon_check(ownColour.changes == 0, "setting the colour stops at a view with its own colour", @"the view was told about a colour it does not use");

        [middle charonHostSetTintColor:nil];
        charon_check([components_of([leaf charonHostTintColor]) isEqualToString:components_of([UIColor redColor])], "clearing a colour falls back to the superview", components_of([leaf charonHostTintColor]));

        root.changes = middle.changes = leaf.changes = 0;
        [middle charonHostSetTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
        charon_check([middle charonHostTintAdjustmentMode] == UIViewTintAdjustmentModeDimmed && [leaf charonHostTintAdjustmentMode] == UIViewTintAdjustmentModeDimmed,
                     "the adjustment mode is inherited", @"the mode is not inherited");
        charon_check([root charonHostTintAdjustmentMode] == UIViewTintAdjustmentModeNormal, "the adjustment mode does not reach the superview", @"the superview was dimmed");
        charon_check(middle.changes == 1 && leaf.changes == 1 && root.changes == 0, "dimming reaches the views below",
                     [NSString stringWithFormat:@"%ld %ld %ld", (long)root.changes, (long)middle.changes, (long)leaf.changes]);
        CGFloat red = 0, green = 0, blue = 0, alpha = 0;
        [[leaf charonHostTintColor] getRed:&red green:&green blue:&blue alpha:&alpha];
        charon_check(red == green && green == blue, "a dimmed colour is grey", components_of([leaf charonHostTintColor]));
        charon_check(fabs(alpha - 0.8) < 0.001, "a dimmed colour keeps four fifths of its alpha", components_of([leaf charonHostTintColor]));
        UIView *systemRoot = [[UIView alloc] init];
        UIView *systemLeaf = [[UIView alloc] init];
        [systemRoot addSubview:systemLeaf];
        systemRoot.tintColor = [UIColor redColor];
        systemRoot.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
        CGFloat systemWhite = 0, systemAlpha = 0, ourWhite = 0, ourAlpha = 0;
        [systemLeaf.tintColor getWhite:&systemWhite alpha:&systemAlpha];
        [[leaf charonHostTintColor] getWhite:&ourWhite alpha:&ourAlpha];
        charon_check(fabs(ourWhite - systemWhite) <= 1 / 255.0 && fabs(ourAlpha - systemAlpha) < 0.001,
                     "the dimmed colour is the one the system makes, to the byte the grey is stored in",
                     [NSString stringWithFormat:@"ours %.6f/%.3f system %.6f/%.3f", ourWhite, ourAlpha, systemWhite, systemAlpha]);
        charon_check([components_of([root charonHostTintColor]) isEqualToString:components_of([UIColor redColor])], "a view above the dimmed one keeps its colour", components_of([root charonHostTintColor]));
        [middle charonHostSetTintAdjustmentMode:UIViewTintAdjustmentModeNormal];
        charon_check([components_of([leaf charonHostTintColor]) isEqualToString:components_of([UIColor redColor])], "the colour comes back when the dimming stops", components_of([leaf charonHostTintColor]));

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
