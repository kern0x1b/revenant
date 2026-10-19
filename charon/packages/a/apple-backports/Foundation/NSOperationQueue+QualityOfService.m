#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSQualityOfService charon_quality_of_service(NSInteger quality);

static char CharonQueueQualityKey;

static void charon_note_queue_scheduling(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"an NSOperationQueue of iOS 6 runs its operations on threads of its own: the quality of service of iOS 8 is remembered but does not steer that scheduling");
    });
}

@implementation NSOperationQueue (CharonQualityOfService)

- (NSQualityOfService)qualityOfService
{
    NSNumber *quality = objc_getAssociatedObject(self, &CharonQueueQualityKey);
    if (quality)
        return (NSQualityOfService)quality.integerValue;
    return self == [NSOperationQueue mainQueue] ? NSQualityOfServiceUserInteractive : NSQualityOfServiceDefault;
}

- (void)setQualityOfService:(NSQualityOfService)qualityOfService
{
    charon_note_queue_scheduling();
    objc_setAssociatedObject(self, &CharonQueueQualityKey, @(charon_quality_of_service(qualityOfService)), OBJC_ASSOCIATION_RETAIN);
}

@end
