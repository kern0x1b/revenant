#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <objc/runtime.h>

@interface RevenantInitOverrider : NSObject
- (instancetype)init;
@end
@implementation RevenantInitOverrider
- (instancetype)init { return [super init]; }
@end

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
        printf("-init RevenantInitOverrider %d\n", inherits_nsobject("RevenantInitOverrider", NO, @selector(init)));
        printf("-init ZZZNoSuchNameRevenantCoreML %d\n", inherits_nsobject("ZZZNoSuchNameRevenantCoreML", NO, @selector(init)));
    }
    return 0;
}
