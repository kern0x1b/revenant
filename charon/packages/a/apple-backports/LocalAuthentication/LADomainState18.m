#import <Foundation/Foundation.h>
#import <LocalAuthentication/LAContext.h>
#import <objc/runtime.h>

// The state of one security domain, iOS 18: which biometry and which companions are available to it,
// and the hashes that identify that state. The port's build SDK is 16.4, which predates all of this,
// so the declarations the headers of the 26.2 SDK give are written here, and the LACompanionType the
// LAEnvironment of this package declares is used from it (facts/LocalAuthentication/LAEnvironment.md).
//
// Every hash here is nil, and that is what the host answers for a state with nothing in it: the
// companion's own stateHash is null and stateHashForCompanionType: gives nil for every type when
// there is no companion (measured, tests/backports/host/localauth18). A device with no sensor and no
// companion has nothing to identify, so there is no hash to make up.

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

@class LADomainState;

// Where the SDK has the header - every SDK but the 16.4 the port builds against, the host included -
// it is used, so the two builds agree on one declaration of these three classes and of the selectors
// their headers mark unavailable.
#if __has_include(<LocalAuthentication/LADomainState.h>)
#import <LocalAuthentication/LADomainState.h>
#else
@interface LADomainStateBiometry : NSObject
@property (nonatomic, readonly) LABiometryType biometryType;
@property (nonatomic, readonly, nullable) NSData *stateHash;
@end

@interface LADomainStateCompanion : NSObject
@property (nonatomic, readonly) NSSet<NSNumber *> *availableCompanionTypes;
@property (nonatomic, readonly, nullable) NSData *stateHash;
- (nullable NSData *)stateHashForCompanionType:(LACompanionType)companionType;
@end

@interface LADomainState : NSObject
@property (nonatomic, readonly) LADomainStateBiometry *biometry;
@property (nonatomic, readonly) LADomainStateCompanion *companion;
@property (nonatomic, readonly, nullable) NSData *stateHash;
@end
#endif

// Each of the three is made once by the one that owns it, through an initialiser of its own: the
// headers mark +new and -init unavailable, and a class that cannot be made by an application is made
// here without reaching for the selector they closed.
@interface LADomainStateBiometry ()
- (instancetype)initWithCharonNoSensor;
@end

@interface LADomainStateCompanion ()
- (instancetype)initWithCharonNoCompanion;
@end

@interface LADomainState ()
- (instancetype)initWithCharonEmptyDomain;
@end

@implementation LADomainStateBiometry

- (instancetype)initWithCharonNoSensor
{
    return [super init];
}

- (LABiometryType)biometryType
{
    return LABiometryTypeNone;
}

- (NSData *)stateHash
{
    return nil;
}

@end

@implementation LADomainStateCompanion

- (instancetype)initWithCharonNoCompanion
{
    return [super init];
}

- (NSSet<NSNumber *> *)availableCompanionTypes
{
    // An empty set, which is what the host holds for a device with no companion paired: the set is
    // there, and it is empty.
    return [NSSet set];
}

- (NSData *)stateHash
{
    return nil;
}

- (NSData *)stateHashForCompanionType:(LACompanionType)companionType
{
    return nil;
}

@end

@implementation LADomainState

- (instancetype)initWithCharonEmptyDomain
{
    return [super init];
}

- (LADomainStateBiometry *)biometry
{
    static LADomainStateBiometry *biometry;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        biometry = [[LADomainStateBiometry alloc] initWithCharonNoSensor];
    });
    return biometry;
}

- (LADomainStateCompanion *)companion
{
    static LADomainStateCompanion *companion;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        companion = [[LADomainStateCompanion alloc] initWithCharonNoCompanion];
    });
    return companion;
}

- (NSData *)stateHash
{
    return nil;
}

@end

// The domain state a LAContext of this release answers, one shared object: the state of a release is
// the same for every context and nothing about it changes while an application runs, which is the
// state the host answers for a context asked twice.
static LADomainState *CharonDomainState(void)
{
    static LADomainState *state;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        state = [[LADomainState alloc] initWithCharonEmptyDomain];
    });
    return state;
}

#pragma mark - the LAContext property that carries it

// domainState is a member of the LAContext this package already implements, so it is added as a
// category on it. It lives in this file rather than one of its own so that nothing here is a C
// function another file calls: a file that exports API can be left out of a band whose release has it,
// and then the call is undefined in that band only.
@interface LAContext (CharonDomainState18)

@property (nonatomic, readonly) LADomainState *domainState;

@end

@implementation LAContext (CharonDomainState18)

@dynamic domainState;

- (LADomainState *)domainState
{
    return CharonDomainState();
}

@end
