#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

NSString *const UIFontDescriptorSystemDesignDefault = @"NSCTFontUIFontDesignDefault";
NSString *const UIFontDescriptorSystemDesignRounded = @"NSCTFontUIFontDesignRounded";
NSString *const UIFontDescriptorSystemDesignSerif = @"NSCTFontUIFontDesignSerif";
NSString *const UIFontDescriptorSystemDesignMonospaced = @"NSCTFontUIFontDesignMonospaced";

@implementation UIFont (CharonSystemDesign)

+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight
{
    NSString *name = weight > UIFontWeightMedium ? @"Menlo-Bold" : @"Menlo-Regular";
    UIFont *font = [UIFont fontWithName:name size:fontSize];
    return font ? font : [UIFont fontWithName:weight > UIFontWeightMedium ? @"Courier-Bold" : @"Courier" size:fontSize];
}

@end
