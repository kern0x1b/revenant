#import "CharonARTracker.h"

#import <CoreVideo/CoreVideo.h>
#import <simd/simd.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static simd_float3x3 CharonSyntheticIntrinsics(NSUInteger width, NSUInteger height)
{
    const float halfAngleTangent = 0.5773502692f;
    float focal = ((float)width / 2.0f) / halfAngleTangent;
    simd_float3x3 intrinsics;
    intrinsics.columns[0] = simd_make_float3(focal, 0, 0);
    intrinsics.columns[1] = simd_make_float3(0, focal, 0);
    intrinsics.columns[2] = simd_make_float3((float)width / 2.0f, (float)height / 2.0f, 1);
    return intrinsics;
}


#pragma mark - The ground truth

typedef struct {
    simd_quatf rotation;
    simd_float3 translation;
} CharonTruth;

static CharonTruth CharonTruthAt(int i, float stepAngle, float stepLength)
{
    CharonTruth truth;
    float angle = (float)i * stepAngle;
    float x = 0.0f, z = 0.0f;
    int step;
    for (step = 0; step < i; step++) {
        x += stepLength * sinf((float)step * stepAngle);
        z += stepLength * cosf((float)step * stepAngle);
    }
    truth.rotation = simd_quaternion(0.0f, sinf(angle / 2.0f), 0.0f, cosf(angle / 2.0f));
    truth.translation = (simd_float3){x, 0.0f, z};
    return truth;
}

static simd_float3 CharonSpecificForceAt(int i, float stepAngle, float stepLength, float dt)
{
    CharonTruth before = CharonTruthAt(i - 1 >= 0 ? i - 1 : 0, stepAngle, stepLength);
    CharonTruth after = CharonTruthAt(i, stepAngle, stepLength);
    simd_float3 step = { after.translation.x - before.translation.x,
                         after.translation.y - before.translation.y,
                         after.translation.z - before.translation.z };
    simd_float3 earlier = { 0, 0, 0 };
    if (i >= 2) {
        CharonTruth back = CharonTruthAt(i - 2, stepAngle, stepLength);
        earlier = (simd_float3){ step.x - (before.translation.x - back.translation.x),
                                 step.y - (before.translation.y - back.translation.y),
                                 step.z - (before.translation.z - back.translation.z) };
    }
    simd_float3 worldAcceleration = { (step.x - earlier.x) / (dt * dt), (step.y - earlier.y) / (dt * dt),
                                      (step.z - earlier.z) / (dt * dt) };
    simd_float4x4 worldFromDevice = CharonQuaternionMatrix(after.rotation);
    simd_float3 inWorld = { worldAcceleration.x, worldAcceleration.y, worldAcceleration.z + 9.80665f };
    return simd_make_float3(
            worldFromDevice.columns[0][0] * inWorld.x + worldFromDevice.columns[1][0] * inWorld.y +
            worldFromDevice.columns[2][0] * inWorld.z,
            worldFromDevice.columns[0][1] * inWorld.x + worldFromDevice.columns[1][1] * inWorld.y +
            worldFromDevice.columns[2][1] * inWorld.z,
            worldFromDevice.columns[0][2] * inWorld.x + worldFromDevice.columns[1][2] * inWorld.y +
            worldFromDevice.columns[2][2] * inWorld.z);
}


static float clampf(float value, float low, float high)
{
    return value < low ? low : (value > high ? high : value);
}

static simd_float3 CharonRotated(simd_float3 v, simd_quatf q)
{
    simd_float3 u = (simd_float3){q.vector.x, q.vector.y, q.vector.z};
    simd_float3 t = 2.0f * simd_cross(u, v);
    return v + q.vector.w * t + simd_cross(u, t);
}

#pragma mark - The frame the camera would see

static void CharonRenderFrame(uint8_t *luma, NSUInteger width, NSUInteger height,
                              CharonTruth truth, float rotationNoise)
{
    NSUInteger x, y;
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            float px = ((float)x / (float)width - 0.5f) * 2.0f;
            float py = (0.5f - (float)y / (float)height) * 2.0f;
            simd_float3 direction = simd_normalize((simd_float3){px * 0.5773502692f,
                                                                  py * 0.5773502692f, -1.0f});
            simd_quatf attitude = simd_quaternion(truth.rotation.vector.x,
                                                   truth.rotation.vector.y,
                                                   truth.rotation.vector.z,
                                                   truth.rotation.vector.w + rotationNoise);
            simd_float3 turned = CharonRotated(direction, attitude);
            float distance = 2.0f / (turned.z < -0.01f ? -turned.z : 0.01f);
            simd_float3 hit = turned * distance + truth.translation;
            float value = 0.6f * sinf(hit.x * 25.0f) + 0.5f * cosf(hit.y * 25.0f)
                         + 0.4f * sinf((hit.x + hit.z) * 25.0f) + 0.3f * cosf(hit.z * 25.0f);
            luma[y * width + x] = (uint8_t)clampf(128.0f + value * 100.0f, 0.0f, 255.0f);
        }
    }
}

#pragma mark - The comparison

static float CharonAngleBetween(simd_quatf a, simd_quatf b)
{
    float dot = fabsf(a.vector.x * b.vector.x + a.vector.y * b.vector.y +
                      a.vector.z * b.vector.z + a.vector.w * b.vector.w);
    return 2.0f * acosf(fminf(1.0f, dot));
}

