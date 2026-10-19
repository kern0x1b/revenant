#import <UIKit/UIKit.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UIScreen (CharonHostNativeBounds)
- (CGRect)charonHostNativeBounds;
- (CGFloat)charonHostNativeScale;
@end

@interface UIFont (CharonHostStyles)
+ (UIFont *)charonHostPreferredFontForTextStyle:(NSString *)style;
+ (UIFont *)charonHostSystemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
@end

@interface UIColor (CharonHostSystemColors)
+ (UIColor *)charonHostSystemRedColor;
+ (UIColor *)charonHostSystemGreenColor;
+ (UIColor *)charonHostSystemBlueColor;
+ (UIColor *)charonHostSystemOrangeColor;
+ (UIColor *)charonHostSystemYellowColor;
+ (UIColor *)charonHostSystemPinkColor;
+ (UIColor *)charonHostSystemTealColor;
+ (UIColor *)charonHostSystemGrayColor;
+ (UIColor *)charonHostSystemPurpleColor;
@end

@interface UIImage (CharonHostRenderingMode)
- (UIImageRenderingMode)charonHostRenderingMode;
- (UIImage *)charonHostImageWithRenderingMode:(UIImageRenderingMode)renderingMode;
@end

@interface UITextField (CharonHostDefaultTextAttributes)
- (NSDictionary *)charonHostDefaultTextAttributes;
- (void)charonHostSetDefaultTextAttributes:(NSDictionary *)attributes;
@end

@interface UIViewController (CharonHostExtendedLayout)
- (UIRectEdge)charonHostEdgesForExtendedLayout;
- (void)charonHostSetEdgesForExtendedLayout:(UIRectEdge)edges;
- (BOOL)charonHostExtendedLayoutIncludesOpaqueBars;
- (void)charonHostSetExtendedLayoutIncludesOpaqueBars:(BOOL)includes;
- (BOOL)charonHostAutomaticallyAdjustsScrollViewInsets;
- (void)charonHostSetAutomaticallyAdjustsScrollViewInsets:(BOOL)adjusts;
@end

