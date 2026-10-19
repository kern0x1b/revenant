#import <AssetsLibrary/AssetsLibrary.h>
#import "CharonPhotos.h"
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static void charon_deliver_authorization(void (^handler)(PHAuthorizationStatus status))
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handler((PHAuthorizationStatus)[ALAssetsLibrary authorizationStatus]);
    });
}

@implementation PHPhotoLibrary

// Both are dynamic, and the second one is the reason this line is worth reading.
//
// currentChangeToken is of iOS 16 and the port does not carry it (registry/Photos/ios8.json), so the
// class declares the property the header declares and answers no selector.
//
// unavailabilityReason is of iOS 13 and IS implemented, in PHPhotoLibraryAvailability13.m. Leaving it
// off this line makes clang auto-synthesize it here: a `_unavailabilityReason` instance variable, a
// getter, and a property the class claims. The category's getter then overrides that one at link time,
// which is what the build printed --
//   ld: warning: method '-unavailabilityReason' in category from .../17.o overrides method from class
//       in .../16.o
//   PHPhotoLibraryAvailability13.m:88: warning: category is implementing a method which will also be
//       implemented by its primary class [-Wobjc-protocol-method-implementation]
// -- and which worked only because ld64 merges a category over the class in the same image. That is a
// warning on every build and an override whose winner is the linker's, not the runtime's: a subclass
// would resolve the class's own nil-returning getter ahead of the category's. Measured on 2026-10-01,
// building the four programs for the device.
@dynamic currentChangeToken, unavailabilityReason;

+ (PHPhotoLibrary *)sharedPhotoLibrary
{
    static PHPhotoLibrary *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = ((id (*)(id, SEL))objc_msgSend)([self alloc], sel_registerName("init"));
    });
    return shared;
}

+ (PHAuthorizationStatus)authorizationStatus
{
    return (PHAuthorizationStatus)[ALAssetsLibrary authorizationStatus];
}

+ (void)requestAuthorization:(void (^)(PHAuthorizationStatus status))handler
{
    void (^kept)(PHAuthorizationStatus) = [handler copy];
    if ([ALAssetsLibrary authorizationStatus] != ALAuthorizationStatusNotDetermined) {
        charon_deliver_authorization(kept);
        return;
    }
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    __block BOOL answered = NO;
    void (^answer)(void) = ^{
        if (answered)
            return;
        answered = YES;
        charon_deliver_authorization(kept);
    };
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        *stop = YES;
        answer();
    } failureBlock:^(NSError *error) {
        answer();
    }];
}

// The release says a change of the library with ALAssetsLibraryChangedNotification, posted by the
// ALAssetsLibrary the port reads through; each observer is told on a serial queue off the main thread,
// and it is held weakly, as the library of iOS 8 holds it (facts/Photos/Changes.md).
- (void)registerChangeObserver:(id<PHPhotoLibraryChangeObserver>)observer
{
    @synchronized(self) {
        if (!_observers) {
            _observers = [NSHashTable weakObjectsHashTable];
            _delivery = dispatch_queue_create("space.kern0x1b.photos.changes", DISPATCH_QUEUE_SERIAL);
        }
        [_observers addObject:observer];
        if (_listening)
            return;
        __weak PHPhotoLibrary *weakSelf = self;
        _listening = [[NSNotificationCenter defaultCenter] addObserverForName:ALAssetsLibraryChangedNotification object:[CharonPhotosStore library] queue:nil usingBlock:^(NSNotification *note) {
            [weakSelf charon_libraryChanged:note.userInfo];
        }];
    }
}

- (void)unregisterChangeObserver:(id<PHPhotoLibraryChangeObserver>)observer
{
    @synchronized(self) {
        [_observers removeObject:observer];
    }
}

// Every notification is passed on: 6.1.3 posts an empty user info for a write of the application itself,
// a real change, and the change reads again whatever it is asked about.
- (void)charon_libraryChanged:(NSDictionary *)userInfo
{
    NSArray *observers;
    @synchronized(self) {
        observers = _observers.allObjects;
    }
    if (observers.count == 0)
        return;
    PHChange *change = [[PHChange alloc] initWithCharonUserInfo:userInfo];
    dispatch_async(_delivery, ^{
        for (id<PHPhotoLibraryChangeObserver> observer in observers)
            [observer photoLibraryDidChange:change];
    });
}

- (void)performChanges:(dispatch_block_t)changeBlock completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    [CharonPhotosTransaction run:changeBlock then:completionHandler];
}

- (BOOL)performChangesAndWait:(dispatch_block_t)changeBlock error:(NSError **)error
{
    return [CharonPhotosTransaction runAndWait:changeBlock error:error];
}

+ (PHAuthorizationStatus)authorizationStatusForAccessLevel:(PHAccessLevel)accessLevel
{
    return [self authorizationStatus];
}

+ (void)requestAuthorizationForAccessLevel:(PHAccessLevel)accessLevel handler:(void (^)(PHAuthorizationStatus status))handler
{
    [self requestAuthorization:handler];
}

@end
