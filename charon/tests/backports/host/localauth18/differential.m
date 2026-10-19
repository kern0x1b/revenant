#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "check.h"

// The port's LAEnvironment family against the host's own LocalAuthentication. The host has a Touch ID
// and a passcode set; this port's devices have neither a sensor nor a companion, and a passcode no
// application can read. So this test does three things, and says which is which:
//
//   1. the shapes are the same - the same classes, the same protocols, the same selectors, the same
//      one-object answers, the same copy-and-equal behaviour;
//   2. the strings and values the port carries are the host's own, read across rather than retyped;
//   3. every answer that must differ, differs, and each one is named here so the test fails if the
//      port ever starts answering as a device with a sensor.

@class CharonHostLAEnvironmentMechanism;
@class CharonHostLAEnvironmentMechanismBiometry;
@class CharonHostLAEnvironmentMechanismCompanion;
@class CharonHostLAEnvironmentMechanismUserPassword;
@class CharonHostLAEnvironmentState;
@class CharonHostLADomainStateBiometry;
@class CharonHostLADomainStateCompanion;

@interface CharonHostLAEnvironment : NSObject
+ (CharonHostLAEnvironment *)currentUser;
- (CharonHostLAEnvironmentState *)state;
- (void)addObserver:(id)observer;
- (void)removeObserver:(id)observer;
@end

@interface CharonHostLAEnvironmentState : NSObject <NSCopying>
- (CharonHostLAEnvironmentMechanismBiometry *)biometry;
- (CharonHostLAEnvironmentMechanismUserPassword *)userPassword;
- (NSArray *)companions;
- (NSArray *)allMechanisms;
@end

@interface CharonHostLAEnvironmentMechanism : NSObject
- (BOOL)isUsable;
- (NSString *)localizedName;
- (NSString *)iconSystemName;
@end

@interface CharonHostLAEnvironmentMechanismBiometry : CharonHostLAEnvironmentMechanism
- (NSUInteger)biometryType;
- (BOOL)isEnrolled;
- (BOOL)isLockedOut;
- (NSData *)stateHash;
- (BOOL)builtInSensorInaccessible;
@end

@interface CharonHostLAEnvironmentMechanismUserPassword : CharonHostLAEnvironmentMechanism
- (BOOL)isSet;
@end

@interface CharonHostLADomainState : NSObject
- (CharonHostLADomainStateBiometry *)biometry;
- (CharonHostLADomainStateCompanion *)companion;
- (NSData *)stateHash;
@end

@interface CharonHostLADomainStateBiometry : NSObject
- (NSUInteger)biometryType;
- (NSData *)stateHash;
@end

@interface CharonHostLADomainStateCompanion : NSObject
- (NSSet<NSNumber *> *)availableCompanionTypes;
- (NSData *)stateHash;
- (NSData *)stateHashForCompanionType:(NSInteger)companionType;
@end

@protocol CharonHostLAEnvironmentObserver <NSObject>
@optional
- (void)environment:(CharonHostLAEnvironment *)environment stateDidChangeFromOldState:(CharonHostLAEnvironmentState *)oldState;
@end

// Everything is asked through objc_msgSend, so the same line asks the port's renamed class and the
// system's own, with no declaration of the system's to get in the way.
// The harness's check takes a C string for the name; a computed one is given as an NSString.
static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    charon_check(passed, [name UTF8String], detail);
}