extern const UIFontWeight CharonHostUIFontWeightUltraLight, CharonHostUIFontWeightThin, CharonHostUIFontWeightLight;
extern const UIFontWeight CharonHostUIFontWeightRegular, CharonHostUIFontWeightMedium, CharonHostUIFontWeightSemibold;
extern const UIFontWeight CharonHostUIFontWeightBold, CharonHostUIFontWeightHeavy, CharonHostUIFontWeightBlack;
extern const CGFloat CharonHostUIFontWidthStandard, CharonHostUIFontWidthExpanded, CharonHostUIFontWidthCondensed, CharonHostUIFontWidthCompressed;
extern UIFontTextStyle const CharonHostUIFontTextStyleHeadline, CharonHostUIFontTextStyleSubheadline, CharonHostUIFontTextStyleBody;
extern UIFontTextStyle const CharonHostUIFontTextStyleFootnote, CharonHostUIFontTextStyleCaption1, CharonHostUIFontTextStyleCaption2;

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
        charon_check(CGRectEqualToRect([screen charonHostNativeBounds], screen.nativeBounds), "nativeBounds",
                     [NSString stringWithFormat:@"%@ != %@", NSStringFromCGRect([screen charonHostNativeBounds]), NSStringFromCGRect(screen.nativeBounds)]);
        charon_check([screen charonHostNativeScale] == screen.nativeScale, "nativeScale",
                     [NSString stringWithFormat:@"%g != %g", (double)[screen charonHostNativeScale], (double)screen.nativeScale]);

        NSArray *ourStyles = @[CharonHostUIFontTextStyleHeadline, CharonHostUIFontTextStyleSubheadline, CharonHostUIFontTextStyleBody,
                               CharonHostUIFontTextStyleFootnote, CharonHostUIFontTextStyleCaption1, CharonHostUIFontTextStyleCaption2];
        NSArray *systemStyles = @[UIFontTextStyleHeadline, UIFontTextStyleSubheadline, UIFontTextStyleBody,
                                  UIFontTextStyleFootnote, UIFontTextStyleCaption1, UIFontTextStyleCaption2];
        for (NSUInteger index = 0; index < ourStyles.count; index++) {
            NSString *ours = [ourStyles objectAtIndex:index], *system = [systemStyles objectAtIndex:index];
            charon_check([ours isEqualToString:system], NAMED(@"text style constant %@", system), [NSString stringWithFormat:@"%@ != %@", ours, system]);
            UIFont *ourFont = [UIFont charonHostPreferredFontForTextStyle:ours];
            UIFont *systemFont = [UIFont preferredFontForTextStyle:system];
            charon_check(ourFont.pointSize == systemFont.pointSize, NAMED(@"%@ size", system), [NSString stringWithFormat:@"%g != %g", (double)ourFont.pointSize, (double)systemFont.pointSize]);
            BOOL ourBold = (ourFont.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
            BOOL systemBold = (systemFont.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
            if (![system isEqualToString:UIFontTextStyleHeadline])
                charon_check(ourBold == systemBold, NAMED(@"%@ weight", system), @"weight differs");
            else
                printf("known %s: iOS 6 has no semibold system font, the backport uses the bold one (ours bold %d, system bold %d)\n", system.UTF8String, ourBold, systemBold);
        }
        UIFont *unknown = [UIFont charonHostPreferredFontForTextStyle:@"bogus"];
        charon_check(unknown.pointSize == [UIFont preferredFontForTextStyle:@"bogus"].pointSize, "an unknown text style", @"the fallback size differs");
        charon_check([UIFont charonHostPreferredFontForTextStyle:@""].pointSize == [UIFont preferredFontForTextStyle:@""].pointSize, "the empty text style", @"the fallback size differs");
        charon_check([UIFont charonHostPreferredFontForTextStyle:nil] == [UIFont preferredFontForTextStyle:nil], "a nil text style", @"the answer differs");
        for (NSString *private in @[@"UICTFontTextStyleCallout", @"UICTFontTextStyleTitle0", @"UICTFontTextStyleTitle1", @"UICTFontTextStyleTitle2", @"UICTFontTextStyleTitle3"])
            charon_check([UIFont charonHostPreferredFontForTextStyle:private].pointSize == [UIFont preferredFontForTextStyle:private].pointSize, NAMED(@"%@ size", private), @"the size differs");

        struct { const UIFontWeight *ours; UIFontWeight system; const char *name; } weights[] = {
            {&CharonHostUIFontWeightUltraLight, UIFontWeightUltraLight, "ultra light"}, {&CharonHostUIFontWeightThin, UIFontWeightThin, "thin"},
            {&CharonHostUIFontWeightLight, UIFontWeightLight, "light"}, {&CharonHostUIFontWeightRegular, UIFontWeightRegular, "regular"},
            {&CharonHostUIFontWeightMedium, UIFontWeightMedium, "medium"}, {&CharonHostUIFontWeightSemibold, UIFontWeightSemibold, "semibold"},
            {&CharonHostUIFontWeightBold, UIFontWeightBold, "bold"}, {&CharonHostUIFontWeightHeavy, UIFontWeightHeavy, "heavy"},
            {&CharonHostUIFontWeightBlack, UIFontWeightBlack, "black"}};
        for (NSUInteger index = 0; index < sizeof(weights) / sizeof(*weights); index++) {
            charon_check(*weights[index].ours == weights[index].system, NAMED(@"UIFontWeight %s", weights[index].name),
                         [NSString stringWithFormat:@"%.17g != %.17g", (double)*weights[index].ours, (double)weights[index].system]);
            UIFont *font = [UIFont charonHostSystemFontOfSize:15 weight:*weights[index].ours];
            BOOL bold = (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
            charon_check(font.pointSize == 15, NAMED(@"weight %s size", weights[index].name), @"the size is not kept");
            charon_check(bold == (*weights[index].ours > UIFontWeightMedium), NAMED(@"weight %s maps to bold or not", weights[index].name),
                         [NSString stringWithFormat:@"bold %d for weight %g", bold, (double)*weights[index].ours]);
        }

        struct { const CGFloat *ours; CGFloat system; const char *name; } widths[] = {
            {&CharonHostUIFontWidthStandard, UIFontWidthStandard, "standard"}, {&CharonHostUIFontWidthExpanded, UIFontWidthExpanded, "expanded"},
            {&CharonHostUIFontWidthCondensed, UIFontWidthCondensed, "condensed"}, {&CharonHostUIFontWidthCompressed, UIFontWidthCompressed, "compressed"}};
        for (NSUInteger index = 0; index < sizeof(widths) / sizeof(*widths); index++)
            charon_check(*widths[index].ours == widths[index].system, NAMED(@"UIFontWidth %s", widths[index].name),
                         [NSString stringWithFormat:@"%.17g != %.17g", (double)*widths[index].ours, (double)widths[index].system]);

        struct { UIColor *(*ours)(void); const char *expected; const char *name; } palette[] = {{NULL, "255 59 48 1.00", "systemRed"}};
        (void)palette;
        NSArray *ourColors = @[[UIColor charonHostSystemRedColor], [UIColor charonHostSystemGreenColor], [UIColor charonHostSystemBlueColor],
                               [UIColor charonHostSystemOrangeColor], [UIColor charonHostSystemYellowColor], [UIColor charonHostSystemPinkColor],
                               [UIColor charonHostSystemTealColor], [UIColor charonHostSystemGrayColor], [UIColor charonHostSystemPurpleColor]];
        NSArray *expectedColors = @[@"255 59 48 1.00", @"52 199 89 1.00", @"0 122 255 1.00", @"255 149 0 1.00", @"255 204 0 1.00",
                                    @"255 45 85 1.00", @"48 176 199 1.00", @"142 142 147 1.00", @"175 82 222 1.00"];
        NSArray *systemColors = @[[UIColor systemRedColor], [UIColor systemGreenColor], [UIColor systemBlueColor], [UIColor systemOrangeColor],
                                  [UIColor systemYellowColor], [UIColor systemPinkColor], [UIColor systemTealColor], [UIColor systemGrayColor],
                                  [UIColor systemPurpleColor]];
        for (NSUInteger index = 0; index < ourColors.count; index++) {
            NSString *ours = components_of([ourColors objectAtIndex:index]);
            charon_check([ours isEqualToString:[expectedColors objectAtIndex:index]], NAMED(@"system colour %lu", (unsigned long)index),
                         [NSString stringWithFormat:@"%@ != %@", ours, [expectedColors objectAtIndex:index]]);
            printf("info system colour %lu: backport %s, this macOS %s\n", (unsigned long)index, ours.UTF8String, components_of([systemColors objectAtIndex:index]).UTF8String);
        }

        UIImage *image = drawn_image(2);
        charon_check([image charonHostRenderingMode] == image.renderingMode, "default rendering mode", @"the default mode differs");
        UIImageRenderingMode modes[] = {UIImageRenderingModeAutomatic, UIImageRenderingModeAlwaysOriginal, UIImageRenderingModeAlwaysTemplate};
        for (NSUInteger index = 0; index < 3; index++) {
            UIImage *ours = [image charonHostImageWithRenderingMode:modes[index]];
            UIImage *system = [image imageWithRenderingMode:modes[index]];
            charon_check([ours charonHostRenderingMode] == system.renderingMode, NAMED(@"rendering mode %lu", (unsigned long)index), @"the stored mode differs");
            charon_check(CGSizeEqualToSize(ours.size, system.size) && ours.scale == system.scale && ours.imageOrientation == system.imageOrientation,
                         NAMED(@"rendering mode %lu keeps the image", (unsigned long)index), @"size, scale or orientation differs");
            charon_check([image charonHostRenderingMode] == image.renderingMode, NAMED(@"rendering mode %lu leaves the original alone", (unsigned long)index), @"the original changed");
        }
        UIImage *resizable = [drawn_image(1) resizableImageWithCapInsets:UIEdgeInsetsMake(1, 2, 3, 4) resizingMode:UIImageResizingModeStretch];
        UIImage *ourResizable = [resizable charonHostImageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage *systemResizable = [resizable imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        charon_check(UIEdgeInsetsEqualToEdgeInsets(ourResizable.capInsets, systemResizable.capInsets) && ourResizable.resizingMode == systemResizable.resizingMode,
                     "a resizable image keeps its cap insets", [NSString stringWithFormat:@"%@ != %@", NSStringFromUIEdgeInsets(ourResizable.capInsets), NSStringFromUIEdgeInsets(systemResizable.capInsets)]);

        UITextField *ourField = [[UITextField alloc] init], *systemField = [[UITextField alloc] init];
        for (UITextField *field in @[ourField, systemField]) {
            field.font = [UIFont systemFontOfSize:19];
            field.textColor = [UIColor greenColor];
            field.textAlignment = NSTextAlignmentRight;
        }
        NSDictionary *ourAttributes = [ourField charonHostDefaultTextAttributes];
        NSDictionary *systemAttributes = systemField.defaultTextAttributes;
        charon_check([[ourAttributes objectForKey:NSFontAttributeName] isEqual:[systemAttributes objectForKey:NSFontAttributeName]], "default text attributes font", @"the font differs");
        charon_check([[ourAttributes objectForKey:NSForegroundColorAttributeName] isEqual:[systemAttributes objectForKey:NSForegroundColorAttributeName]], "default text attributes colour", @"the colour differs");
        charon_check([[ourAttributes objectForKey:NSParagraphStyleAttributeName] alignment] == [[systemAttributes objectForKey:NSParagraphStyleAttributeName] alignment],
                     "default text attributes alignment", @"the alignment differs");
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.alignment = NSTextAlignmentCenter;
        NSDictionary *applied = @{NSFontAttributeName: [UIFont systemFontOfSize:23], NSForegroundColorAttributeName: [UIColor blueColor],
                                  NSParagraphStyleAttributeName: paragraph, NSKernAttributeName: @1.5};
        [ourField charonHostSetDefaultTextAttributes:applied];
        systemField.defaultTextAttributes = applied;
        charon_check([ourField.font isEqual:systemField.font], "setting the attributes sets the font", @"the font differs");
        charon_check([ourField.textColor isEqual:systemField.textColor], "setting the attributes sets the colour", @"the colour differs");
        charon_check(ourField.textAlignment == systemField.textAlignment, "setting the attributes sets the alignment", @"the alignment differs");
        charon_check([[[ourField charonHostDefaultTextAttributes] objectForKey:NSKernAttributeName] isEqual:[systemField.defaultTextAttributes objectForKey:NSKernAttributeName]],
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
        charon_check([summary([freshOurs charonHostDefaultTextAttributes]) isEqual:summary(freshSystem.defaultTextAttributes)], "the default attributes of a new field",
                     [NSString stringWithFormat:@"%@ != %@", summary([freshOurs charonHostDefaultTextAttributes]), summary(freshSystem.defaultTextAttributes)]);
        NSMutableParagraphStyle *head = [[NSMutableParagraphStyle alloc] init];
        head.alignment = NSTextAlignmentRight;
        head.lineBreakMode = NSLineBreakByTruncatingHead;
        NSArray *sequence = @[@{NSFontAttributeName: [UIFont boldSystemFontOfSize:20], NSKernAttributeName: @2}, @{}, @{NSForegroundColorAttributeName: [UIColor redColor]},
                              @{NSParagraphStyleAttributeName: head, NSUnderlineStyleAttributeName: @1}, [NSNull null], @{NSFontAttributeName: [UIFont systemFontOfSize:9], NSBackgroundColorAttributeName: [UIColor yellowColor]}];
        UITextField *sequenceOurs = [[UITextField alloc] init], *sequenceSystem = [[UITextField alloc] init];
        for (NSUInteger index = 0; index < sequence.count; index++) {
            NSDictionary *attributes = sequence[index] == [NSNull null] ? nil : sequence[index];
            [sequenceOurs charonHostSetDefaultTextAttributes:attributes];
            sequenceSystem.defaultTextAttributes = attributes;
            NSString *ourSummary = [NSString stringWithFormat:@"%@ %@ %ld", summary([sequenceOurs charonHostDefaultTextAttributes]), sequenceOurs.font.pointSize > 0 ? @(sequenceOurs.font.pointSize) : @0, (long)sequenceOurs.textAlignment];
            NSString *systemSummary = [NSString stringWithFormat:@"%@ %@ %ld", summary(sequenceSystem.defaultTextAttributes), sequenceSystem.font.pointSize > 0 ? @(sequenceSystem.font.pointSize) : @0, (long)sequenceSystem.textAlignment];
            charon_check([ourSummary isEqualToString:systemSummary], NAMED(@"default attributes after setting number %lu", (unsigned long)index), [NSString stringWithFormat:@"%@ != %@", ourSummary, systemSummary]);
        }
        UIViewController *controller = [[UIViewController alloc] init];
        charon_check([controller charonHostEdgesForExtendedLayout] == controller.edgesForExtendedLayout, "edgesForExtendedLayout default", @"the default differs");
        charon_check([controller charonHostExtendedLayoutIncludesOpaqueBars] == controller.extendedLayoutIncludesOpaqueBars, "extendedLayoutIncludesOpaqueBars default", @"the default differs");
        charon_check([controller charonHostAutomaticallyAdjustsScrollViewInsets] == YES, "automaticallyAdjustsScrollViewInsets default", @"the default is not YES");
        [controller charonHostSetEdgesForExtendedLayout:UIRectEdgeBottom | UIRectEdgeLeft];
        controller.edgesForExtendedLayout = UIRectEdgeBottom | UIRectEdgeLeft;
        charon_check([controller charonHostEdgesForExtendedLayout] == controller.edgesForExtendedLayout, "edgesForExtendedLayout round trip", @"the stored edges differ");
        [controller charonHostSetExtendedLayoutIncludesOpaqueBars:YES];
        charon_check([controller charonHostExtendedLayoutIncludesOpaqueBars], "extendedLayoutIncludesOpaqueBars round trip", @"the stored value differs");
        [controller charonHostSetAutomaticallyAdjustsScrollViewInsets:NO];
        charon_check(![controller charonHostAutomaticallyAdjustsScrollViewInsets], "automaticallyAdjustsScrollViewInsets round trip", @"the stored value differs");

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
