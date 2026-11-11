#include <math.h>
#include <stdio.h>
#include <string.h>

static const double GIRDLE[8][2] = {{0.70024, 1}, {1, 0.70024}, {1, -0.70024}, {0.70024, -1},
                                    {-0.70024, -1}, {-1, -0.70024}, {-1, 0.70024}, {-0.70024, 1}};
static const double TABLE[8][2] = {{0.498552, 0.631807}, {0.631807, 0.498552}, {0.631807, -0.498552},
                                   {0.498552, -0.631807}, {-0.498552, -0.631807}, {-0.631807, -0.498552},
                                   {-0.631807, 0.498552}, {-0.498552, 0.631807}};
static const double SECTIONS[7][3] = {{0.965, 0.583526, 1}, {1, 0.571526, 1}, {0.990, -0.081806, 0},
                                      {1, -0.112806, 0}, {0.978, -0.151806, 0}, {0.025, -1.07157, 0},
                                      {0.009, -1.08757, 0}};

typedef struct {
    double v[3];
} V3;

typedef struct {
    const char *name;
    double v[4];
} Vector;

static const Vector STONE[] = {
    {"parameters", {0.5, 0.6, 1.0, 1.0}},
    {"sparkleShape", {0.3, 0.4, 0.5, 0.6}},
    {"sparkleHalo", {1.0, 0.25, 0.8, 0.5}},
    {"crownGradient", {0.2, 0.8, 0.4, 0.6}},
    {"pavilionGradient", {0.7, 0.3, 0.5, 0.9}},
    {"lightSweep", {0.1, 0.9, 0.5, 0.5}},
    {"facetProjection", {0.3, 0.2, 0.9, 0.5}},
    {"crownSweep", {0.4, 0.2, 0.6, 0.8}},
    {"rightCrownSweep", {0.5, 0.1, 0.2, 0.7}},
    {"leftCrownSweep", {0.6, 0.3, 0.1, 0.4}},
    {"pavilionSweep", {0.2, 0.5, 0.7, 0.3}},
    {"rightPavilionSweep", {0.8, 0.4, 0.3, 0.6}},
    {"leftPavilionSweep", {0.3, 0.7, 0.4, 0.2}},
    {"appearance", {0.0, 0.5, 0.25, 0.0}},
    {"referenceCrownFlash", {0.3, 0.1, 0.2, 0.5}},
    {"referencePavilionFlash", {0.6, 0.2, 0.1, 0.4}},
};

static const Vector LENS[] = {
    {"lens_parameters", {0.8, 0.6, 40, 0}},
    {"rect", {-32, -32, 64, 64}},
    {"uv", {0, 0, 1, 1}},
    {"center", {0, 0, 0, 0}},
};

static V3 v3(double x, double y, double z)
{
    V3 r = {{x, y, z}};
    return r;
}

static V3 sub(V3 a, V3 b)
{
    return v3(a.v[0] - b.v[0], a.v[1] - b.v[1], a.v[2] - b.v[2]);
}

static double dot(V3 a, V3 b)
{
    return a.v[0] * b.v[0] + a.v[1] * b.v[1] + a.v[2] * b.v[2];
}

static V3 cross(V3 a, V3 b)
{
    return v3(a.v[1] * b.v[2] - a.v[2] * b.v[1], a.v[2] * b.v[0] - a.v[0] * b.v[2], a.v[0] * b.v[1] - a.v[1] * b.v[0]);
}

static V3 normalize(V3 a)
{
    double length = sqrt(dot(a, a));
    return v3(a.v[0] / length, a.v[1] / length, a.v[2] / length);
}

static double planes[17][4];
static int planeCount = 0;

static void face(const V3 *input, int count, int kind)
{
    V3 p[8];
    for (int i = 0; i < count; i++)
        p[i] = input[i];
    V3 n = normalize(cross(sub(p[1], p[0]), sub(p[2], p[0])));
    V3 center = v3(0, 0, 0);
    for (int i = 0; i < count; i++)
        for (int k = 0; k < 3; k++)
            center.v[k] += p[i].v[k] / count;
    if (dot(n, sub(center, v3(0, -0.12, 0))) < 0) {
        for (int i = 0; i < count / 2; i++) {
            V3 t = p[i];
            p[i] = p[count - 1 - i];
            p[count - 1 - i] = t;
        }
        n = v3(-n.v[0], -n.v[1], -n.v[2]);
    }
    if (kind != 3) {
        planes[planeCount][0] = n.v[0];
        planes[planeCount][1] = n.v[1];
        planes[planeCount][2] = n.v[2];
        planes[planeCount][3] = -dot(n, p[0]);
        planeCount++;
    }
}

static void multiply(const double a[4][4], const double b[4][4], double out[4][4])
{
    double r[4][4];
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) {
            r[i][j] = 0;
            for (int k = 0; k < 4; k++)
                r[i][j] += a[i][k] * b[k][j];
        }
    memcpy(out, r, sizeof r);
}

static void identity(double m[4][4])
{
    memset(m, 0, sizeof(double) * 16);
    for (int i = 0; i < 4; i++)
        m[i][i] = 1;
}

static void flatten(const double m[4][4], int transposed, double flat[16])
{
    for (int c = 0; c < 4; c++)
        for (int r = 0; r < 4; r++)
            flat[c * 4 + r] = transposed ? m[c][r] : m[r][c];
}

