#import "RevenantBrailleMap.h"

#import "../RevenantSayOnce.h"

static NSString *RevenantBrailleMapKey(CGPoint point)
{
    return [NSString stringWithFormat:@"%g,%g", point.x, point.y];
}

@protocol RevenantBrailleMapPinStore <NSObject>

- (NSNumber *)objectForKey:(NSString *)key;
- (void)setObject:(NSNumber *)value forKey:(NSString *)key;

@end

@implementation AXBrailleMap {
    id<RevenantBrailleMapPinStore> _pins;
    CGSize _size;
}

+ (instancetype)revenant_mapWithDimensions:(CGSize)dimensions
{
    AXBrailleMap *map = [[AXBrailleMap alloc] init];
    map->_size = dimensions;
    return map;
}

- (void)setHeight:(float)height atPoint:(CGPoint)point
{
    if (!_pins) {
        _pins = (id<RevenantBrailleMapPinStore>)[NSMutableDictionary dictionary];
    }
    [_pins setObject:@(height) forKey:RevenantBrailleMapKey(point)];
}

- (float)heightAtPoint:(CGPoint)point
{
    return [_pins objectForKey:RevenantBrailleMapKey(point)].floatValue;
}

- (CGSize)dimensions
{
    return _size;
}

- (void)presentImage:(CGImageRef)image
{
    (void)image;
    revenant_say_once_for(@"AXBrailleMap.presentImage",
                        @"AXBrailleMap -presentImage: this release has no braille display to show an image "
                        @"on, so the image is not presented");
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    AXBrailleMap *copy = [[AXBrailleMap allocWithZone:zone] init];
    copy->_size = _size;
    copy->_pins = _pins ? (id<RevenantBrailleMapPinStore>)[NSDictionary dictionaryWithDictionary:(NSDictionary *)_pins] : nil;
    return copy;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_size.width forKey:@"sizeWidth"];
    [coder encodeDouble:_size.height forKey:@"sizeHeight"];
    [coder encodeObject:_pins forKey:@"pins"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _size = CGSizeMake([coder decodeDoubleForKey:@"sizeWidth"],
                           [coder decodeDoubleForKey:@"sizeHeight"]);
        _pins = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"pins"];
    }
    return self;
}

@end
