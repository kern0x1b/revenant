#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>

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

    for (NSUInteger index = 0; index < host_names.count; index++) {
        NSString *label = [NSString stringWithFormat:@"jointNames[%lu]", (unsigned long)index];
        same_text([label UTF8String], port_names[index], host_names[index]);
    }
    for (NSUInteger index = 0; index < host_parents.count; index++) {
        NSString *label = [NSString stringWithFormat:@"parentIndices[%lu]", (unsigned long)index];
        same([label UTF8String], (long long)[port_parents[index] integerValue],
             (long long)[host_parents[index] integerValue]);
    }

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
