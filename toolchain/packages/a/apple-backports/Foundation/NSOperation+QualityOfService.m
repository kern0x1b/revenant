#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSQualityOfService charon_quality_of_service(NSInteger quality);

static char CharonOperationQualityKey;

@implementation NSOperation (CharonQualityOfService)

- (NSQualityOfService)qualityOfService
{
    NSNumber *quality = objc_getAssociatedObject(self, &CharonOperationQualityKey);
    return quality ? (NSQualityOfService)quality.integerValue : NSQualityOfServiceDefault;
}

- (void)setQualityOfService:(NSQualityOfService)qualityOfService
{
    objc_setAssociatedObject(self, &CharonOperationQualityKey, @(charon_quality_of_service(qualityOfService)), OBJC_ASSOCIATION_RETAIN);
}

@end
