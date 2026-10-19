#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <unistd.h>
#import "check.h"

static uint64_t state = 0xD1EC7042ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static void build_tree(NSString *root, int depth)
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSUInteger count = next() % 5;
    NSArray *names = @[@"a", @"b", @"c", @".h", @"d.app", @"e", @"f.txt", @"g", @"h.bundle"];
    for (NSUInteger index = 0; index < count; index++) {
        NSString *name = names[next() % names.count];
        NSString *path = [root stringByAppendingPathComponent:name];
        if ([manager fileExistsAtPath:path])
            continue;
        switch (next() % 6) {
        case 0:
        case 1:
        case 2:
            [manager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL];
            if (depth < 4)
                build_tree(path, depth + 1);
            break;
        case 3:
            symlink(root.UTF8String, path.UTF8String);
            break;
        default:
            [@"x" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        }
    }
}

static NSString *walk(id enumerator, BOOL port, NSString *root, uint64_t skips)
{
    NSMutableString *out = [NSMutableString string];
    SEL nextSelector = @selector(nextObject), levelSelector = @selector(level);
    // The port's enumerator answers the PLAIN name, and the measurement says why. prefix_selectors.py leaves a
    // member of a class the port itself defines alone - the class is renamed, so nothing of it can reach the
    // host's - and that is what the built objects show:
    //
    //   $ nm foundation14directoryenumerator/NSDirectoryEnumerator+PostOrder13.m.o | grep -i postorder
    //   -[CharonHostCharonPostOrderEnumerator isEnumeratingDirectoryPostOrder]      <- the enumerator's own
    //   -[NSDirectoryEnumerator(CharonPostOrder) charonHostIsEnumeratingDirectoryPostOrder]  <- the category
    //
    // So the prefixed name is the CATEGORY's, which answers NO for every receiver, and asking it of the port's
    // enumerator reported no entry as post-order while the host's answered YES - "174 of 300 trees differ" with
    // identical order and identical levels on both sides. The enumerator is a port-defined class, so its own
    // member keeps its name; asking each side for the name its own class defines is what compares them.
    SEL postSelector = @selector(isEnumeratingDirectoryPostOrder);
    NSURL *url;
    NSUInteger index = 0;
    uint64_t saved = state;
    state = skips;
    while ((url = ((id (*)(id, SEL))objc_msgSend)(enumerator, nextSelector))) {
        BOOL post = ((BOOL (*)(id, SEL))objc_msgSend)(enumerator, postSelector);
        if (!port && index == 0)
            fprintf(stderr, "system enumerator %s responds %d\n", class_getName([enumerator class]), [enumerator respondsToSelector:postSelector]);
        NSUInteger level = ((NSUInteger (*)(id, SEL))objc_msgSend)(enumerator, levelSelector);
        NSString *path = url.path;
        NSRange found = [path rangeOfString:@"/root/"];
        [out appendFormat:@"%@%@ L%lu\n", found.location == NSNotFound ? @"." : [path substringFromIndex:NSMaxRange(found)], post ? @"^" : @"", (unsigned long)level];
        if (!post && next() % 5 == 0) {
            if (next() % 2)
                [enumerator skipDescendants];
            else
                [enumerator skipDescendents];
        }
        if (++index > 400)
            break;
    }
    state = saved;
    return out;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class wrapper = NSClassFromString(@"CharonHostCharonPostOrderEnumerator");
        CHECK(wrapper != Nil, "the port defines the enumerator");
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *base = [NSTemporaryDirectory() stringByAppendingPathComponent:@"f14-tree"];
        NSUInteger trees = argc > 1 ? (NSUInteger)atoi(argv[1]) : 300, wrong = 0;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < trees; index++) {
            [manager removeItemAtPath:base error:NULL];
            NSString *root = [base stringByAppendingPathComponent:@"root"];
            [manager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
            build_tree(root, 0);
            NSDirectoryEnumerationOptions options = (NSDirectoryEnumerationOptions)(next() % 8) & (NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles);
            uint64_t skips = next() * 977ull + index;
            NSURL *url = [NSURL fileURLWithPath:root];
            NSDirectoryEnumerator *system = [manager enumeratorAtURL:url includingPropertiesForKeys:nil options:options | (1UL << 3) errorHandler:nil];
            NSDirectoryEnumerator *inner = [manager enumeratorAtURL:url includingPropertiesForKeys:nil options:options errorHandler:nil];
            id port = ((id (*)(id, SEL, id))objc_msgSend)([wrapper alloc], @selector(initWithEnumerator:), inner);
            NSString *a = walk(port, YES, root, skips), *b = walk(system, NO, root, skips);
            if (![a isEqualToString:b]) {
                wrong++;
                if (samples.count < 3)
                    [samples addObject:[NSString stringWithFormat:@"options %lu\n port:\n%@ system:\n%@", (unsigned long)options, a, b]];
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        [manager removeItemAtPath:base error:NULL];
        charon_check(wrong == 0, "directories are visited again after their contents, as the system's enumerator visits them", [NSString stringWithFormat:@"%lu of %lu trees differ", (unsigned long)wrong, (unsigned long)trees]);
        NSDirectoryEnumerator *plain = [manager enumeratorAtPath:NSTemporaryDirectory()];
        CHECK(!((BOOL (*)(id, SEL))objc_msgSend)(plain, NSSelectorFromString(@"charonHostIsEnumeratingDirectoryPostOrder")), "an enumerator made without the option is never in post order");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
