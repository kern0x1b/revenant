#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static void probe(const char *name, id (^make)(void))
{
    __weak id weak;
    printf("%s: ", name);
    @autoreleasepool {
        id object = make();
        printf("%s, ", class_getName(object_getClass(object)));
        weak = object;
        printf("weak %s, ", weak ? "set" : "nil");
    }
    printf("after release: %s\n", weak ? "STILL SET" : "nil");
    fflush(stdout);
}

static void lookup(void)
{
    void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY | RTLD_NOLOAD);
    const char *error = objc ? NULL : dlerror();
    printf("libobjc handle: %s%s%s\n", objc ? "non-NULL" : "NULL", error ? ", dlerror: " : "", error ? error : "");
    static const char *names[] = {"objc_loadWeakRetained", "objc_storeWeak", "objc_loadWeak"};
    for (unsigned i = 0; objc && i < sizeof names / sizeof *names; i++)
        printf("dlsym %s: %s\n", names[i], dlsym(objc, names[i]) ? "found" : "NULL");
    fflush(stdout);
}

int main(void)
{
    lookup();
    @autoreleasepool {
        int n = 1000;
        probe("NSObject", ^id { return [[NSObject alloc] init]; });
        probe("NSMutableString", ^id { return [[NSMutableString alloc] initWithFormat:@"k%d", n]; });
        probe("NSString", ^id { return [[NSString alloc] initWithFormat:@"key %d", n]; });
        probe("NSNumber", ^id { return [[NSNumber alloc] initWithInt:n * 1000]; });
        probe("NSDate", ^id { return [[NSDate alloc] initWithTimeIntervalSince1970:n]; });
        probe("NSArray", ^id { return [[NSArray alloc] initWithObjects:@"a", [NSNumber numberWithInt:n], nil]; });
    }
    return 0;
}
