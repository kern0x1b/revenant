#import "CharonSCN.h"

@implementation SCNPlane

- (instancetype)init
{
    if ((self = [super init])) {
        _width = 1;
        _height = 1;
        _widthSegmentCount = 1;
        _heightSegmentCount = 1;
        _cornerRadius = 0;
        _cornerSegmentCount = 10;
    }
    return self;
}

+ (instancetype)planeWithWidth:(CGFloat)width height:(CGFloat)height
{
    SCNPlane *plane = [[self alloc] init];
    plane->_width = width;
    plane->_height = height;
    return plane;
}

@synthesize width = _width;
@synthesize height = _height;
@synthesize widthSegmentCount = _widthSegmentCount;
@synthesize heightSegmentCount = _heightSegmentCount;
@synthesize cornerRadius = _cornerRadius;
@synthesize cornerSegmentCount = _cornerSegmentCount;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _width = [coder containsValueForKey:@"width"] ? [coder decodeDoubleForKey:@"width"] : 1;
        _height = [coder containsValueForKey:@"height"] ? [coder decodeDoubleForKey:@"height"] : 1;
        _widthSegmentCount = [coder containsValueForKey:@"widthSegmentCount"] ? [coder decodeIntegerForKey:@"widthSegmentCount"] : 1;
        _heightSegmentCount = [coder containsValueForKey:@"heightSegmentCount"] ? [coder decodeIntegerForKey:@"heightSegmentCount"] : 1;
        _cornerRadius = [coder decodeDoubleForKey:@"cornerRadius"];
        _cornerSegmentCount = [coder containsValueForKey:@"cornerSegmentCount"] ? [coder decodeIntegerForKey:@"cornerSegmentCount"] : 10;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_width forKey:@"width"];
    [coder encodeDouble:_height forKey:@"height"];
    [coder encodeInteger:_widthSegmentCount forKey:@"widthSegmentCount"];
    [coder encodeInteger:_heightSegmentCount forKey:@"heightSegmentCount"];
    [coder encodeDouble:_cornerRadius forKey:@"cornerRadius"];
    [coder encodeInteger:_cornerSegmentCount forKey:@"cornerSegmentCount"];
}

@end
