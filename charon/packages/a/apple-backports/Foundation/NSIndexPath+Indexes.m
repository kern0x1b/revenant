#import <Foundation/Foundation.h>

@implementation NSIndexPath (CharonIndexes)

- (void)getIndexes:(NSUInteger *)indexes range:(NSRange)positionRange
{
    NSUInteger length = self.length;
    if (positionRange.location > length || positionRange.length > length - positionRange.location)
        [NSException raise:NSRangeException format:@"*** -[%@ %@]: range %@ beyond bounds (%lu)", [self class], NSStringFromSelector(_cmd), NSStringFromRange(positionRange), (unsigned long)length];
    for (NSUInteger position = 0; position < positionRange.length; position++)
        indexes[position] = [self indexAtPosition:positionRange.location + position];
}

@end
