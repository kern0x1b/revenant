// ARPlaneExtent16.m - how large a detected plane is, and how far it is turned about the vertical.
//
// The 16.0 API of ARPlaneExtent. Three readonly floats and the archive the class declares, in one
// object because an object carries the API of one release.
//
// Every number and every string here was read out of ARKitCore in the arm64e shared cache of iOS
// 16.0, not chosen. The class's own method list is eleven entries; -encodeWithCoder: at 0x1af14f2c0
// encodes three floats under three literal keys, in the order origin, width, height, and each
// property is identified by the address of its own accessor, so the key each float is written under
// and the property it belongs to were read separately and agree. -init at 0x1af14f268 writes one
// 64-bit constant across the rotation and the width and a second value into the height. The keys and
// the addresses are in `facts/ARKit/PlaneExtent.md`, which also says why the host cannot be the oracle
// for this class (this Mac's ARKit has no ARPlaneExtent) and what stands in for it.
//
// The three setters are in the release's own method list at 0x1af14f4d4, 0x1af14f4e4 and 0x1af14f4f4
// and the release's public header does not declare them, so a caller cannot reach them and this
// package does not claim them as API: they are how the object is filled, from -initWithCoder: here and
// from ARKitCore's own C++ above it in the release.

#import <Foundation/Foundation.h>
#import <float.h>
#import <math.h>

#import "CharonARKitPlaneExtent.h"

@implementation ARPlaneExtent
{
    float _rotationOnYAxis;
    float _width;
    float _height;
}

    @synthesize rotationOnYAxis = _rotationOnYAxis;
    @synthesize width = _width;
    @synthesize height = _height;

/// An extent nobody has measured: no plane is this big, and Apple's own default says so.
- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    // The release writes one double, -1.0, across the rotation and the width and then the same -1.0
    // into the height: -1.0 has a zero low word, which is the rotation, and 0xBF800000 as its high
    // word, which is the width. The rotation is the low word because the store is a 64-bit store at
    // the rotation's own offset, and little-endian puts the low word at the lower address.
    _rotationOnYAxis = 0.0f;
    _width = -1.0f;
    _height = -1.0f;
    return self;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeFloat:_rotationOnYAxis forKey:@"origin"];
    [coder encodeFloat:_width forKey:@"width"];
    [coder encodeFloat:_height forKey:@"height"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _rotationOnYAxis = [coder decodeFloatForKey:@"origin"];
    _width = [coder decodeFloatForKey:@"width"];
    _height = [coder decodeFloatForKey:@"height"];
    return self;
}

- (void)setRotationOnYAxis:(float)rotationOnYAxis { _rotationOnYAxis = rotationOnYAxis; }
- (void)setWidth:(float)width { _width = width; }
- (void)setHeight:(float)height { _height = height; }

/// Whether that is the same extent: the same class first, then each of the three floats equal to
/// within the release's own tolerance.
///
/// The tolerance is not this file's choice. -isEqual: at 0x1af14f3bc compares with `fabd` (the
/// difference, made positive) against the float `mov w8, #0x34000000` loads for each of the three in
/// turn, and `0x34000000` is FLT_EPSILON; a difference below it passes. Without that the port would
/// answer NO for two extents the release answers YES for, and answering NO for equal values is as much
/// an invented answer as the other kind.
- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[ARPlaneExtent class]])
        return NO;
    ARPlaneExtent *other = object;
    return fabsf(_rotationOnYAxis - other->_rotationOnYAxis) < FLT_EPSILON &&
           fabsf(_width - other->_width) < FLT_EPSILON &&
           fabsf(_height - other->_height) < FLT_EPSILON;
}

- (id)copyWithZone:(NSZone *)zone
{
    ARPlaneExtent *copy = [[self class] allocWithZone:zone];
    copy->_rotationOnYAxis = _rotationOnYAxis;
    copy->_width = _width;
    copy->_height = _height;
    return copy;
}

@end