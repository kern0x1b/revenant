#import "CharonPassKit.h"

@implementation PKPassLibrary (CharonWallet)

+ (NSArray *)passesOfType:(NSString *)passType
{
    (void)passType;
    return @[];
}

- (void)addPasses:(NSArray *)passes withCompletionHandler:(void (^)(BOOL, NSError *))completionHandler
{
    (void)passes;
    if (completionHandler) {
        completionHandler(NO, CharonPassKitNoHardwareError());
    }
}

+ (BOOL)isSuppressingAutomaticPassPresentation
{
    return NO;
}

+ (void)requestAutomaticPassPresentationSuppressionWithResponseHandler:
    (void (^)(id suppressionToken, NSError *error))responseHandler
{
    if (responseHandler) {
        responseHandler(nil, CharonPassKitNoHardwareError());
    }
}

+ (void)endAutomaticPassPresentationSuppressionWithRequestToken:(id)requestToken
{
    (void)requestToken;
}

+ (NSArray *)remotePaymentPasses
{
    return @[];
}

- (PKPassLibraryAuthorizationStatus)authorizationStatusForCapability:(PKPassLibraryCapability)capability
{
    (void)capability;
    return PKPassLibraryAuthorizationStatusNotDetermined;
}

- (void)requestAuthorizationForCapability:(PKPassLibraryCapability)capability
                                   completion:(void (^)(PKPassLibraryAuthorizationStatus status))completion
{
    (void)capability;
    if (completion) {
        completion(PKPassLibraryAuthorizationStatusNotDetermined);
    }
}

- (void)openPaymentSetup
{
}

- (BOOL)presentPaymentPass:(PKPaymentPass *)paymentPass
{
    (void)paymentPass;
    return NO;
}

@end

@implementation PKAddPassesViewController (CharonWallet)

+ (BOOL)canAddPasses
{
    return NO;
}

- (instancetype)initWithPasses:(NSArray *)passes
{
    (void)passes;
    return [super init];
}

- (nullable instancetype)initWithIssuerData:(NSData *)issuerData
                                  signature:(NSData *)signature
                                      error:(NSError **)error
{
    (void)issuerData;
    (void)signature;
    if (error) {
        *error = CharonPassKitNoHardwareError();
    }
    return nil;
}

@end
