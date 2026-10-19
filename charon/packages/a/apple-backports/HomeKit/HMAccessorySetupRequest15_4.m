#import "CharonHomeKitInternal.h"

@implementation HMAccessorySetupRequest

@synthesize payload = _payload, homeUniqueIdentifier = _homeUniqueIdentifier,
          suggestedRoomUniqueIdentifier = _suggestedRoomUniqueIdentifier,
          suggestedAccessoryName = _suggestedAccessoryName,
          matterPayload = _matterPayload;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    HMAccessorySetupRequest *copy = [[self class] allocWithZone:zone];
    copy.payload = self.payload;
    copy.homeUniqueIdentifier = self.homeUniqueIdentifier;
    copy.suggestedRoomUniqueIdentifier = self.suggestedRoomUniqueIdentifier;
    copy.suggestedAccessoryName = self.suggestedAccessoryName;
    copy.matterPayload = self.matterPayload;
    return copy;
}

@end
