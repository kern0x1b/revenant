// init.m - the host's own answer for -[<class> init], for every class the registry carries a row for.
//
// WHAT THIS IS FOR. The registry carries 110 `-[<class> init]` rows at status `implemented`, and
// each one's `source` says the same thing: the header marks the class's -init unavailable, the
// system still answers one, so the object defines the method and reaches the superclass's own
// -init through its IMP. Eight of the 110 had been measured by hand; the other hundred and two
// were "the same rule applied to the same header, which is a claim and not a measurement until
// that harness runs". This file is that harness, for all 110, on every run.
//
// WHAT IT MEASURES, per class, one tab-separated line: the class, then
//
//   own | inherit     whether the class declares -init itself or takes NSObject's, read by the
//                    IMP address. The port's generated body always forwards to the superclass's
//                    IMP, so a class answering `own` is a row whose body is not the answer the
//                    host gives. This is not visible in a header and not visible in the registry,
//                    and it is the measurement worth having.
//   object | nil | threw | absent | noimp    what `[[Cls alloc] init]` answered, through that IMP.
//   <n> <n> <names>   of the properties THE PORT SYNTHESIZES for this class (init-properties.inc),
//                    how many read non-nil on that fresh object and which.
//
// WHY THE PROPERTIES COME FROM A TABLE AND NOT FROM THE RUNTIME. The first version of this file
// asked `class_copyPropertyList` and got 48 properties for INActivateCarSignalIntentResponse:
// NSObject's `hash`, `superclass`, `description` and `debugDescription` four times over, and the
// framework's own `_JSONDictionaryRepresentation` and `propertiesByName`, whose getters are not
// the API under test and one of which took the run down with SIGSEGV. The population that matters
// is the properties the port synthesizes, because those are the ones the row claims stay nil, and
// that is what init-properties.inc holds: 336 reads over 105 classes, read from the port's own
// `@synthesize` lines. Five of the 110 synthesize nothing and are measured on -init alone.
//
//   xcrun clang -fobjc-arc init.m -framework Foundation -framework Intents -o init
//   ./init expected.txt                    compare with the golden, exit 1 on any difference
//   VERBOSE=1 ./init expected.txt          every class, not only the ones that differ
//   PLANT=one-wrong ./init expected.txt    force one line to disagree; must exit 1
//
// A claim nobody re-measures is a claim. The golden file is what makes this a measurement on every
// run, in the shape the rest of the tree uses for exactly that: tests/backports/host/morphology.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LINE_MAX_LEN 512

// The class, and the properties the port synthesizes for it.
//
// A struct and not a `const char *CLASSES[][2]`: in a two-dimensional array the second slot of a
// row is a SCALAR, so `{ "INCar", { "make", "model", NULL } }` initializes that scalar with the
// first element and calls the rest excess. Clang only warns (-Wexcess-initializers), so the table
// compiled and the program read `properties[0]` three bytes into a string literal, which is how
// the first version of this harness died in strlen on an address that spelled "Index...".
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
        // Unbuffered and line-flushed: this program reads a crash as a finding, and a
        // block-buffered pipe loses everything printed before the one that segfaulted. Measured:
        // the first run printed nothing at all and returned 139.
        setvbuf(stdout, NULL, _IOLBF, 0);

        const size_t count = sizeof(CLASSES) / sizeof(*CLASSES);
        const BOOL verbose = getenv("VERBOSE") != NULL;
        const BOOL plant = getenv("PLANT") != NULL;
        const char *golden = (argc > 1) ? argv[1] : NULL;

        // NSObject's own -init IMP, read once: a class that inherits -init answers with exactly
        // this address, and that is what makes `own` and `inherit` a measurement and not a guess.
        IMP nsInit = class_getMethodImplementation([NSObject class], @selector(init));

        static char measured[256][LINE_MAX_LEN];
        size_t ok = 0, absent = 0, noImp = 0, raised = 0, nilObject = 0, dirty = 0, own = 0, reads = 0;

        // stdout is the measurement and nothing else: run.sh writes expected.txt from it, and a
        // banner on stdout becomes a golden line the next run reads as data.
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

            // One guard over the whole measurement of this class, not only over -init: a property
            // getter raises too, and INRelevanceProvider's -init raises by design ("cannot be
            // initialized directly with -init, initialize a subclass instead").
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
            // A measurement that cannot fail guards nothing. One measured line is replaced with a
            // value the host did not answer, and the comparison against the golden has to notice.
            // The index is fixed rather than random so the plant is reproducible: a plant that
            // lands on a different class each run proves less about the comparison than one that
            // always lands on the same one.
            const size_t target = count / 2;
            fprintf(stderr, "# intents-init: PLANT=one-wrong on %s\n", CLASSES[target].name);
            char wrong[LINE_MAX_LEN];
            snprintf(wrong, sizeof wrong, "%s\tplantedplanted\t999\t999\tplanted", CLASSES[target].name);
            snprintf(measured[target], LINE_MAX_LEN, "%s", wrong);
        }

        if (!golden || !*golden) {
            // No golden given: print what was measured and exit 0, so the file can be written
            // from this run. Three of the 110 do not answer -init with an object (two answer nil
            // and INRelevanceProvider raises), and that is the measurement, not a failure of it.
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

        // A class measured but missing from the golden file is the failure init-classes.inc's
        // derivation comment is about: the registry grew a row and the golden did not follow.
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