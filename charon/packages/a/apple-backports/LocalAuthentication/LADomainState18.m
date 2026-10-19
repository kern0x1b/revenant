#import <Foundation/Foundation.h>
#import <LocalAuthentication/LAContext.h>
#import <objc/runtime.h>

#if __has_include(<LocalAuthentication/LACompanionType.h>)
#import <LocalAuthentication/LACompanionType.h>
#else
typedef NS_ENUM(NSInteger, LACompanionType) {
    LACompanionTypeWatch = 1 << 0,
    LACompanionTypeMac = 1 << 1
};
#endif

@class LADomainState;

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
