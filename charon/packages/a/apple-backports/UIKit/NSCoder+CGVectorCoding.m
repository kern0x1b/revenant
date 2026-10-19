#import <UIKit/UIKit.h>

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
