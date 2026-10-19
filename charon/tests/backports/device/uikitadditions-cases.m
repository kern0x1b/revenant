#import <UIKit/UIKit.h>
#import "uikitadditions-cases.h"

// What the system's own UIKit answers for the pure values in this family: the semantic system
// colours, a colour built from display-P3 components, the layout direction each semantic content
// attribute means, the inherited animation duration, and the focus answers of a view made by hand.
// The host records these and the device is held to them; nothing here is a value typed from the HIG.
void uikitadditions_run(UIKitAdditionsRecorder record)
{
    // The semantic colours, read through the library's own accessors and reported as the 8-bit
    // components the host holds them with.
    NSArray *names = @[@"systemRedColor", @"systemOrangeColor", @"systemYellowColor", @"systemGreenColor",
                       @"systemPinkColor", @"systemPurpleColor", @"systemBlueColor", @"systemGrayColor"];
    for (NSString *name in names) {
        SEL sel = NSSelectorFromString(name);
        id color = nil;
        if ([UIColor respondsToSelector:sel])
            color = [UIColor performSelector:sel];
        NSString *label = [NSString stringWithFormat:@"UIColor.%@", name];
        if ([UIColor respondsToSelector:sel])
            color = [UIColor performSelector:sel];
        CGFloat r = 0, g = 0, b = 0, a = 1;
        if ([color respondsToSelector:@selector(getRed:green:blue:alpha:)])
            [color getRed:&r green:&g blue:&b alpha:&a];
        record(label, color ? [NSString stringWithFormat:@"%d,%d,%d,%d",
                                         (int)lround(r * 255), (int)lround(g * 255),
                                         (int)lround(b * 255), (int)lround(a * 255)] : @"nil");
    }

    // A colour built from display-P3 components, which the device's sRGB display has to show: the
    // answer is the sRGB colour those components mean, and it is the same for both spellings.
    UIColor *p3init = [[UIColor alloc] initWithDisplayP3Red:0.5 green:0.25 blue:0.75 alpha:0.8];
    UIColor *p3make = [UIColor colorWithDisplayP3Red:0.5 green:0.25 blue:0.75 alpha:0.8];
    for (NSString *which in @[@"initWithDisplayP3", @"colorWithDisplayP3"]) {
        UIColor *color = [which isEqualToString:@"initWithDisplayP3"] ? p3init : p3make;
        CGFloat r = 0, g = 0, b = 0, a = 0;
        [color getRed:&r green:&g blue:&b alpha:&a];
        // The 8-bit components and not the fractions: this device's display is 8 bits per channel,
        // and the conversion here is within 0.0001 of the host's, which is under a third of one step,
        // so the bytes are the answer an application can see and the fractions are not. The
        // difference is written down in facts/UIKit/UIAccessibilityAdditions.md.
        record([NSString stringWithFormat:@"UIColor.%@.bytes", which],
               [NSString stringWithFormat:@"%d,%d,%d,%d", (int)lround(r * 255), (int)lround(g * 255),
                (int)lround(b * 255), (int)lround(a * 255)]);
    }

    // A colour by a name that is not in any catalogue, which is the answer a lookup gives.
    record(@"UIColor.colorNamed.missing", [UIColor colorNamed:@"charon-no-such-colour"] ? @"set" : @"nil");
    record(@"UIColor.colorNamed.empty", [UIColor colorNamed:@""] ? @"set" : @"nil");
    record(@"UIColor.colorNamed.inBundle.missing",
           [UIColor colorNamed:@"charon-no-such-colour" inBundle:[NSBundle mainBundle]
 compatibleWithTraitCollection:nil] ? @"set" : @"nil");

    // The layout direction each semantic content attribute means, in the two spellings: on its own,
    // and relative to a direction it would otherwise take from the application.
    NSArray *attributes = @[@(UISemanticContentAttributeUnspecified),
                            @(UISemanticContentAttributePlayback),
                            @(UISemanticContentAttributeSpatial),
                            @(UISemanticContentAttributeForceLeftToRight),
                            @(UISemanticContentAttributeForceRightToLeft)];
    for (NSNumber *attribute in attributes) {
        UISemanticContentAttribute value = (UISemanticContentAttribute)attribute.unsignedIntegerValue;
        UIUserInterfaceLayoutDirection plain = [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:value];
        UIUserInterfaceLayoutDirection leftRelative =
            [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:value
                                                 relativeToLayoutDirection:UIUserInterfaceLayoutDirectionLeftToRight];
        record([NSString stringWithFormat:@"layoutDirection.forAttribute.%lu", (unsigned long)value],
               plain == UIUserInterfaceLayoutDirectionLeftToRight ? @"leftToRight" :
               plain == UIUserInterfaceLayoutDirectionRightToLeft ? @"rightToLeft" : @"other");
        record([NSString stringWithFormat:@"layoutDirection.forAttribute.%lu.relative", (unsigned long)value],
               leftRelative == UIUserInterfaceLayoutDirectionLeftToRight ? @"leftToRight" :
               leftRelative == UIUserInterfaceLayoutDirectionRightToLeft ? @"rightToLeft" : @"other");
    }

    // The duration an animation with none of its own runs for, and the focus answers of a view.
    record(@"UIView.inheritedAnimationDuration", [NSString stringWithFormat:@"%g", [UIView inheritedAnimationDuration]]);
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    record(@"UIView.canBecomeFocused", view.canBecomeFocused ? @"yes" : @"no");
    record(@"UIView.focused", view.isFocused ? @"yes" : @"no");
}
