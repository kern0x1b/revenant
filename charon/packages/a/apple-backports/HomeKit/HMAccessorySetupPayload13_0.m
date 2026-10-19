#import "CharonHomeKitInternal.h"

@implementation HMAccessorySetupPayload (Charon13_0)

- (instancetype)initWithURL:(NSURL *)setupPayloadURL
         ownershipToken:(HMAccessoryOwnershipToken *)ownershipToken
{
    if (setupPayloadURL == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        self.charon_setupPayloadURL = setupPayloadURL;
        self.charon_ownershipToken = ownershipToken;
    }
    return self;
}

@end
