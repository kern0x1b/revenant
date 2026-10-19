#import <Foundation/Foundation.h>

@implementation NSCoder (CharonDecodeValueSize)

- (void)decodeValueOfObjCType:(const char *)type at:(void *)data size:(NSUInteger)size
{
    NSUInteger expected = 0;
    NSGetSizeAndAlignment(type, &expected, NULL);
    if (size != expected)
        [NSException raise:NSInvalidArgumentException format:@"Cannot get decode with size %lu. The type encoded as %s is expected to be %lu bytes",
                                                             (unsigned long)size, type, (unsigned long)expected];
    [self decodeValueOfObjCType:type at:data];
}

@end
