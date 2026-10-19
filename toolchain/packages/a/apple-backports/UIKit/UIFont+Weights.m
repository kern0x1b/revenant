#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

const UIFontWeight UIFontWeightUltraLight = -0.8f;
const UIFontWeight UIFontWeightThin = -0.6f;
const UIFontWeight UIFontWeightLight = -0.4f;
const UIFontWeight UIFontWeightRegular = 0;
const UIFontWeight UIFontWeightMedium = 0.23f;
const UIFontWeight UIFontWeightSemibold = 0.3f;
const UIFontWeight UIFontWeightBold = 0.4f;
const UIFontWeight UIFontWeightHeavy = 0.56f;
const UIFontWeight UIFontWeightBlack = 0.62f;

@implementation UIFont (CharonWeights)

+ (UIFont *)systemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight
{
    if (weight > UIFontWeightMedium)
        return [UIFont boldSystemFontOfSize:fontSize];
    if (weight > UIFontWeightLight / 2)
        return [UIFont systemFontOfSize:fontSize];
    UIFont *regular = [UIFont systemFontOfSize:fontSize];
    UIFont *lighter = [UIFont fontWithName:[regular.fontName stringByAppendingString:@"-Light"] size:fontSize];
    return [lighter.familyName isEqualToString:regular.familyName] ? lighter : regular;
}

@end
