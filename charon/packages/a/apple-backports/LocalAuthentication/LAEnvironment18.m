#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <LocalAuthentication/LAContext.h>
// The generated protocols of this library, and the one place the body of LAEnvironmentObserver is
// written down: the generated protocol source defines that protocol's object from this same header, so
// a second copy of the body in this file would be a second definition of the same object.
#import "CharonLocalAuthenticationProtocols.h"

// The environment of iOS 18: what the device can authenticate the owner with, and in what state.
//
// The port's build SDK is charon@iphoneos-sdk 16.4, which predates all of this, so the declarations
// the headers of the 26.2 SDK give are written here: LAEnvironment, its state, the mechanisms and the
// observer. LABiometryType is the one piece the 16.4 SDK does declare, in LAContext.h, and is used
// from there (facts/LocalAuthentication/LAEnvironment.md).
//
// What these devices are: an iPhone 4S and an iPad 2 have no biometric sensor at all, so there is no
// biometry mechanism; they can be paired with no watch or Mac companion, so there is no companion
// mechanism; and iOS 6 gives an application no way to read whether a passcode is set and no way to ask
// for one, which the port's own LAContext already answers as LAErrorNotInteractive. So the state has
// one mechanism - the lock screen's passcode - and it is not usable.

// The port's build SDK is charon@iphoneos-sdk 16.4, which has no LACompanionType.h; a later SDK, and so
// the host the differential is built against, does. Where the header is there it is used, so the two
// builds agree on one declaration of it.
#if __has_include(<LocalAuthentication/LACompanionType.h>)
#import <LocalAuthentication/LACompanionType.h>
#else
typedef NS_ENUM(NSInteger, LACompanionType) {
    LACompanionTypeWatch = 1 << 0,
    LACompanionTypeMac = 1 << 1
};
#endif

@class LAEnvironment;
@class LAEnvironmentState;

// The protocol's body is NOT written out here, and the header that carries it is imported above like
// any other: writing it out gave one protocol two definitions in one library - this file's and the
// generated protocol source's - and ld64 keeps whichever it reads first:
//
//   registry_test FAIL: LAEnvironment18.m declares @protocol LAEnvironmentObserver, which the generated
//                      protocol source defines too, so two objects define that protocol object
//
// A forward declaration is not what replaces it: this file writes `@protocol(LAEnvironmentObserver)`,
// and a forward declaration cannot take that - "@protocol is using a forward protocol declaration of
// 'LAEnvironmentObserver'". The import is the one definition both this file and the generated source
// read, and the generated source is what defines the object.
@protocol LAEnvironmentObserver;

@interface LAEnvironmentMechanism : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) BOOL isUsable;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *iconSystemName;
@end

@interface LAEnvironmentMechanismBiometry : LAEnvironmentMechanism
@property (nonatomic, readonly) LABiometryType biometryType;
@property (nonatomic, readonly) BOOL isEnrolled;
@property (nonatomic, readonly) BOOL isLockedOut;
@property (nonatomic, readonly) NSData *stateHash;
@property (nonatomic, readonly) BOOL builtInSensorInaccessible;
@end

@interface LAEnvironmentMechanismCompanion : LAEnvironmentMechanism
@property (nonatomic, readonly) LACompanionType type;
@property (nonatomic, readonly) NSData *stateHash;
@end

@interface LAEnvironmentMechanismUserPassword : LAEnvironmentMechanism
@property (nonatomic, readonly) BOOL isSet;
@end

@interface LAEnvironmentState : NSObject <NSCopying>
@property (nonatomic, readonly, nullable) LAEnvironmentMechanismBiometry *biometry;
@property (nonatomic, readonly, nullable) LAEnvironmentMechanismUserPassword *userPassword;
@property (nonatomic, readonly) NSArray<LAEnvironmentMechanismCompanion *> *companions;
@property (nonatomic, readonly) NSArray<LAEnvironmentMechanism *> *allMechanisms;
@end

@interface LAEnvironment : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, class) LAEnvironment *currentUser;
@property (nonatomic, readonly) LAEnvironmentState *state;
- (void)addObserver:(id<LAEnvironmentObserver>)observer;
- (void)removeObserver:(id<LAEnvironmentObserver>)observer;
@end

#pragma mark - the one mechanism of a release with a lock screen and no sensor

@interface LAEnvironmentMechanismUserPassword ()
- (instancetype)initWithCharonLockScreenPasscode;
@end

@implementation LAEnvironmentMechanismUserPassword

@synthesize isSet = _isSet;

- (instancetype)initWithCharonLockScreenPasscode
{
    // NSObject's -init, reached at run time: the framework's header marks -init unavailable for an
    // application, and this initialiser is how the port makes the one mechanism there is.
    self = ((id (*)(id, SEL))objc_msgSend)(self, @selector(init));
    if (self) {
        // NO, and the facts say why: the release gives an application no way to read whether a passcode
        // is set, and claiming one exists would be the claim that cannot be made. isUsable is NO either
        // way, because the release gives an application no way to ask for one - which is the same
        // reason this package's LAContext answers LAPolicyDeviceOwnerAuthentication with NO and
        // LAErrorNotInteractive.
        _isSet = NO;
    }
    return self;
}

- (BOOL)isUsable
{
    return NO;
}

// The two strings are the host's own, measured: the mechanism of a passcode is named "User Password"
// and drawn with the lock.shield symbol (tests/backports/host/localauth18).
- (NSString *)localizedName
{
    return @"User Password";
}

