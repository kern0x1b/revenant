#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSQualityOfService revenant_quality_of_service(NSInteger quality);

static char RevenantThreadQualityKey;

@implementation NSThread (RevenantQualityOfService)

- (NSQualityOfService)qualityOfService
{
    NSNumber *quality = objc_getAssociatedObject(self, &RevenantThreadQualityKey);
    if (quality)
        return (NSQualityOfService)quality.integerValue;
    return self.isMainThread ? NSQualityOfServiceUserInteractive : NSQualityOfServiceDefault;
}

- (void)setQualityOfService:(NSQualityOfService)qualityOfService
{
    if (self.isExecuting || self.isFinished || self.isMainThread)
        return;
    objc_setAssociatedObject(self, &RevenantThreadQualityKey, @(revenant_quality_of_service(qualityOfService)), OBJC_ASSOCIATION_RETAIN);
}

@end
