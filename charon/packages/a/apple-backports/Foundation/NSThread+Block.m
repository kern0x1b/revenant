#import "CharonMethodProem.h"
#include <Block.h>
#include <pthread.h>

static pthread_key_t charon_thread_block_key;

static void *charon_thread_main(void *argument)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pthread_key_create(&charon_thread_block_key, (void (*)(void *))_Block_release);
    });
    pthread_setspecific(charon_thread_block_key, argument);
    @autoreleasepool {
        ((__bridge void (^)(void))argument)();
    }
    return NULL;
}

@implementation NSThread (CharonBlocks)

- (instancetype)initWithBlock:(void (^)(void))block
{
    if (!block)
        [NSException raise:NSInvalidArgumentException format:@"%@: block targets for threads cannot be nil", charon_method_proem(self, _cmd)];
    return [self initWithTarget:[block copy] selector:@selector(invoke) object:nil];
}

+ (void)detachNewThreadWithBlock:(void (^)(void))block
{
    if (!block)
        [NSException raise:NSInvalidArgumentException format:@"%@: block targets for threads cannot be nil", charon_method_proem(self, _cmd)];
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setscope(&attributes, PTHREAD_SCOPE_SYSTEM);
    pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
    void *argument = (__bridge_retained void *)[block copy];
    pthread_t thread;
    if (pthread_create(&thread, &attributes, charon_thread_main, argument) != 0)
        _Block_release(argument);
    pthread_attr_destroy(&attributes);
}

@end
