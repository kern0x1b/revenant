#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSQualityOfService charon_quality_of_service(NSInteger quality);

static char CharonThreadQualityKey;

@implementation NSThread (CharonQualityOfService)

- (NSQualityOfService)qualityOfService
{
    NSNumber *quality = objc_getAssociatedObject(self, &CharonThreadQualityKey);
    if (quality)
        return (NSQualityOfService)quality.integerValue;
    return self.isMainThread ? NSQualityOfServiceUserInteractive : NSQualityOfServiceDefault;
}

- (void)setQualityOfService:(NSQualityOfService)qualityOfService
{
    if (self.isExecuting || self.isFinished || self.isMainThread)
        return;
    objc_setAssociatedObject(self, &CharonThreadQualityKey, @(charon_quality_of_service(qualityOfService)), OBJC_ASSOCIATION_RETAIN);
}

@end
