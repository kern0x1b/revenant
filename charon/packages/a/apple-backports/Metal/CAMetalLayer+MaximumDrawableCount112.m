#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>

static const void *charon_count_key = &charon_count_key;

@implementation CAMetalLayer (CharonMaximumDrawableCount)

- (NSUInteger)maximumDrawableCount
{
    NSNumber *value = objc_getAssociatedObject(self, charon_count_key);
    return value ? value.unsignedIntegerValue : 3;
}

- (void)setMaximumDrawableCount:(NSUInteger)count
{
    if (count < 2 || count > 3)
        [NSException raise:@"CAMetalLayerInvalidMaximumDrawableCount" format:@"failed trying to set maximumDrawableCount to %lu outside of the valid range of [2, 3]", (unsigned long)count];
    objc_setAssociatedObject(self, charon_count_key, @(count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
