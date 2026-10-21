#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIFontDescriptor (RevenantDesign13)

- (UIFontDescriptor *)fontDescriptorWithDesign:(UIFontDescriptorSystemDesign)design
{
    if (!design || [design isEqualToString:UIFontDescriptorSystemDesignDefault])
        return self;
    BOOL bold = (self.symbolicTraits & UIFontDescriptorTraitBold) != 0;
    NSArray *names = nil;
    if ([design isEqualToString:UIFontDescriptorSystemDesignSerif])
        names = bold ? @[@"Georgia-Bold", @"TimesNewRomanPS-BoldMT"] : @[@"Georgia", @"TimesNewRomanPSMT"];
    else if ([design isEqualToString:UIFontDescriptorSystemDesignRounded])
        names = @[@"ArialRoundedMTBold"];
    else if ([design isEqualToString:UIFontDescriptorSystemDesignMonospaced])
        names = bold ? @[@"Menlo-Bold", @"Courier-Bold"] : @[@"Menlo-Regular", @"Courier"];
    CGFloat size = self.pointSize;
    for (NSString *name in names) {
        if ([UIFont fontWithName:name size:size ?: 12])
            return [UIFontDescriptor fontDescriptorWithName:name size:size];
    }
    return nil;
}

@end
