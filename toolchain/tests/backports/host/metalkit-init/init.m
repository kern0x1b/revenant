#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface RevenantInitOverrider : NSObject
@end

@implementation RevenantInitOverrider
- (instancetype)init { return [super init]; }
@end

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

static IMP initOf(Class c)
{
    Method m = c ? class_getInstanceMethod(c, @selector(init)) : NULL;
    return m ? method_getImplementation(m) : NULL;
}

static int definesInit(Class c)
{
    unsigned own = 0;
    int found = 0;
    Method *list = class_copyMethodList(c, &own);
    for (unsigned i = 0; i < own; i++)
        if (sel_isEqual(method_getName(list[i]), @selector(init))) { found = 1; break; }
    free(list);
    return found;
}

static void expectInheritsInit(NSString *name, NSString *label)
{
    Class c = NSClassFromString(name);
    if (!c) {
        check(0, [NSString stringWithFormat:@"%@: the class %@ is there", label, name]);
        return;
    }
    IMP nsobjectInit = initOf([NSObject class]);
    check(initOf(c) == nsobjectInit && !definesInit(c),
          ([NSString stringWithFormat:@"%@: -init is NSObject's own and the class defines none", label]));
    id allocated = ((id (*)(id, SEL))objc_msgSend)(c, @selector(alloc));
    id made = ((id (*)(id, SEL))objc_msgSend)(allocated, @selector(init));
    check(made != nil && [made isKindOfClass:c],
          ([NSString stringWithFormat:@"%@: alloc then -init gives an instance of the class", label]));
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("does -init on each MetalKit class answer NSObject's own, on Apple's and on the port's?\n");

        IMP overrider = initOf([RevenantInitOverrider class]);
        check(overrider != NULL && overrider != initOf([NSObject class]) && definesInit([RevenantInitOverrider class]),
              @"control: a class that overrides -init differs from NSObject's IMP");
        check(NSClassFromString(@"ZZZNoSuchNameRevenantR16") == nil,
              @"control: a name no framework has is not a class");

        printf("Apple's MetalKit (the host framework)\n");
        expectInheritsInit(@"MTKMesh", @"apple MTKMesh");
        expectInheritsInit(@"MTKSubmesh", @"apple MTKSubmesh");
        expectInheritsInit(@"MTKMeshBuffer", @"apple MTKMeshBuffer");
        expectInheritsInit(@"MTKMeshBufferAllocator", @"apple MTKMeshBufferAllocator");
        expectInheritsInit(@"MTKTextureLoader", @"apple MTKTextureLoader");

        printf("the port's classes (renamed RevenantHost<Name> in this process)\n");
        expectInheritsInit(@"RevenantHostMTKMesh", @"port MTKMesh");
        expectInheritsInit(@"RevenantHostMTKSubmesh", @"port MTKSubmesh");
        expectInheritsInit(@"RevenantHostMTKMeshBuffer", @"port MTKMeshBuffer");
        expectInheritsInit(@"RevenantHostMTKMeshBufferAllocator", @"port MTKMeshBufferAllocator");
        expectInheritsInit(@"RevenantHostMTKTextureLoader", @"port MTKTextureLoader");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
