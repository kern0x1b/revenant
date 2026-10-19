// The completer's delegate, driven twice: once against the HOST's own MKLocalSearchCompleter and once
// against the PORT's, both with the same query and the same delegate, so the two transcripts -- the
// calls, their ORDER and their VALUES -- can be compared name for name.
//
// The port's completer is built here as a dylib with its class RENAMED, because the class name is
// Apple's and two classes of one name cannot both be live: the rename is the only way both can answer
// the same query in one probe. Apple's own is used through the unrenamed name.
//
// The MUTANT is the same binary built with -DCHARON_DELEGATE_MUTANT, where the port's completer hands
// the delegate the WRONG ARGUMENT. Every other case is identical, so a run that does not go red means
// the comparison cannot see a wrong argument, and the probe says so rather than passing.
#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdio.h>

// A delegate that records every call in order, with the values it was given. The record is printed at
// the end, so the transcript is the ORDER and the VALUES and nothing else.
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
    // The value that matters: how many results the completer had at the moment it said so, AND
    // whether it is a completer at all. The count alone cannot tell a wrong argument from a right
    // one: the port answers 0 results for a query that finds nothing, so a mutant that passes nil
    // records "results=0" too and the two transcripts are identical -- which is what the probe said
    // when it ran. The argument's IDENTITY is the thing under test, so it is recorded: the port
    // passes ITSELF, and anything else is a wrong argument whatever its count.
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

        // THE MUTANT, when the third argument says so: a SUBCLASS, allocated at run time, whose
        // -charon_delegateDidUpdate hands the delegate the WRONG ARGUMENT -- nil, where the real one
        // hands over the completer. A category would lose to the class's own method, so it has to be
        // a subclass, and a subclass built here means the PORT's source is identical in both runs and
        // the only difference between them is the argument.
        if (getenv("CHARON_MUTANT") != NULL) {
            Class mutant = objc_allocateClassPair(completerClass, "CharonMutantCompleter", 0);
            // THE MUTANT SENDS THE MESSAGE TO THE REAL DELEGATE, AND PASSES THE WRONG ARGUMENT.
            // It used to declare `id delegate = nil` and send to that, so the runner's own recorder
            // was never asked and the transcript recorded "# 0 call(s)" -- a mutant that silences
            // the thing it is meant to exercise, which reads as a probe that cannot see anything at
            // all. A mutant has to go wrong in the ONE THING UNDER TEST and do everything else
            // normally, so the delegate is the one the runner set and only the argument is wrong.
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
        // A query that finds nothing, so the FAILURE path runs and the delegate's second message is
        // the one exercised. The success path needs a place that exists, which is the device's.
        // Setting queryFragment IS the trigger on Apple's own side -- the 16.4 header declares no
        // -start on the completer at all -- and this port's own also schedules on it. The port
        // additionally answers -start, so the runner calls it when it is there, and either way the
        // search runs from the same set of values.
        SEL start = NSSelectorFromString(@"start");
        printf("  starting (fragment set; -start %s)\n",
               [completer respondsToSelector:start] ? "present" : "absent, as on Apple's own");
        fflush(stdout);
        if ([completer respondsToSelector:start]) {
            ((void (*)(id, SEL))objc_msgSend)(completer, start);
        }
        // give the search a moment to come back with its error
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
