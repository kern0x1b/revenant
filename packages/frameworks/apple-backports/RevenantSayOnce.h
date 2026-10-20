#import <Foundation/Foundation.h>

static inline void revenant_say_once_for(NSString *key, NSString *text)
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
