#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>
#import <objc/runtime.h>

static const char revenant_diagnosisKeysAvailableHandlerKey;

@implementation ENManager (RevenantPreAuthorized14)

- (void)revenant_setDiagnosisKeysAvailableHandler:(void (^)(NSArray<ENTemporaryExposureKey *> *diagnosisKeys))diagnosisKeysAvailableHandler
{
    objc_setAssociatedObject(self, &revenant_diagnosisKeysAvailableHandlerKey,
                             [diagnosisKeysAvailableHandler copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(NSArray<ENTemporaryExposureKey *> *))diagnosisKeysAvailableHandler
{
    return objc_getAssociatedObject(self, &revenant_diagnosisKeysAvailableHandlerKey);
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
