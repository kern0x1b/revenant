#import <Foundation/Foundation.h>

NSQualityOfService charon_quality_of_service(NSInteger quality)
{
    switch (quality) {
    case NSQualityOfServiceUserInteractive:
    case NSQualityOfServiceUserInitiated:
    case NSQualityOfServiceUtility:
    case NSQualityOfServiceBackground:
        return (NSQualityOfService)quality;
    default:
        return NSQualityOfServiceDefault;
    }
}
