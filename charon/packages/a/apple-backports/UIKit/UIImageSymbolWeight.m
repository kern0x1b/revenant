#import <UIKit/UIKit.h>

static const float CharonFontWeights[10] = {0, -0.8f, -0.6f, -0.4f, 0, 0.23f, 0.3f, 0.4f, 0.56f, 0.62f};

UIImageSymbolWeight UIImageSymbolWeightForFontWeight(UIFontWeight fontWeight)
{
    if (fontWeight < CharonFontWeights[1])
        return UIImageSymbolWeightUnspecified;
    for (NSInteger weight = 2; weight <= 9; weight++) {
        if (fontWeight < CharonFontWeights[weight])
            return (UIImageSymbolWeight)(weight - 1);
    }
    return UIImageSymbolWeightBlack;
}

UIFontWeight UIFontWeightForImageSymbolWeight(UIImageSymbolWeight symbolWeight)
{
    return symbolWeight >= 0 && symbolWeight <= 9 ? CharonFontWeights[symbolWeight] : 0;
}
