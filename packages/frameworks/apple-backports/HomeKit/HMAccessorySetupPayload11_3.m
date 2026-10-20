#import "RevenantHomeKitInternal.h"

@implementation HMAccessorySetupPayload

@synthesize revenant_setupPayloadURL = _revenant_setupPayloadURL;
@synthesize revenant_ownershipToken = _revenant_ownershipToken;

- (instancetype)initWithURL:(NSURL *)setupPayloadURL
{
    if (setupPayloadURL == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        _revenant_setupPayloadURL = setupPayloadURL;
    }
    return self;
}

@end
