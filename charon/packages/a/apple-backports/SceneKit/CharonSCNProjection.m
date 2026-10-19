// The renderer's projection: a world point to the viewport it is drawn in, and back.
//
// SCNSceneRenderer declares projectPoint: and unprojectPoint: (SCNSceneRenderer.h:129-142) and the
// port carried neither (measured 2026-09-28: `grep -rn projectPoint packages/a/apple-backports/` was
// empty), so a hit test - Scene.pixelCast, and a touch that has to agree with it - had no way to
// turn a world point into a screen one.
//
// The arithmetic is transcribed from what host/scenekitprojection/project.swift verified against
// macOS SceneKit's own renderer, over eight points spread across the viewport and in depth: the
// viewport y carries the sign of the camera-space y with no flip, the depth is the perspective one
// and not a linear share of the range, and the field of view and the planes are the camera's and
// not a default. The projection itself is CharonSCNProjectionMatrix, the one the frame is drawn
// with, so a hit test cannot disagree with the picture.
//
// Where the viewport comes from is what the two classes differ in, and it is what SceneKit says: the
// renderer answers with the viewport of its last render - measured, an SCNRenderer that has not
// rendered answers every point unchanged - and the view with its own bounds scaled by its content
// scale. The arithmetic is written once, over the point of view and the viewport, and both answer
// through it.

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <SceneKit/SceneKit.h>

#import "CharonSCN.h"
#include "CharonSCNMath.h"

/// The world and the projection, once, for both directions. A nil point of view or a viewport with
/// no width answers the point as it went in, which is what macOS SceneKit's own renderer answers
/// before it has rendered (measured 2026-09-28: every point comes back unchanged, at the origin, at
/// (3, -2, -5) and off to the side).
static BOOL CharonSCNProjectable(SCNNode *pointOfView, int width, int height)
{
    return pointOfView != nil && width > 0 && height > 0;
}

SCNVector3 CharonSCNProjectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point)
{
    if (!CharonSCNProjectable(pointOfView, width, height)) {
        return point;
    }
    SCNMatrix4 view = CharonSCNMatrixInvert([pointOfView charonPresentedWorldTransform]);
    float world[4] = {point.x, point.y, point.z, 1}, eye[4];
    CharonSCNMatrixMultiplyVector(view, world, eye);
    float clip[4];
    CharonSCNMatrixMultiplyVector(CharonSCNProjectionMatrix(pointOfView, width, height), eye, clip);
    // The w divide is the perspective depth, and it is what puts z 0 at the near plane and 1 at the
    // far one. A point behind the camera has a w near zero and no screen position, so it is left
    // where it was rather than folded onto an edge that is not there.
    if (fabsf(clip[3]) < 1e-6f) {
        return point;
    }
    float ndcX = clip[0] / clip[3], ndcY = clip[1] / clip[3], ndcZ = clip[2] / clip[3];
    // The same form for x and y, with no flip on y: the viewport y carries the sign of the
    // camera-space y (measured, not assumed - the flip is what the arithmetic had wrong first).
    return SCNVector3Make((ndcX + 1) * 0.5f * (float)width, (ndcY + 1) * 0.5f * (float)height,
                          (ndcZ + 1) * 0.5f);
}

SCNVector3 CharonSCNUnprojectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point)
{
    if (!CharonSCNProjectable(pointOfView, width, height)) {
        return point;
    }
    float ndcX = point.x / (float)width * 2 - 1;
    float ndcY = point.y / (float)height * 2 - 1;
    float ndcZ = point.z * 2 - 1;
    float screen[4] = {ndcX, ndcY, ndcZ, 1}, eye[4];
    CharonSCNMatrixMultiplyVector(CharonSCNProjectionMatrix(pointOfView, width, height), screen, eye);
    if (fabsf(eye[3]) < 1e-6f) {
        return point;
    }
    float clip[4] = {eye[0] / eye[3], eye[1] / eye[3], eye[2] / eye[3], 1}, world[4];
    CharonSCNMatrixMultiplyVector(CharonSCNMatrixInvert([pointOfView charonPresentedWorldTransform]),
                                  clip, world);
    if (fabsf(world[3]) < 1e-6f) {
        return point;
    }
    return SCNVector3Make(world[0] / world[3], world[1] / world[3], world[2] / world[3]);
}

/// The renderer: its own point of view and the viewport of its last render.
@implementation CharonSCNRenderer (CharonSCNProjection)

- (SCNVector3)projectPoint:(SCNVector3)point
{
    return CharonSCNProjectPoint(self.lastRenderPointOfView, self.lastRenderWidth, self.lastRenderHeight, point);
}

- (SCNVector3)unprojectPoint:(SCNVector3)point
{
    return CharonSCNUnprojectPoint(self.lastRenderPointOfView, self.lastRenderWidth, self.lastRenderHeight, point);
}

@end

/// The view: its own point of view and its own bounds in points, times the content scale, which is
/// the viewport its frame was drawn into.
@implementation SCNView (CharonSCNProjection)

- (SCNVector3)projectPoint:(SCNVector3)point
{
    return CharonSCNProjectPoint(self.pointOfView, (int)roundf(self.bounds.size.width * self.contentScaleFactor),
                                 (int)roundf(self.bounds.size.height * self.contentScaleFactor), point);
}

- (SCNVector3)unprojectPoint:(SCNVector3)point
{
    return CharonSCNUnprojectPoint(self.pointOfView, (int)roundf(self.bounds.size.width * self.contentScaleFactor),
                                   (int)roundf(self.bounds.size.height * self.contentScaleFactor), point);
}

@end