- (NSString *)iconSystemName
{
    return @"lock.shield";
}

@end

static LAEnvironmentMechanismUserPassword *CharonLockScreenPasscode(void)
{
    static LAEnvironmentMechanismUserPassword *mechanism;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mechanism = [[LAEnvironmentMechanismUserPassword alloc] initWithCharonLockScreenPasscode];
    });
    return mechanism;
}

#pragma mark - the base mechanism and the two kinds this device has none of

@implementation LAEnvironmentMechanism

- (BOOL)isUsable
{
    return NO;
}

- (NSString *)localizedName
{
    return nil;
}

- (NSString *)iconSystemName
{
    return nil;
}

@end

// Nothing on this release makes one of these two: the state below answers nil for a biometry and an
// empty array of companions, and +new/-init are unavailable in the headers, so no application can ask
// for one either. The properties answer the port's answer for a device with no sensor, which is the
// same answer the state gives, and the two strings are nil rather than the name of a sensor this
// device does not have - the header says they are not nullable, and that divergence is recorded in
// facts/LocalAuthentication/LAEnvironment.md. Nothing reaches them on this port.

@implementation LAEnvironmentMechanismBiometry

- (LABiometryType)biometryType
{
    return LABiometryTypeNone;
}

- (BOOL)isEnrolled
{
    return NO;
}

- (BOOL)isLockedOut
{
    return NO;
}

- (NSData *)stateHash
{
    return nil;
}

- (BOOL)builtInSensorInaccessible
{
    // NO: there is no built-in sensor on this device to be inaccessible to. A YES would report a
    // locked-out sensor where there is no sensor at all.
    return NO;
}

@end

@implementation LAEnvironmentMechanismCompanion

- (LACompanionType)type
{
    return 0;
}

- (NSData *)stateHash
{
    return nil;
}

@end

#pragma mark - the state

@interface LAEnvironmentState ()
- (instancetype)initWithCharonMechanisms:(NSArray<LAEnvironmentMechanism *> *)mechanisms
                                 biometry:(LAEnvironmentMechanismBiometry *)biometry
                              userPassword:(LAEnvironmentMechanismUserPassword *)userPassword
                               companions:(NSArray<LAEnvironmentMechanismCompanion *> *)companions;
@end

@implementation LAEnvironmentState

@synthesize biometry = _biometry, userPassword = _userPassword, companions = _companions, allMechanisms = _allMechanisms;

- (instancetype)initWithCharonMechanisms:(NSArray<LAEnvironmentMechanism *> *)mechanisms
                                 biometry:(LAEnvironmentMechanismBiometry *)biometry
                              userPassword:(LAEnvironmentMechanismUserPassword *)userPassword
                               companions:(NSArray<LAEnvironmentMechanismCompanion *> *)companions
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, @selector(init));
    if (self) {
        _allMechanisms = [mechanisms copy];
        _biometry = biometry;
        _userPassword = userPassword;
        _companions = [companions copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A copy of a state is a state of the same mechanisms and a different object, as it is on the host.
    return [[[self class] alloc] initWithCharonMechanisms:_allMechanisms biometry:_biometry userPassword:_userPassword companions:_companions];
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    }
    if (![other isKindOfClass:[LAEnvironmentState class]]) {
        return NO;
    }
    LAEnvironmentState *state = other;
    return [_allMechanisms isEqualToArray:state->_allMechanisms] && (_biometry == state->_biometry)
        && (_userPassword == state->_userPassword) && [_companions isEqualToArray:state->_companions];
}

- (NSUInteger)hash
{
    return _allMechanisms.count ^ _companions.count;
}

@end

static LAEnvironmentState *CharonLockScreenState(void)
{
    static LAEnvironmentState *state;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        LAEnvironmentMechanismUserPassword *passcode = CharonLockScreenPasscode();
        state = [[LAEnvironmentState alloc] initWithCharonMechanisms:@[passcode] biometry:nil userPassword:passcode companions:@[]];
    });
    return state;
}

#pragma mark - the environment

@interface LAEnvironment ()
- (instancetype)initWithCharonEnvironment;
@end

@implementation LAEnvironment

+ (LAEnvironment *)currentUser
{
    // One user: the release has no multiple user accounts and no second profile to ask for.
    static LAEnvironment *environment;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        environment = [[LAEnvironment alloc] initWithCharonEnvironment];
    });
    return environment;
}

- (instancetype)initWithCharonEnvironment
{
    return ((id (*)(id, SEL))objc_msgSend)(self, @selector(init));
}

- (LAEnvironmentState *)state
{
    return CharonLockScreenState();
}

- (void)addObserver:(id<LAEnvironmentObserver>)observer
{
    // The observer is asked whether it adopts the protocol before it is kept, which is what a real
    // implementation does before it ever sends the one message of the protocol - and it is what puts
    // the protocol into a conformance list, so this library carries the protocol object and
    // NSProtocolFromString(@"LAEnvironmentObserver") finds it in a process that has one.
    //
    // Nothing is ever sent to it. Nothing about the environment of this device can change while an
    // application runs: no sensor can be enrolled, no companion can be paired, and the passcode
    // belongs to the lock screen, which is not up while an application is. A nil observer and an
    // observer that does not adopt the protocol are both allowed and neither is kept.
    if ([observer conformsToProtocol:@protocol(LAEnvironmentObserver)]) {
        return;
    }
}

- (void)removeObserver:(id<LAEnvironmentObserver>)observer
{
}

@end
