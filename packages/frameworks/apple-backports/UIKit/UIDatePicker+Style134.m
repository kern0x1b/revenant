#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_preferred_key;

@implementation UIDatePicker (RevenantStyle134)

- (UIDatePickerStyle)datePickerStyle
{
    return UIDatePickerStyleWheels;
}

- (UIDatePickerStyle)preferredDatePickerStyle
{
    return (UIDatePickerStyle)[objc_getAssociatedObject(self, &revenant_preferred_key) integerValue];
}

- (void)setPreferredDatePickerStyle:(UIDatePickerStyle)preferredDatePickerStyle
{
    objc_setAssociatedObject(self, &revenant_preferred_key, @(preferredDatePickerStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
