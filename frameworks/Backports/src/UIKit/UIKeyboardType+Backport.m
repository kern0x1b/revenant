#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, UIKeyboardType) {
    UIKeyboardTypeDefault = 0,
    UIKeyboardTypeASCIICapable = 1,
    UIKeyboardTypeNumbersAndPunctuation = 2,
    UIKeyboardTypeURL = 3,
    UIKeyboardTypeNumberPad = 4,
    UIKeyboardTypePhonePad = 5,
    UIKeyboardTypeNamePhonePad = 6,
    UIKeyboardTypeEmailAddress = 7,
    UIKeyboardTypeDecimalPad = 8,
    UIKeyboardTypeTwitter = 9,
    UIKeyboardTypeWebSearch = 10,
    UIKeyboardTypeASCIICapableNumberPad = 11,
};

static UIKeyboardType revenant_fallback_for_web_search(void)
{
    return UIKeyboardTypeDefault;
}

static UIKeyboardType revenant_fallback_for_ascii_capable_number_pad(void)
{
    return UIKeyboardTypeNumbersAndPunctuation;
}

UIKeyboardType revenant_keyboard_type_fallback(UIKeyboardType type)
{
    switch (type) {
        case UIKeyboardTypeWebSearch:
            return revenant_fallback_for_web_search();
        case UIKeyboardTypeASCIICapableNumberPad:
            return revenant_fallback_for_ascii_capable_number_pad();
        default:
            return type;
    }
}

const char *revenant_keyboard_type_name(UIKeyboardType type)
{
    switch (type) {
        case UIKeyboardTypeDefault: return "UIKeyboardTypeDefault";
        case UIKeyboardTypeASCIICapable: return "UIKeyboardTypeASCIICapable";
        case UIKeyboardTypeNumbersAndPunctuation: return "UIKeyboardTypeNumbersAndPunctuation";
        case UIKeyboardTypeURL: return "UIKeyboardTypeURL";
        case UIKeyboardTypeNumberPad: return "UIKeyboardTypeNumberPad";
        case UIKeyboardTypePhonePad: return "UIKeyboardTypePhonePad";
        case UIKeyboardTypeNamePhonePad: return "UIKeyboardTypeNamePhonePad";
        case UIKeyboardTypeEmailAddress: return "UIKeyboardTypeEmailAddress";
        case UIKeyboardTypeDecimalPad: return "UIKeyboardTypeDecimalPad";
        case UIKeyboardTypeTwitter: return "UIKeyboardTypeTwitter";
        case UIKeyboardTypeWebSearch: return "UIKeyboardTypeWebSearch";
        case UIKeyboardTypeASCIICapableNumberPad: return "UIKeyboardTypeASCIICapableNumberPad";
        default: return "UIKeyboardTypeUnknown";
    }
}