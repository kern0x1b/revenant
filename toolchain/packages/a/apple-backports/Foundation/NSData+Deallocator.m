#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef void (^CharonDataDeallocator)(void *bytes, NSUInteger length);

@interface CharonDataDeallocation : NSObject
- (instancetype)initWithBytes:(void *)bytes length:(NSUInteger)length deallocator:(CharonDataDeallocator)deallocator;
@end

@implementation CharonDataDeallocation {
    void *_bytes;
    NSUInteger _length;
    CharonDataDeallocator _deallocator;
}

- (instancetype)initWithBytes:(void *)bytes length:(NSUInteger)length deallocator:(CharonDataDeallocator)deallocator
{
    if ((self = [super init])) {
        _bytes = bytes;
        _length = length;
        _deallocator = [deallocator copy];
    }
    return self;
}

- (void)dealloc
{
    _deallocator(_bytes, _length);
}

@end

static char CharonDeallocationKey;

@implementation NSData (CharonDeallocator)

- (instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length deallocator:(CharonDataDeallocator)deallocator
{
    if (!deallocator)
        return [self initWithBytesNoCopy:bytes length:length freeWhenDone:NO];
    if (!length || [self isKindOfClass:[NSMutableData class]]) {
        self = [self initWithBytes:bytes length:length];
        deallocator(bytes, length);
        return self;
    }
    self = [self initWithBytesNoCopy:bytes length:length freeWhenDone:NO];
    if (self)
        objc_setAssociatedObject(self, &CharonDeallocationKey, [[CharonDataDeallocation alloc] initWithBytes:bytes length:length deallocator:deallocator], OBJC_ASSOCIATION_RETAIN);
    else
        deallocator(bytes, length);
    return self;
}

@end
