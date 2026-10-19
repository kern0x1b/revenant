#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSQualityOfService revenant_quality_of_service(NSInteger quality);

static char RevenantOperationQualityKey;

@implementation NSOperation (RevenantQualityOfService)

- (NSQualityOfService)qualityOfService
{
    NSNumber *quality = objc_getAssociatedObject(self, &RevenantOperationQualityKey);
    return quality ? (NSQualityOfService)quality.integerValue : NSQualityOfServiceDefault;
}

- (void)setQualityOfService:(NSQualityOfService)qualityOfService
{
    objc_setAssociatedObject(self, &RevenantOperationQualityKey, @(revenant_quality_of_service(qualityOfService)), OBJC_ASSOCIATION_RETAIN);
}

@end
