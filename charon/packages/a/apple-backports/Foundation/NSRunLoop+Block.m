#import "CharonMethodProem.h"

@interface NSRunLoop (CharonPrivate)
- (CFRunLoopRef)getCFRunLoop;
@end

@implementation NSRunLoop (CharonBlocks)

- (void)performBlock:(void (^)(void))block
{
    [self performInModes:@[(__bridge NSString *)kCFRunLoopDefaultMode] block:block];
}

- (void)performInModes:(NSArray *)modes block:(void (^)(void))block
{
    if (!block)
        [NSException raise:NSInvalidArgumentException format:@"%@: block targets for run loops cannot be nil", charon_method_proem(self, _cmd)];
    if (!modes.count)
        [NSException raise:NSInvalidArgumentException
                    format:@"%@: modes for block performers on run loops cannot be nil or contain no elements", charon_method_proem(self, _cmd)];
    CFRunLoopRef loop = [self getCFRunLoop];
    CFRunLoopPerformBlock(loop, (__bridge CFArrayRef)modes, block);
    CFRunLoopWakeUp(loop);
}

@end
