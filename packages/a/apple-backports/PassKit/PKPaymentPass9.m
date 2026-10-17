// The release-9 object's PassKit API: the three classes iOS 9 added for adding a payment pass to the
// Secure Element, and the one member of the release's own PKPass that arrives with them.
//
// THE CLASSES ARE CARRIED, not left absent, and that is the correction this file carries. The
// registry had all three as `absent` with the reason "the Secure Element: this device has none", and
// the 6.1.3 gate had already refused the same reasoning for the two payment controllers once: a
// class that exists on a device without the hardware answers the question instead of being missing.
// `+[PKAddPaymentPassViewController canAddPaymentPass]` is that question, and its answer here is NO,
// which is what Apple's own documentation gives a device with no Secure Element. Leaving the class
// out would not give a device with no Secure Element a wrong answer -- it would give it an
// unrecognized selector, which is a crash and not an answer. Same rule as PKWallet's `+canAddPasses`
// and `PKPaymentAuthorizationViewController`'s `+canMakePayments`.
//
// The other two are data, and data needs no hardware: PKAddPaymentPassRequestConfiguration and
// PKAddPaymentPassRequest are the issuer's own encrypted payload and the display fields that go with
// it, every property filled in by the caller out of NSString and NSData, which every release this
// port builds for carries. Nothing here stands in for a Secure Element.
//
// What is NOT here, and why, is in each row of registry/PassKit/ios8.json:
//
//   - `-[PKPass deviceName]` is here and answers nil: the release's PKPass has no such selector
//     (measured, 90 methods, listed in facts/PassKit/PassKit.md), and there is no device to name --
//     no Secure Element to have added a pass to, and the release's one remote-pass class,
//     PKRemotePass, carries 8 methods of its own and no -deviceName among them (armv7 cache of 6.1.3;
//     PKPassLibrary's own 34 instance methods and 1 class method carry no remote-payment member).
//     Apple's header declares the property nonnull, and no name is invented here to satisfy that.
//   - `PKPass.remotePass` is NOT here. Its selector is `isRemotePass` and it answers NO just as
//     truthfully, but the registry's own property row is spelled `PKPass.remotePass` and the
//     check that decides whether an implemented row was built looks the row's spelling up as
//     selectors -- `-[PKPass remotePass]` and `-[PKPass setRemotePass:]` -- and never the getter
//     Apple's `getter=isRemotePass` attribute actually renames it to. Carrying the selector would
//     therefore ship a definition the registry calls absent. The row stays `absent` and names the
//     selector and the measurement; this is the check being blind, which is recorded in the row and
//     not papered over by defining a `-remotePass` method no Apple SDK ever declares.
//   - `PKPaymentMethod` is not here because Apple's own API gives a caller no way to reach the name:
//     the 26.2 header declares three readonly properties and no initializer at all, and the surface
//     lists no method for it at any version, so nothing can construct one and nothing can hand one
//     over -- the one flow that would, the payment sheet's didSelectPaymentMethod, sits behind a
//     `+canMakePayments` that answers NO.
//
// ONE OBJECT PER RELEASE, and it is the whole of release 9 in this folder: every class here first
// appears at 9.0 in the held cache ladder (tools/cache-index/first-rung.lua, all three), and the
// PKPass member arrives with them. That is also what places the object. modules/apple/backports.lua's
// band() drops an object from every band whose release already exports all of its symbols, so this
// file is built exactly where the release lacks these classes and nowhere else -- which is what
// keeps the PKPass category from replacing the release's own -deviceName in a band that has it.
//
// The properties iOS 10.1, 12.0 and 12.3 added to PKAddPaymentPassRequestConfiguration are
// @dynamic and not synthesized: an object that answers a 10.1 member from a 9.0 object carries two
// releases, which is what the release-split rule refuses, and nil would be a wrong answer rather
// than a missing one.
//
// Compiled against the iOS SDK only: none of the three classes exists in a macOS PassKit (the 26.2
// annotations are ios(9.0) with no macos), and the host probe names its own sources rather than
// taking this directory's.
#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>

// The release's own PKPass, whose iOS 9 accessor arrives here. The property is declared again in
// this category so the declaration that reaches the compiler is this file's, without the header's
// API_AVAILABLE(ios(9.0)) -- the same reason PKPass14.m redeclares userInfo and passType, and the
// same shape: the class is the release's and only the member is this port's.
@interface PKPass (CharonPaymentPass9)
@property (nonatomic, copy, readonly) NSString *deviceName;
@end

@implementation PKPass (CharonPaymentPass9)

