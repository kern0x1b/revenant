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

int main(int argc, const char *argv[])
{
    @autoreleasepool {
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
