#import "VNRectangleDetector.h"
#import "VNRectangleImage.h"
#import <Vision/Vision.h>
#import <CoreGraphics/CoreGraphics.h>
#include <algorithm>
#include <cmath>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#import <objc/runtime.h>

@interface VNRectangleObservation (RevenantRectangleTestCorners)
- (void)revenant_setCornersTopLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft;
- (NSArray<NSArray<NSNumber *> *> *)revenant_testCorners;
@end

@implementation VNRectangleObservation (RevenantRectangleTestCorners)
- (void)revenant_setCornersTopLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft
{
    objc_setAssociatedObject(self, @selector(revenant_testCorners), @[@[@(topLeft.x), @(topLeft.y)], @[@(topRight.x), @(topRight.y)], @[@(bottomRight.x), @(bottomRight.y)], @[@(bottomLeft.x), @(bottomLeft.y)]], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSArray<NSArray<NSNumber *> *> *)revenant_testCorners
{
    return objc_getAssociatedObject(self, @selector(revenant_testCorners));
}
@end

static void check_at(bool value, int line)
{
    if (!value) {
        std::fprintf(stderr, "rectangle test failure at line %d\n", line);
        std::abort();
    }
}

#define check(value) check_at((value), __LINE__)

struct Quad { CGPoint points[4]; };

static std::vector<uint8_t> fixture(size_t width, size_t height, const Quad *quads, size_t count, bool noise)
{
    std::vector<uint8_t> pixels(width * height, 245);
    if (noise) {
        uint32_t state = 0x8b31;
        for (uint8_t& value : pixels) {
            state = state * 1664525u + 1013904223u;
            value = (uint8_t)(120 + ((state >> 24) % 17));
        }
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(pixels.data(), width, height, 8, width, colorSpace, kCGImageAlphaNone);
    check(context != NULL);
    if (!noise) {
        CGContextSetGrayStrokeColor(context, 0.02, 1);
        CGContextSetLineWidth(context, 7);
        for (size_t i = 0; i < count; ++i) {
            CGContextMoveToPoint(context, quads[i].points[0].x, quads[i].points[0].y);
            for (int j = 1; j < 4; ++j)
                CGContextAddLineToPoint(context, quads[i].points[j].x, quads[i].points[j].y);
            CGContextClosePath(context);
            CGContextStrokePath(context);
        }
    }
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    return pixels;
}

static RevenantVisionRectangleOptions options(size_t maximum)
{
    return {0.2f, 1.0f, 35.0f, 0.2f, 0.3f, maximum};
}

static float corner_error(const RevenantVisionRectangle& result, const Quad& expected, size_t width, size_t height)
{
    float best = INFINITY;
    for (int a = 0; a < 4; ++a)
        for (int b = 0; b < 4; ++b)
            for (int c = 0; c < 4; ++c)
                for (int d = 0; d < 4; ++d) {
                    int permutation[4] = {a, b, c, d};
                    if (a == b || a == c || a == d || b == c || b == d || c == d) continue;
                    float maximum = 0;
                    for (int i = 0; i < 4; ++i) {
                        float ex = (float)(expected.points[i].x / width);
                        float ey = (float)(expected.points[i].y / height);
                        float dx = result.corners[permutation[i]].x - ex;
                        float dy = result.corners[permutation[i]].y - ey;
                        maximum = std::max(maximum, std::sqrt(dx * dx * width * width + dy * dy * height * height));
                    }
                    best = std::min(best, maximum);
                }
    return best;
}

static size_t detect(const std::vector<uint8_t>& pixels, size_t width, size_t height,
                     RevenantVisionRectangleOptions request, RevenantVisionRectangle *result, size_t capacity)
{
    return RevenantVisionDetectRectangles(pixels.data(), width, height, width, request, result, capacity);
}

int main(int argc, char **argv)
{
    bool negative = argc > 1 && std::strcmp(argv[1], "--negative") == 0;
    VNDetectRectanglesRequest *request = [[VNDetectRectanglesRequest alloc] init];
    const size_t width = 640, height = 480;
    Quad rotated = {{{110, 135}, {280, 80}, {330, 230}, {160, 285}}};
    auto one = fixture(width, height, &rotated, 1, false);
    RevenantVisionRectangle result[8];
    size_t count = detect(one, width, height, options(4), result, 8);
    check((count == 1) != negative);
    float rotated_error = corner_error(result[0], rotated, width, height);
    check(rotated_error <= 0.5f);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, one.data(), one.size(), NULL);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGImageRef image = CGImageCreate(width, height, 8, 8, width, colorSpace, kCGImageAlphaNone, provider, NULL, false, kCGRenderingIntentDefault);
    request.minimumAspectRatio = 0.2f;
    request.maximumAspectRatio = 1.0f;
    request.minimumSize = 0.2f;
    request.minimumConfidence = 0.3f;
    request.quadratureTolerance = 35.0f;
    request.maximumObservations = 4;
    NSError *error = nil;
    NSArray *observations = RevenantVisionRectangles((__bridge id)image, kCGImagePropertyOrientationUp, request, &error);
    check(error == nil && observations.count == 1);
    VNRectangleObservation *observation = observations[0];
    NSArray<NSArray<NSNumber *> *> *mappedCorners = [observation revenant_testCorners];
    check(mappedCorners.count == 4);
    Quad mapped = {{{[mappedCorners[0][0] doubleValue] * width, [mappedCorners[0][1] doubleValue] * height},
                    {[mappedCorners[1][0] doubleValue] * width, [mappedCorners[1][1] doubleValue] * height},
                    {[mappedCorners[2][0] doubleValue] * width, [mappedCorners[2][1] doubleValue] * height},
                    {[mappedCorners[3][0] doubleValue] * width, [mappedCorners[3][1] doubleValue] * height}}};
    RevenantVisionRectangle mappedResult = {};
    for (int i = 0; i < 4; ++i) {
        mappedResult.corners[i].x = (float)(mapped.points[i].x / width);
        mappedResult.corners[i].y = (float)(mapped.points[i].y / height);
    }
    float mapped_error = corner_error(mappedResult, rotated, width, height);
    check(mapped_error <= 1.25f);
    CGImageRelease(image);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    Quad pair[2] = {rotated, {{{390, 90}, {570, 90}, {570, 250}, {390, 250}}}};
    auto two = fixture(width, height, pair, 2, false);
    count = detect(two, width, height, options(4), result, 8);
    check(count == 2);
    count = detect(two, width, height, options(1), result, 8);
    check(count == 1);

    Quad card = {{{115, 80}, {505, 145}, {480, 395}, {145, 330}}};
    auto perspective = fixture(width, height, &card, 1, false);
    count = detect(perspective, width, height, options(4), result, 8);
    check(count == 1);
    float perspective_error = corner_error(result[0], card, width, height);
    check(perspective_error <= 0.5f);

    auto noise = fixture(width, height, NULL, 0, true);
    count = detect(noise, width, height, options(4), result, 8);
    check(count == 0);
    RevenantVisionRectangleOptions filtered = options(4);
    filtered.minimum_size = 0.9f;
    check(detect(perspective, width, height, filtered, result, 8) == 0);
    filtered = options(4); filtered.minimum_aspect_ratio = 0.95f;
    check(detect(one, width, height, filtered, result, 8) == 0);
    filtered = options(4); filtered.maximum_aspect_ratio = 0.4f;
    check(detect(one, width, height, filtered, result, 8) == 0);
    filtered = options(4); filtered.minimum_confidence = 1.01f;
    check(detect(one, width, height, filtered, result, 8) == 0);
    filtered = options(4); filtered.quadrature_tolerance = 10.0f;
    check(detect(perspective, width, height, filtered, result, 8) == 0);

    CGRect imageRect = VNImageRectForNormalizedRect(CGRectMake(0.1, 0.2, 0.4, 0.3), 640, 480);
    CGPoint imagePoint = VNImagePointForNormalizedPoint(CGPointMake(0.25, 0.75), 640, 480);
    check(fabs(imageRect.origin.x - 64) < 0.001 && fabs(imageRect.origin.y - 96) < 0.001);
    check(fabs(imageRect.size.width - 256) < 0.001 && fabs(imageRect.size.height - 144) < 0.001);
    check(fabs(imagePoint.x - 160) < 0.001 && fabs(imagePoint.y - 360) < 0.001);

    RevenantVisionRectangleOptions timingOptions = options(4);
    for (int i = 0; i < 10; ++i) detect(one, width, height, timingOptions, result, 8);
    auto start = std::chrono::steady_clock::now();
    const int iterations = 300;
    for (int i = 0; i < iterations; ++i) detect(one, width, height, timingOptions, result, 8);
    auto elapsed = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count() / iterations;
    std::printf("rectangle-corner-error-max-px=%.2f\n", std::max({rotated_error, perspective_error, mapped_error}));
    std::printf("rectangle-host-640x480-ms-per-frame=%.3f\n", elapsed);
}
