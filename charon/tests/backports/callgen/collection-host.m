// The host's own answer for the five +successesWithResolved…: factories, through objc_msgSend.
#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        const char *title = argc > 1 ? argv[1] : "the host";
        Class item = NSClassFromString(@"INMediaItem");
        if (!item) { printf("%s: INMediaItem is not on this host\n", title); return 2; }
        id one = [[item alloc] initWithIdentifier:@"one" title:@"One" type:0 artwork:nil artist:nil];
        id two = [[item alloc] initWithIdentifier:@"two" title:@"Two" type:0 artwork:nil artist:nil];
        const char *names[] = {"INMediaItemResolutionResult", "INPlayMediaMediaItemResolutionResult",
                               "INAddMediaMediaItemResolutionResult",
                               "INSearchForMediaMediaItemResolutionResult",
                               "INUpdateMediaAffinityMediaItemResolutionResult"};
        NSArray *inputs[] = {@[one, two], @[one], @[], nil};
        printf("%s:\n", title);
        for (unsigned c = 0; c < sizeof(names)/sizeof(*names); c++) {
            Class cls = NSClassFromString([NSString stringWithUTF8String:names[c]]);
            if (!cls) { printf("  %s: not on this host\n", names[c]); continue; }
            for (unsigned index = 0; index < 4; index++) {
                id results = ((id (*)(id, SEL, id))objc_msgSend)(cls,
                                  @selector(successesWithResolvedMediaItems:), inputs[index]);
                printf("  %-42s count=%lu\n", names[c], (unsigned long)[results count]);
            }
        }
    }
    return 0;
}