static int memberCount;

static void member(FILE *out, const char *name, const double *v, int n)
{
    fprintf(out, "%s\"%s\": [", memberCount ? ", " : "", name);
    for (int i = 0; i < n; i++)
        fprintf(out, "%s%.9g", i ? ", " : "", v[i]);
    fprintf(out, "]");
    memberCount++;
}

static void writeSet(const char *directory, const char *name, int z, int w)
{
    char path[1024];
    snprintf(path, sizeof path, "%s/diamond_%s.data.json", directory, name);
    FILE *out = fopen(path, "w");
    if (!out)
        return;

    double rotation[4][4], rx[4][4], ry[4][4];
    double pitch = 0.35, yaw = 0.6;
    identity(rx);
    identity(ry);
    rx[1][1] = cos(pitch);
    rx[1][2] = -sin(pitch);
    rx[2][1] = sin(pitch);
    rx[2][2] = cos(pitch);
    ry[0][0] = cos(yaw);
    ry[0][2] = sin(yaw);
    ry[2][0] = -sin(yaw);
    ry[2][2] = cos(yaw);
    multiply(rx, ry, rotation);

    double near = 0.1, far = 10, fovy = 40 * M_PI / 180, focal = 1 / tan(fovy / 2);
    double projection[4][4], translate[4][4];
    identity(projection);
    memset(projection, 0, sizeof projection);
    projection[0][0] = focal;
    projection[1][1] = focal;
    projection[2][2] = (near + far) / (near - far);
    projection[2][3] = 2 * near * far / (near - far);
    projection[3][2] = -1;
    identity(translate);
    translate[2][3] = -4;
    multiply(projection, translate, projection);

    fprintf(out, "{\"arrays\": {\"planes\": [");
    for (int i = 0; i < 17; i++)
        for (int k = 0; k < 4; k++)
            fprintf(out, "%s%.9g", (i || k) ? ", " : "", planes[i][k]);
    fprintf(out, "], \"edges\": [");
    for (int i = 0; i < 128; i++) {
        double e[4] = {0, 0, 0, 0};
        if (i < w) {
            double a[2] = {90.0 * cos(2 * M_PI * i / w), 90.0 * sin(2 * M_PI * i / w)};
            double b[2] = {90.0 * cos(2 * M_PI * ((i + 1) % w) / w), 90.0 * sin(2 * M_PI * ((i + 1) % w) / w)};
            double dx = b[0] - a[0], dy = b[1] - a[1];
            double length = fmax(sqrt(dx * dx + dy * dy), 0.0001);
            double nx = -dy / length, ny = dx / length;
            e[0] = nx;
            e[1] = ny;
            e[2] = -(nx * a[0] + ny * a[1]);
        }
        for (int k = 0; k < 4; k++)
            fprintf(out, "%s%.9g", (i || k) ? ", " : "", e[k]);
    }
    fprintf(out, "]}, \"members\": {");
    memberCount = 0;
    double flat[16];
    flatten(rotation, 0, flat);
    member(out, "model", flat, 16);
    flatten(projection, 0, flat);
    member(out, "projection", flat, 16);
    flatten(rotation, 1, flat);
    member(out, "inverseModel", flat, 16);
    double viewport[4] = {64, 64, z, 0};
    member(out, "viewport", viewport, 4);
    member(out, "u_viewport", viewport, 4);
    for (size_t i = 0; i < sizeof STONE / sizeof STONE[0]; i++)
        member(out, STONE[i].name, STONE[i].v, 4);
    member(out, "u_parameters", STONE[0].v, 4);
    double lensViewport[4] = {32, 32, 2, w};
    member(out, "lens_viewport", lensViewport, 4);
    for (size_t i = 0; i < sizeof LENS / sizeof LENS[0]; i++)
        member(out, LENS[i].name, LENS[i].v, 4);
    fprintf(out, "}}\n");
    fclose(out);
}

int main(int argc, const char *argv[])
{
    if (argc < 2)
        return 2;
    V3 rings[7][8];
    for (int s = 0; s < 7; s++)
        for (int i = 0; i < 8; i++) {
            const double *outline = SECTIONS[s][2] != 0 ? TABLE[i] : GIRDLE[i];
            rings[s][i] = v3(outline[0] * SECTIONS[s][0], SECTIONS[s][1], outline[1] * SECTIONS[s][0]);
        }
    face(rings[0], 8, 0);
    for (int band = 0; band < 6; band++)
        for (int i = 0; i < 8; i++) {
            int next = (i + 1) % 8;
            V3 quad[4] = {rings[band][i], rings[band + 1][i], rings[band + 1][next], rings[band][next]};
            face(quad, 4, band == 1 ? 1 : (band == 4 ? 2 : 3));
        }
    face(rings[6], 8, 3);
    if (planeCount != 17) {
        fprintf(stderr, "planes %d\n", planeCount);
        return 1;
    }
    writeSet(argv[1], "zero", 0, 0);
    writeSet(argv[1], "one", 1, 3);
    writeSet(argv[1], "mid", 8, 64);
    writeSet(argv[1], "max", 17, 128);
    printf("planes %d\n", planeCount);
    return 0;
}
