#import <Foundation/Foundation.h>
#import <simd/simd.h>

static inline matrix_double4x4 RevenantMDLDouble4x4Identity(void)
{
    matrix_double4x4 identity;
    identity.columns[0] = (vector_double4){1, 0, 0, 0};
    identity.columns[1] = (vector_double4){0, 1, 0, 0};
    identity.columns[2] = (vector_double4){0, 0, 1, 0};
    identity.columns[3] = (vector_double4){0, 0, 0, 1};
    return identity;
}

static inline matrix_float4x4 RevenantMDLFloat4x4(matrix_double4x4 value)
{
    matrix_float4x4 result;
    for (size_t c = 0; c < 4; c++)
        for (size_t r = 0; r < 4; r++)
            result.columns[c][r] = (float)value.columns[c][r];
    return result;
}

static inline matrix_double4x4 RevenantMDLDouble4x4(matrix_float4x4 value)
{
    matrix_double4x4 result;
    for (size_t c = 0; c < 4; c++)
        for (size_t r = 0; r < 4; r++)
            result.columns[c][r] = value.columns[c][r];
    return result;
}

static inline matrix_double4x4 RevenantMDLTranslation(vector_double3 translation)
{
    matrix_double4x4 result = RevenantMDLDouble4x4Identity();
    result.columns[3] = (vector_double4){translation.x, translation.y, translation.z, 1};
    return result;
}

static inline matrix_double4x4 RevenantMDLScale(vector_double3 scale)
{
    matrix_double4x4 result;
    result.columns[0] = (vector_double4){scale.x, 0, 0, 0};
    result.columns[1] = (vector_double4){0, scale.y, 0, 0};
    result.columns[2] = (vector_double4){0, 0, scale.z, 0};
    result.columns[3] = (vector_double4){0, 0, 0, 1};
    return result;
}

static inline matrix_double4x4 RevenantMDLAxisRotation(int axis, double angle)
{
    double c = cos(angle), s = sin(angle);
    matrix_double4x4 result = RevenantMDLDouble4x4Identity();
    int next = (axis + 1) % 3, far = (axis + 2) % 3;
    vector_double4 movedNext = {0, 0, 0, 0}, movedFar = {0, 0, 0, 0};
    movedNext[next] = c;
    movedNext[far] = s;
    movedFar[next] = -s;
    movedFar[far] = c;
    result.columns[next] = movedNext;
    result.columns[far] = movedFar;
    return result;
}

static inline matrix_double4x4 RevenantMDLAngleRotation(vector_double3 angles, MDLTransformOpRotationOrder order)
{
    static const int axes[6] = {0, 1, 2, 0, 1, 2};
    static const int orderOf[6] = {0, 1, 2, 1, 0, 2};
    MDLTransformOpRotationOrder chosen = order >= MDLTransformOpRotationOrderXYZ && order <= MDLTransformOpRotationOrderZYX
                                            ? order
                                            : MDLTransformOpRotationOrderXYZ;
    int index = (int)chosen - (int)MDLTransformOpRotationOrderXYZ;
    if (index < 0 || index > 5)
        index = 0;
    double values[3] = {angles.x, angles.y, angles.z};
    matrix_double4x4 result = RevenantMDLAxisRotation(axes[index], values[orderOf[index]]);
    for (int k = index + 1; k < 3; k++)
        result = simd_mul(result, RevenantMDLAxisRotation(axes[k], values[orderOf[k]]));
    return result;
}

static inline matrix_double4x4 RevenantMDLQuaternionMatrix(simd_quatd rotation)
{
    double x = rotation.vector.x, y = rotation.vector.y, z = rotation.vector.z, w = rotation.vector.w;
    matrix_double4x4 result;
    result.columns[0] = (vector_double4){1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0};
    result.columns[1] = (vector_double4){2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0};
    result.columns[2] = (vector_double4){2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0};
    result.columns[3] = (vector_double4){0, 0, 0, 1};
    return result;
}
