#import <UIKit/UIKit.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UIScreen (RevenantHostNativeBounds)
- (CGRect)revenantHostNativeBounds;
- (CGFloat)revenantHostNativeScale;
@end

@interface UIFont (RevenantHostStyles)
+ (UIFont *)revenantHostPreferredFontForTextStyle:(NSString *)style;
+ (UIFont *)revenantHostSystemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
@end

@interface UIColor (RevenantHostSystemColors)
+ (UIColor *)revenantHostSystemRedColor;
+ (UIColor *)revenantHostSystemGreenColor;
+ (UIColor *)revenantHostSystemBlueColor;
+ (UIColor *)revenantHostSystemOrangeColor;
+ (UIColor *)revenantHostSystemYellowColor;
+ (UIColor *)revenantHostSystemPinkColor;
+ (UIColor *)revenantHostSystemTealColor;
+ (UIColor *)revenantHostSystemGrayColor;
+ (UIColor *)revenantHostSystemPurpleColor;
@end

@interface UIImage (RevenantHostRenderingMode)
- (UIImageRenderingMode)revenantHostRenderingMode;
- (UIImage *)revenantHostImageWithRenderingMode:(UIImageRenderingMode)renderingMode;
@end

@interface UITextField (RevenantHostDefaultTextAttributes)
- (NSDictionary *)revenantHostDefaultTextAttributes;
- (void)revenantHostSetDefaultTextAttributes:(NSDictionary *)attributes;
@end

@interface UIViewController (RevenantHostExtendedLayout)
- (UIRectEdge)revenantHostEdgesForExtendedLayout;
- (void)revenantHostSetEdgesForExtendedLayout:(UIRectEdge)edges;
- (BOOL)revenantHostExtendedLayoutIncludesOpaqueBars;
- (void)revenantHostSetExtendedLayoutIncludesOpaqueBars:(BOOL)includes;
- (BOOL)revenantHostAutomaticallyAdjustsScrollViewInsets;
- (void)revenantHostSetAutomaticallyAdjustsScrollViewInsets:(BOOL)adjusts;
@end

extern const UIFontWeight RevenantHostUIFontWeightUltraLight, RevenantHostUIFontWeightThin, RevenantHostUIFontWeightLight;
extern const UIFontWeight RevenantHostUIFontWeightRegular, RevenantHostUIFontWeightMedium, RevenantHostUIFontWeightSemibold;
extern const UIFontWeight RevenantHostUIFontWeightBold, RevenantHostUIFontWeightHeavy, RevenantHostUIFontWeightBlack;
extern const CGFloat RevenantHostUIFontWidthStandard, RevenantHostUIFontWidthExpanded, RevenantHostUIFontWidthCondensed, RevenantHostUIFontWidthCompressed;
extern UIFontTextStyle const RevenantHostUIFontTextStyleHeadline, RevenantHostUIFontTextStyleSubheadline, RevenantHostUIFontTextStyleBody;
extern UIFontTextStyle const RevenantHostUIFontTextStyleFootnote, RevenantHostUIFontTextStyleCaption1, RevenantHostUIFontTextStyleCaption2;

static NSString *components_of(UIColor *color)
{
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"%.0f %.0f %.0f %.2f", red * 255, green * 255, blue * 255, alpha];
}

static UIImage *drawn_image(CGFloat scale)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 6), NO, scale);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, 10, 6));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

