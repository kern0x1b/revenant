#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UIView (RevenantHostTintColor)
- (UIColor *)revenantHostTintColor;
- (void)revenantHostSetTintColor:(UIColor *)tintColor;
- (UIViewTintAdjustmentMode)revenantHostTintAdjustmentMode;
- (void)revenantHostSetTintAdjustmentMode:(UIViewTintAdjustmentMode)mode;
- (void)revenantHostTintColorDidChange;
@end

@interface CountingView : UIView
@property (nonatomic) NSInteger changes;
@end

@implementation CountingView

- (void)revenantHostTintColorDidChange
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

        revenant_check([components_of([root revenantHostTintColor]) isEqualToString:components_of([UIColor colorWithRed:0 green:122 / 255.0 blue:1 alpha:1])],
                     "the default tint colour", components_of([root revenantHostTintColor]));
        revenant_check([components_of([leaf revenantHostTintColor]) isEqualToString:components_of([root revenantHostTintColor])], "the default reaches every view", @"the leaf sees another colour");
        revenant_check([root revenantHostTintAdjustmentMode] == UIViewTintAdjustmentModeNormal, "the default adjustment mode", @"the default mode is not normal");

        [ownColour revenantHostSetTintColor:[UIColor greenColor]];
        root.changes = middle.changes = leaf.changes = ownColour.changes = 0;
        [root revenantHostSetTintColor:[UIColor redColor]];
        revenant_check([components_of([leaf revenantHostTintColor]) isEqualToString:components_of([UIColor redColor])], "a set colour is inherited", components_of([leaf revenantHostTintColor]));
        revenant_check([components_of([ownColour revenantHostTintColor]) isEqualToString:components_of([UIColor greenColor])], "a view with its own colour keeps it", components_of([ownColour revenantHostTintColor]));
        revenant_check(root.changes == 1 && middle.changes == 1 && leaf.changes == 1, "setting the colour reaches the views that inherit it",
                     [NSString stringWithFormat:@"%ld %ld %ld", (long)root.changes, (long)middle.changes, (long)leaf.changes]);
        revenant_check(ownColour.changes == 0, "setting the colour stops at a view with its own colour", @"the view was told about a colour it does not use");

        [middle revenantHostSetTintColor:nil];
        revenant_check([components_of([leaf revenantHostTintColor]) isEqualToString:components_of([UIColor redColor])], "clearing a colour falls back to the superview", components_of([leaf revenantHostTintColor]));

        root.changes = middle.changes = leaf.changes = 0;
        [middle revenantHostSetTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
        revenant_check([middle revenantHostTintAdjustmentMode] == UIViewTintAdjustmentModeDimmed && [leaf revenantHostTintAdjustmentMode] == UIViewTintAdjustmentModeDimmed,
                     "the adjustment mode is inherited", @"the mode is not inherited");
        revenant_check([root revenantHostTintAdjustmentMode] == UIViewTintAdjustmentModeNormal, "the adjustment mode does not reach the superview", @"the superview was dimmed");
        revenant_check(middle.changes == 1 && leaf.changes == 1 && root.changes == 0, "dimming reaches the views below",
                     [NSString stringWithFormat:@"%ld %ld %ld", (long)root.changes, (long)middle.changes, (long)leaf.changes]);
        CGFloat red = 0, green = 0, blue = 0, alpha = 0;
        [[leaf revenantHostTintColor] getRed:&red green:&green blue:&blue alpha:&alpha];
        revenant_check(red == green && green == blue, "a dimmed colour is grey", components_of([leaf revenantHostTintColor]));
        revenant_check(fabs(alpha - 0.8) < 0.001, "a dimmed colour keeps four fifths of its alpha", components_of([leaf revenantHostTintColor]));
        UIView *systemRoot = [[UIView alloc] init];
        UIView *systemLeaf = [[UIView alloc] init];
        [systemRoot addSubview:systemLeaf];
        systemRoot.tintColor = [UIColor redColor];
        systemRoot.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
        CGFloat systemWhite = 0, systemAlpha = 0, ourWhite = 0, ourAlpha = 0;
        [systemLeaf.tintColor getWhite:&systemWhite alpha:&systemAlpha];
        [[leaf revenantHostTintColor] getWhite:&ourWhite alpha:&ourAlpha];
        revenant_check(fabs(ourWhite - systemWhite) <= 1 / 255.0 && fabs(ourAlpha - systemAlpha) < 0.001,
                     "the dimmed colour is the one the system makes, to the byte the grey is stored in",
                     [NSString stringWithFormat:@"ours %.6f/%.3f system %.6f/%.3f", ourWhite, ourAlpha, systemWhite, systemAlpha]);
        revenant_check([components_of([root revenantHostTintColor]) isEqualToString:components_of([UIColor redColor])], "a view above the dimmed one keeps its colour", components_of([root revenantHostTintColor]));
        [middle revenantHostSetTintAdjustmentMode:UIViewTintAdjustmentModeNormal];
        revenant_check([components_of([leaf revenantHostTintColor]) isEqualToString:components_of([UIColor redColor])], "the colour comes back when the dimming stops", components_of([leaf revenantHostTintColor]));

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}