// -deviceName, 9.0: nil, and nil is the whole answer. A device name is the name of the device a pass
// was added to, and this device has neither of the two things that add one: no Secure Element to
// provision a payment pass into, and no pass relay to bring a pass down from another device. The
// release carries neither -- measured, PKPassLibrary answers 34 instance methods and one class
// method and none of them is a remote-payment member, and PKPass answers 90 instance methods of
// which none is -deviceName.
//
// Apple's header declares this property nonnull (PKPass.h, iPhoneOS26.2.sdk line 51 and iPhoneOS
// 16.4 line 56, the same text in both), and that promise holds only where a device was there to
// name. A name is not invented here to satisfy it: that would be the port's opinion where Apple's
// own answer is that there is none, and a caller asking "which device is this pass bound to" on a
// device with no Secure Element is told the true thing, which is that it is bound to none.
- (NSString *)deviceName
{
    return nil;
}

@end

@implementation PKAddPaymentPassRequestConfiguration

// The iOS 10.1, 12.0 and 12.3 members of this class, not synthesized and not answered here: see the
// head of this file. This object is release 9 and nothing else.
@dynamic cardDetails;
@dynamic productIdentifiers;
@dynamic requiresFelicaSecureElement;
@dynamic style;

// -init is NOT overridden here, and clang says so once: the header makes -initWithEncryptionScheme:
// this class's designated initializer, so clang asks for -init to be overridden and routed to it.
// Routing it needs a scheme, the two schemes are the release's 9.0 constants PKEncryptionSchemeECC_V2
// and PKEncryptionSchemeRSA_V2, and neither is named here: naming one would add a symbol this
// object has no registry row for, and naming neither means -init is the state of a configuration
// whose issuer chose no scheme. So -init stays NSObject's own, encryptionScheme stays nil, and the
// two key properties of the request built from it are both unused -- which is the truth about a
// caller that built a configuration without choosing. Passing a nil scheme to satisfy clang instead
// would be passing nil to a parameter Apple's header declares nonnull.
//
// -initWithEncryptionScheme:, 9.0, the header's own designated initialiser. The scheme is the
// caller's own (PKEncryptionSchemeECC_V2 or PKEncryptionSchemeRSA_V2) and it selects which of the
// request's two key properties is used: ephemeralPublicKey for ECC, wrappedKey for RSA. Storing it
// is the whole of the initialiser -- there is nothing else to compute, and nothing about it needs a
// Secure Element to have been chosen.
- (nullable instancetype)initWithEncryptionScheme:(PKEncryptionScheme)encryptionScheme
{
    self = [super init];
    if (self) {
        _encryptionScheme = [encryptionScheme copy];
    }
    return self;
}

@end

@implementation PKAddPaymentPassRequest

// -init is this class's own designated initializer in the header, so it is defined here: the four
// properties left nil, which is the state of a request whose issuer has filled in nothing yet.
// Everything this object holds is NSData the issuer encrypted for the Secure Element, so it stores
// bytes and nothing decides anything with them -- adding a pass is the Secure Element's work and
// this class does not pretend to do any of it.
- (instancetype)init
{
    return [super init];
}

@end

@implementation PKAddPaymentPassViewController

// +canAddPaymentPass, 9.0: the capability question, NO. This is the whole reason the class is
// carried rather than left absent -- a device with no Secure Element cannot add a payment pass, and
// NO is the answer Apple's own documentation gives for exactly that device. The argument list is
// empty; the method takes nothing, like its sibling +canAddPasses over PKAddPassesViewController.
+ (BOOL)canAddPaymentPass
{
    return NO;
}

// -initWithRequestConfiguration:delegate:, 9.0.
//
// The configuration is taken and not kept. Its five properties are display fields and Pass Library
// filters that Apple's own add-pass sheet renders and applies, and this device presents no such
// sheet, so there is nothing that would read them back -- storing them would be a second copy of
// state with no reader. The delegate is kept, because it is the one thing a caller hands over that
// has a use this device can honour, and it is kept weakly exactly as the header declares it.
//
// Nothing is presented and no delegate callback fires: the sheet is Apple's, and the Secure Element
// that would answer it is not here. A delegate that expects didFinishAddingPaymentPass:error: is
// never called rather than being called with a pass this device cannot hold, which is the same
// choice PKPaymentAuthorizationViewController8.m makes for its own initialiser.
//
// The superclass call is -initWithNibName:bundle: and not -init, because this class's designated
// initialiser has to reach UIViewController's: -init is not a designated initializer there, and the
// controller is created from a nib name like any other. The two overrides below are what that
// contract obliges, and they route through this class's own designated initialiser the way
// UIFontPickerViewController.m does: a caller who reaches the controller through UIViewController's
// initialiser gets a real configuration with no scheme and no delegate, not a half-built object that
// skipped its own initialiser.
- (nullable instancetype)initWithRequestConfiguration:(PKAddPaymentPassRequestConfiguration *)configuration
                                             delegate:(nullable id<PKAddPaymentPassViewControllerDelegate>)delegate
{
    (void)configuration;
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    (void)nibNameOrNil;
    (void)nibBundleOrNil;
    return [self initWithRequestConfiguration:[[PKAddPaymentPassRequestConfiguration alloc] init]
                                    delegate:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    (void)coder;
    return [self initWithRequestConfiguration:[[PKAddPaymentPassRequestConfiguration alloc] init]
                                    delegate:nil];
}

@end
