#import "CharonHomeKitInternal.h"

@implementation HMAccessorySetupPayload

@synthesize charon_setupPayloadURL = _charon_setupPayloadURL;
@synthesize charon_ownershipToken = _charon_ownershipToken;

- (instancetype)initWithURL:(NSURL *)setupPayloadURL
{
    if (setupPayloadURL == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        _charon_setupPayloadURL = setupPayloadURL;
    }
    return self;
}

@end
