#import <SceneKit/SceneKit.h>

void RevenantSCNRowTransform(SCNMatrix4 matrix, const float in[4], float out[4]);
BOOL RevenantSCNReadVector(SCNGeometrySource *source, NSUInteger index, NSUInteger components, float *out);
BOOL RevenantSCNReadIndex(SCNGeometryElement *element, NSUInteger index, NSUInteger *out);
BOOL RevenantSCNGeometryBounds(SCNGeometry *geometry, float min[3], float max[3]);
void RevenantSCNWorldBox(SCNMatrix4 world, const float min[3], const float max[3], float worldMin[3], float worldMax[3]);
void RevenantSCNExpandBox(float min[3], float max[3], const float point[3]);
BOOL RevenantSCNRayHitsTriangle(const float origin[3], const float direction[3], const float a[3], const float b[3], const float c[3], BOOL cullBackFaces, float *distance, float *u, float *v);
BOOL RevenantSCNRayHitsBox(const float origin[3], const float direction[3], const float min[3], const float max[3], float *distance);
void RevenantSCNFrustumPlanes(SCNMatrix4 viewProjection, float planes[6][4]);
BOOL RevenantSCNBoxInFrustum(const float planes[6][4], const float min[3], const float max[3]);
