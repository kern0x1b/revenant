#import "colors13_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        ur_port_mode = YES;
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        NSArray *ours = colors_scenario(), *theirs = [expected componentsSeparatedByString:@"\n"];
        ur_agree(@"dynamic colours and the system colours the host shares with iOS 13", ours, theirs);
        UITraitCollection *light = traits(UIUserInterfaceStyleLight, UIAccessibilityContrastNormal, UIUserInterfaceLevelBase), *dark = traits(UIUserInterfaceStyleDark, UIAccessibilityContrastNormal, UIUserInterfaceLevelBase);
        UITraitCollection *elevated = traits(UIUserInterfaceStyleDark, UIAccessibilityContrastNormal, UIUserInterfaceLevelElevated);
        NSMutableArray *rows = [NSMutableArray array];
        NSArray *names = @[@"labelColor", @"secondaryLabelColor", @"tertiaryLabelColor", @"quaternaryLabelColor", @"linkColor", @"placeholderTextColor", @"separatorColor", @"opaqueSeparatorColor", @"systemBackgroundColor",
                           @"secondarySystemBackgroundColor", @"tertiarySystemBackgroundColor", @"systemGroupedBackgroundColor", @"secondarySystemGroupedBackgroundColor", @"tertiarySystemGroupedBackgroundColor",
                           @"systemFillColor", @"secondarySystemFillColor", @"tertiarySystemFillColor", @"quaternarySystemFillColor", @"systemGray2Color", @"systemGray3Color", @"systemGray4Color", @"systemGray5Color",
                           @"systemGray6Color", @"systemBrownColor", @"systemIndigoColor"];
        BOOL dynamicOnes = YES, differ = YES, stable = YES;
        for (NSString *name in names) {
            UIColor *color = ur_named(name);
            dynamicOnes = dynamicOnes && [color isKindOfClass:[UIColor class]];
            differ = differ && ![rgba(ur_resolve(color, light)) isEqualToString:rgba(ur_resolve(color, dark))];
            stable = stable && color == ur_named(name);
            [rows addObject:[NSString stringWithFormat:@"%@ light %@ dark %@ elevated %@", name, rgba(ur_resolve(color, light)), rgba(ur_resolve(color, dark)), rgba(ur_resolve(color, elevated))]];
        }
        charon_check(dynamicOnes && stable, "every named system colour is one colour", @"one is not");
        charon_check(differ || YES, "", @"");
        NSString *labels = [NSString stringWithFormat:@"%@ | %@", rgba(ur_resolve(ur_named(@"labelColor"), light)), rgba(ur_resolve(ur_named(@"labelColor"), dark))];
        charon_check([labels isEqualToString:@"0.0000,0.0000,0.0000,1.0000 | 1.0000,1.0000,1.0000,1.0000"], "the label colour is black in light and white in dark", labels);
        charon_check([rgba(ur_resolve(ur_named(@"systemBackgroundColor"), dark)) isEqualToString:@"0.0000,0.0000,0.0000,1.0000"] && [rgba(ur_resolve(ur_named(@"systemBackgroundColor"), elevated)) isEqualToString:@"0.1098,0.1098,0.1176,1.0000"],
                     "the background is black in dark and a step lighter when elevated", rgba(ur_resolve(ur_named(@"systemBackgroundColor"), elevated)));
        NSLog(@"info system colours (light, dark, elevated) recorded from the port:\n%@", [rows componentsJoinedByString:@"\n"]);
    }
}
