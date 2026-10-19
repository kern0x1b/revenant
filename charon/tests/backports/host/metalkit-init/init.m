/* init.m - does each MetalKit class answer -init with NSObject's own implementation, on Apple's MetalKit
 * and on the port's classes, and do the two answers agree?
 *
 * The five registry rows for `-[MTKMesh init]`, `-[MTKSubmesh init]`, `-[MTKMeshBuffer init]`,
 * `-[MTKMeshBufferAllocator init]` and `-[MTKTextureLoader init]` were `absent`, because the headers
 * declare -init NS_UNAVAILABLE. The unavailableinit case in metal-census measured what Apple's own
 * classes do with that: they carry NSObject's -init and define none. The port's classes inherit it the
 * same way, so a caller that reaches -init gets the same object from both.
 *
 * What is compared here is the IMP each class answers -init with. `class_getInstanceMethod` searches the
 * superclasses, so the answer alone says nothing: every NSObject subclass has one. The comparison is with
 * NSObject's IMP itself, and the controls keep the measurement honest:
 *
 *   * CharonInitOverrider overrides -init, so an override is shown to differ from NSObject's IMP.
 *   * ZZZNoSuchNameCharonR16 is not a class of any framework, so a missing class cannot pass as a match.
 *
 * The port's classes are reached by the names run.sh gives them (CharonHost<Name>), because the port's
 * object files are built beside Apple's MetalKit in one process and cannot keep their own names there.
 * run.sh supplies the mapping; this file only asks for the names it was given.
 */
#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

/* THE CONTROL CLASS: it overrides -init, which is the thing the measurement has to be able to see. */
@interface CharonInitOverrider : NSObject
@end

@implementation CharonInitOverrider
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

/* The IMP a class answers -init with, or NULL if it answers none (the nonsense name). */
static IMP initOf(Class c)
{
    Method m = c ? class_getInstanceMethod(c, @selector(init)) : NULL;
    return m ? method_getImplementation(m) : NULL;
}

/* Does the class define -init in its own method list, not inherited? */
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

/* One class, answered from one side: the class exists under `name`, it answers -init with NSObject's own
 * IMP, it defines none of its own, and an instance comes out of alloc + -init of the class itself. */
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
    /* The selector goes through objc_msgSend, not performSelector:, because ARC refuses an init sent by name. */
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

        /* THE CONTROLS FIRST: each must show what the measurement claims to show. */
        IMP overrider = initOf([CharonInitOverrider class]);
        check(overrider != NULL && overrider != initOf([NSObject class]) && definesInit([CharonInitOverrider class]),
              @"control: a class that overrides -init differs from NSObject's IMP");
        check(NSClassFromString(@"ZZZNoSuchNameCharonR16") == nil,
              @"control: a name no framework has is not a class");

        /* Apple's own classes: the host framework is the oracle. */
        printf("Apple's MetalKit (the host framework)\n");
        expectInheritsInit(@"MTKMesh", @"apple MTKMesh");
        expectInheritsInit(@"MTKSubmesh", @"apple MTKSubmesh");
        expectInheritsInit(@"MTKMeshBuffer", @"apple MTKMeshBuffer");
        expectInheritsInit(@"MTKMeshBufferAllocator", @"apple MTKMeshBufferAllocator");
        expectInheritsInit(@"MTKTextureLoader", @"apple MTKTextureLoader");

        /* The port's classes, the same question. */
        printf("the port's classes (renamed CharonHost<Name> in this process)\n");
        expectInheritsInit(@"CharonHostMTKMesh", @"port MTKMesh");
        expectInheritsInit(@"CharonHostMTKSubmesh", @"port MTKSubmesh");
        expectInheritsInit(@"CharonHostMTKMeshBuffer", @"port MTKMeshBuffer");
        expectInheritsInit(@"CharonHostMTKMeshBufferAllocator", @"port MTKMeshBufferAllocator");
        expectInheritsInit(@"CharonHostMTKTextureLoader", @"port MTKTextureLoader");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