static id ask(id target, NSString *name)
{
    return ((id (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(name));
}

static unsigned long number(id target, NSString *name)
{
    return (unsigned long)((unsigned long (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(name));
}

static BOOL flag(id target, NSString *name)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(name));
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    // 1. The classes and the protocol are all there, on both sides, under their own names.
    NSArray *classes = @[@"LAEnvironment", @"LAEnvironmentState", @"LAEnvironmentMechanism",
                         @"LAEnvironmentMechanismBiometry", @"LAEnvironmentMechanismCompanion",
                         @"LAEnvironmentMechanismUserPassword", @"LADomainState", @"LADomainStateBiometry",
                         @"LADomainStateCompanion"];
    for (NSString *name in classes) {
        Class port = NSClassFromString([@"CharonHost" stringByAppendingString:name]);
        Class system = NSClassFromString(name);
        check_named(port != Nil && system != Nil, [NSString stringWithFormat:@"%@ is there on both sides", name],
                     [NSString stringWithFormat:@"port %@, host %@", port, system]);
        if (port && system) {
            // The port's superclass carries the rename the differential gives it, so the names are
            // compared with the prefix taken off rather than the pointers.
            NSString *port_super = [NSStringFromClass([port superclass]) stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
            check_named([port_super isEqualToString:NSStringFromClass([system superclass])],
                         [NSString stringWithFormat:@"%@ stands on the same class", name],
                         [NSString stringWithFormat:@"port %@, host %@", port_super, NSStringFromClass([system superclass])]);
        }
    }
    check_named(NSClassFromString(@"CharonHostLAEnvironmentState") != Nil, @"LAEnvironmentState is there to copy", @"no class");
    charon_check([NSClassFromString(@"CharonHostLAEnvironmentState") instancesRespondToSelector:@selector(copyWithZone:)],
                 "and it answers -copyWithZone:, as the header's NSCopying conformance says", @"no -copyWithZone:");

    // 2. The shapes: one environment, one state, a copy that is another object and equal to it.
    id port_environment = ask(NSClassFromString(@"CharonHostLAEnvironment"), @"currentUser");
    id host_environment = ask(NSClassFromString(@"LAEnvironment"), @"currentUser");
    charon_check(port_environment != nil && host_environment != nil, "both hand out an environment", @"one is nil");
    charon_check(ask(NSClassFromString(@"CharonHostLAEnvironment"), @"currentUser") == port_environment,
                 "the port's is one object, asked twice", @"a second object came back");
    charon_check(ask(NSClassFromString(@"LAEnvironment"), @"currentUser") == host_environment,
                 "and so is the host's, which is the control", @"the host handed out a second object");

    id port_state = ask(port_environment, @"state");
    id host_state = ask(host_environment, @"state");
    charon_check(port_state != nil && host_state != nil, "both hand out a state", @"one is nil");
    charon_check(ask(port_environment, @"state") == port_state, "the port's state is one object, asked twice", @"a second state came back");

    id port_copy = ((id (*)(id, SEL))objc_msgSend)(port_state, NSSelectorFromString(@"copy"));
    charon_check(port_copy != port_state, "a copy of the port's state is another object", @"the copy is the original");
    charon_check([port_copy isEqual:port_state], "and equal to it, as the host's is", @"the copy does not equal the original");
    id host_copy = ((id (*)(id, SEL))objc_msgSend)(host_state, NSSelectorFromString(@"copy"));
    charon_check(host_copy != host_state && [host_copy isEqual:host_state],
                 "which is what the host does with its own, asked the same way", @"the host's copy differs");

    // 3. The port's mechanisms: one, and it is the passcode. The host has two, biometry and passcode,
    //    which is the difference this port is here to report.
    NSArray *port_all = (NSArray *)ask(port_state, @"allMechanisms");
    NSArray *host_all = (NSArray *)ask(host_state, @"allMechanisms");
    printf("mechanisms: port %s host %s\n", [[port_all description] UTF8String], [[host_all description] UTF8String]);
    charon_check(port_all.count == 1, "the port lists one mechanism, the lock screen's passcode",
                 [NSString stringWithFormat:@"%lu", (unsigned long)port_all.count]);
    charon_check(host_all.count == 2, "the host lists two, its Touch ID and its passcode, which is the control",
                 [NSString stringWithFormat:@"%lu", (unsigned long)host_all.count]);
    charon_check(ask(port_state, @"biometry") == nil, "the port has no biometry mechanism: this device has no sensor",
                 @"a biometry mechanism came back");
    check_named([(NSArray *)ask(port_state, @"companions") count] == 0, @"and no companion, because the release pairs with none",
                 @"a companion came back");

    id port_password = ask(port_state, @"userPassword");
    charon_check(port_password != nil, "the passcode mechanism is there", @"nil");
    if (port_password) {
        // 2. The strings the port carries are the host's own: read from the host's passcode mechanism.
        id host_password = ask(host_state, @"userPassword");
        charon_check(flag(port_password, @"isUsable") == NO, "the port's passcode mechanism is not usable",
                     [NSString stringWithFormat:@"%d", (int)flag(port_password, @"isUsable")]);
        charon_check(flag(port_password, @"isSet") == NO, "and the port does not claim a passcode is set, which it cannot read",
                     [NSString stringWithFormat:@"%d", (int)flag(port_password, @"isSet")]);
        charon_check([ask(port_password, @"localizedName") isEqual:ask(host_password, @"localizedName")],
                     "the name the port carries is the host's own name for the passcode mechanism",
                     [NSString stringWithFormat:@"port %@, host %@", ask(port_password, @"localizedName"), ask(host_password, @"localizedName")]);
        charon_check([ask(port_password, @"iconSystemName") isEqual:ask(host_password, @"iconSystemName")],
                     "and so is the symbol the host draws it with",
                     [NSString stringWithFormat:@"port %@, host %@", ask(port_password, @"iconSystemName"), ask(host_password, @"iconSystemName")]);
        printf("passcode mechanism: name %s icon %s (host: name %s icon %s)\n",
               [[ask(port_password, @"localizedName") description] UTF8String], [[ask(port_password, @"iconSystemName") description] UTF8String],
               [[ask(host_password, @"localizedName") description] UTF8String], [[ask(host_password, @"iconSystemName") description] UTF8String]);
        // The host's answers are the ones this port cannot have, and naming them keeps the difference
        // visible: if the host ever answers NO here, this test is looking at something else.
        charon_check(flag(host_password, @"isSet") == YES, "the host's passcode is set, as it says",
                     [NSString stringWithFormat:@"host %d", (int)flag(host_password, @"isSet")]);
        charon_check(flag(host_password, @"isUsable") == YES, "and usable, as it says",
                     [NSString stringWithFormat:@"host %d", (int)flag(host_password, @"isUsable")]);
    }

    // 4. Observers are taken and never called; the host's state does not change either while this runs,
    //    so both are silent, and the test checks the port takes a nil one without raising.
    [(id)port_environment addObserver:nil];
    [(id)port_environment removeObserver:nil];
    charon_check(YES, "a nil observer is taken by both calls", @"raised");

    // 5. The domain state: the shapes are the host's, the contents are this release's.
    id port_domain = ask(port_state, @"biometry") == nil ? nil : nil;
    charon_check(port_domain == nil, "(the port's state has no biometry, so there is nothing to ask for one there)", @"not nil");
    LAContext *context = [[LAContext alloc] init];
    id host_domain = nil;
    if ([context respondsToSelector:NSSelectorFromString(@"domainState")]) {
        host_domain = ask(context, @"domainState");
    }
    charon_check(host_domain != nil, "the host's LAContext has a domainState, which is the control", @"nil");

    Class port_domain_class = NSClassFromString(@"CharonHostLADomainState");
    id port_domain_state = [port_domain_class alloc];
    id port_domain_biometry = ask(port_domain_state, @"biometry");
    id port_domain_companion = ask(port_domain_state, @"companion");
    charon_check(port_domain_biometry != nil && port_domain_companion != nil,
                 "the port's domain state has a biometry and a companion member, as the header's nullability says",
                 [NSString stringWithFormat:@"biometry %@ companion %@", port_domain_biometry, port_domain_companion]);
    charon_check(number(port_domain_biometry, @"biometryType") == LABiometryTypeNone,
                 "the port's biometry type is none, which is what this package's LAContext answers on this release",
                 [NSString stringWithFormat:@"%lu", number(port_domain_biometry, @"biometryType")]);
    charon_check(ask(port_domain_biometry, @"stateHash") == nil, "and its hash is nil: there is no biometry to identify",
                 [NSString stringWithFormat:@"%@", ask(port_domain_biometry, @"stateHash")]);
    check_named([(NSSet *)ask(port_domain_companion, @"availableCompanionTypes") count] == 0,
                 @"the companion's available types are an empty set, which is the shape the host has with none paired",
                 [NSString stringWithFormat:@"%@", ask(port_domain_companion, @"availableCompanionTypes")]);
    charon_check(ask(port_domain_companion, @"stateHash") == nil, "the companion's hash is nil, as the host's is with no companion",
                 [NSString stringWithFormat:@"%@", ask(port_domain_companion, @"stateHash")]);
    charon_check(ask(port_domain_state, @"stateHash") == nil, "and the domain's own hash is nil for a domain with nothing in it",
                 [NSString stringWithFormat:@"%@", ask(port_domain_state, @"stateHash")]);
    for (NSInteger type = 0; type < 3; type++) {
        id port_one = ((id (*)(id, SEL, NSInteger))objc_msgSend)(port_domain_companion, NSSelectorFromString(@"stateHashForCompanionType:"), type);
        id host_one = host_domain ? ((id (*)(id, SEL, NSInteger))objc_msgSend)(ask(host_domain, @"companion"), NSSelectorFromString(@"stateHashForCompanionType:"), type) : nil;
        check_named(port_one == nil, [NSString stringWithFormat:@"the port answers nil for the hash of companion type %ld", (long)type],
                     [NSString stringWithFormat:@"%@", port_one]);
        check_named(port_one == host_one, [NSString stringWithFormat:@"which is what the host answers for type %ld", (long)type],
                     [NSString stringWithFormat:@"port %@, host %@", port_one, host_one]);
    }
    if (host_domain) {
        printf("host domain: biometry hash %lu bytes, companion hash %s, domain hash %lu bytes\n",
               (unsigned long)[ask(ask(host_domain, @"biometry"), @"stateHash") length],
               [ask(ask(host_domain, @"companion"), @"stateHash") ? @"set" : @"null" UTF8String],
               (unsigned long)[ask(host_domain, @"stateHash") length]);
        charon_check([ask(ask(host_domain, @"companion"), @"stateHash") length] == 0,
                     "the host's companion hash is empty, which is why the port's nil is its own answer for a state with nothing in it",
                     @"the host's companion hash is not empty");
        // A context that has never evaluated anything has no enrolled biometry in its domain either,
        // and the host answers nil for those hashes as well: the port's nil is what the host itself
        // gives a domain with nothing in it, not only for a companion.
        check_named([ask(ask(host_domain, @"biometry"), @"stateHash") length] == 0
                    && [ask(host_domain, @"stateHash") length] == 0,
                    @"the host's own fresh context has no biometry hash and no domain hash either",
                    [NSString stringWithFormat:@"biometry %lu domain %lu",
                     (unsigned long)[ask(ask(host_domain, @"biometry"), @"stateHash") length],
                     (unsigned long)[ask(host_domain, @"stateHash") length]]);
    }

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
