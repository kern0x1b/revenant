#import <SceneKit/SceneKit.h>

@interface SCNHitTestResult (RevenantSCNPicking)
+ (instancetype)revenantResultWithNode:(SCNNode *)node geometryIndex:(NSInteger)geometryIndex faceIndex:(NSInteger)faceIndex localCoordinates:(const float *)localCoordinates worldCoordinates:(const float *)worldCoordinates localNormal:(const float *)localNormal worldNormal:(const float *)worldNormal modelTransform:(SCNMatrix4)modelTransform textureCoordinates:(NSArray<NSValue *> *)textureCoordinates;
@end
