#import "RevenantLabelBackground.h"

BOOL RevenantLabelBackgroundIsDefaultWhite(const CGFloat *components, size_t count)
{
    if (!components)
        return NO;
    for (size_t index = 0; index < count; index++) {
        if (components[index] != 1)
            return NO;
    }
    return count == 2 || count == 4;
}
