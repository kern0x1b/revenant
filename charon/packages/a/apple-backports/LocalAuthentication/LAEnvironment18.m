#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <LocalAuthentication/LAContext.h>
#import "CharonLocalAuthenticationProtocols.h"

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
    self = ((id (*)(id, SEL))objc_msgSend)(self, @selector(init));
    if (self) {
        _isSet = NO;
    }
    return self;
}

- (BOOL)isUsable
{
    return NO;
}

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
    if ([observer conformsToProtocol:@protocol(LAEnvironmentObserver)]) {
        return;
    }
}

- (void)removeObserver:(id<LAEnvironmentObserver>)observer
{
}

@end
