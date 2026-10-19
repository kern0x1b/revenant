// CharonMDLTransformMath.h - the 4x4 arithmetic MDLTransformStack11.m and MDLTransformStack16.m share.
//
// One definition, because a `static` in a .m is a second copy in every .m that needs it: the two
// files each carried their own CharonMDLTranslation, CharonMDLScale, CharonMDLAxisRotation,
// CharonMDLAngleRotation, CharonMDLQuaternionMatrix, CharonMDLFloat4x4 and CharonMDLDouble4x4, and
// five of the seven in the 16 file were dead there, its one class using two of them. A header is
// the shape the tree already uses for this (UIKit/CharonDynamics.h), and `static inline` in a
// header is one definition per translation unit that includes it, not a second copy in the tree.
//
// The matrices are built by assigning their columns, never by a braced initialiser. A
// matrix_double4x4 is a struct of four vector_double4 columns, so
//     matrix_double4x4 m = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}};
// initialises the FIRST column from the first group and warns "excess elements in struct
// initializer" for the other three. Measured, that form gives col0 1 1 1 1 with columns 1 to 3 all
// zero, and the port's stack product of a translate and a rotate came out with a zero bottom row
// where the system's is 0 0 0 1 - the whole class of a transform was wrong and the old differential
// read only the first number of the line, which is 0 either way.
//
// The angle of a rotation operation's animated scalar is in DEGREES, measured against the system:
// an operation set to 90 gives an exact quarter turn (col1 0 0 1, col2 0 -1 0), and one set to
// pi/2 gives 0 0.99962 0.02741, a turn of 0.02741 radians, and pi/2 degrees is 0.02742. MDLTransform's
// own rotation is radians - the other way round, measured: MDLTransform set to 90 gives
// 0 -0.44807 0.89400, a turn of ninety radians - which is why the two are not shared.

#import <Foundation/Foundation.h>
#import <simd/simd.h>

static inline matrix_double4x4 CharonMDLDouble4x4Identity(void)
{
    matrix_double4x4 identity;
    identity.columns[0] = (vector_double4){1, 0, 0, 0};
    identity.columns[1] = (vector_double4){0, 1, 0, 0};
    identity.columns[2] = (vector_double4){0, 0, 1, 0};
    identity.columns[3] = (vector_double4){0, 0, 0, 1};
    return identity;
}

static inline matrix_float4x4 CharonMDLFloat4x4(matrix_double4x4 value)
{
    matrix_float4x4 result;
    for (size_t c = 0; c < 4; c++)
        for (size_t r = 0; r < 4; r++)
            result.columns[c][r] = (float)value.columns[c][r];
    return result;
}

static inline matrix_double4x4 CharonMDLDouble4x4(matrix_float4x4 value)
{
    matrix_double4x4 result;
    for (size_t c = 0; c < 4; c++)
        for (size_t r = 0; r < 4; r++)
            result.columns[c][r] = value.columns[c][r];
    return result;
}

static inline matrix_double4x4 CharonMDLTranslation(vector_double3 translation)
{
    matrix_double4x4 result = CharonMDLDouble4x4Identity();
    result.columns[3] = (vector_double4){translation.x, translation.y, translation.z, 1};
    return result;
}

static inline matrix_double4x4 CharonMDLScale(vector_double3 scale)
{
    matrix_double4x4 result;
    result.columns[0] = (vector_double4){scale.x, 0, 0, 0};
    result.columns[1] = (vector_double4){0, scale.y, 0, 0};
    result.columns[2] = (vector_double4){0, 0, scale.z, 0};
    result.columns[3] = (vector_double4){0, 0, 0, 1};
    return result;
}

// One axis rotation by an angle in RADIANS, its inverse turning the other way by as much. A
// rotation about one axis turns the other two and leaves its own where it is, so the two columns it
// moves are the ones after it and the one after those.
static inline matrix_double4x4 CharonMDLAxisRotation(int axis, double angle)
{
    double c = cos(angle), s = sin(angle);
    matrix_double4x4 result = CharonMDLDouble4x4Identity();
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

// Three axis angles in radians composed in the order the operation was added with, the axes named
// as MDLTransformOpRotationOrder names them, so XYZ is the product of X, Y and Z in that order.
static inline matrix_double4x4 CharonMDLAngleRotation(vector_double3 angles, MDLTransformOpRotationOrder order)
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
    matrix_double4x4 result = CharonMDLAxisRotation(axes[index], values[orderOf[index]]);
    for (int k = index + 1; k < 3; k++)
        result = simd_mul(result, CharonMDLAxisRotation(axes[k], values[orderOf[k]]));
    return result;
}

// The rotation matrix of a quaternion, by its own four components: the imaginary part first and the
// real part last, which is the order a quaternion is written in.
static inline matrix_double4x4 CharonMDLQuaternionMatrix(simd_quatd rotation)
{
    double x = rotation.vector.x, y = rotation.vector.y, z = rotation.vector.z, w = rotation.vector.w;
    matrix_double4x4 result;
    result.columns[0] = (vector_double4){1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0};
    result.columns[1] = (vector_double4){2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0};
    result.columns[2] = (vector_double4){2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0};
    result.columns[3] = (vector_double4){0, 0, 0, 1};
    return result;
}
