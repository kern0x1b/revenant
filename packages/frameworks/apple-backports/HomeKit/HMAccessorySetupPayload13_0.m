#import "RevenantHomeKitInternal.h"

@implementation HMAccessorySetupPayload (Revenant13_0)

- (instancetype)initWithURL:(NSURL *)setupPayloadURL
         ownershipToken:(HMAccessoryOwnershipToken *)ownershipToken
{
    if (setupPayloadURL == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        self.revenant_setupPayloadURL = setupPayloadURL;
        self.revenant_ownershipToken = ownershipToken;
    }
    return self;
}

@end
