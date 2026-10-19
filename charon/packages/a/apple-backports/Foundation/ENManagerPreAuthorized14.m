#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>
#import <objc/runtime.h>

// ENManager's pre-authorized diagnosis keys, iOS 14.4: -preAuthorizeDiagnosisKeysWithCompletionHandler:,
// -requestPreAuthorizedDiagnosisKeysWithCompletionHandler: and the -diagnosisKeysAvailableHandler.
//
// Three members, and one release: ENManager's other members arrived in 12.5 and are in ENManager.m, whose
// file explains why this release has no exposure-notification service to ask. An object holds the API of
// exactly one release, so these cannot share a file with those.
//
// The handler is carried: the header declares it readwrite and copy, so setting it and reading it back
// are the port's own. The two methods answer the same way ENManager's do, through the framework's own
// domain and its own documented code: pre-authorizing keys means handing a bundle of keys to the
// service to publish, and there is no service to publish them to, so each completion handler is called
// with NO and ENErrorCodeUnsupported.

// The handler's storage, an associated object rather than an ivar on the 12.5 object: an ivar added
// there cannot be named from this file, and this object's exports are its API symbols and not its
// storage. The key is a file-static, so nothing outside this translation unit can collide with it.
static const char charon_diagnosisKeysAvailableHandlerKey;

@implementation ENManager (CharonPreAuthorized14)

- (void)charon_setDiagnosisKeysAvailableHandler:(void (^)(NSArray<ENTemporaryExposureKey *> *diagnosisKeys))diagnosisKeysAvailableHandler
{
    objc_setAssociatedObject(self, &charon_diagnosisKeysAvailableHandlerKey,
                             [diagnosisKeysAvailableHandler copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(NSArray<ENTemporaryExposureKey *> *))diagnosisKeysAvailableHandler
{
    return objc_getAssociatedObject(self, &charon_diagnosisKeysAvailableHandlerKey);
}

- (void)preAuthorizeDiagnosisKeysWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler([NSError errorWithDomain:ENErrorDomain
                                              code:ENErrorCodeUnsupported
                                          userInfo:@{NSLocalizedDescriptionKey: @"Operation is not supported"}]);
}

- (void)requestPreAuthorizedDiagnosisKeysWithCompletionHandler:(void (^)(NSArray<ENTemporaryExposureKey *> *_Nullable diagnosisKeys, NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil, [NSError errorWithDomain:ENErrorDomain
                                                   code:ENErrorCodeUnsupported
                                               userInfo:@{NSLocalizedDescriptionKey: @"Operation is not supported"}]);
}

@end
