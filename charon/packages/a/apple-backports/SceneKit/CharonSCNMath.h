// The matrix and rotation arithmetic SceneKit's types are defined by, measured against macOS SceneKit
// (facts/SceneKit/SCNView.md, "Conventions"): an SCNMatrix4 is row-major with the translation in m41..m43 and
// transforms row vectors, SCNMatrix4Mult(a, b) is a then b, and its memory is the column-major matrix OpenGL ES
// multiplies column vectors with. Every file of the library takes the arithmetic from here, so there is one copy.
#import <SceneKit/SceneKit.h>
#include <math.h>

static inline SCNMatrix4 CharonSCNMatrixMultiply(SCNMatrix4 a, SCNMatrix4 b)
{
    const float *x = &a.m11, *y = &b.m11;
    SCNMatrix4 result;
    float *r = &result.m11;
    for (int row = 0; row < 4; row++) {
        for (int column = 0; column < 4; column++) {
            r[row * 4 + column] = x[row * 4 + 0] * y[0 * 4 + column] + x[row * 4 + 1] * y[1 * 4 + column] +
                                  x[row * 4 + 2] * y[2 * 4 + column] + x[row * 4 + 3] * y[3 * 4 + column];
        }
    }
    return result;
}

// A vector by a matrix, in the same convention as CharonSCNMatrixMultiply: the matrix's memory is
// the column-major one OpenGL ES multiplies column vectors with, and the transform is a row vector,
// so a point is multiplied as a row and a direction is multiplied with the translation left out.
static inline void CharonSCNMatrixMultiplyVector(SCNMatrix4 matrix, const float *v, float *out)
{
    const float *m = &matrix.m11;
    for (int row = 0; row < 4; row++) {
        out[row] = m[row * 4 + 0] * v[0] + m[row * 4 + 1] * v[1] + m[row * 4 + 2] * v[2] + m[row * 4 + 3] * v[3];
    }
}

// The inverse by cofactors; a matrix with no inverse is answered unchanged, as SceneKit answers it.
static inline SCNMatrix4 CharonSCNMatrixInvert(SCNMatrix4 matrix)
{
    const float *m = &matrix.m11;
    float inv[16];
    inv[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10];
    inv[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10];
    inv[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9];
    inv[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9];
    inv[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10];
    inv[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10];
    inv[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9];
    inv[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9];
    inv[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6];
    inv[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6];
    inv[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5];
    inv[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5];
    inv[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6];
    inv[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6];
    inv[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5];
    inv[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5];
    float determinant = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];
    if (determinant == 0) {
        return matrix;
    }
    SCNMatrix4 result;
    float *r = &result.m11;
    for (int i = 0; i < 16; i++) {
        r[i] = inv[i] / determinant;
    }
    return result;
}

// Rotation by angle about an axis, normalised first; a zero axis is no rotation (both measured).
static inline SCNMatrix4 CharonSCNMatrixRotation(float angle, float x, float y, float z)
{
    float length = sqrtf(x * x + y * y + z * z);
    if (length == 0) {
        return SCNMatrix4Identity;
    }
    x /= length;
    y /= length;
    z /= length;
    float c = cosf(angle), s = sinf(angle), t = 1 - c;
    SCNMatrix4 m = SCNMatrix4Identity;
    m.m11 = t * x * x + c;     m.m12 = t * x * y + s * z; m.m13 = t * x * z - s * y;
    m.m21 = t * x * y - s * z; m.m22 = t * y * y + c;     m.m23 = t * y * z + s * x;
    m.m31 = t * x * z + s * y; m.m32 = t * y * z - s * x; m.m33 = t * z * z + c;
    return m;
}

static inline SCNMatrix4 CharonSCNMatrixFromQuaternion(SCNQuaternion q)
{
    float x = q.x, y = q.y, z = q.z, w = q.w;
    SCNMatrix4 m = SCNMatrix4Identity;
    m.m11 = 1 - 2 * (y * y + z * z); m.m12 = 2 * (x * y + z * w);     m.m13 = 2 * (x * z - y * w);
    m.m21 = 2 * (x * y - z * w);     m.m22 = 1 - 2 * (x * x + z * z); m.m23 = 2 * (y * z + x * w);
    m.m31 = 2 * (x * z + y * w);     m.m32 = 2 * (y * z - x * w);     m.m33 = 1 - 2 * (x * x + y * y);
    return m;
}

static inline SCNQuaternion CharonSCNQuaternionFromAxisAngle(SCNVector4 rotation)
{
    float length = sqrtf(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z);
    if (length == 0) {
        return SCNVector4Make(0, 0, 0, 1);
    }
    float s = sinf(rotation.w / 2) / length;
    return SCNVector4Make(rotation.x * s, rotation.y * s, rotation.z * s, cosf(rotation.w / 2));
}

static inline SCNVector4 CharonSCNAxisAngleFromQuaternion(SCNQuaternion q)
{
    float s = sqrtf(q.x * q.x + q.y * q.y + q.z * q.z);
    if (s == 0) {
        return SCNVector4Make(0, 0, 0, 0);
    }
    return SCNVector4Make(q.x / s, q.y / s, q.z / s, 2 * atan2f(s, q.w));
}

