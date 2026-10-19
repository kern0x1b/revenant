#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdatomic.h>

#ifdef CHARON_WITHOUT_NATIVE
void *charon_test_dlsym(void *handle, const char *name) { return NULL; }
#endif

static atomic_int deallocated;
@interface Tracked : NSObject
@end
@implementation Tracked
- (void)dealloc { atomic_fetch_add(&deallocated, 1); }
@end

@interface Holder : NSObject
@property (nonatomic, weak) id target;
@end
@implementation Holder
@end

static void *stress(void *argument)
{
    int *failures = argument;
    for (int i = 0; i < 20000; i++) {
        @autoreleasepool {
            Holder *holder = [Holder new];
            __weak Tracked *watcher;
            @autoreleasepool {
                Tracked *tracked = [Tracked new];
                holder.target = tracked;
                watcher = tracked;
                if (watcher != tracked || holder.target != tracked) (*failures)++;
            }
            if (watcher != nil || holder.target != nil) (*failures)++;
        }
    }
    return NULL;
}

int main(void)
{
    int failures = 0;
    @autoreleasepool {
        __weak id first;
        __weak id second;
        @autoreleasepool {
            id object = [Tracked new];
            first = object;
            second = first;
            if (!first || second != object) { printf("weak reference not stored\n"); failures++; }
        }
        if (first || second) { printf("weak reference not cleared on dealloc\n"); failures++; }
    }
    pthread_t threads[4];
    int counts[4] = {0};
    for (int i = 0; i < 4; i++) pthread_create(&threads[i], NULL, stress, &counts[i]);
    for (int i = 0; i < 4; i++) { pthread_join(threads[i], NULL); failures += counts[i]; }
    if (deallocated != 80001) { printf("deallocated %d objects, expected 80001\n", deallocated); failures++; }
    printf("failures %d\n", failures);
    return failures != 0;
}
