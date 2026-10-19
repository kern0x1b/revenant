#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_preferred_key;

@implementation UIDatePicker (CharonStyle134)

- (UIDatePickerStyle)datePickerStyle
{
    return UIDatePickerStyleWheels;
}

- (UIDatePickerStyle)preferredDatePickerStyle
{
    return (UIDatePickerStyle)[objc_getAssociatedObject(self, &charon_preferred_key) integerValue];
}

- (void)setPreferredDatePickerStyle:(UIDatePickerStyle)preferredDatePickerStyle
{
    objc_setAssociatedObject(self, &charon_preferred_key, @(preferredDatePickerStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
