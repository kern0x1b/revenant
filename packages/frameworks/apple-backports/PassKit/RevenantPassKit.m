#import "RevenantPassKit.h"

NSString *const RevenantPassKitNoHardwareReason =
    @"this device has no wallet hardware, so the operation cannot be carried out";

NSError *RevenantPassKitNoHardwareError(void)
{
    return [NSError errorWithDomain:PKPassKitErrorDomain
                               code:PKUnsupportedVersionError
                           userInfo:@{NSLocalizedDescriptionKey: RevenantPassKitNoHardwareReason}];
}
