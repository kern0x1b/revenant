#import "../Foundation/check.h"
#import "../../src/SceneKit/RevenantSCNGeometry.h"
#include <math.h>

static BOOL revenant_near(double value, double expected, double tolerance)
{
    return fabs(value - expected) <= tolerance;
}

static SCNMatrix4 revenant_translation(float x, float y, float z)
{
    SCNMatrix4 matrix = SCNMatrix4Identity;
    matrix.m41 = x;
    matrix.m42 = y;
    matrix.m43 = z;
    return matrix;
}

static SCNMatrix4 revenant_perspective(void)
{
    float near = 1, far = 100;
    SCNMatrix4 matrix = SCNMatrix4Identity;
    matrix.m11 = 1;
    matrix.m22 = 1;
    matrix.m33 = (far + near) / (near - far);
    matrix.m43 = 2 * far * near / (near - far);
    matrix.m34 = -1;
    matrix.m44 = 0;
    return matrix;
}

static BOOL revenant_box_inside(SCNMatrix4 viewProjection, float minX, float minY, float minZ, float maxX, float maxY, float maxZ)
{
    float planes[6][4];
    float min[3] = {minX, minY, minZ}, max[3] = {maxX, maxY, maxZ};
    RevenantSCNFrustumPlanes(viewProjection, planes);
    return RevenantSCNBoxInFrustum(planes, min, max);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);

        float in[4] = {1, 2, 3, 1}, out[4];
        RevenantSCNRowTransform(revenant_translation(10, 20, 30), in, out);
        revenant_check(revenant_near(out[0], 11, 1e-5) && revenant_near(out[1], 22, 1e-5) && revenant_near(out[2], 33, 1e-5) && revenant_near(out[3], 1, 1e-5),
                       "a point is moved by the translation in the fourth row", @"the point is not moved as the row convention requires");

        float a[3] = {-1, -1, -5}, b[3] = {1, -1, -5}, c[3] = {0, 1, -5};
        float origin[3] = {0, 0, 0}, forward[3] = {0, 0, -1};
        float distance = 0, u = 0, v = 0;
        BOOL hit = RevenantSCNRayHitsTriangle(origin, forward, a, b, c, NO, &distance, &u, &v);
        revenant_check(hit && revenant_near(distance, 5, 1e-5), "a ray along the axis hits a triangle at its distance", [NSString stringWithFormat:@"hit %d at %f", hit, distance]);
        float px = (1 - u - v) * a[0] + u * b[0] + v * c[0], py = (1 - u - v) * a[1] + u * b[1] + v * c[1];
        revenant_check(hit && revenant_near(px, 0, 1e-4) && revenant_near(py, 0, 1e-4), "the barycentric coordinates locate the hit point", [NSString stringWithFormat:@"the point is (%f, %f)", px, py]);

        float far[3] = {5, 0, 0};
        revenant_check(!RevenantSCNRayHitsTriangle(far, forward, a, b, c, NO, &distance, &u, &v), "a ray beside a triangle reports no hit", @"the ray hits a triangle it passes beside");

        float reversedA[3] = {-1, -1, -5}, reversedB[3] = {0, 1, -5}, reversedC[3] = {1, -1, -5};
        BOOL culled = RevenantSCNRayHitsTriangle(origin, forward, reversedA, reversedB, reversedC, YES, &distance, &u, &v);
        BOOL visible = RevenantSCNRayHitsTriangle(origin, forward, reversedA, reversedB, reversedC, NO, &distance, &u, &v);
        revenant_check(!culled && visible, "a triangle facing away is hit only when back faces are not culled", [NSString stringWithFormat:@"culled hit %d, uncull hit %d", culled, visible]);

        float boxMin[3] = {-1, -1, -6}, boxMax[3] = {1, 1, -4};
        float boxDistance = 0;
        revenant_check(RevenantSCNRayHitsBox(origin, forward, boxMin, boxMax, &boxDistance) && revenant_near(boxDistance, 4, 1e-5), "a ray hits a box at its near face", [NSString stringWithFormat:@"distance %f", boxDistance]);
        float inside[3] = {0, 0, -5};
        revenant_check(RevenantSCNRayHitsBox(inside, forward, boxMin, boxMax, &boxDistance) && revenant_near(boxDistance, 0, 1e-5), "a ray starting inside a box hits it at distance zero", [NSString stringWithFormat:@"distance %f", boxDistance]);
        float backward[3] = {0, 0, 1};
        revenant_check(!RevenantSCNRayHitsBox(origin, backward, boxMin, boxMax, &boxDistance), "a ray pointing away from a box misses it", @"the box behind the ray is reported");

        SCNMatrix4 viewProjection = revenant_perspective();
        revenant_check(revenant_box_inside(viewProjection, -1, -1, -11, 1, 1, -9), "the frustum keeps a box in front of the camera", @"a box in front of the camera is culled");
        revenant_check(!revenant_box_inside(viewProjection, -1, -1, 9, 1, 1, 11), "the frustum culls a box behind the camera", @"a box behind the camera is kept");
        revenant_check(!revenant_box_inside(viewProjection, 49, -1, -11, 51, 1, -9), "the frustum culls a box beside the view", @"a box beside the view is kept");
        BOOL crossing = revenant_box_inside(viewProjection, -0.1, -0.1, -3, 0.1, 0.1, -0.5);
        revenant_check(crossing, "the frustum keeps a box that crosses the near plane", @"a box that reaches past the near plane is culled");

        unsigned short indexData[3] = {0, 1, 2};
        SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:[NSData dataWithBytes:indexData length:sizeof indexData] primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:1 bytesPerIndex:sizeof(unsigned short)];
        NSUInteger index = 99;
        BOOL read = RevenantSCNReadIndex(element, 2, &index);
        revenant_check(read && index == 2, "an index is read at its element size", [NSString stringWithFormat:@"read %d, index %lu", read, (unsigned long)index]);

        float positions[6] = {0, 0, 0, 1, 2, 3};
        SCNGeometrySource *source = [SCNGeometrySource geometrySourceWithData:[NSData dataWithBytes:positions length:sizeof positions] semantic:SCNGeometrySourceSemanticVertex vectorCount:2 floatComponents:YES componentsPerVector:3 bytesPerComponent:sizeof(float) dataOffset:0 dataStride:3 * sizeof(float)];
        float vector[3] = {0, 0, 0};
        BOOL vectorRead = RevenantSCNReadVector(source, 1, 3, vector);
        revenant_check(vectorRead && revenant_near(vector[0], 1, 1e-6) && revenant_near(vector[2], 3, 1e-6), "a vertex is read from a float source", @"the second vertex is not read");

        if (revenant_negative) {
            revenant_check(!RevenantSCNRayHitsTriangle(origin, forward, a, b, c, NO, &distance, &u, &v), "negative control: a hit is reported as a miss", @"the negative control is inverted");
        }
    }
    return revenant_finish();
}
