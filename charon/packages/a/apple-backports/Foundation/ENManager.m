#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>

// ENManager, iOS 12.5: the class an application creates to ask the system whether it has been near
// another device that reported itself infected.
//
// What this release can answer, and why that is the whole of it
//
// Exposure Notification is an OS service that arrived in iOS 12.5. It needs three things this
// release does not have: the framework, which 6.1.3 has no trace of (its ObjC inventory carries no EN
// class and its export trie carries no EN symbol), the entitlement and the per-device authorization
// behind the service, which no port can grant itself, and the Bluetooth Low Energy subsystem the
// service broadcasts over, which iOS 6 does not run at all -- the ENManager header says so itself,
// twice: that Bluetooth must be on for Exposure Notification under ENStatusBluetoothOff, and that the
// service can use Bluetooth where apps cannot (the header).
//
// So there is no detection to perform and no key to hand out, and every member that needs the service
// answers what Apple's own framework answers for a device that cannot do Exposure Notification at all:
//
//   -exposureNotificationStatus   ENStatusUnauthorized (6). ENStatus has no "unsupported" case; its own
//                                 header documents ENStatusUnauthorized as "Exposure Notification is
//                                 not available due to insufficient authorization", which is what a
//                                 release with no service and no entitlement is.
//   +authorizationStatus          ENAuthorizationStatusNotAuthorized (2), documented as "This app is
//                                 not authorized to use Exposure Notification".
//   -exposureNotificationEnabled  NO.
//   every method                  its completion handler, with an NSError in ENErrorDomain carrying
//                                 ENErrorCodeUnsupported (5), documented as "Operation is not
//                                 supported" -- or ENErrorCodeInvalidated (6) after -invalidate,
//                                 which is what that code documents.
//
// The handlers run on `dispatchQueue`, which the header says defaults to the main queue, and
// -invalidate is the one member with behaviour that does not need the service: it marks the object
// unusable and calls -invalidationHandler exactly once, which is precisely what the header promises
// (the invalidation handler runs once even when invalidate is called several times, as the header states).
//
// One release per object file: every member here arrived in iOS 12.5. The 13.5 and 14.4 members are in
// ENManagerExposureInfo13.m and ENManagerPreAuthorized14.m beside this one.

// The one answer this file builds, so every member below hands out the same one: an NSError in the
// framework's own domain, with the framework's own code and Apple's own description of what it means.
// ENCommon.h states ENErrorCodeUnsupported as "Operation is not supported" and ENErrorCodeInvalidated as
// "Invalidate was called before the operation completed normally".
static NSError *CharonENUnsupportedError(void)
{
    return [NSError errorWithDomain:ENErrorDomain
                               code:ENErrorCodeUnsupported
                           userInfo:@{NSLocalizedDescriptionKey: @"Operation is not supported"}];
}

static NSError *CharonENInvalidatedError(void)
{
    return [NSError errorWithDomain:ENErrorDomain
                               code:ENErrorCodeInvalidated
                           userInfo:@{NSLocalizedDescriptionKey: @"Invalidate was called before the operation completed normally"}];
}

@implementation ENManager {
    ENActivityHandler _activityHandler;
    dispatch_block_t _invalidationHandler;
    BOOL _invalidated;
}

- (void)dealloc
{
    // The header promises the invalidation handler is invoked exactly once and that all strong
    // references are cleared when invalidation completes, "to break potential retain cycles", and that
    // nothing is invoked after invalidation. An application that drops its last ENManager without
    // calling -invalidate still gets its one invocation, from the only place left that can give it.
    [self invalidate];
}

- (ENActivityHandler)activityHandler
{
    return _activityHandler;
}

- (void)setActivityHandler:(ENActivityHandler)activityHandler
{
    _activityHandler = [activityHandler copy];
}

- (dispatch_block_t)invalidationHandler
{
    return _invalidationHandler;
}

- (void)setInvalidationHandler:(dispatch_block_t)invalidationHandler
{
    _invalidationHandler = [invalidationHandler copy];
}

// The header gives the dispatch queue for invoking handlers, defaulting to the main queue. The queue is what a
// completion handler would be called on, and every handler here is called where it is called -- the
// completion blocks are invoked synchronously, so there is nothing to dispatch -- but the property is
// carried because it is what the header declares and a caller may set it.
- (dispatch_queue_t)dispatchQueue
{
    return _dispatchQueue ? _dispatchQueue : dispatch_get_main_queue();
}

- (ENStatus)exposureNotificationStatus
{
    return ENStatusUnauthorized;
}

+ (ENAuthorizationStatus)authorizationStatus
{
    return ENAuthorizationStatusNotAuthorized;
}

- (BOOL)exposureNotificationEnabled
{
    return NO;
}

- (void)activateWithCompletionHandler:(void (^)(BOOL success, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(NO, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

- (void)invalidate
{
    if (_invalidated)
        return;
    _invalidated = YES;
    dispatch_block_t handler = _invalidationHandler;
    // Cleared before it is invoked, which is what the header says this property is done for.
    _invalidationHandler = nil;
    _activityHandler = nil;
    if (handler)
        handler();
}

- (void)setExposureNotificationEnabled:(BOOL)enabled completionHandler:(void (^)(BOOL success, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(NO, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

- (void)detectExposuresWithConfiguration:(ENExposureConfiguration *)configuration
                       completionHandler:(void (^)(ENExposureDetectionSummary *_Nullable summary, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

- (void)detectExposuresWithConfiguration:(ENExposureConfiguration *)configuration
                     diagnosisKeyURLs:(NSSet<NSURL *> *)diagnosisKeyURLs
                      completionHandler:(void (^)(ENExposureDetectionSummary *_Nullable summary, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

- (void)getDiagnosisKeysWithCompletionHandler:(void (^)(NSArray<ENTemporaryExposureKey *> *_Nullable diagnosisKeys, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

- (void)getTestDiagnosisKeysWithCompletionHandler:(void (^)(NSArray<ENTemporaryExposureKey *> *_Nullable testDiagnosisKeys, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

- (void)getExposureWindowsFromSummary:(ENExposureDetectionSummary *)summary
                    completionHandler:(void (^)(NSArray<ENExposureWindow *> *_Nullable exposureWindows, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

- (void)getUserTraveledWithCompletionHandler:(void (^)(BOOL userTraveled, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(NO, self->_invalidated ? CharonENInvalidatedError() : CharonENUnsupportedError());
}

@end