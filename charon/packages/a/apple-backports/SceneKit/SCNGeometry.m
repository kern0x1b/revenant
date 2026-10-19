#import "CharonSCN.h"

static NSArray<SCNGeometrySourceSemantic> *CharonSCNKnownSemantics(void)
{
    static NSArray<SCNGeometrySourceSemantic> *semantics;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        semantics = @[SCNGeometrySourceSemanticVertex, SCNGeometrySourceSemanticNormal,
                      SCNGeometrySourceSemanticColor, SCNGeometrySourceSemanticTexcoord,
                      SCNGeometrySourceSemanticTangent];
    });
    return semantics;
}

@implementation SCNGeometry
{
    SCNVector3 _boundingBoxMin;
    SCNVector3 _boundingBoxMax;
    BOOL _hasExplicitBoundingBox;
    NSMutableDictionary<SCNGeometrySourceSemantic, NSArray<SCNGeometrySource *> *> *_sourcesBySemantic;
    NSArray<SCNGeometryElement *> *_elements;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _materials = @[];
        _sourcesBySemantic = [NSMutableDictionary dictionary];
        _elements = @[];
    }
    return self;
}

+ (instancetype)geometry
{
    return [[self alloc] init];
}

+ (instancetype)geometryWithSources:(NSArray<SCNGeometrySource *> *)sources elements:(NSArray<SCNGeometryElement *> *)elements
{
    SCNGeometry *geometry = [[self alloc] init];
    for (SCNGeometrySource *source in sources) {
        NSArray<SCNGeometrySource *> *existing = geometry->_sourcesBySemantic[source.semantic];
        geometry->_sourcesBySemantic[source.semantic] = existing ? [existing arrayByAddingObject:source] : @[source];
    }
    geometry->_elements = [elements copy] ?: @[];
    return geometry;
}

@synthesize name = _name;
@synthesize materials = _materials;
@synthesize subdivisionLevel = _subdivisionLevel;

- (SCNMaterial *)firstMaterial
{
    return _materials.firstObject;
}

- (void)setFirstMaterial:(SCNMaterial *)firstMaterial
{
    _materials = firstMaterial ? @[firstMaterial] : @[];
}

- (NSArray<SCNGeometrySource *> *)geometrySourcesForSemantic:(SCNGeometrySourceSemantic)semantic
{
    return _sourcesBySemantic[semantic] ?: @[];
}

- (NSArray<SCNGeometrySource *> *)geometrySources
{
    NSMutableArray<SCNGeometrySource *> *all = [NSMutableArray array];
    for (SCNGeometrySourceSemantic semantic in CharonSCNKnownSemantics()) {
        [all addObjectsFromArray:_sourcesBySemantic[semantic]];
    }
    return all;
}

- (NSArray<SCNGeometryElement *> *)geometryElements
{
    return _elements;
}

#pragma mark - SCNBoundingVolume

- (BOOL)getBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max
{
    if (!_hasExplicitBoundingBox) {
        return NO;
    }
    if (min) {
        *min = _boundingBoxMin;
    }
    if (max) {
        *max = _boundingBoxMax;
    }
    return YES;
}

- (void)setBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max
{
    if (min == NULL || max == NULL) {
        _hasExplicitBoundingBox = NO;
        return;
    }
    _boundingBoxMin = *min;
    _boundingBoxMax = *max;
    _hasExplicitBoundingBox = YES;
}

- (BOOL)getBoundingSphereCenter:(SCNVector3 *)center radius:(CGFloat *)radius
{
    if (!_hasExplicitBoundingBox) {
        return NO;
    }
    SCNVector3 mid = SCNVector3Make((_boundingBoxMin.x + _boundingBoxMax.x) / 2,
                                     (_boundingBoxMin.y + _boundingBoxMax.y) / 2,
                                     (_boundingBoxMin.z + _boundingBoxMax.z) / 2);
    float dx = _boundingBoxMax.x - mid.x, dy = _boundingBoxMax.y - mid.y, dz = _boundingBoxMax.z - mid.z;
    if (center) {
        *center = mid;
    }
    if (radius) {
        *radius = sqrt(dx * dx + dy * dy + dz * dz);
    }
    return YES;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _materials = [CharonSCNCoding decodeArrayOfClass:[SCNMaterial class] coder:coder forKey:@"materials"];
        for (SCNGeometrySourceSemantic semantic in CharonSCNKnownSemantics()) {
            NSArray<SCNGeometrySource *> *sources = [CharonSCNCoding decodeArrayOfClass:[SCNGeometrySource class] coder:coder forKey:semantic];
            if (sources.count) {
                _sourcesBySemantic[semantic] = sources;
            }
        }
        _elements = [CharonSCNCoding decodeArrayOfClass:[SCNGeometryElement class] coder:coder forKey:@"elements"];
        _subdivisionLevel = (NSUInteger)[coder decodeIntegerForKey:@"subdivisionLevel"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_materials forKey:@"materials"];
    for (SCNGeometrySourceSemantic semantic in CharonSCNKnownSemantics()) {
        [coder encodeObject:_sourcesBySemantic[semantic] forKey:semantic];
    }
    [coder encodeObject:_elements forKey:@"elements"];
    [coder encodeInteger:(NSInteger)_subdivisionLevel forKey:@"subdivisionLevel"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNGeometry *copy = [[[self class] allocWithZone:zone] init];
    copy->_name = [_name copy];
    copy->_materials = [_materials copy];
    copy->_boundingBoxMin = _boundingBoxMin;
    copy->_boundingBoxMax = _boundingBoxMax;
    copy->_hasExplicitBoundingBox = _hasExplicitBoundingBox;
    copy->_sourcesBySemantic = [_sourcesBySemantic mutableCopy];
    copy->_elements = [_elements copy];
    copy->_subdivisionLevel = _subdivisionLevel;
    return copy;
}

@end

@implementation SCNGeometry (CharonReplace)

- (void)charon_replaceSources:(NSArray<SCNGeometrySource *> *)sources
                     elements:(NSArray<SCNGeometryElement *> *)elements
{
    // The class keeps no array of sources: `-geometrySources` is built from the by-semantic index,
    // which is what `-geometrySourcesForSemantic:` answers from, and an index that is not rebuilt when
    // the sources change is an index that lies. So the index is rebuilt here, and it is rebuilt the
    // way the initialiser builds it - keyed by the semantic itself, which is the dictionary's own key
    // type, and each semantic's sources in the order they were given.
    NSMutableDictionary<SCNGeometrySourceSemantic, NSArray<SCNGeometrySource *> *> *bySemantic =
            [NSMutableDictionary dictionary];
    for (SCNGeometrySource *source in sources) {
        NSArray<SCNGeometrySource *> *existing = bySemantic[source.semantic];
        bySemantic[source.semantic] = existing ? [existing arrayByAddingObject:source] : @[ source ];
    }
    _sourcesBySemantic = bySemantic;
    _elements = [elements copy];
}

@end
