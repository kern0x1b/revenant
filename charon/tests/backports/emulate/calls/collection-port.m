//
//  collection-port.m
//  The resolution results' collection factories, run on the port.
//
//  The same table the host run prints, read out of **this** process: on the device there is no
//  Intents.framework of the system's own, so the classes looked up by name are libIntentsBackports'
//  and nothing has to be renamed. What the port must answer is the host's measured answer:
//
//      two items  -> count 2, one result per item, each the class asked
//      one item   -> count 1
//      empty      -> count 0, an array
//      nil        -> count 0, an array
//
//  and the same program is built a second time against a **mutant** of the generated factory - one
//  that returns an element fewer - so the table is shown going red on the device and not argued
//  about. The mutant is a source swap in the tree, restored afterwards and checked with git status.
//
//  Run with "counts" as the first argument it prints the numbers alone under a fixed title, which
//  is what run-collection.sh compares. Two things have to come out of the comparison for that to
//  work, and neither is the label alone: the program writes the label it was given into the first
//  line, so two transcripts of one table differ there whatever the counts say, and the element
//  lines carry -[NSObject description] of the port's INMediaItem, which overrides no description
//  and so answers with its address - measured, two of them in one process print two addresses, so
//  dropping the first line in the shell would still compare a run against itself. This is the
//  argument the host half already takes (tests/backports/callgen/collection-test.m, and the .counts
//  files collection-test.sh compares), so both halves of the measurement answer in one shape.
//

#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>

static BOOL charon_countsOnly;

static NSArray *items(void)
{
    Class item = NSClassFromString(@"INMediaItem");
    if (!item) {
        return nil;
    }
    SEL build = NSSelectorFromString(@"initWithIdentifier:title:type:artwork:artist:");
    if (![item instancesRespondToSelector:build]) {
        return nil;
    }
    id one = [[item alloc] initWithIdentifier:@"one" title:@"One" type:0 artwork:nil artist:nil];
    id two = [[item alloc] initWithIdentifier:@"two" title:@"Two" type:0 artwork:nil artist:nil];
    return @[one, two];
}

static void probe(NSString *name, NSArray *input)
{
    Class cls = NSClassFromString(name);
    if (!cls) {
        printf("  %-42s not in this build\n", [name UTF8String]);
        return;
    }
    SEL factory = NSSelectorFromString(@"successesWithResolvedMediaItems:");
    if (![cls respondsToSelector:factory]) {
        printf("  %-42s has no successesWithResolvedMediaItems:\n", [name UTF8String]);
        return;
    }
    id results = ((id (*)(id, SEL, id))objc_msgSend)(cls, factory, input);
    printf("  %-42s count=%lu %s\n", [name UTF8String], (unsigned long)[results count],
           input ? "" : "(nil input)");
    if (charon_countsOnly) {
        return;
    }
    for (id element in results) {
        id value = [element valueForKey:@"resolvedValue"];
        printf("      element %-38s resolvedValue %s\n", class_getName([element class]),
               value ? [[value description] UTF8String] : "(nil)");
    }
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        charon_countsOnly = argc > 1 && strcmp(argv[1], "counts") == 0;
        const char *title = "the port's own body";
        if (charon_countsOnly) {
            title = "counts";
        } else if (argc > 1) {
            title = argv[1];
        }
        NSArray *both = items();
        if (!both) {
            printf("%s: this build has no INMediaItem to hand the factories\n", title);
            return 2;
        }
        const char *classes[] = {"INMediaItemResolutionResult", "INPlayMediaMediaItemResolutionResult",
                                 "INAddMediaMediaItemResolutionResult",
                                 "INSearchForMediaMediaItemResolutionResult",
                                 "INUpdateMediaAffinityMediaItemResolutionResult"};
        printf("%s:\n", title);
        for (unsigned index = 0; index < sizeof(classes) / sizeof(*classes); index++) {
            probe([NSString stringWithUTF8String:classes[index]], @[both[0], both[1]]);
        }
        // And the three other inputs on the base class, which is where the empty and nil answers
        // are the interesting ones: a caller counts what it is given, so nil must be an array.
        NSString *base = @"INMediaItemResolutionResult";
        probe(base, @[both[0]]);
        probe(base, @[]);
        probe(base, nil);
        return 0;
    }
}
