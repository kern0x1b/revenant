//
//  collection-test.m
//  What a resolution result's collection factory answers, beside the host's own answer.
//
//  `+successesWithResolved<Items>:` and its four siblings answer an **array** of resolution
//  results, one per item, each made by the class's own single-item factory. That was measured on
//  the host through objc_msgSend into all five of them (macOS 26's Intents.framework, 2026-09-28):
//
//      two items  -> __NSArrayM, count 2, each element an instance of the class asked
//      one item   -> count 1, one element of that class
//      empty      -> count 0, an array
//      nil        -> count 0, an array - not nil, because a caller counts what it is given
//
//  and each element's resolvedValue is the item it was made from. This test prints the same table
//  for the port's own body, so a reader can put the two side by side, and the mutation below is
//  there to show the table goes red rather than drifting: a factory that returns **one element
//  fewer** than the host's answer is built as well, and the counts are printed for it too.
//
//  It is built twice: once with the generated objects, once with a mutant of them
//  (tests/backports/callgen/collection-test.sh), and the mutant's counts are the ones that differ.
//

#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>

static BOOL charon_countsOnly;

static void probe(Class cls, SEL factory, SEL single, NSArray *input)
{
    id results = ((id (*)(id, SEL, id))objc_msgSend)(cls, factory, input);
    NSMutableString *elements = [NSMutableString string];
    for (id element in results) {
        id value = [element valueForKey:@"resolvedValue"];
        [elements appendFormat:@" [%s %s]", class_getName([element class]),
                              value ? [[value description] UTF8String] : "nil"];
    }
    printf("  %-6s count=%lu\n", input ? "items" : "nil", (unsigned long)[results count]);
    if (!charon_countsOnly) {
        printf("        %s\n", [elements UTF8String]);
    }
    (void)single;
    (void)charon_countsOnly;
}

// The class to ask, because the port's own classes are renamed when they are built into a macOS
// binary for this test: the system has INMediaItemResolutionResult of its own, and without the
// rename that one answers and the port's body never runs - which is what the first version of this
// test measured, two identical tables and a mutation that changed nothing.
int main(int argc, const char *argv[])
{
    @autoreleasepool {
        // "counts" prints the numbers alone, so two runs can be diffed.
        BOOL countsOnly = argc > 1 && strcmp(argv[1], "counts") == 0;
        charon_countsOnly = countsOnly;
        const char *title = countsOnly ? "counts" : (argc > (countsOnly ? 1 : 2)
                                                    ? argv[countsOnly ? 0 : 1] : "the port's own body");
        const char *asked = argc > (countsOnly ? 2 : 3) ? argv[countsOnly ? 1 : 2]
                                                      : "INMediaItemResolutionResult";
        const char *itemName = argc > (countsOnly ? 3 : 4) ? argv[countsOnly ? 2 : 3]
                                                        : "INMediaItem";
        Class item = NSClassFromString([NSString stringWithUTF8String:itemName]);
        if (!item) {
            printf("%s: INMediaItem is not in this build\n", title);
            return 2;
        }
        SEL byName = NSSelectorFromString(@"initWithIdentifier:title:type:artwork:artist:");
        if (![item instancesRespondToSelector:byName]) {
            printf("%s: %s has no initWithIdentifier:title:type:artwork:artist:\n", title, itemName);
            return 2;
        }
        id one = [[item alloc] initWithIdentifier:@"one" title:@"One" type:0 artwork:nil artist:nil];
        id two = [[item alloc] initWithIdentifier:@"two" title:@"Two" type:0 artwork:nil artist:nil];
        NSArray *inputs[] = {@[one, two], @[one], @[], nil};
        Class cls = NSClassFromString([NSString stringWithUTF8String:asked]);
        if (!cls) {
            printf("%s: %s is not in this build\n", title, asked);
            return 2;
        }
        SEL factory = NSSelectorFromString(@"successesWithResolvedMediaItems:");
        SEL single = NSSelectorFromString(@"successWithResolvedMediaItem:");
        printf("%s:\n", title);
        for (unsigned index = 0; index < 4; index++) {
            probe(cls, factory, single, inputs[index]);
        }
    }
    return 0;
}
