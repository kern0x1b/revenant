#import "RevenantGC.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation GCKeyboard {
    GCKeyboardInput *_keyboardInput;
    dispatch_queue_t _handlerQueue;
    NSString *_vendorName;
    NSString *_productCategory;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _keyboardInput = [[GCKeyboardInput alloc] init];
        [_keyboardInput revenant_setDevice:self];
        _handlerQueue = dispatch_get_main_queue();
        _vendorName = @"Keyboard";
        _productCategory = @"Keyboard";
    }
    return self;
}

+ (GCKeyboard *)coalescedKeyboard
{
    return nil;
}

- (GCKeyboardInput *)keyboardInput
{
    return _keyboardInput;
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
    return _vendorName;
}

- (NSString *)productCategory
{
    return _productCategory;
}

- (GCPhysicalInputProfile *)physicalInputProfile
{
    return _keyboardInput;
}

@end
