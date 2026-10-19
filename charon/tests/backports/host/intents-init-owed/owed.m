// owed.m - the host's own answer for -[<class> init] on the five Intents classes whose -init row is owed,
// and what the port answers for the same five, from one source compiled twice by run.sh.
//
// The five rows are owed because the port has no -init on them. Whether that is a gap depends on what the host
// answers. If the host's -init is NSObject's, the port's inherited one is the same answer and the row can be
// implemented with a fact. If the host's is its own and answers nil, the port must answer nil too. If it answers an
// object with a property that is not nil, the port must answer that. So each build prints, per class:
//
//   own | inherit   whether the class declares -init itself, by the IMP's address against NSObject's.
//   the owner       the first class in the superclass chain whose own method list has -init.
//   object | nil | threw   what [[Cls alloc] init] answered, called through the IMP.
//   <n> <n> <names> the class's own object-typed properties read on that fresh object: how many, how many read
//                   non-nil, and which.
//   <n> <n> <names> the class's own scalar properties read on that object: how many, how many are non-zero, which.
//                   A property of a struct type is not read, and is counted in the last column as unread.
//
// The host build links the system's Intents and says so: every class must come from the Intents image, or the run
// stops with status 2. The port build (-DPORT) names the port's classes with the CharonHost prefix that run.sh renames
// them to, and every one must come from this probe's own image, not from Intents. The IMP call is how the answer is
// read, because the header marks some of these -init NS_UNAVAILABLE and a compile-time send would not be the measurement.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

// The five owed rows, by the name Apple gives them. The port defines all five in CharonIntents100.m.
static const char *OWED[] = {
    "INInteraction",
    "INIntentResolutionResult",
    "INPaymentMethod",
    "INRideCompletionStatus",
    "INSpeakableString",
    NULL,
};

// Controls, host only: one that inherits -init (INPaymentAmount, in IN10_0_1.m, not built here) and one that declares
// it (INListCarsIntent). They show the reader finds both kinds on the host, so the zeros above are not a blind reader.
static const char *CONTROLS[] = {
    "INPaymentAmount",
    "INListCarsIntent",
    NULL,
};

// The name a port class has at run time, and the name the Apple class has.
static const char *apple_name(const char *runtime)
{
    size_t prefix = strlen(PREFIX);
    return strncmp(runtime, PREFIX, prefix) == 0 ? runtime + prefix : runtime;
}

// The first class in the chain that declares -init itself, by Apple's name, or "-" when none does.
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

// 0 for a zero scalar, 1 for a non-zero one, -1 for a type this probe does not read (a struct).
// Each read is through the getter's own return type, and masked to the type's width, because the upper bits of a
// narrow return are not defined on arm64.
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

// Measures one class and prints one line. Returns 0 on success, 2 when the class is not where the build says it is.
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

    // NSObject's -init, read once: an inherited -init answers with exactly this address.
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
    // The release's property list is the port's own and the host's is the SDK's, so the two lists differ in length
    // by release: the counts go to stderr for the facts, and the diff is on what each read answered, which must match.
    unsigned objectRead = 0, scalarRead = 0, unread = 0;
    char nonNil[512] = "", nonZero[512] = "";
    if (object && !threw) {
        unsigned count = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &count);
        for (unsigned i = 0; i < count; i++) {
            // description, debugDescription and hash are NSObject's, and appear in the class's own list because the
            // header re-declares them. They are not the class's properties.
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
    // respondsToSelector: asked of the class, as the registry's effect text asks it, and not inferred from the IMP.
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
