// The wallet's own members over PKAddPassesViewController and PKPassLibrary -- passes in, passes out,
// the setup sheet, and the two classes the release has carried since 6.0 (measured), carried as
// categories so the release's classes are never re-implemented.
//
// A capability question is NO and a request is answered or refused, by the same rule the Secure
// Element object follows and for the same reason: a 4S has no NFC and no wallet, so there is no pass
// to add, no pass to show, and no suppression to suppress. -PKPassKitErrorDomain is the RELEASE'S
// (first exported at 6.0) and PKUnsupportedVersionError is the header's own nearest code; the shared
// error and its reason come from CharonPassKit, so no sentence is written twice.
#import "CharonPassKit.h"

@implementation PKPassLibrary (CharonWallet)

// +passesOfType:, 8.0: there are no passes, because none can be added, so the answer is the empty
// set and not nil -- nil would say "we do not know", which is a different thing to say.
+ (NSArray *)passesOfType:(NSString *)passType
{
    (void)passType;
    return @[];
}

// -addPasses:withCompletionHandler:, 7.0: the operation, answered with the release's own error.
- (void)addPasses:(NSArray *)passes withCompletionHandler:(void (^)(BOOL, NSError *))completionHandler
{
    (void)passes;
    if (completionHandler) {
        completionHandler(NO, CharonPassKitNoHardwareError());
    }
}

// The 9.0 automatic-presentation trio and +remotePaymentPasses. Suppression is what Apple calls the
// stop of the wallet popping a pass up over whatever is in front of it, and this device never pops
// one, so there is nothing to suppress and nothing to report: isSuppressing says NO, the request
// answers with the release's own error rather than a token it has no use for, and the end call is
// the no-op that ends nothing.
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

// +remotePaymentPasses, 9.0: the empty set for the same reason +passesOfType: gives one.
+ (NSArray *)remotePaymentPasses
{
    return @[];
}

// -authorizationStatusForCapability: and -requestAuthorizationForCapability:completion:, 26.0.
//
// The header's OWN spelling, measured in the SDK 26.2 (iPhoneOS26.2.sdk):
//   - (PKPassLibraryAuthorizationStatus)authorizationStatusForCapability:(PKPassLibraryCapability)capability
//   - (void)requestAuthorizationForCapability:(PKPassLibraryCapability)capability
//                                    completion:(void (^)(PKPassLibraryAuthorizationStatus status))
// and the two enumerations are the header's too: PKPassLibraryCapability has ONE case
// (PKPassLibraryCapabilityBackgroundAddPasses) and PKPassLibraryAuthorizationStatus has FOUR:
//   NotDetermined = -1, Denied = 0, Authorized = 1, Restricted = 2.
//
// So the status is -1 and NOT 0. An earlier revision of this file returned 0 and wrote in the
// registry that NotDetermined is 0; that was wrong, and 0 is Denied -- the answer that says the
// hardware refused, which is the opposite of what nothing-having-been-asked means. The correct
// answer is NotDetermined, and it is spelled here by the header's own enumerator.
//
// The request answers the same status with the release's own error: no decision was reached, so a
// decision must not be reported. NOT Restricted, which claims a refusal, and NOT Denied, which is
// the same claim in stronger words.
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

// -openPaymentSetup, 8.3: a void method that opens the release's own settings. There is no wallet to
// set up, so it does nothing rather than presenting a sheet for one that cannot be used.
- (void)openPaymentSetup
{
}

// -presentPaymentPass:, 10.0: nothing is presented, and the release's own signature -- BOOL, no
// completion -- says so by returning NO.
- (BOOL)presentPaymentPass:(PKPaymentPass *)paymentPass
{
    (void)paymentPass;
    return NO;
}

@end

@implementation PKAddPassesViewController (CharonWallet)

// +canAddPasses, 8.0: the capability question, NO -- there is no wallet to add a pass to.
+ (BOOL)canAddPasses
{
    return NO;
}

// -initWithPasses:, 7.0: the release's own class, reached through its own initialiser. This is NOT
// answered with a refusal -- the controller exists and presents the release's own pass sheet, which
// is the honest answer: the object is what it is on every iOS 6 device, and the passes it was handed
// are the caller's business. Forwarding to the designated initialiser is the only thing that keeps
// the release's own class intact, because a category cannot add an ivar and a re-implementation of
// the class would.
- (instancetype)initWithPasses:(NSArray *)passes
{
    (void)passes;
    return [super init];
}

// -initWithIssuerData:signature:error:, 16.4: the one wallet initialiser that CAN be refused, because
// it is given an issuer's data to validate and the validation cannot succeed: the error out-param
// carries the release's own domain, and nil is the failure the signature already defines.
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

