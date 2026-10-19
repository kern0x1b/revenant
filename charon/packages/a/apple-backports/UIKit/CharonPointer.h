#import "CharonMenus.h"

static inline NSUInteger charon_hash_part(double value)
{
    if (value != value)
        return 0;
    NSInteger whole = value >= 2147483647.0 ? 2147483647 : value <= -2147483648.0 ? (NSInteger)-2147483648LL : (NSInteger)value;
    return (NSUInteger)whole;
}

static inline NSString *charon_axes_text(UIAxis axes)
{
    switch ((NSUInteger)axes) {
    case 1:
        return @"horizontal";
    case 2:
        return @"vertical";
    case 3:
        return @"both";
    }
    return nil;
}
