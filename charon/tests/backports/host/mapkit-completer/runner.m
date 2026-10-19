#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface CharonRecorder : NSObject
@property (nonatomic, strong) NSMutableArray *calls;
@end

@implementation CharonRecorder
@synthesize calls = _calls;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _calls = [NSMutableArray array];
    }
    return self;
}

- (void)completerDidUpdateResults:(id)completer
{
    NSUInteger count = [completer respondsToSelector:@selector(results)]
        ? [[completer valueForKey:@"results"] count] : 0;
    NSString *who = (completer == nil) ? @"nil" : NSStringFromClass([completer class]);
    [_calls addObject:[NSString stringWithFormat:@"update results=%lu completer=%@",
                        (unsigned long)count, who]];
    printf("  call 1: completerDidUpdateResults: results=%lu completer=%s\n",
           (unsigned long)count, [who UTF8String]);
    fflush(stdout);
}

- (void)completer:(id)completer didFailWithError:(NSError *)error
{
    [_calls addObject:[NSString stringWithFormat:@"fail error=%@",
                        error ? [NSString stringWithFormat:@"%@ %ld", [error domain], (long)[error code]] : @"nil"]];
    printf("  call 2: completer:didFailWithError: error=%s\n",
           [[NSString stringWithFormat:@"%@ %ld", [error domain], (long)[error code]] UTF8String]);
    fflush(stdout);
}

@end

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: runner (port|host) QUERY\n");
        return 2;
    }
    @autoreleasepool {
        const char *which = argv[1];
        NSString *query = [NSString stringWithUTF8String:argv[2]];

        Class completerClass = Nil;
        if (strcmp(which, "port") == 0) {
            const char *dylib = getenv("CHARON_PORT_DYLIB");
            if (dylib) {
                dlopen(dylib, RTLD_LOCAL);
            }
            completerClass = objc_getClass("charonHost_MKLocalSearchCompleter");
        } else {
            completerClass = objc_getClass("MKLocalSearchCompleter");
        }
        if (completerClass == Nil) {
            printf("  no %s completer class\n", which);
            return 3;
        }
        printf("# %s completer in %s\n", which, class_getImageName(completerClass));
        fflush(stdout);

        if (getenv("CHARON_MUTANT") != NULL) {
            Class mutant = objc_allocateClassPair(completerClass, "CharonMutantCompleter", 0);
            IMP wrong = imp_implementationWithBlock(^(id self_, SEL _cmd) {
                id delegate = [self_ valueForKey:@"delegate"];
                SEL updated = NSSelectorFromString(@"completerDidUpdateResults:");
                if ([delegate respondsToSelector:updated]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(delegate, updated, nil);
                }
            });
            class_addMethod(mutant, NSSelectorFromString(@"charon_delegateDidUpdate"), wrong, "v@:");
            objc_registerClassPair(mutant);
            completerClass = mutant;
            printf("#   (a subclass of the port's own, passing the WRONG argument)\n");
        }
        CharonRecorder *recorder = [[CharonRecorder alloc] init];
        id completer = [[completerClass alloc] init];
        if (![completer respondsToSelector:@selector(setDelegate:)]) {
            printf("  it has no delegate\n");
            return 3;
        }
        [completer setValue:recorder forKey:@"delegate"];
        if ([completer respondsToSelector:@selector(setQueryFragment:)]) {
            [completer setValue:query forKey:@"queryFragment"];
        }
        SEL start = NSSelectorFromString(@"start");
        printf("  starting (fragment set; -start %s)\n",
               [completer respondsToSelector:start] ? "present" : "absent, as on Apple's own");
        fflush(stdout);
        if ([completer respondsToSelector:start]) {
            ((void (*)(id, SEL))objc_msgSend)(completer, start);
        }
        for (int spin = 0; spin < 60; spin++) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
            if (recorder.calls.count > 0) {
                break;
            }
        }
        printf("# %d call(s)\n", (int)recorder.calls.count);
        for (NSString *call in recorder.calls) {
            printf("  transcript %s\n", [call UTF8String]);
        }
        fflush(stdout);
    }
    return 0;
}
