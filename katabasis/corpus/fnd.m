#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@interface Shape : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSInteger sides;
@property (nonatomic) CGFloat length;
- (instancetype)initWithName:(NSString *)name sides:(NSInteger)sides length:(CGFloat)length;
- (CGFloat)perimeter;
- (CGRect)boundsAtOrigin:(CGPoint)origin;
@end

@implementation Shape
- (instancetype)initWithName:(NSString *)name sides:(NSInteger)sides length:(CGFloat)length
{
    if ((self = [super init])) {
        _name = [name copy];
        _sides = sides;
        _length = length;
    }
    return self;
}
- (CGFloat)perimeter
{
    return _sides * _length;
}
- (CGRect)boundsAtOrigin:(CGPoint)origin
{
    return CGRectMake(origin.x, origin.y, _length, _length * 0.5);
}
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %ld×%.1f>", _name, (long)_sides, _length];
}
@end

@interface Shape (Area)
- (double)scaledBy:(double)factor;
@end

@implementation Shape (Area)
- (double)scaledBy:(double)factor
{
    return [self perimeter] * factor;
}
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableArray<Shape *> *shapes = [NSMutableArray array];
        NSArray *names = @[ @"triangle", @"square", @"pentagon", @"hexagon" ];
        [names enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, BOOL *stop) {
            [shapes addObject:[[Shape alloc] initWithName:name sides:(NSInteger)index + 3 length:1.5 + index]];
        }];
        [shapes sortUsingComparator:^NSComparisonResult(Shape *a, Shape *b) {
            return [@([b perimeter]) compare:@([a perimeter])];
        }];
        NSMutableDictionary *table = [NSMutableDictionary dictionary];
        CGFloat total = 0;
        for (Shape *shape in shapes) {
            table[shape.name] = @(shape.sides);
            total += [shape scaledBy:2.0];
        }
        CGRect r = [shapes.firstObject boundsAtOrigin:CGPointMake(10, 20)];
        __block NSInteger count = 0;
        dispatch_sync(dispatch_get_global_queue(0, 0), ^{
            count = (NSInteger)table.count;
        });
        NSString *joined = [[table.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
        NSLog(@"first=%@ total=%.2f height=%.1f count=%ld keys=%@", shapes.firstObject, total, CGRectGetHeight(r), (long)count, joined);
        printf("first=%s total=%.2f rect=%.1f,%.1f,%.1f,%.1f count=%ld keys=%s\n", shapes.firstObject.description.UTF8String, total, r.origin.x, r.origin.y, r.size.width, r.size.height, (long)count, joined.UTF8String);
    }
    return 0;
}
