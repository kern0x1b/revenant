#import <Foundation/Foundation.h>

@interface CharonTimerBlockTarget : NSObject
- (instancetype)initWithBlock:(void (^)(NSTimer *timer))block;
- (void)fire:(NSTimer *)timer;
@end

@implementation CharonTimerBlockTarget {
@private
    void (^_block)(NSTimer *timer);
}

- (instancetype)initWithBlock:(void (^)(NSTimer *timer))block
{
    if ((self = [super init]))
        _block = [block copy];
    return self;
}

- (void)fire:(NSTimer *)timer
{
    _block(timer);
}

@end

@implementation NSTimer (CharonBlocks)

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block
{
    return [[self allocWithZone:NULL] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]
                                              interval:interval
                                               repeats:repeats
                                                 block:block];
}

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block
{
    NSTimer *timer = [[self allocWithZone:NULL] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]
                                                        interval:interval
                                                         repeats:repeats
                                                           block:block];
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), (__bridge CFRunLoopTimerRef)timer, kCFRunLoopDefaultMode);
    return timer;
}

- (instancetype)initWithFireDate:(NSDate *)date interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block
{
    CharonTimerBlockTarget *target = [[CharonTimerBlockTarget alloc] initWithBlock:block];
    return [self initWithFireDate:date interval:interval target:target selector:@selector(fire:) userInfo:nil repeats:repeats];
}

@end
