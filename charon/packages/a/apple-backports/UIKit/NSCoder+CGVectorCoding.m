#import <UIKit/UIKit.h>

/* UIKit's own geometry coding gained the vector after iOS 6, and the SDK header
   carries no availability for it, so nothing warns at compile time: a spring's
   archive simply raises an unrecognised selector on a release that has not got it.
   UIKit encodes the vector as a string through -encodeObject:forKey: and reads it
   back with -decodeObjectOfClass:[NSString class] forKey:, in the shape
   NSStringFromCGPoint writes, so the archive crosses to a release that has it. */

@implementation NSCoder (CharonVectorCoding)

- (void)encodeCGVector:(CGVector)vector forKey:(NSString *)key
{
    [self encodeObject:NSStringFromCGPoint(CGPointMake(vector.dx, vector.dy)) forKey:key];
}

- (CGVector)decodeCGVectorForKey:(NSString *)key
{
    NSString *text = [self respondsToSelector:@selector(decodeObjectOfClass:forKey:)]
                   ? [self decodeObjectOfClass:[NSString class] forKey:key]
                   : [self decodeObjectForKey:key];
    CGPoint point = CGPointFromString(text ? text : @"");
    return CGVectorMake(point.x, point.y);
}

@end
