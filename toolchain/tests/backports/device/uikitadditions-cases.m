#import <UIKit/UIKit.h>
#import "uikitadditions-cases.h"

void uikitadditions_run(UIKitAdditionsRecorder record)
{
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

    UIColor *p3init = [[UIColor alloc] initWithDisplayP3Red:0.5 green:0.25 blue:0.75 alpha:0.8];
    UIColor *p3make = [UIColor colorWithDisplayP3Red:0.5 green:0.25 blue:0.75 alpha:0.8];
    for (NSString *which in @[@"initWithDisplayP3", @"colorWithDisplayP3"]) {
        UIColor *color = [which isEqualToString:@"initWithDisplayP3"] ? p3init : p3make;
        CGFloat r = 0, g = 0, b = 0, a = 0;
        [color getRed:&r green:&g blue:&b alpha:&a];
        record([NSString stringWithFormat:@"UIColor.%@.bytes", which],
               [NSString stringWithFormat:@"%d,%d,%d,%d", (int)lround(r * 255), (int)lround(g * 255),
                (int)lround(b * 255), (int)lround(a * 255)]);
    }

    record(@"UIColor.colorNamed.missing", [UIColor colorNamed:@"charon-no-such-colour"] ? @"set" : @"nil");
    record(@"UIColor.colorNamed.empty", [UIColor colorNamed:@""] ? @"set" : @"nil");
    record(@"UIColor.colorNamed.inBundle.missing",
           [UIColor colorNamed:@"charon-no-such-colour" inBundle:[NSBundle mainBundle]
 compatibleWithTraitCollection:nil] ? @"set" : @"nil");

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

    record(@"UIView.inheritedAnimationDuration", [NSString stringWithFormat:@"%g", [UIView inheritedAnimationDuration]]);
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    record(@"UIView.canBecomeFocused", view.canBecomeFocused ? @"yes" : @"no");
    record(@"UIView.focused", view.isFocused ? @"yes" : @"no");
}
