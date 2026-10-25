#import "RevenantSCNPicking.h"

@implementation SCNHitTestResult
{
    NSArray<NSValue *> *_textureCoordinates;
}

@synthesize node = _node;
@synthesize geometryIndex = _geometryIndex;
@synthesize faceIndex = _faceIndex;
@synthesize localCoordinates = _localCoordinates;
@synthesize worldCoordinates = _worldCoordinates;
@synthesize localNormal = _localNormal;
@synthesize worldNormal = _worldNormal;
@synthesize modelTransform = _modelTransform;

+ (instancetype)revenantResultWithNode:(SCNNode *)node geometryIndex:(NSInteger)geometryIndex faceIndex:(NSInteger)faceIndex localCoordinates:(const float *)localCoordinates worldCoordinates:(const float *)worldCoordinates localNormal:(const float *)localNormal worldNormal:(const float *)worldNormal modelTransform:(SCNMatrix4)modelTransform textureCoordinates:(NSArray<NSValue *> *)textureCoordinates
{
    SCNHitTestResult *result = [[self alloc] init];
    result->_node = node;
    result->_geometryIndex = geometryIndex;
    result->_faceIndex = faceIndex;
    result->_localCoordinates = SCNVector3Make(localCoordinates[0], localCoordinates[1], localCoordinates[2]);
    result->_worldCoordinates = SCNVector3Make(worldCoordinates[0], worldCoordinates[1], worldCoordinates[2]);
    result->_localNormal = SCNVector3Make(localNormal[0], localNormal[1], localNormal[2]);
    result->_worldNormal = SCNVector3Make(worldNormal[0], worldNormal[1], worldNormal[2]);
    result->_modelTransform = modelTransform;
    result->_textureCoordinates = textureCoordinates;
    return result;
}

- (SCNNode *)boneNode
{
    return nil;
}

- (CGPoint)textureCoordinatesWithMappingChannel:(NSInteger)channel
{
    if (channel < 0 || channel >= (NSInteger)_textureCoordinates.count) {
        return CGPointZero;
    }
    return _textureCoordinates[(NSUInteger)channel].CGPointValue;
}

@end