int main(void)
{
    @autoreleasepool {
        UIScreen *screen = [UIScreen mainScreen];
        revenant_check(CGRectEqualToRect([screen revenantHostNativeBounds], screen.nativeBounds), "nativeBounds",
                     [NSString stringWithFormat:@"%@ != %@", NSStringFromCGRect([screen revenantHostNativeBounds]), NSStringFromCGRect(screen.nativeBounds)]);
        revenant_check([screen revenantHostNativeScale] == screen.nativeScale, "nativeScale",
                     [NSString stringWithFormat:@"%g != %g", (double)[screen revenantHostNativeScale], (double)screen.nativeScale]);

        NSArray *ourStyles = @[RevenantHostUIFontTextStyleHeadline, RevenantHostUIFontTextStyleSubheadline, RevenantHostUIFontTextStyleBody,
                               RevenantHostUIFontTextStyleFootnote, RevenantHostUIFontTextStyleCaption1, RevenantHostUIFontTextStyleCaption2];
        NSArray *systemStyles = @[UIFontTextStyleHeadline, UIFontTextStyleSubheadline, UIFontTextStyleBody,
                                  UIFontTextStyleFootnote, UIFontTextStyleCaption1, UIFontTextStyleCaption2];
        for (NSUInteger index = 0; index < ourStyles.count; index++) {
            NSString *ours = [ourStyles objectAtIndex:index], *system = [systemStyles objectAtIndex:index];
            revenant_check([ours isEqualToString:system], NAMED(@"text style constant %@", system), [NSString stringWithFormat:@"%@ != %@", ours, system]);
            UIFont *ourFont = [UIFont revenantHostPreferredFontForTextStyle:ours];
            UIFont *systemFont = [UIFont preferredFontForTextStyle:system];
            revenant_check(ourFont.pointSize == systemFont.pointSize, NAMED(@"%@ size", system), [NSString stringWithFormat:@"%g != %g", (double)ourFont.pointSize, (double)systemFont.pointSize]);
            BOOL ourBold = (ourFont.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
            BOOL systemBold = (systemFont.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
            if (![system isEqualToString:UIFontTextStyleHeadline])
                revenant_check(ourBold == systemBold, NAMED(@"%@ weight", system), @"weight differs");
            else
                printf("known %s: iOS 6 has no semibold system font, the backport uses the bold one (ours bold %d, system bold %d)\n", system.UTF8String, ourBold, systemBold);
        }
        UIFont *unknown = [UIFont revenantHostPreferredFontForTextStyle:@"bogus"];
        revenant_check(unknown.pointSize == [UIFont preferredFontForTextStyle:@"bogus"].pointSize, "an unknown text style", @"the fallback size differs");
        revenant_check([UIFont revenantHostPreferredFontForTextStyle:@""].pointSize == [UIFont preferredFontForTextStyle:@""].pointSize, "the empty text style", @"the fallback size differs");
        revenant_check([UIFont revenantHostPreferredFontForTextStyle:nil] == [UIFont preferredFontForTextStyle:nil], "a nil text style", @"the answer differs");
        for (NSString *private in @[@"UICTFontTextStyleCallout", @"UICTFontTextStyleTitle0", @"UICTFontTextStyleTitle1", @"UICTFontTextStyleTitle2", @"UICTFontTextStyleTitle3"])
            revenant_check([UIFont revenantHostPreferredFontForTextStyle:private].pointSize == [UIFont preferredFontForTextStyle:private].pointSize, NAMED(@"%@ size", private), @"the size differs");

        struct { const UIFontWeight *ours; UIFontWeight system; const char *name; } weights[] = {
            {&RevenantHostUIFontWeightUltraLight, UIFontWeightUltraLight, "ultra light"}, {&RevenantHostUIFontWeightThin, UIFontWeightThin, "thin"},
            {&RevenantHostUIFontWeightLight, UIFontWeightLight, "light"}, {&RevenantHostUIFontWeightRegular, UIFontWeightRegular, "regular"},
            {&RevenantHostUIFontWeightMedium, UIFontWeightMedium, "medium"}, {&RevenantHostUIFontWeightSemibold, UIFontWeightSemibold, "semibold"},
            {&RevenantHostUIFontWeightBold, UIFontWeightBold, "bold"}, {&RevenantHostUIFontWeightHeavy, UIFontWeightHeavy, "heavy"},
            {&RevenantHostUIFontWeightBlack, UIFontWeightBlack, "black"}};
        for (NSUInteger index = 0; index < sizeof(weights) / sizeof(*weights); index++) {
            revenant_check(*weights[index].ours == weights[index].system, NAMED(@"UIFontWeight %s", weights[index].name),
                         [NSString stringWithFormat:@"%.17g != %.17g", (double)*weights[index].ours, (double)weights[index].system]);
            UIFont *font = [UIFont revenantHostSystemFontOfSize:15 weight:*weights[index].ours];
            BOOL bold = (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
            revenant_check(font.pointSize == 15, NAMED(@"weight %s size", weights[index].name), @"the size is not kept");
            revenant_check(bold == (*weights[index].ours > UIFontWeightMedium), NAMED(@"weight %s maps to bold or not", weights[index].name),
                         [NSString stringWithFormat:@"bold %d for weight %g", bold, (double)*weights[index].ours]);
        }

        struct { const CGFloat *ours; CGFloat system; const char *name; } widths[] = {
            {&RevenantHostUIFontWidthStandard, UIFontWidthStandard, "standard"}, {&RevenantHostUIFontWidthExpanded, UIFontWidthExpanded, "expanded"},
            {&RevenantHostUIFontWidthCondensed, UIFontWidthCondensed, "condensed"}, {&RevenantHostUIFontWidthCompressed, UIFontWidthCompressed, "compressed"}};
        for (NSUInteger index = 0; index < sizeof(widths) / sizeof(*widths); index++)
            revenant_check(*widths[index].ours == widths[index].system, NAMED(@"UIFontWidth %s", widths[index].name),
                         [NSString stringWithFormat:@"%.17g != %.17g", (double)*widths[index].ours, (double)widths[index].system]);

        struct { UIColor *(*ours)(void); const char *expected; const char *name; } palette[] = {{NULL, "255 59 48 1.00", "systemRed"}};
        (void)palette;
        NSArray *ourColors = @[[UIColor revenantHostSystemRedColor], [UIColor revenantHostSystemGreenColor], [UIColor revenantHostSystemBlueColor],
                               [UIColor revenantHostSystemOrangeColor], [UIColor revenantHostSystemYellowColor], [UIColor revenantHostSystemPinkColor],
                               [UIColor revenantHostSystemTealColor], [UIColor revenantHostSystemGrayColor], [UIColor revenantHostSystemPurpleColor]];
        NSArray *expectedColors = @[@"255 59 48 1.00", @"52 199 89 1.00", @"0 122 255 1.00", @"255 149 0 1.00", @"255 204 0 1.00",
                                    @"255 45 85 1.00", @"48 176 199 1.00", @"142 142 147 1.00", @"175 82 222 1.00"];
        NSArray *systemColors = @[[UIColor systemRedColor], [UIColor systemGreenColor], [UIColor systemBlueColor], [UIColor systemOrangeColor],
                                  [UIColor systemYellowColor], [UIColor systemPinkColor], [UIColor systemTealColor], [UIColor systemGrayColor],
                                  [UIColor systemPurpleColor]];
        for (NSUInteger index = 0; index < ourColors.count; index++) {
            NSString *ours = components_of([ourColors objectAtIndex:index]);
            revenant_check([ours isEqualToString:[expectedColors objectAtIndex:index]], NAMED(@"system colour %lu", (unsigned long)index),
                         [NSString stringWithFormat:@"%@ != %@", ours, [expectedColors objectAtIndex:index]]);
            printf("info system colour %lu: backport %s, this macOS %s\n", (unsigned long)index, ours.UTF8String, components_of([systemColors objectAtIndex:index]).UTF8String);
        }

        UIImage *image = drawn_image(2);
        revenant_check([image revenantHostRenderingMode] == image.renderingMode, "default rendering mode", @"the default mode differs");
        UIImageRenderingMode modes[] = {UIImageRenderingModeAutomatic, UIImageRenderingModeAlwaysOriginal, UIImageRenderingModeAlwaysTemplate};
        for (NSUInteger index = 0; index < 3; index++) {
            UIImage *ours = [image revenantHostImageWithRenderingMode:modes[index]];
            UIImage *system = [image imageWithRenderingMode:modes[index]];
            revenant_check([ours revenantHostRenderingMode] == system.renderingMode, NAMED(@"rendering mode %lu", (unsigned long)index), @"the stored mode differs");
            revenant_check(CGSizeEqualToSize(ours.size, system.size) && ours.scale == system.scale && ours.imageOrientation == system.imageOrientation,
                         NAMED(@"rendering mode %lu keeps the image", (unsigned long)index), @"size, scale or orientation differs");
            revenant_check([image revenantHostRenderingMode] == image.renderingMode, NAMED(@"rendering mode %lu leaves the original alone", (unsigned long)index), @"the original changed");
        }
        UIImage *resizable = [drawn_image(1) resizableImageWithCapInsets:UIEdgeInsetsMake(1, 2, 3, 4) resizingMode:UIImageResizingModeStretch];
        UIImage *ourResizable = [resizable revenantHostImageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage *systemResizable = [resizable imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        revenant_check(UIEdgeInsetsEqualToEdgeInsets(ourResizable.capInsets, systemResizable.capInsets) && ourResizable.resizingMode == systemResizable.resizingMode,
                     "a resizable image keeps its cap insets", [NSString stringWithFormat:@"%@ != %@", NSStringFromUIEdgeInsets(ourResizable.capInsets), NSStringFromUIEdgeInsets(systemResizable.capInsets)]);

        UITextField *ourField = [[UITextField alloc] init], *systemField = [[UITextField alloc] init];
        for (UITextField *field in @[ourField, systemField]) {
            field.font = [UIFont systemFontOfSize:19];
            field.textColor = [UIColor greenColor];
            field.textAlignment = NSTextAlignmentRight;
        }
        NSDictionary *ourAttributes = [ourField revenantHostDefaultTextAttributes];
        NSDictionary *systemAttributes = systemField.defaultTextAttributes;
        revenant_check([[ourAttributes objectForKey:NSFontAttributeName] isEqual:[systemAttributes objectForKey:NSFontAttributeName]], "default text attributes font", @"the font differs");
        revenant_check([[ourAttributes objectForKey:NSForegroundColorAttributeName] isEqual:[systemAttributes objectForKey:NSForegroundColorAttributeName]], "default text attributes colour", @"the colour differs");
        revenant_check([[ourAttributes objectForKey:NSParagraphStyleAttributeName] alignment] == [[systemAttributes objectForKey:NSParagraphStyleAttributeName] alignment],
                     "default text attributes alignment", @"the alignment differs");
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.alignment = NSTextAlignmentCenter;
        NSDictionary *applied = @{NSFontAttributeName: [UIFont systemFontOfSize:23], NSForegroundColorAttributeName: [UIColor blueColor],
                                  NSParagraphStyleAttributeName: paragraph, NSKernAttributeName: @1.5};
        [ourField revenantHostSetDefaultTextAttributes:applied];
        systemField.defaultTextAttributes = applied;
        revenant_check([ourField.font isEqual:systemField.font], "setting the attributes sets the font", @"the font differs");
        revenant_check([ourField.textColor isEqual:systemField.textColor], "setting the attributes sets the colour", @"the colour differs");
        revenant_check(ourField.textAlignment == systemField.textAlignment, "setting the attributes sets the alignment", @"the alignment differs");
        revenant_check([[[ourField revenantHostDefaultTextAttributes] objectForKey:NSKernAttributeName] isEqual:[systemField.defaultTextAttributes objectForKey:NSKernAttributeName]],
                     "setting the attributes keeps the other attributes", @"the kerning differs");

        NSDictionary * (^summary)(NSDictionary *) = ^(NSDictionary *attributes) {
            NSMutableDictionary *found = [NSMutableDictionary dictionary];
            for (NSString *key in attributes) {
                id value = [attributes objectForKey:key];
                found[key] = [value isKindOfClass:[NSParagraphStyle class]] ? [NSString stringWithFormat:@"%ld/%ld", (long)[value alignment], (long)[value lineBreakMode]] : ([value isKindOfClass:[UIFont class]] ? [NSString stringWithFormat:@"%g", (double)[value pointSize]] : [value isKindOfClass:[UIColor class]] ? @"colour" : value);
            }
            return found;
        };
        UITextField *freshOurs = [[UITextField alloc] init], *freshSystem = [[UITextField alloc] init];
        revenant_check([summary([freshOurs revenantHostDefaultTextAttributes]) isEqual:summary(freshSystem.defaultTextAttributes)], "the default attributes of a new field",
                     [NSString stringWithFormat:@"%@ != %@", summary([freshOurs revenantHostDefaultTextAttributes]), summary(freshSystem.defaultTextAttributes)]);
        NSMutableParagraphStyle *head = [[NSMutableParagraphStyle alloc] init];
        head.alignment = NSTextAlignmentRight;
        head.lineBreakMode = NSLineBreakByTruncatingHead;
        NSArray *sequence = @[@{NSFontAttributeName: [UIFont boldSystemFontOfSize:20], NSKernAttributeName: @2}, @{}, @{NSForegroundColorAttributeName: [UIColor redColor]},
                              @{NSParagraphStyleAttributeName: head, NSUnderlineStyleAttributeName: @1}, [NSNull null], @{NSFontAttributeName: [UIFont systemFontOfSize:9], NSBackgroundColorAttributeName: [UIColor yellowColor]}];
        UITextField *sequenceOurs = [[UITextField alloc] init], *sequenceSystem = [[UITextField alloc] init];
        for (NSUInteger index = 0; index < sequence.count; index++) {
            NSDictionary *attributes = sequence[index] == [NSNull null] ? nil : sequence[index];
            [sequenceOurs revenantHostSetDefaultTextAttributes:attributes];
            sequenceSystem.defaultTextAttributes = attributes;
            NSString *ourSummary = [NSString stringWithFormat:@"%@ %@ %ld", summary([sequenceOurs revenantHostDefaultTextAttributes]), sequenceOurs.font.pointSize > 0 ? @(sequenceOurs.font.pointSize) : @0, (long)sequenceOurs.textAlignment];
            NSString *systemSummary = [NSString stringWithFormat:@"%@ %@ %ld", summary(sequenceSystem.defaultTextAttributes), sequenceSystem.font.pointSize > 0 ? @(sequenceSystem.font.pointSize) : @0, (long)sequenceSystem.textAlignment];
            revenant_check([ourSummary isEqualToString:systemSummary], NAMED(@"default attributes after setting number %lu", (unsigned long)index), [NSString stringWithFormat:@"%@ != %@", ourSummary, systemSummary]);
        }
        UIViewController *controller = [[UIViewController alloc] init];
        revenant_check([controller revenantHostEdgesForExtendedLayout] == controller.edgesForExtendedLayout, "edgesForExtendedLayout default", @"the default differs");
        revenant_check([controller revenantHostExtendedLayoutIncludesOpaqueBars] == controller.extendedLayoutIncludesOpaqueBars, "extendedLayoutIncludesOpaqueBars default", @"the default differs");
        revenant_check([controller revenantHostAutomaticallyAdjustsScrollViewInsets] == YES, "automaticallyAdjustsScrollViewInsets default", @"the default is not YES");
        [controller revenantHostSetEdgesForExtendedLayout:UIRectEdgeBottom | UIRectEdgeLeft];
        controller.edgesForExtendedLayout = UIRectEdgeBottom | UIRectEdgeLeft;
        revenant_check([controller revenantHostEdgesForExtendedLayout] == controller.edgesForExtendedLayout, "edgesForExtendedLayout round trip", @"the stored edges differ");
        [controller revenantHostSetExtendedLayoutIncludesOpaqueBars:YES];
        revenant_check([controller revenantHostExtendedLayoutIncludesOpaqueBars], "extendedLayoutIncludesOpaqueBars round trip", @"the stored value differs");
        [controller revenantHostSetAutomaticallyAdjustsScrollViewInsets:NO];
        revenant_check(![controller revenantHostAutomaticallyAdjustsScrollViewInsets], "automaticallyAdjustsScrollViewInsets round trip", @"the stored value differs");

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}
