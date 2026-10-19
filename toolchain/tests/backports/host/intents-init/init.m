#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LINE_MAX_LEN 512

typedef struct {
    const char *name;
    const char *properties[48];
} InitClass;

static const InitClass CLASSES[] = {
#include "init-classes.inc"
};

static void render(char *buffer, size_t size, const char *name, const char *whose,
                   const char *outcome, unsigned read, unsigned nonNil, const char *which)
{
    snprintf(buffer, size, "%s\t%s%s\t%u\t%u\t%s", name, whose, outcome, read, nonNil, which);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);

        const size_t count = sizeof(CLASSES) / sizeof(*CLASSES);
        const BOOL verbose = getenv("VERBOSE") != NULL;
        const BOOL plant = getenv("PLANT") != NULL;
        const char *golden = (argc > 1) ? argv[1] : NULL;

        IMP nsInit = class_getMethodImplementation([NSObject class], @selector(init));

        static char measured[256][LINE_MAX_LEN];
        size_t ok = 0, absent = 0, noImp = 0, raised = 0, nilObject = 0, dirty = 0, own = 0, reads = 0;

        fprintf(stderr, "intents-init: %zu classes, NSObject -init at %p\n", count, (void *)nsInit);

        for (size_t i = 0; i < count; i++) {
            const char *name = CLASSES[i].name;
            const char *const *properties = CLASSES[i].properties;
            Class cls = NSClassFromString(@(name));

            if (!cls) {
                absent++;
                render(measured[i], LINE_MAX_LEN, name, "", "absent", 0, 0, "-");
                continue;
            }
            Method method = class_getInstanceMethod(cls, @selector(init));
            IMP imp = method ? method_getImplementation(method) : NULL;
            if (!imp) {
                noImp++;
                render(measured[i], LINE_MAX_LEN, name, "", "noimp", 0, 0, "-");
                continue;
            }
            const char *whose = (imp == nsInit) ? "inherit" : "own";
            if (imp != nsInit) own++;

            id object = nil;
            BOOL threw = NO, initNil = NO;
            unsigned read = 0, nonNil = 0;
            char which[256];
            which[0] = '\0';
            size_t used = 0;

            @try {
                object = [[cls alloc] init];
                if (!object) {
                    initNil = YES;
                } else {
                    for (const char *const *p = properties; *p; p++, read++) {
                        SEL getter = NSSelectorFromString(@(*p));
                        if (![object respondsToSelector:getter]) continue;
                        id (*value)(id, SEL) = (id (*)(id, SEL))[object methodForSelector:getter];
                        if (!value || !value(object, getter)) continue;
                        nonNil++;
                        int wrote = snprintf(which + used, sizeof(which) - used, "%s%s",
                                             used ? "," : "", *p);
                        if (wrote < 0) break;
                        used += (size_t)wrote;
                        if (used >= sizeof(which)) break;
                    }
                }
            } @catch (id exception) {
                threw = YES;
            }
            reads += read;

            if (threw) {
                raised++;
                render(measured[i], LINE_MAX_LEN, name, whose, "threw", read, 0, "-");
                continue;
            }
            if (initNil) {
                nilObject++;
                render(measured[i], LINE_MAX_LEN, name, whose, "nil", read, 0, "-");
                continue;
            }
            if (nonNil) dirty++;
            render(measured[i], LINE_MAX_LEN, name, whose, "object", read, nonNil, which);
            ok++;

            if (verbose && !nonNil) {
                printf("      %-42s %s, %u properties read, all nil\n", name, whose, read);
            }
        }

        fprintf(stderr, "# intents-init: %zu classes, %zu answered, %zu absent, %zu no IMP, %zu raised, "
               "%zu nil; -init own %zu, inherited %zu; %zu property reads, %zu classes with a "
               "non-nil property\n",
               count, ok, absent, noImp, raised, nilObject, own, count - own, reads, dirty);

        if (plant && count) {
            const size_t target = count / 2;
            fprintf(stderr, "# intents-init: PLANT=one-wrong on %s\n", CLASSES[target].name);
            char wrong[LINE_MAX_LEN];
            snprintf(wrong, sizeof wrong, "%s\tplantedplanted\t999\t999\tplanted", CLASSES[target].name);
            snprintf(measured[target], LINE_MAX_LEN, "%s", wrong);
        }

        if (!golden || !*golden) {
            for (size_t i = 0; i < count; i++) printf("%s\n", measured[i]);
            return 0;
        }

        FILE *file = fopen(golden, "r");
        if (!file) { printf("intents-init: cannot read the golden file %s\n", golden); return 1; }
        static unsigned char inGolden[256];
        char want[LINE_MAX_LEN];
        size_t compared = 0, differ = 0;
        while (fgets(want, sizeof want, file)) {
            want[strcspn(want, "\n")] = '\0';
            if (!*want || want[0] == '#' || want[0] == '/') continue;
            compared++;
            const char *tab = strchr(want, '\t');
            if (!tab) { printf("intents-init: RED golden line has no class name: %s\n", want); differ++; continue; }
            size_t nameLength = (size_t)(tab - want);
            size_t index = count;
            for (size_t i = 0; i < count; i++) {
                if (strlen(CLASSES[i].name) == nameLength && strncmp(CLASSES[i].name, want, nameLength) == 0) {
                    index = i;
                    break;
                }
            }
            if (index == count) {
                printf("intents-init: RED %s is in the golden file and not in the class list\n", want);
                differ++;
                continue;
            }
            if (index < sizeof inGolden) inGolden[index] = 1;
            if (strcmp(measured[index], want) != 0) {
                printf("intents-init: RED %s\n            measured %s\n            golden   %s\n",
                       CLASSES[index].name, measured[index], want);
                differ++;
            }
            if (plant && index == count / 2) {
                printf("intents-init: PLANT=one-wrong forced one line to disagree\n");
            }
        }
        fclose(file);

        for (size_t i = 0; i < count && i < sizeof inGolden; i++) {
            if (inGolden[i]) continue;
            printf("intents-init: RED %s is measured and not in the golden file\n", CLASSES[i].name);
            differ++;
        }

        printf("intents-init: %zu golden lines, %zu differ -> %s\n",
               compared, differ, differ ? "FAIL" : "PASS");
        return differ ? 1 : 0;
    }
}
