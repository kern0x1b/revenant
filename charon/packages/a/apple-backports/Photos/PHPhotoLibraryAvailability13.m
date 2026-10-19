#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "CharonPhotos.h"
#import <objc/runtime.h>

// PHPhotoLibrary's library availability, of iOS 13. One object for one release: the class members of
// the other releases are in their own files, and this one carries nothing of another.
//
// iOS 6 says the state of the photo library in two ways, and these answer from the two: the
// authorization ALAssetsLibrary reports, which the port's +[PHPhotoLibrary authorizationStatus] is
// already made of, and the refusal its own enumeration answers with when the library cannot be read.
// There is no third. The release has no way to be told that a volume went away, and the port does not
// invent one: the codes Apple's header gives for those events (3114, 3142, 3143) are named in
// facts/Photos/Availability.md as unreachable here, with the measurement that says so.
//
// The codes here are the header's own, for the cases the header gives them: PHPhotosErrorAccessUserDenied
// (3311) for a denied process and PHPhotosErrorAccessRestricted (3310) for a restricted one, both in
// the domain the header declares them in, PHPhotosErrorDomain.

// What the build still prints, and it is inherent to this file's shape: TWO
// -Wobjc-protocol-method-implementation, one for each registration method. PHPhotoLibrary's own
// interface in the SDK header declares both members, and a later release's members live in their own
// object, which is this category -- so clang sees a category implementing a method the primary class
// declares. The class implements neither: `nm` of the built PHPhotoLibrary.o carries no
// registerAvailabilityObserver: and no unregisterAvailabilityObserver: (measured 2026-10-01), and
// @dynamic on PHPhotoLibrary keeps it from claiming the property's getter, which auto-synthesis would
// otherwise put there ahead of the category's. The same diagnostic is ignored the same way in
// MPSImageThreshold13.m and MTLHeap13.m, for the same reason.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The state this file keeps for one library: the observers, the queue their callbacks are delivered
// on, the notification subscription that watches the release, and the last state it reported. It is
// an object of its own, held beside the library, because it cannot be an ivar of PHPhotoLibrary: this
// file is a category, so no band drops it and it is in every one of them, while the object that lays
// PHPhotoLibrary out is PHPhotoLibrary.m and a band from iOS 8.0 does not link that (the release has
// carried the class since 8.0). Four ivars of the class's own were read from here before, and the
// 8.0 gate refused the file by name for them:
//
//   REFUSED PHPhotoLibraryAvailability13.o is carried by every band and names
//           _OBJC_IVAR_$_PHPhotoLibrary._availabilityDelivery, which PHPhotoLibrary.o defines only
//           from 8.0 on
//
// An associated object is the runtime's own answer for state that belongs to an object but not to its
// class, and this package uses it elsewhere for the same reason (CloudKit/CKRecords10.m keeps a
// record's parent beside it for the same one).
@interface CharonPhotosAvailability : NSObject {
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

@implementation CharonPhotosAvailability
@synthesize observers = _observers, delivery = _delivery, listening = _listening, last = _last;
@end

static const char CharonPhotosAvailabilityKey[] = "CharonPhotosAvailability";

static CharonPhotosAvailability *charon_availabilityOf(PHPhotoLibrary *library)
{
    return objc_getAssociatedObject(library, CharonPhotosAvailabilityKey);
}

static CharonPhotosAvailability *charon_availabilityAttachedTo(PHPhotoLibrary *library)
{
    CharonPhotosAvailability *availability = [[CharonPhotosAvailability alloc] init];
    objc_setAssociatedObject(library, CharonPhotosAvailabilityKey, availability,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return availability;
}

@interface PHPhotoLibrary (CharonAvailability)
- (void)charon_availabilityRefreshed;
@end

@implementation PHPhotoLibrary (CharonAvailability)

// 0: available to this process. 1: denied. 2: restricted.
+ (NSInteger)charon_unavailabilityOfRelease
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

+ (NSError *)charon_unavailabilityReasonOf:(NSInteger)state
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

// A transition, not a state. An observer registered while the library is already unavailable is not
// told about it: "did become unavailable" is about a change, and a registration is otherwise a second
// way of asking for -[PHPhotoLibrary unavailabilityReason], which answers it.
- (void)charon_availabilityBecame:(NSInteger)state
{
    NSArray *observers;
    CharonPhotosAvailability *availability = charon_availabilityOf(self);
    @synchronized(self) {
        // The state is made on the first transition rather than on the first registration, which is
        // when the instance variable it replaces was first written: -last starts at 0, and 0 is the
        // "nothing reported yet" that makes the next transition a first one.
        if (!availability) {
            availability = charon_availabilityAttachedTo(self);
        }
        NSInteger before = availability.last;
        availability.last = state;
        if (before == state || before != 0 || state == 0)
            return;
        observers = availability.observers.allObjects;
    }
    if (observers.count == 0)
        return;
    // "This notification is posted on a private queue" (PHPhotoLibrary.h:45), which the header says
    // of the availability observers and of nothing else here; one serial queue of the port's own is,
    // and it exists because a queue is only made where an observer is registered.
    dispatch_async(availability.delivery, ^{
        for (id<PHPhotoLibraryAvailabilityObserver> observer in observers)
            [observer photoLibraryDidBecomeUnavailable:[PHPhotoLibrary sharedPhotoLibrary]];
    });
}

- (void)charon_availabilityRefreshed
{
    [self charon_availabilityBecame:[PHPhotoLibrary charon_unavailabilityOfRelease]];
}

- (NSError *)unavailabilityReason
{
    // Reading the reason is one of the two ways the port learns of a change: a denied process is told
    // no more than that, since the release posts nothing it cannot read.
    [self charon_availabilityRefreshed];
    return [PHPhotoLibrary charon_unavailabilityReasonOf:[PHPhotoLibrary charon_unavailabilityOfRelease]];
}

- (void)registerAvailabilityObserver:(id<PHPhotoLibraryAvailabilityObserver>)observer
{
    if (!observer)
        return;
    @synchronized(self) {
        CharonPhotosAvailability *availability = charon_availabilityOf(self);
        if (!availability) {
            availability = charon_availabilityAttachedTo(self);
            availability.last = [PHPhotoLibrary charon_unavailabilityOfRelease];
            __weak PHPhotoLibrary *weakSelf = self;
            availability.listening = [[NSNotificationCenter defaultCenter] addObserverForName:ALAssetsLibraryChangedNotification
                                                                                          object:[CharonPhotosStore library]
                                                                                           queue:nil
                                                                                      usingBlock:^(NSNotification *note) {
                (void)note;
                [weakSelf charon_availabilityRefreshed];
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
        [charon_availabilityOf(self).observers removeObject:observer];
    }
}

@end
