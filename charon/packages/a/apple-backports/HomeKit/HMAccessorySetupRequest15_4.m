// HMAccessorySetupRequest, of iOS 15.4: what an application fills in and hands to the setup manager.
//
// One release's API per object file, and this class is of 15.4 alone.
//
// The 26.2 header, HMAccessorySetupRequest.h:18-59:
//   API_AVAILABLE(ios(15.4))
//   @interface HMAccessorySetupRequest : NSObject<NSCopying>
//     - (instancetype)init;                                                  line 23
//     @property (nullable, copy) HMAccessorySetupPayload *payload;           line 30
//     @property (nullable, copy) NSUUID *homeUniqueIdentifier;               line 36
//     @property (nullable, copy) NSUUID *suggestedRoomUniqueIdentifier;      line 44
//     @property (nullable, copy) NSString *suggestedAccessoryName;           line 52
//     @property (nullable, strong) MTRSetupPayload *matterPayload;           line 59
//
// **The properties are the request's content and are copied like the header says.**
// `payload` is the HMAccessorySetupPayload of 11.3, the `homeUniqueIdentifier` and
// `suggestedRoomUniqueIdentifier` are identifiers of a home and a room in the port's own store, and
// `suggestedAccessoryName` is a name. Each is nullable and each is `copy`, which is not decoration: a
// caller that hands in an NSUUID and then mutates it must not find the request changed underneath, and
// -copyWithZone: below carries all four for the same reason.
//
// **-matterPayload is storage, and it is carried.** It holds the Matter setup payload a caller sets and
// reads it back, which is what a property is; the port's class has to be able to hold what the release's
// class holds. What the port does NOT do is commission a Matter device -- the pairing, the transport and
// the system setup UI are all things a real device has and this has not -- and that is recorded as what it
// is, on the member that does the commissioning and not on the slot that holds its object.

#import "CharonHomeKitInternal.h"

@implementation HMAccessorySetupRequest

// matterPayload is carried, and it is the fifth of the five the header declares: a property is STORAGE,
// and this one stores the payload object a caller sets and reads it back -- which is what a property is,
// and the port's class must be able to hold what the release's class holds. Commissioning a Matter
// accessory over Matter is a transport the port does not speak, and THAT is the part this port does not
// do; the slot that holds the object is storage, not the commissioning, and drawing the line at the slot
// would leave a header property silently unsynthesised, which is a port answering a member of the
// release's surface with nothing at all. So it is synthesised explicitly, like the other four, and the
// type is the SDK's own MTRSetupPayload * -- the port holds the object and does not look inside it.
@synthesize payload = _payload, homeUniqueIdentifier = _homeUniqueIdentifier,
          suggestedRoomUniqueIdentifier = _suggestedRoomUniqueIdentifier,
          suggestedAccessoryName = _suggestedAccessoryName,
          matterPayload = _matterPayload;

// The release declares -init available on this NSObject subclass, so the port answers it: a request
// whose four properties are all nullable and default to nil is already a valid empty request, and a
// caller that allocated one without calling -init would get something the release would not hand it.
- (instancetype)init
{
    self = [super init];
    return self;
}

// NSObject<NSCopying>, and the four the header declares copy. A request that copied only some of them
// would come back from -copy with some of the caller's values and some of its own, and a caller that set
// a name, copied the request and changed the original would find the copy still pointing at the old graph
// object. All five the header declares are carried, and the header's own "copy" attribute is why each is
// copied rather than retained.
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
