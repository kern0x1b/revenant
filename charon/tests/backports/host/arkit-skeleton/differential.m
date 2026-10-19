// differential.m - the port's ARSkeletonDefinition against this Mac's own ARKit.
//
// The host has ARKit in its dyld shared cache (ARKit.framework, dlopen'd by path), so the two
// definitions can be asked the same questions in one process and compared. The port's class is
// compiled into this harness under a renamed class (run.sh passes -DARSkeletonDefinition=...), so
// what runs is the port's own code and not a re-implementation of it, and the host's class is reached
// through objc_msgSend so that nothing here needs ARKit's headers -- they are the iPhoneOS ones, which
// do not compile into a macOS build.
//
// What is compared: jointCount, every joint name in order, every parent index in order, and
// `indexForJointName:` for every name in the table plus a name that is not in it (the answer has to
// be NSNotFound, and a harness that never asks cannot tell a right answer from a lucky one).
//
// Every line is `name value`, so a mutant that changes one joint of the port's table shows up as one
// differing line rather than as a count.

#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>

// The port's own class, declared here rather than imported from `CharonARKitSkeleton.h`: that header
// carries `NS_TYPED_ENUM` and `NS_REFINED_FOR_SWIFT`, whose availability attributes name iOS and are
// an error in a macOS build. The declarations below are the four properties and the one method this
// harness asks for, and they are the port's own -- a shim that agreed with the port about nothing
// would compare the host against itself.
// The host's own class, under the name the runtime has it by: this harness does not rename the host's
// side, so the two definitions are two ordinary classes with the same shape.
@interface HostARSkeletonDefinition : NSObject
@property (class, nonatomic, readonly) HostARSkeletonDefinition *defaultBody2DSkeletonDefinition;
@property (nonatomic, readonly) NSUInteger jointCount;
@property (nonatomic, readonly) NSArray<NSString *> *jointNames;
@property (nonatomic, readonly) NSArray<NSNumber *> *parentIndices;
- (NSUInteger)indexForJointName:(NSString *)jointName;
@end

@interface CharonPortARSkeletonDefinition : NSObject
@property (class, nonatomic, readonly) CharonPortARSkeletonDefinition *defaultBody2DSkeletonDefinition;
@property (nonatomic, readonly) NSUInteger jointCount;
@property (nonatomic, readonly) NSArray<NSString *> *jointNames;
@property (nonatomic, readonly) NSArray<NSNumber *> *parentIndices;
- (NSUInteger)indexForJointName:(NSString *)jointName;
@end

static int failures = 0;

static void same(const char *what, long long port, long long host)
{
    if (port != host) {
        printf("FAIL %s port=%lld host=%lld\n", what, port, host);
        failures++;
    }
}

static void same_text(const char *what, NSString *port, NSString *host)
{
    if (port == nil || host == nil || ![port isEqualToString:host]) {
        printf("FAIL %s port=%s host=%s\n", what, port ? port.UTF8String : "(nil)",
               host ? host.UTF8String : "(nil)");
        failures++;
    }
}

int main(void)
{
    // Unbuffered: this harness's lines are the evidence when a run fails, and a buffered line is lost
    // with the process when the run dies. stderr first, because a line on stderr is not buffered even
    // when stdout is, so "reached main" survives a fault on the next line.
    setvbuf(stdout, NULL, _IONBF, 0);
    void *handle = dlopen("/System/Library/Frameworks/ARKit.framework/ARKit", RTLD_LAZY);
    if (!handle) {
        handle = dlopen("ARKit", RTLD_LAZY);
    }
    if (!handle) {
        printf("SKIP this machine's ARKit does not load\n");
        return 77;
    }
    Class host_class = NSClassFromString(@"ARSkeletonDefinition");
    if (!host_class) {
        printf("SKIP this machine's ARKit has no ARSkeletonDefinition\n");
        return 77;
    }
    // The host's class is reached by name and then sent real messages, not through a cast
    // `objc_msgSend`: a variadic function-pointer call to `objc_msgSend` for a method whose result is
    // not an object puts float data in the return register and faults in the runtime, and the run
    // says nothing about which call it was. Both definitions are therefore declared here and called
    // directly -- the host's under the name the runtime knows it by, the port's under the name run.sh
    // renamed it to.

    id host = [host_class defaultBody2DSkeletonDefinition];
    CharonPortARSkeletonDefinition *port = [CharonPortARSkeletonDefinition defaultBody2DSkeletonDefinition];
    if (!host || !port) {
        printf("FAIL one of the two definitions is nil host=%p port=%p\n", host, port);
        return 1;
    }

    NSArray *host_names = [(HostARSkeletonDefinition *)host jointNames];
    NSArray *host_parents = [(HostARSkeletonDefinition *)host parentIndices];
    NSUInteger host_count = [(HostARSkeletonDefinition *)host jointCount];
    NSArray *port_names = [port jointNames];
    NSArray *port_parents = [port parentIndices];
    (void)host;

    same("jointCount", (long long)port.jointCount, (long long)host_count);
    same("jointNames.count", (long long)port_names.count, (long long)host_names.count);
    same("parentIndices.count", (long long)port_parents.count, (long long)host_parents.count);

    // The label is held in a strong local for the length of the call, not written inline: under ARC an
    // inline `[NSString stringWithFormat:].UTF8String` hands `same` a pointer into a temporary that the
    // caller is free to release before `same` reads it, and the run then faults in the runtime rather
    // than reporting a difference.
    for (NSUInteger index = 0; index < host_names.count; index++) {
        NSString *label = [NSString stringWithFormat:@"jointNames[%lu]", (unsigned long)index];
        same_text([label UTF8String], port_names[index], host_names[index]);
    }
    for (NSUInteger index = 0; index < host_parents.count; index++) {
        NSString *label = [NSString stringWithFormat:@"parentIndices[%lu]", (unsigned long)index];
        same([label UTF8String], (long long)[port_parents[index] integerValue],
             (long long)[host_parents[index] integerValue]);
    }

    // indexForJointName: is asked both ways for every name in the host's table and for a name that is
    // in none of them, so a harness that answered NSNotFound for everything would be caught.
    for (NSUInteger index = 0; index < host_names.count; index++) {
        NSString *name = host_names[index];
        NSUInteger port_index = [port indexForJointName:name];
        NSUInteger host_index = [(HostARSkeletonDefinition *)host indexForJointName:name];
        NSString *label = [NSString stringWithFormat:@"indexForJointName:%@", name];
        same([label UTF8String], (long long)port_index, (long long)host_index);
    }
    NSUInteger host_missing = [(HostARSkeletonDefinition *)host indexForJointName:@"not_a_joint_of_any_body"];
    same("indexForJointName:no_such_joint",
         (long long)[port indexForJointName:@"not_a_joint_of_any_body"],
         (long long)host_missing);

    if (failures == 0) {
        printf("VERDICT ok %lu joints, names and parents the host's own\n", (unsigned long)host_count);
        return 0;
    }
    printf("VERDICT red %d difference(s)\n", failures);
    return 1;
}