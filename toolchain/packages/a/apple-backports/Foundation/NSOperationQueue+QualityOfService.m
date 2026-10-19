#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSQualityOfService revenant_quality_of_service(NSInteger quality);

static char RevenantQueueQualityKey;

static void revenant_note_queue_scheduling(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"an NSOperationQueue of iOS 6 runs its operations on threads of its own: the quality of service of iOS 8 is remembered but does not steer that scheduling");
    });
}

@implementation NSOperationQueue (RevenantQualityOfService)

- (NSQualityOfService)qualityOfService
{
    NSNumber *quality = objc_getAssociatedObject(self, &RevenantQueueQualityKey);
    if (quality)
        return (NSQualityOfService)quality.integerValue;
    return self == [NSOperationQueue mainQueue] ? NSQualityOfServiceUserInteractive : NSQualityOfServiceDefault;
}

- (void)setQualityOfService:(NSQualityOfService)qualityOfService
{
    revenant_note_queue_scheduling();
    objc_setAssociatedObject(self, &RevenantQueueQualityKey, @(revenant_quality_of_service(qualityOfService)), OBJC_ASSOCIATION_RETAIN);
}

@end
