#import <Foundation/Foundation.h>

@implementation NSData (CharonByteRanges)

- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(const void *bytes, NSRange byteRange, BOOL *stop))block
{
    BOOL stop = NO;
    block(self.bytes, NSMakeRange(0, self.length), &stop);
}

@end
