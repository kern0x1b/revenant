#import "CharonSCN.h"
#import "CharonSCNMath.h"

// Each answer below is macOS SceneKit's for the same input (tests/backports/host/scenekit, mathcases).

bool SCNVector3EqualToVector3(SCNVector3 a, SCNVector3 b)
{
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

bool SCNVector4EqualToVector4(SCNVector4 a, SCNVector4 b)
{
    return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;
}

bool SCNMatrix4IsIdentity(SCNMatrix4 m)
{
    return SCNMatrix4EqualToMatrix4(m, SCNMatrix4Identity);
}

bool SCNMatrix4EqualToMatrix4(SCNMatrix4 a, SCNMatrix4 b)
{
    const float *x = &a.m11, *y = &b.m11;
    for (int i = 0; i < 16; i++) {
        if (x[i] != y[i]) {
            return false;
        }
    }
    return true;
}

SCNMatrix4 SCNMatrix4MakeRotation(float angle, float x, float y, float z)
{
    return CharonSCNMatrixRotation(angle, x, y, z);
}

SCNMatrix4 SCNMatrix4Scale(SCNMatrix4 m, float sx, float sy, float sz)
{
    return CharonSCNMatrixMultiply(SCNMatrix4MakeScale(sx, sy, sz), m);
}

SCNMatrix4 SCNMatrix4Rotate(SCNMatrix4 m, float angle, float x, float y, float z)
{
    return CharonSCNMatrixMultiply(CharonSCNMatrixRotation(angle, x, y, z), m);
}

SCNMatrix4 SCNMatrix4Invert(SCNMatrix4 m)
{
    return CharonSCNMatrixInvert(m);
}

SCNMatrix4 SCNMatrix4Mult(SCNMatrix4 a, SCNMatrix4 b)
{
    return CharonSCNMatrixMultiply(a, b);
}

GLKMatrix4 SCNMatrix4ToGLKMatrix4(SCNMatrix4 m)
{
    GLKMatrix4 result;
    memcpy(result.m, &m.m11, sizeof(result.m));
    return result;
}

SCNMatrix4 SCNMatrix4FromGLKMatrix4(GLKMatrix4 m)
{
    SCNMatrix4 result;
    memcpy(&result.m11, m.m, sizeof(m.m));
    return result;
}
