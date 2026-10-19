#import <Foundation/Foundation.h>

// Says a thing the port does not do, once per key, so that an application that reaches it leaves a line in the log
// instead of silently getting less than it asked for. The set of keys said is one per file that includes this: a
// static inside a static inline function is the including file's own.
static inline void charon_say_once_for(NSString *key, NSString *text)
{
    static NSMutableSet *said;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        said = [[NSMutableSet alloc] init];
    });
    @synchronized (said) {
        if ([said containsObject:key])
            return;
        [said addObject:key];
    }
    NSLog(@"%@", text);
}
