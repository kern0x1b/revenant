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
        NSString *base = @"INMediaItemResolutionResult";
        probe(base, @[both[0]]);
        probe(base, @[]);
        probe(base, nil);
        return 0;
    }
}
