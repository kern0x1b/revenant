#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "RevenantPhotos.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface RevenantPhotosAvailability : NSObject {
    NSHashTable *_observers;
    dispatch_queue_t _delivery;
    id _listening;
    NSInteger _last;
}
@property (nonatomic, strong, nullable) NSHashTable *observers;
@property (nonatomic, strong, nullable) dispatch_queue_t delivery;
@property (nonatomic, strong, nullable) id listening;
@property (nonatomic, assign) NSInteger last;
@end

@implementation RevenantPhotosAvailability
@synthesize observers = _observers, delivery = _delivery, listening = _listening, last = _last;
@end

static const char RevenantPhotosAvailabilityKey[] = "RevenantPhotosAvailability";

static RevenantPhotosAvailability *revenant_availabilityOf(PHPhotoLibrary *library)
{
    return objc_getAssociatedObject(library, RevenantPhotosAvailabilityKey);
}

static RevenantPhotosAvailability *revenant_availabilityAttachedTo(PHPhotoLibrary *library)
{
    RevenantPhotosAvailability *availability = [[RevenantPhotosAvailability alloc] init];
    objc_setAssociatedObject(library, RevenantPhotosAvailabilityKey, availability,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return availability;
}

@interface PHPhotoLibrary (RevenantAvailability)
- (void)revenant_availabilityRefreshed;
@end

@implementation PHPhotoLibrary (RevenantAvailability)

+ (NSInteger)revenant_unavailabilityOfRelease
{
    switch ([ALAssetsLibrary authorizationStatus]) {
        case ALAuthorizationStatusRestricted:
            return 2;
        case ALAuthorizationStatusDenied:
            return 1;
        default:
            return 0;
    }
}

+ (NSError *)revenant_unavailabilityReasonOf:(NSInteger)state
{
    switch (state) {
        case 1:
            return [NSError errorWithDomain:PHPhotosErrorDomain code:PHPhotosErrorAccessUserDenied
                                   userInfo:@{NSLocalizedDescriptionKey: @"the user has denied access to the photo library"}];
        case 2:
            return [NSError errorWithDomain:PHPhotosErrorDomain code:PHPhotosErrorAccessRestricted
                                   userInfo:@{NSLocalizedDescriptionKey: @"access to the photo library is restricted by system configuration"}];
        default:
            return nil;
    }
}

- (void)revenant_availabilityBecame:(NSInteger)state
{
    NSArray *observers;
    RevenantPhotosAvailability *availability = revenant_availabilityOf(self);
    @synchronized(self) {
        if (!availability) {
            availability = revenant_availabilityAttachedTo(self);
        }
        NSInteger before = availability.last;
        availability.last = state;
        if (before == state || before != 0 || state == 0)
            return;
        observers = availability.observers.allObjects;
    }
    if (observers.count == 0)
        return;
    dispatch_async(availability.delivery, ^{
        for (id<PHPhotoLibraryAvailabilityObserver> observer in observers)
            [observer photoLibraryDidBecomeUnavailable:[PHPhotoLibrary sharedPhotoLibrary]];
    });
}

- (void)revenant_availabilityRefreshed
{
    [self revenant_availabilityBecame:[PHPhotoLibrary revenant_unavailabilityOfRelease]];
}

- (NSError *)unavailabilityReason
{
    [self revenant_availabilityRefreshed];
    return [PHPhotoLibrary revenant_unavailabilityReasonOf:[PHPhotoLibrary revenant_unavailabilityOfRelease]];
}

- (void)registerAvailabilityObserver:(id<PHPhotoLibraryAvailabilityObserver>)observer
{
    if (!observer)
        return;
    @synchronized(self) {
        RevenantPhotosAvailability *availability = revenant_availabilityOf(self);
        if (!availability) {
            availability = revenant_availabilityAttachedTo(self);
            availability.last = [PHPhotoLibrary revenant_unavailabilityOfRelease];
            __weak PHPhotoLibrary *weakSelf = self;
            availability.listening = [[NSNotificationCenter defaultCenter] addObserverForName:ALAssetsLibraryChangedNotification
                                                                                          object:[RevenantPhotosStore library]
                                                                                           queue:nil
                                                                                      usingBlock:^(NSNotification *note) {
                (void)note;
                [weakSelf revenant_availabilityRefreshed];
            }];
        }
        if (!availability.observers) {
            availability.observers = [NSHashTable weakObjectsHashTable];
            availability.delivery = dispatch_queue_create("space.kern0x1b.photos.availability", DISPATCH_QUEUE_SERIAL);
        }
        [availability.observers addObject:observer];
    }
}

- (void)unregisterAvailabilityObserver:(id<PHPhotoLibraryAvailabilityObserver>)observer
{
    @synchronized(self) {
        [revenant_availabilityOf(self).observers removeObject:observer];
    }
}

@end
