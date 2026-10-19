#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
#include <objc/runtime.h>

#ifdef CHARON_WITHOUT_NATIVE
void *charon_test_dlsym(void *handle, const char *name) { return NULL; }
#endif
extern void *_Block_copy(const void *);
extern void _Block_release(const void *);

static int deallocated;
@interface Tracked : NSObject
@end
@implementation Tracked
- (void)dealloc { deallocated++; [super dealloc]; }
@end

typedef int (^Counter)(void);

static Counter make_counter(int start)
{
    __block int value = start;
    Tracked *tracked = [[Tracked alloc] init];
    Counter stack = ^{ (void)tracked; return ++value; };
    Counter heap = _Block_copy(stack);
    [tracked release];
    return heap;
}

int main(void)
{
    int failures = 0;
    @autoreleasepool {
        Counter counter = make_counter(10);
        if (counter() != 11 || counter() != 12) { printf("byref value not shared\n"); failures++; }
        Counter second = _Block_copy(counter);
        if (second != counter) { printf("copy of heap block must retain, not copy\n"); failures++; }
        if (second() != 13) { printf("retained copy lost state\n"); failures++; }
        _Block_release(second);
        if (deallocated != 0) { printf("captured object released too early\n"); failures++; }
        if (strcmp(object_getClassName(counter), MALLOC_BLOCK_CLASS) != 0) { printf("heap block class is %s\n", object_getClassName(counter)); failures++; }
        NSMutableArray *array = [NSMutableArray array];
        [array addObject:(id)counter];
        [array removeAllObjects];
        _Block_release(counter);
        if (deallocated != 1) { printf("captured object not released with the last block reference (%d)\n", deallocated); failures++; }
        void (^global)(void) = ^{};
        if (_Block_copy(global) != (void *)global) { printf("global block copied\n"); failures++; }
        for (int i = 0; i < 100000; i++) { Counter c = make_counter(i); if (c() != i + 1) { failures++; break; } _Block_release(c); }
        if (deallocated != 100001) { printf("leak or double free in loop: %d\n", deallocated); failures++; }
    }
    printf("failures %d\n", failures);
    return failures != 0;
}