// eulerAngles (pitch x, yaw y, roll z) apply x, then y, then z to a row vector: the node's rotation is
// Rx * Ry * Rz, which is what macOS SceneKit's transform is for eulerAngles (0.3, 0.5, 0.7).
static inline SCNQuaternion CharonSCNQuaternionFromEuler(SCNVector3 euler)
{
    float cx = cosf(euler.x / 2), sx = sinf(euler.x / 2);
    float cy = cosf(euler.y / 2), sy = sinf(euler.y / 2);
    float cz = cosf(euler.z / 2), sz = sinf(euler.z / 2);
    // qz * qy * qx: rotating a vector by the result applies x first
    return SCNVector4Make(sx * cy * cz - cx * sy * sz,
                          cx * sy * cz + sx * cy * sz,
                          cx * cy * sz - sx * sy * cz,
                          cx * cy * cz + sx * sy * sz);
}

static inline SCNVector3 CharonSCNEulerFromQuaternion(SCNQuaternion q)
{
    SCNMatrix4 m = CharonSCNMatrixFromQuaternion(q);
    // m is Rx * Ry * Rz in row-vector form: m13 = -sin(yaw)
    float sinYaw = -m.m13;
    sinYaw = sinYaw > 1 ? 1 : (sinYaw < -1 ? -1 : sinYaw);
    float yaw = asinf(sinYaw), pitch, roll;
    if (fabsf(sinYaw) < 0.99999f) {
        pitch = atan2f(m.m23, m.m33);
        roll = atan2f(m.m12, m.m11);
    } else {
        pitch = atan2f(-m.m32, m.m22);
        roll = 0;
    }
    return SCNVector3Make(pitch, yaw, roll);
}

// scale, then rotate, then translate a row vector
static inline SCNMatrix4 CharonSCNMatrixCompose(SCNVector3 position, SCNQuaternion orientation, SCNVector3 scale)
{
    SCNMatrix4 m = CharonSCNMatrixFromQuaternion(orientation);
    m.m11 *= scale.x; m.m12 *= scale.x; m.m13 *= scale.x;
    m.m21 *= scale.y; m.m22 *= scale.y; m.m23 *= scale.y;
    m.m31 *= scale.z; m.m32 *= scale.z; m.m33 *= scale.z;
    m.m41 = position.x;
    m.m42 = position.y;
    m.m43 = position.z;
    return m;
}

static inline SCNQuaternion CharonSCNQuaternionFromMatrix(SCNMatrix4 m)
{
    float trace = m.m11 + m.m22 + m.m33;
    SCNQuaternion q;
    if (trace > 0) {
        float s = sqrtf(trace + 1) * 2;
        q = SCNVector4Make((m.m23 - m.m32) / s, (m.m31 - m.m13) / s, (m.m12 - m.m21) / s, s / 4);
    } else if (m.m11 > m.m22 && m.m11 > m.m33) {
        float s = sqrtf(1 + m.m11 - m.m22 - m.m33) * 2;
        q = SCNVector4Make(s / 4, (m.m21 + m.m12) / s, (m.m31 + m.m13) / s, (m.m23 - m.m32) / s);
    } else if (m.m22 > m.m33) {
        float s = sqrtf(1 + m.m22 - m.m11 - m.m33) * 2;
        q = SCNVector4Make((m.m21 + m.m12) / s, s / 4, (m.m32 + m.m23) / s, (m.m31 - m.m13) / s);
    } else {
        float s = sqrtf(1 + m.m33 - m.m11 - m.m22) * 2;
        q = SCNVector4Make((m.m31 + m.m13) / s, (m.m32 + m.m23) / s, s / 4, (m.m12 - m.m21) / s);
    }
    return q;
}

// Split an affine transform into position, orientation and scale. A mirror (negative determinant) gets a negative
// scale on every axis, as macOS SceneKit splits it, so that the orientation stays a rotation.
static inline void CharonSCNMatrixDecompose(SCNMatrix4 m, SCNVector3 *position, SCNQuaternion *orientation, SCNVector3 *scale)
{
    float sx = sqrtf(m.m11 * m.m11 + m.m12 * m.m12 + m.m13 * m.m13);
    float sy = sqrtf(m.m21 * m.m21 + m.m22 * m.m22 + m.m23 * m.m23);
    float sz = sqrtf(m.m31 * m.m31 + m.m32 * m.m32 + m.m33 * m.m33);
    float determinant = m.m11 * (m.m22 * m.m33 - m.m23 * m.m32) - m.m12 * (m.m21 * m.m33 - m.m23 * m.m31) + m.m13 * (m.m21 * m.m32 - m.m22 * m.m31);
    if (determinant < 0) {
        sx = -sx, sy = -sy, sz = -sz;
    }
    *position = SCNVector3Make(m.m41, m.m42, m.m43);
    *scale = SCNVector3Make(sx, sy, sz);
    SCNMatrix4 rotation = SCNMatrix4Identity;
    if (sx != 0) { rotation.m11 = m.m11 / sx; rotation.m12 = m.m12 / sx; rotation.m13 = m.m13 / sx; }
    if (sy != 0) { rotation.m21 = m.m21 / sy; rotation.m22 = m.m22 / sy; rotation.m23 = m.m23 / sy; }
    if (sz != 0) { rotation.m31 = m.m31 / sz; rotation.m32 = m.m32 / sz; rotation.m33 = m.m33 / sz; }
    *orientation = CharonSCNQuaternionFromMatrix(rotation);
}