static simd_quatf CharonAttitudeOf(simd_float4x4 pose)
{
    float trace = pose.columns[0][0] + pose.columns[1][1] + pose.columns[2][2];
    if (trace > 0.0f) {
        float s = sqrtf(trace + 1.0f) * 2.0f;
        return simd_normalize(simd_quaternion((pose.columns[1][2] - pose.columns[2][1]) / s,
                              (pose.columns[2][0] - pose.columns[0][2]) / s,
                              (pose.columns[0][1] - pose.columns[1][0]) / s,
                              0.25f * s));
    }
    if (pose.columns[0][0] > pose.columns[1][1] && pose.columns[0][0] > pose.columns[2][2]) {
        float s = sqrtf(1.0f + pose.columns[0][0] - pose.columns[1][1] - pose.columns[2][2]) * 2.0f;
        return simd_normalize(simd_quaternion(0.25f * s,
                                              (pose.columns[0][1] + pose.columns[1][0]) / s,
                                              (pose.columns[0][2] + pose.columns[2][0]) / s,
                                              (pose.columns[1][2] - pose.columns[2][1]) / s));
    }
    float s = sqrtf(1.0f + pose.columns[2][2] - pose.columns[0][0] - pose.columns[1][1]) * 2.0f;
    return simd_normalize(simd_quaternion((pose.columns[0][1] + pose.columns[1][0]) / s,
                                          0.25f * s,
                                          (pose.columns[1][2] + pose.columns[2][1]) / s,
                                          (pose.columns[2][0] - pose.columns[0][2]) / s));
}

int main(void)
{
    const NSUInteger width = 160, height = 120;
    const int count = 100;
    const float stepAngle = 0.10f;
    const float stepLength = 0.05f;
    const float rotationNoise = 0.002f;
    const float translationNoise = 0.002f;

    uint8_t **planes = calloc((size_t)count, sizeof *planes);
    if (!planes) {
        printf("no memory for the frame list\n");
        return 1;
    }
    for (int step = 0; step < count; step++) {
        planes[step] = (uint8_t *)calloc(width * height, 1);
        if (!planes[step]) {
            printf("no memory for the frames\n");
            return 1;
        }
    }
    for (int step = 0; step < count; step++)
        CharonRenderFrame(planes[step], width, height, CharonTruthAt(step, stepAngle, stepLength), rotationNoise);

    CharonARTracker *tracker = [[CharonARTracker alloc] init];
    [CharonARTracker useCameraIntrinsics:CharonSyntheticIntrinsics(width, height)];
    double sumRotation = 0, sumDistance = 0, worstRotation = 0, worstDistance = 0;
    int measured = 0;
    for (int step = 0; step < count; step++) {
        CharonTruth truth = CharonTruthAt(step, stepAngle, stepLength);
        truth.translation.x += translationNoise;

        CVPixelBufferRef buffer = NULL;
        if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8,
                                NULL, &buffer) != kCVReturnSuccess || !buffer) {
            printf("no pixel buffer\n");
            return 1;
        }
        CVPixelBufferLockBaseAddress(buffer, 0);
        uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(buffer);
        size_t stride = CVPixelBufferGetBytesPerRow(buffer);
        for (NSUInteger y = 0; y < height; y++)
            memcpy(base + y * stride, planes[step] + y * width, width);
        CVPixelBufferUnlockBaseAddress(buffer, 0);

        tracker.measuredAcceleration = CharonSpecificForceAt(step, stepAngle, stepLength, 1.0 / 30.0);
        simd_float4x4 got = [tracker processPixelBuffer:buffer
                                 captureTime:(double)step / 30.0
                             deviceRotation:truth.rotation];
        CVPixelBufferRelease(buffer);

        simd_float3 walked = (simd_float3){got.columns[3].x, got.columns[3].y, got.columns[3].z};
        double rotation = CharonAngleBetween(CharonAttitudeOf(got), truth.rotation);
        if (step < 4 || step == count - 1)
            printf("  step %2d: pose rotation error %8.3f deg   distance error %8.4f m\n", step,
                   rotation * 180.0 / M_PI, simd_length(walked - truth.translation));
        double distance = simd_length(walked - truth.translation);
        sumRotation += rotation;
        sumDistance += distance;
        if (rotation > worstRotation) worstRotation = rotation;
        if (distance > worstDistance) worstDistance = distance;
        measured++;
    }

    printf("spatial tracker differential: %d frames, %.2f degrees and %.3f m a step,\n",
           count, stepAngle * 180.0 / M_PI, stepLength);
    printf("  driven %.3f m along the path, the last pose truth at %.3f m\n",
           (count - 1) * stepLength, (count - 1) * stepLength);
    if (measured == 0) {
        printf("  nothing measured: the tracker never reported a pose\n");
        return 1;
    }
    printf("  rotation error: mean %.5f rad (%.3f deg), worst %.5f rad (%.3f deg)\n",
           sumRotation / measured, (sumRotation / measured) * 180.0 / M_PI,
           worstRotation, worstRotation * 180.0 / M_PI);
    printf("  distance error: mean %.5f m, worst %.5f m\n", sumDistance / measured, worstDistance);
    printf("  tracking: %s, %lu points, %lu planes\n",
           [tracker isTracking] ? "yes" : "no",
           (unsigned long)([tracker pointCloud].length / 12),
           (unsigned long)[[tracker planes] count]);
    return 0;
}
