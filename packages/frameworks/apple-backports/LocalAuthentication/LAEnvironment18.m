#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <LocalAuthentication/LAContext.h>
#import <LocalAuthentication/LAEnvironment.h>

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

#pragma mark - the one mechanism of a release with a lock screen and no sensor

@interface LAEnvironmentMechanismUserPassword ()
- (instancetype)initWithRevenantLockScreenPasscode;
@end

@implementation LAEnvironmentMechanismUserPassword

@synthesize isSet = _isSet;

- (instancetype)initWithRevenantLockScreenPasscode
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

static LAEnvironmentMechanismUserPassword *RevenantLockScreenPasscode(void)
{
    static LAEnvironmentMechanismUserPassword *mechanism;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mechanism = [[LAEnvironmentMechanismUserPassword alloc] initWithRevenantLockScreenPasscode];
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
- (instancetype)initWithRevenantMechanisms:(NSArray<LAEnvironmentMechanism *> *)mechanisms
                                 biometry:(LAEnvironmentMechanismBiometry *)biometry
                              userPassword:(LAEnvironmentMechanismUserPassword *)userPassword
                               companions:(NSArray<LAEnvironmentMechanismCompanion *> *)companions;
@end

@implementation LAEnvironmentState

@synthesize biometry = _biometry, userPassword = _userPassword, companions = _companions, allMechanisms = _allMechanisms;

- (instancetype)initWithRevenantMechanisms:(NSArray<LAEnvironmentMechanism *> *)mechanisms
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
    return [[[self class] alloc] initWithRevenantMechanisms:_allMechanisms biometry:_biometry userPassword:_userPassword companions:_companions];
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

static LAEnvironmentState *RevenantLockScreenState(void)
{
    static LAEnvironmentState *state;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        LAEnvironmentMechanismUserPassword *passcode = RevenantLockScreenPasscode();
        state = [[LAEnvironmentState alloc] initWithRevenantMechanisms:@[passcode] biometry:nil userPassword:passcode companions:@[]];
    });
    return state;
}

#pragma mark - the environment

@interface LAEnvironment ()
- (instancetype)initWithRevenantEnvironment;
@end

@implementation LAEnvironment

+ (LAEnvironment *)currentUser
{
    static LAEnvironment *environment;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        environment = [[LAEnvironment alloc] initWithRevenantEnvironment];
    });
    return environment;
}

- (instancetype)initWithRevenantEnvironment
{
    return ((id (*)(id, SEL))objc_msgSend)(self, @selector(init));
}

- (LAEnvironmentState *)state
{
    return RevenantLockScreenState();
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
