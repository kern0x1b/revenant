#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

#ifdef PORT
#define PREFIX "RevenantHost"
#else
#define PREFIX ""
#endif

static const char *OWED[] = {
    "INInteraction",
    "INIntentResolutionResult",
    "INPaymentMethod",
    "INRideCompletionStatus",
    "INSpeakableString",
    NULL,
};

static const char *CONTROLS[] = {
    "INPaymentAmount",
    "INListCarsIntent",
    NULL,
};

static const char *apple_name(const char *runtime)
{
    size_t prefix = strlen(PREFIX);
    return strncmp(runtime, PREFIX, prefix) == 0 ? runtime + prefix : runtime;
}

static const char *init_owner(Class cls)
{
    for (Class c = cls; c; c = class_getSuperclass(c)) {
        unsigned count = 0;
        Method *methods = class_copyMethodList(c, &count);
        BOOL declares = NO;
        for (unsigned i = 0; i < count; i++) {
            if (method_getName(methods[i]) == @selector(init)) declares = YES;
        }
        free(methods);
        if (declares) return apple_name(class_getName(c));
    }
    return "-";
}

static int scalar_state(id object, SEL getter, const char *type)
{
    IMP imp = [object methodForSelector:getter];
    switch (type[0]) {
        case 'B': case 'c': case 'C':
            return (((unsigned long long (*)(id, SEL))imp)(object, getter) & 0xff) != 0;
        case 's': case 'S':
            return (((unsigned long long (*)(id, SEL))imp)(object, getter) & 0xffff) != 0;
        case 'i': case 'I':
            return (((unsigned long long (*)(id, SEL))imp)(object, getter) & 0xffffffffULL) != 0;
        case 'l': case 'L': case 'q': case 'Q':
            return ((unsigned long long (*)(id, SEL))imp)(object, getter) != 0;
        case 'd':
            return ((double (*)(id, SEL))imp)(object, getter) != 0;
        case 'f':
            return ((float (*)(id, SEL))imp)(object, getter) != 0;
        default:
            return -1;
    }
}

static int measure(const char *apple, BOOL control)
{
    NSString *runtime = [NSString stringWithFormat:@"%s%s", PREFIX, apple];
    Class cls = NSClassFromString(runtime);
    if (!cls) {
        fprintf(stderr, "FAIL: %s is not defined in this build\n", apple);
        return 2;
    }
    const char *image = class_getImageName(cls);
    BOOL fromSystem = image && strstr(image, "/Intents.framework/") != NULL;
#ifdef PORT
    if (fromSystem) {
        fprintf(stderr, "FAIL: the port build got %s from the system Intents\n", apple);
        return 2;
    }
#else
    if (!fromSystem) {
        fprintf(stderr, "FAIL: the host build got %s from outside the system Intents\n", apple);
        return 2;
    }
#endif

    IMP nsInit = class_getMethodImplementation([NSObject class], @selector(init));
    Method method = class_getInstanceMethod(cls, @selector(init));
    IMP imp = method ? method_getImplementation(method) : NULL;
    if (!imp) {
        printf("%s\tnoimp\n", apple);
        return 0;
    }
    const char *whose = (imp == nsInit) ? "inherit" : "own";
    const char *owner = init_owner(cls);

    id object = nil;
    BOOL threw = NO;
    @try {
        id allocated = [cls alloc];
        object = ((id (*)(id, SEL))imp)(allocated, @selector(init));
    } @catch (id exception) {
        threw = YES;
    }

    const char *outcome = threw ? "threw" : (object ? "object" : "nil");
    unsigned objectRead = 0, scalarRead = 0, unread = 0;
    char nonNil[512] = "", nonZero[512] = "";
    if (object && !threw) {
        unsigned count = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &count);
        for (unsigned i = 0; i < count; i++) {
            if (class_getProperty([NSObject class], property_getName(properties[i]))) continue;
            const char *name = property_getName(properties[i]);
            const char *attributes = property_getAttributes(properties[i]);
            SEL getter = NSSelectorFromString(@(name));
            if (![object respondsToSelector:getter]) continue;
            if (attributes[0] == 'T' && attributes[1] == '@') {
                objectRead++;
                id (*value)(id, SEL) = (id (*)(id, SEL))[object methodForSelector:getter];
                if (!value(object, getter)) continue;
                size_t used = strlen(nonNil);
                snprintf(nonNil + used, sizeof(nonNil) - used, "%s%s", used ? "," : "", name);
            } else if (attributes[0] == 'T') {
                int state = scalar_state(object, getter, attributes + 1);
                if (state < 0) {
                    unread++;
                    continue;
                }
                scalarRead++;
                if (!state) continue;
                size_t used = strlen(nonZero);
                snprintf(nonZero + used, sizeof(nonZero) - used, "%s%s", used ? "," : "", name);
            }
        }
        free(properties);
    }
    fprintf(stderr, "info\t%s\tobject-properties %u\tscalar-properties %u\tunread %u\n", apple, objectRead, scalarRead,
            unread);
    BOOL responds = [cls instancesRespondToSelector:@selector(init)];
    printf("%s%s\t%s\t%s\t%s\tnonnil=%s\tnonzero=%s\tresponds=%s\n", control ? "control\t" : "", apple, whose, owner,
           outcome, nonNil[0] ? nonNil : "-", nonZero[0] ? nonZero : "-", responds ? "YES" : "NO");
    return 0;
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        for (const char **name = OWED; *name; name++) {
            if (measure(*name, NO) != 0) return 2;
        }
#ifndef PORT
        for (const char **name = CONTROLS; *name; name++) {
            if (measure(*name, YES) != 0) return 2;
        }
#endif
    }
    return 0;
}
