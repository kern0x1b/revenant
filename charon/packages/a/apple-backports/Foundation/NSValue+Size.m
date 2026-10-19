#import <Foundation/Foundation.h>

@implementation NSValue (CharonSize)

- (void)getValue:(void *)value size:(NSUInteger)size
{
    NSUInteger expected = 0;
    NSGetSizeAndAlignment(self.objCType, &expected, NULL);
    if (size != expected)
        [NSException raise:NSInvalidArgumentException format:@"Cannot get value with size %lu. The type encoded as %s is expected to be %lu bytes",
                                                             (unsigned long)size, self.objCType, (unsigned long)expected];
    [self getValue:value];
}

@end
