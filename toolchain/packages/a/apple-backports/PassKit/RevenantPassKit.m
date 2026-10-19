#import "CharonPassKit.h"

NSString *const CharonPassKitNoHardwareReason =
    @"this device has no wallet hardware, so the operation cannot be carried out";

NSError *CharonPassKitNoHardwareError(void)
{
    return [NSError errorWithDomain:PKPassKitErrorDomain
                               code:PKUnsupportedVersionError
                           userInfo:@{NSLocalizedDescriptionKey: CharonPassKitNoHardwareReason}];
}
