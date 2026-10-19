#import "touchtypes-cases.h"

static NSString *types(NSArray *array)
{
    NSMutableArray *kept = [NSMutableArray array];
    for (NSNumber *number in array)
        if (number.integerValue < 3)
            [kept addObject:number];
    return [kept componentsJoinedByString:@","];
}

void touchtypes_run(UIWindow *window, TouchTypesRecorder record)
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] init];
    record(@"defaults", [NSString stringWithFormat:@"tap=%@ pan=%@ exclusive=%d presses=%lu", types(tap.allowedTouchTypes), types(pan.allowedTouchTypes), tap.requiresExclusiveTouchType, (unsigned long)tap.allowedPressTypes.count]);
    tap.allowedTouchTypes = @[@(UITouchTypeIndirect)];
    record(@"set", types(tap.allowedTouchTypes));
    tap.allowedTouchTypes = @[];
    record(@"empty", [NSString stringWithFormat:@"%lu", (unsigned long)tap.allowedTouchTypes.count]);
    tap.allowedTouchTypes = @[@(UITouchTypeDirect), @(UITouchTypeDirect)];
    record(@"duplicates", types(tap.allowedTouchTypes));
    tap.requiresExclusiveTouchType = NO;
    record(@"exclusive", [NSString stringWithFormat:@"%d", tap.requiresExclusiveTouchType]);
    tap.allowedPressTypes = @[@(UIPressTypeMenu)];
    record(@"pressTypes", [tap.allowedPressTypes componentsJoinedByString:@","]);
    record(@"values", [NSString stringWithFormat:@"%ld %ld %ld", (long)UITouchTypeDirect, (long)UITouchTypeIndirect, (long)UITouchTypePencil]);
    UILongPressGestureRecognizer *long_press = [[UILongPressGestureRecognizer alloc] init];
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] init];
    record(@"otherDefaults", [NSString stringWithFormat:@"%@ %@", types(long_press.allowedTouchTypes), types(swipe.allowedTouchTypes)]);
}
