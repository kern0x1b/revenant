#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>
#import <objc/runtime.h>

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
