// CPSessionConfiguration: the application's half of a CarPlay session's configuration, and the split
// between the two halves is the header's own.
//
// CPSessionConfiguration.h:25-40 is five rows in one header and they are not the same kind of thing.
// :26 gives the class, :28 the designated initialiser, :38 a readwrite weak `delegate` whose own comment
// says the system will use it "to configure the system UI" -- that is the application's half and it is
// :33 declares `limitedUserInterfaces` readonly, described only as a bitmask of the limited interface types; :36 declares
// `contentStyle` readonly, described as the content style the connected CarPlay system suggests. Those two are the connected system's, and they are
// `inert` -- the symbol loads and nothing applies it -- and `contentStyle` is 13.0 so it is an object of
// its own.
//
// Not `absent`, and that is the correction this slice makes. The 26.2 header declares both values and
// Apple's own object carries them, so an `absent` row would be a claim about Apple rather than about this
// port. The 16.0 arm64e cache says who writes them, and it says it is a connection: per class,
// CPSessionConfiguration conforms to the private protocol CARSessionObserving, carries -setContentStyle:
// and -setLimitedUserInterfaces: as its only writers of those two values, and carries the connection
// lifecycle around them -- -sessionDidConnect:, -_contentStyleUpdated:, -_limitedUIDidChange:,
// -_updateContentStyleWithScene:, -_updateLimitedUIStatus, -convertLimitableUserInterfaces:. A session is
// a connection to a head unit, and neither fleet device (iPhone 4S, iPad 2, iOS 6.1.3) has one, so
// nothing in this library writes either value and there is nothing for it to be written from.
//
// Measured on Apple's own object with no head unit attached, and on the port's, diffed label by label
// (tests/backports/host/carplay/headunit-probe.m section 5, tests/backports/host/carplay/runner.m):
//
//     ok  the designated initialiser makes a configuration               CPSessionConfiguration
//     ok  delegate answers the delegate it was given                    same object
//     ok  limitedUserInterfaces answers the mask the connected system suggests  0
//     ok  contentStyle answers the style the connected system suggests    0
//     ok  the two values have no public setter: both are readonly in the header
//     ok  what the connected system writes is the only writer: nothing here writes it  0 / 0
//
// -init and +new are NOT here: CPSessionConfiguration.h:29-30 marks both NS_UNAVAILABLE, and the
// registry carries those two rows `absent` for exactly that reason. The measurement behind that is the
// cache's own: at both 16.0 and 18.0 the class's method list contains neither `-init` nor `+new`, so the
// release declares no initialiser of its own and both are NSObject's -- which is why those rows are
// `absent` (the release carries nothing under those names) and not `ignored` (which would be the status
// for a name the release DOES carry and the port declines).
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlaySessionConfiguration.h"

@implementation CPSessionConfiguration {
    // The delegate is weak because the header says weak (:38): the configuration does not keep a
    // delegate alive, and a strong reference here would be a port's own ownership the header forbids.
    __weak id<CPSessionConfigurationDelegate> _delegate;
    // The 12.0 value. Its only writer in the release is the connected system's private
    // -setLimitedUserInterfaces:, so nothing in this library writes it and it stays at the mask's 0,
    // which is what Apple's own object answers with no head unit.
    CPLimitableUserInterface _limitedUserInterfaces;
    // The 13.0 value's storage. A category cannot add an ivar and this is the class's @implementation,
    // so it sits here behind Charon-prefixed accessors and CarPlaySessionConfiguration13.m's category
    // carries the 13.0 getter. Same shape, and the same reason, as the 17.4 members of the navigation
    // session in CarPlayNavigationSession12.m.
    CPContentStyle _charonContentStyle;
}

// The 13.0 property is @dynamic and NOT @synthesize, and the reason is measured rather than stylistic.
// The compiler auto-synthesises every property an SDK header declares whether or not the object
// implements it, and @synthesize here would emit the getter into a 12.0 object -- 13.0 API in a 12.0
// band. `@dynamic` says the storage is here (the ivar and its Charon accessor below) and the accessor is
// elsewhere: CarPlaySessionConfiguration13.m's category, which is where that row's API belongs. With no
// @dynamic at all the class's ivar list would still carry _contentStyle, which is fine, but the getter
// would land in the wrong object.
@dynamic contentStyle;

// :28 `- (instancetype)initWithDelegate:(id <CPSessionConfigurationDelegate>)delegate
// NS_DESIGNATED_INITIALIZER` -- the only way to make one, and :29-30 forbid the other two. The delegate
// is stored through the property, so it is weak and it answers the object the caller gave.
- (instancetype)initWithDelegate:(id<CPSessionConfigurationDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _limitedUserInterfaces = 0;
        _charonContentStyle = 0;
    }
    return self;
}

// :33 `@property (nonatomic, readonly) CPLimitableUserInterface limitedUserInterfaces` -- readonly, with
// no public setter, and CPLimitableUserInterface is an NS_OPTIONS over NSUInteger whose members are
// CPLimitableUserInterfaceKeyboard = 1 << 0 and CPLimitableUserInterfaceLists = 1 << 1 (:13-16). The
// value is the connected system's; with none connected it is 0, and 0 is also the "nothing is limited"
// mask, which is what the release's own object answers.
- (CPLimitableUserInterface)limitedUserInterfaces
{
    return _limitedUserInterfaces;
}

// :38 `@property (nonatomic, weak) id<CPSessionConfigurationDelegate> delegate` -- readwrite, and the
// application's own: the header's comment says the system will use it to configure the system UI, so a
// caller sets it and reads back what it set. nil in, nil out, which is what the port answers for the nil
// the probe passes and what Apple's own object answers.
- (id<CPSessionConfigurationDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<CPSessionConfigurationDelegate>)delegate
{
    _delegate = delegate;
}

// The 13.0 value's storage, reached from CarPlaySessionConfiguration13.m. Charon-prefixed, so it carries
// no API and stays out of the library's exports. A reader and no writer, and the reason is in
// CharonCarPlaySessionConfiguration.h: the header declares the property readonly and the release's only
// writer is the connected CarPlay system's private -setContentStyle:.
- (CPContentStyle)charon_contentStyle
{
    return _charonContentStyle;
}

@end