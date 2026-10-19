#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>

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
