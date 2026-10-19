// The 13.0 member of the session configuration: the content style the connected CarPlay system
// suggests, and nothing else in this class.
//
// CPSessionConfiguration.h:36 declares `@property (nonatomic, readonly) CPContentStyle contentStyle
// API_AVAILABLE(ios(13.0))`, and the rest of the class is 12.0. An object holds API of exactly one
// release (modules/apple/backports.lua's releases_in, read by `tools/release-split.lua`), so this
// property is an object of its own and CarPlaySessionConfiguration12.m stays 12.0. That is the same
// reason the 15.4 pause-with-a-colour of the navigation session is CarPlayNavigationSession154.m and the
// 17.4 members are CarPlayNavigationSession174.m.
//
// WHAT THE VALUE IS, and why this row is `inert` and not `absent` and not `implemented`. The header's
// own comment at :35-36 gives the current content style as suggested by the connected CarPlay system, and it
// is `readonly` with no public setter. Per class on the 16.0 arm64e cache (tools/corpus/objc-inventory.lua)
// CPSessionConfiguration conforms to the private protocol CARSessionObserving and carries
// -setContentStyle: as the only writer of this value, alongside the connection lifecycle
// -sessionDidConnect:, -_contentStyleUpdated:, -_updateContentStyleWithScene: and -_updateLimitedUIStatus.
// So the writer is the connected system, and there is no connected system on either fleet device
// (iPhone 4S, iPad 2, iOS 6.1.3). The symbol loads, the getter answers, and nothing applies it: that is
// what `inert` says and it is why this is not `absent` -- the 26.2 header declares the property and
// Apple's own object carries it, so `absent` would be a claim about Apple rather than about this port.
//
// Measured on Apple's own object with no head unit attached: `contentStyle` answers 0, which is not one
// of CPContentStyleLight = 1 << 0 or CPContentStyleDark = 1 << 1 (CPSessionConfiguration.h:18-21). So 0
// is not "light" and not "dark" and the port does not turn it into either -- a caller that reads this and
// acts on 0 as a style would be reading a value the system never chose, and the row's effect says so.
//
// The storage is not here: a category cannot add an ivar, so `_charonContentStyle` sits with the class's
// own ivars in CarPlaySessionConfiguration12.m and this category reads it through the Charon accessor
// declared there. The 12.0 object declares `@dynamic contentStyle` for the same reason it does not
// @synthesize it.
#import <CarPlay/CarPlay.h>
#import "CharonCarPlaySessionConfiguration.h"

@implementation CPSessionConfiguration (CharonContentStyle13)

// The header's readonly accessor and nothing more: no setter, because the header declares none and the
// release's own writer is the private -setContentStyle: on a class conforming to CARSessionObserving.
- (CPContentStyle)contentStyle
{
    return [self charon_contentStyle];
}

@end