#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <SceneKit/SceneKit.h>

#import "RevenantSCN.h"
#include "RevenantSCNMath.h"

static BOOL RevenantSCNProjectable(SCNNode *pointOfView, int width, int height)
{
    return pointOfView != nil && width > 0 && height > 0;
}

SCNVector3 RevenantSCNProjectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point)
{
    if (!RevenantSCNProjectable(pointOfView, width, height)) {
        return point;
    }
    SCNMatrix4 view = RevenantSCNMatrixInvert([pointOfView revenantPresentedWorldTransform]);
    float world[4] = {point.x, point.y, point.z, 1}, eye[4];
    RevenantSCNMatrixMultiplyVector(view, world, eye);
    float clip[4];
    RevenantSCNMatrixMultiplyVector(RevenantSCNProjectionMatrix(pointOfView, width, height), eye, clip);
    if (fabsf(clip[3]) < 1e-6f) {
        return point;
    }
    float ndcX = clip[0] / clip[3], ndcY = clip[1] / clip[3], ndcZ = clip[2] / clip[3];
    return SCNVector3Make((ndcX + 1) * 0.5f * (float)width, (ndcY + 1) * 0.5f * (float)height,
                          (ndcZ + 1) * 0.5f);
}

SCNVector3 RevenantSCNUnprojectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point)
{
    if (!RevenantSCNProjectable(pointOfView, width, height)) {
        return point;
    }
    float ndcX = point.x / (float)width * 2 - 1;
    float ndcY = point.y / (float)height * 2 - 1;
    float ndcZ = point.z * 2 - 1;
    float screen[4] = {ndcX, ndcY, ndcZ, 1}, eye[4];
    RevenantSCNMatrixMultiplyVector(RevenantSCNProjectionMatrix(pointOfView, width, height), screen, eye);
    if (fabsf(eye[3]) < 1e-6f) {
        return point;
    }
    float clip[4] = {eye[0] / eye[3], eye[1] / eye[3], eye[2] / eye[3], 1}, world[4];
    RevenantSCNMatrixMultiplyVector(RevenantSCNMatrixInvert([pointOfView revenantPresentedWorldTransform]),
                                  clip, world);
    if (fabsf(world[3]) < 1e-6f) {
        return point;
    }
    return SCNVector3Make(world[0] / world[3], world[1] / world[3], world[2] / world[3]);
}

@implementation RevenantSCNRenderer (RevenantSCNProjection)

- (SCNVector3)projectPoint:(SCNVector3)point
{
    return RevenantSCNProjectPoint(self.lastRenderPointOfView, self.lastRenderWidth, self.lastRenderHeight, point);
}

- (SCNVector3)unprojectPoint:(SCNVector3)point
{
    return RevenantSCNUnprojectPoint(self.lastRenderPointOfView, self.lastRenderWidth, self.lastRenderHeight, point);
}

@end

@implementation SCNView (RevenantSCNProjection)

- (SCNVector3)projectPoint:(SCNVector3)point
{
    return RevenantSCNProjectPoint(self.pointOfView, (int)roundf(self.bounds.size.width * self.contentScaleFactor),
                                 (int)roundf(self.bounds.size.height * self.contentScaleFactor), point);
}

- (SCNVector3)unprojectPoint:(SCNVector3)point
{
    return RevenantSCNUnprojectPoint(self.pointOfView, (int)roundf(self.bounds.size.width * self.contentScaleFactor),
                                   (int)roundf(self.bounds.size.height * self.contentScaleFactor), point);
}

@end
