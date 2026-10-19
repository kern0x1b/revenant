/* probe.m - for each Core ML class whose header declares -init or +new NS_UNAVAILABLE, does the class answer with NSObject's
 * own implementation, and does a class that really overrides the selector show as different? Printed one line per question,
 * so the host framework's answer and the port's can be compared line by line.
 *
 * Compiled once against the host's CoreML framework and once against the port's CoreML objects (no framework linked on the
 * port side). The controls are the same probe on a class that overrides -init, and on a name no framework has. */
#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <objc/runtime.h>

@interface CharonInitOverrider : NSObject
- (instancetype)init;
@end
@implementation CharonInitOverrider
- (instancetype)init { return [super init]; }
@end

/* 1 when the class's own IMP for sel is NSObject's, 0 when it differs, -1 when the class does not exist. */
static int inherits_nsobject(const char *name, BOOL classMethod, SEL sel)
{
    Class cls = NSClassFromString([NSString stringWithUTF8String:name]);
    if (!cls) {
        return -1;
    }
    Class root = [NSObject class];
    Class ownerOfClass = classMethod ? object_getClass(cls) : cls;
    Class ownerOfRoot = classMethod ? object_getClass(root) : root;
    IMP here = class_getMethodImplementation(ownerOfClass, sel);
    IMP base = class_getMethodImplementation(ownerOfRoot, sel);
    return here == base ? 1 : 0;
}

int main(void)
{
    @autoreleasepool {
        const char *names[] = {"MLKey", "MLMetricKey", "MLParameterKey", "MLModelAsset", "MLImageConstraint"};
        for (size_t i = 0; i < sizeof names / sizeof names[0]; i++) {
            printf("-init %s %d\n", names[i], inherits_nsobject(names[i], NO, @selector(init)));
            printf("+new %s %d\n", names[i], inherits_nsobject(names[i], YES, @selector(new)));
        }
        printf("-init CharonInitOverrider %d\n", inherits_nsobject("CharonInitOverrider", NO, @selector(init)));
        printf("-init ZZZNoSuchNameCharonCoreML %d\n", inherits_nsobject("ZZZNoSuchNameCharonCoreML", NO, @selector(init)));
    }
    return 0;
}
