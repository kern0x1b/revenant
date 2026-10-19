#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation GCMouse
{
    GCMouseInput *_mouseInput;
    dispatch_queue_t _handlerQueue;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _mouseInput = [[GCMouseInput alloc] init];
        [_mouseInput charon_setDevice:self];
        _handlerQueue = dispatch_get_main_queue();
    }
    return self;
}

+ (NSArray<GCMouse *> *)mice
{
    return @[];
}

+ (GCMouse *)current
{
    return nil;
}

- (GCMouseInput *)mouseInput
{
    return _mouseInput;
}

- (dispatch_queue_t)handlerQueue
{
    return _handlerQueue;
}

- (void)setHandlerQueue:(dispatch_queue_t)handlerQueue
{
    _handlerQueue = handlerQueue;
}

- (NSString *)vendorName
{
    return @"Mouse";
}

- (NSString *)productCategory
{
    return GCProductCategoryMouse;
}

@end
