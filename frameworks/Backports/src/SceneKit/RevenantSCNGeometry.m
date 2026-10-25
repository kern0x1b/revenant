#import "RevenantSCNGeometry.h"
#include <math.h>
#include <string.h>

static float RevenantSCNDot(const float a[3], const float b[3])
{
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

static void RevenantSCNCross(const float a[3], const float b[3], float out[3])
{
    float x = a[1] * b[2] - a[2] * b[1];
    float y = a[2] * b[0] - a[0] * b[2];
    float z = a[0] * b[1] - a[1] * b[0];
    out[0] = x;
    out[1] = y;
    out[2] = z;
}

static void RevenantSCNSubtract(const float a[3], const float b[3], float out[3])
{
    out[0] = a[0] - b[0];
    out[1] = a[1] - b[1];
    out[2] = a[2] - b[2];
}

static void RevenantSCNNormalize(float v[3])
{
    float length = sqrtf(RevenantSCNDot(v, v));
    if (length > 0) {
        v[0] /= length;
        v[1] /= length;
        v[2] /= length;
    }
}

static void RevenantSCNMatrixFloats(SCNMatrix4 matrix, float m[16])
{
    float values[16] = {
        matrix.m11, matrix.m12, matrix.m13, matrix.m14,
        matrix.m21, matrix.m22, matrix.m23, matrix.m24,
        matrix.m31, matrix.m32, matrix.m33, matrix.m34,
        matrix.m41, matrix.m42, matrix.m43, matrix.m44
    };
    memcpy(m, values, sizeof values);
}

void RevenantSCNRowTransform(SCNMatrix4 matrix, const float in[4], float out[4])
{
    float m[16];
    RevenantSCNMatrixFloats(matrix, m);
    float result[4];
    for (int column = 0; column < 4; column++) {
        result[column] = in[0] * m[column] + in[1] * m[4 + column] + in[2] * m[8 + column] + in[3] * m[12 + column];
    }
    memcpy(out, result, sizeof result);
}

BOOL RevenantSCNReadVector(SCNGeometrySource *source, NSUInteger index, NSUInteger components, float *out)
{
    if (source == nil || !source.floatComponents || components == 0 || components > source.componentsPerVector) {
        return NO;
    }
    NSUInteger size = source.bytesPerComponent;
    if (size != sizeof(float) && size != sizeof(double)) {
        return NO;
    }
    if (index >= source.vectorCount) {
        return NO;
    }
    NSUInteger offset = source.dataOffset + index * source.dataStride;
    if (offset + components * size > source.data.length) {
        return NO;
    }
    const uint8_t *bytes = source.data.bytes + offset;
    for (NSUInteger component = 0; component < components; component++) {
        if (size == sizeof(float)) {
            float value;
            memcpy(&value, bytes + component * size, sizeof value);
            out[component] = value;
        } else {
            double value;
            memcpy(&value, bytes + component * size, sizeof value);
            out[component] = (float)value;
        }
    }
    return YES;
}

BOOL RevenantSCNReadIndex(SCNGeometryElement *element, NSUInteger index, NSUInteger *out)
{
    NSUInteger size = element.bytesPerIndex;
    if (index >= element.data.length / size || (index + 1) * size > element.data.length) {
        return NO;
    }
    const uint8_t *bytes = element.data.bytes + index * size;
    switch (size) {
        case 1:
            *out = *bytes;
            return YES;
        case 2: {
            uint16_t value;
            memcpy(&value, bytes, sizeof value);
            *out = value;
            return YES;
        }
        case 4: {
            uint32_t value;
            memcpy(&value, bytes, sizeof value);
            *out = value;
            return YES;
        }
        default:
            return NO;
    }
}

void RevenantSCNExpandBox(float min[3], float max[3], const float point[3])
{
    for (int axis = 0; axis < 3; axis++) {
        if (point[axis] < min[axis]) {
            min[axis] = point[axis];
        }
        if (point[axis] > max[axis]) {
            max[axis] = point[axis];
        }
    }
}

BOOL RevenantSCNGeometryBounds(SCNGeometry *geometry, float min[3], float max[3])
{
    SCNVector3 explicitMin, explicitMax;
    if ([geometry getBoundingBoxMin:&explicitMin max:&explicitMax]) {
        min[0] = (float)explicitMin.x;
        min[1] = (float)explicitMin.y;
        min[2] = (float)explicitMin.z;
        max[0] = (float)explicitMax.x;
        max[1] = (float)explicitMax.y;
        max[2] = (float)explicitMax.z;
        return YES;
    }
    SCNGeometrySource *position = [geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticVertex].firstObject;
    if (position == nil || position.vectorCount == 0) {
        return NO;
    }
    float vertex[3];
    if (!RevenantSCNReadVector(position, 0, 3, vertex)) {
        return NO;
    }
    memcpy(min, vertex, sizeof vertex);
    memcpy(max, vertex, sizeof vertex);
    for (NSUInteger index = 1; index < position.vectorCount; index++) {
        if (!RevenantSCNReadVector(position, index, 3, vertex)) {
            return NO;
        }
        RevenantSCNExpandBox(min, max, vertex);
    }
    return YES;
}

void RevenantSCNWorldBox(SCNMatrix4 world, const float min[3], const float max[3], float worldMin[3], float worldMax[3])
{
    BOOL started = NO;
    for (int corner = 0; corner < 8; corner++) {
        float local[4] = {
            (corner & 1) ? max[0] : min[0],
            (corner & 2) ? max[1] : min[1],
            (corner & 4) ? max[2] : min[2],
            1
        };
        float transformed[4];
        RevenantSCNRowTransform(world, local, transformed);
        float point[3] = {transformed[0] / transformed[3], transformed[1] / transformed[3], transformed[2] / transformed[3]};
        if (!started) {
            memcpy(worldMin, point, sizeof point);
            memcpy(worldMax, point, sizeof point);
            started = YES;
        } else {
            RevenantSCNExpandBox(worldMin, worldMax, point);
        }
    }
}

BOOL RevenantSCNRayHitsTriangle(const float origin[3], const float direction[3], const float a[3], const float b[3], const float c[3], BOOL cullBackFaces, float *distance, float *u, float *v)
{
    float edge1[3], edge2[3], normal[3];
    RevenantSCNSubtract(b, a, edge1);
    RevenantSCNSubtract(c, a, edge2);
    RevenantSCNCross(edge1, edge2, normal);
    if (cullBackFaces && RevenantSCNDot(normal, direction) > 0) {
        return NO;
    }
    float p[3];
    RevenantSCNCross(direction, edge2, p);
    float determinant = RevenantSCNDot(edge1, p);
    if (fabsf(determinant) < 1e-12f) {
        return NO;
    }
    float inverse = 1 / determinant;
    float s[3];
    RevenantSCNSubtract(origin, a, s);
    float barycentricU = RevenantSCNDot(s, p) * inverse;
    if (barycentricU < 0 || barycentricU > 1) {
        return NO;
    }
    float q[3];
    RevenantSCNCross(s, edge1, q);
    float barycentricV = RevenantSCNDot(direction, q) * inverse;
    if (barycentricV < 0 || barycentricU + barycentricV > 1) {
        return NO;
    }
    *distance = RevenantSCNDot(edge2, q) * inverse;
    *u = barycentricU;
    *v = barycentricV;
    return YES;
}

BOOL RevenantSCNRayHitsBox(const float origin[3], const float direction[3], const float min[3], const float max[3], float *distance)
{
    float enter = -HUGE_VALF, leave = HUGE_VALF;
    for (int axis = 0; axis < 3; axis++) {
        if (fabsf(direction[axis]) < 1e-12f) {
            if (origin[axis] < min[axis] || origin[axis] > max[axis]) {
                return NO;
            }
            continue;
        }
        float near = (min[axis] - origin[axis]) / direction[axis];
        float far = (max[axis] - origin[axis]) / direction[axis];
        if (near > far) {
            float swap = near;
            near = far;
            far = swap;
        }
        enter = fmaxf(enter, near);
        leave = fminf(leave, far);
        if (enter > leave) {
            return NO;
        }
    }
    if (leave < 0) {
        return NO;
    }
    *distance = fmaxf(enter, 0);
    return YES;
}

void RevenantSCNFrustumPlanes(SCNMatrix4 viewProjection, float planes[6][4])
{
    float m[16];
    RevenantSCNMatrixFloats(viewProjection, m);
    int index = 0;
    for (int axis = 0; axis < 3; axis++) {
        for (int sign = -1; sign <= 1; sign += 2) {
            for (int row = 0; row < 4; row++) {
                planes[index][row] = m[row * 4 + 3] + sign * m[row * 4 + axis];
            }
            index++;
        }
    }
}

BOOL RevenantSCNBoxInFrustum(const float planes[6][4], const float min[3], const float max[3])
{
    for (int plane = 0; plane < 6; plane++) {
        float x = planes[plane][0] >= 0 ? max[0] : min[0];
        float y = planes[plane][1] >= 0 ? max[1] : min[1];
        float z = planes[plane][2] >= 0 ? max[2] : min[2];
        if (planes[plane][0] * x + planes[plane][1] * y + planes[plane][2] * z + planes[plane][3] < 0) {
            return NO;
        }
    }
    return YES;
}
