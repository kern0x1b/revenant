#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <CoreGraphics/CoreGraphics.h>

enum { WIDE = 64, HIGH = 48 };

static CGImageRef picture(int scene)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(NULL, WIDE, HIGH, 8, WIDE, space, kCGImageAlphaNone);
    CGColorSpaceRelease(space);
    CGContextSetGrayFillColor(context, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, WIDE, HIGH));
    CGContextSetGrayFillColor(context, 1, 1);
    switch (scene) {
    case 0:
        CGContextFillRect(context, CGRectMake(10, 8, 30, 20));
        break;
    case 1:
        CGContextFillRect(context, CGRectMake(8, 6, 40, 36));
        CGContextSetGrayFillColor(context, 0, 1);
        CGContextFillRect(context, CGRectMake(16, 14, 24, 20));
        break;
    case 2:
        CGContextFillRect(context, CGRectMake(4, 4, 14, 10));
        CGContextFillRect(context, CGRectMake(40, 30, 16, 12));
        break;
    case 3:
        CGContextFillRect(context, CGRectMake(6, 4, 46, 40));
        CGContextSetGrayFillColor(context, 0, 1);
        CGContextFillRect(context, CGRectMake(12, 10, 34, 28));
        CGContextSetGrayFillColor(context, 1, 1);
        CGContextFillRect(context, CGRectMake(22, 18, 12, 8));
        break;
    case 4:
        CGContextSetShouldAntialias(context, false);
        CGContextFillEllipseInRect(context, CGRectMake(12, 8, 36, 30));
        break;
    case 5:
        CGContextFillRect(context, CGRectMake(10, 10, 12, 12));
        CGContextFillRect(context, CGRectMake(22, 22, 12, 12));
        break;
    case 6:
        for (int row = 0; row < 3; row++)
            for (int column = 0; column < 4; column++)
                if ((row + column) % 2 == 0)
                    CGContextFillRect(context, CGRectMake(column * 8, row * 8, 8, 8));
        break;
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static NSComparator canonical = ^NSComparisonResult(VNContour *a, VNContour *b) {
    if (a.pointCount != b.pointCount)
        return a.pointCount < b.pointCount ? NSOrderedAscending : NSOrderedDescending;
    simd_float2 pa = a.normalizedPoints[0], pb = b.normalizedPoints[0];
    if (pa.x != pb.x)
        return pa.x < pb.x ? NSOrderedAscending : NSOrderedDescending;
    return pa.y < pb.y ? NSOrderedAscending : (pa.y > pb.y ? NSOrderedDescending : NSOrderedSame);
};

static void show(VNContour *contour, NSString *indent)
{
    printf("%scontour points=%ld children=%ld aspect=%.6g\n", indent.UTF8String, (long)contour.pointCount,
           (long)contour.childContourCount, contour.aspectRatio);
    for (NSInteger i = 0; i < contour.pointCount; i++) {
        simd_float2 point = contour.normalizedPoints[i];
        printf("%s  point %ld %.6g %.6g\n", indent.UTF8String, (long)i, point.x, point.y);
    }
    for (VNContour *child in [contour.childContours sortedArrayUsingComparator:canonical])
        show(child, [indent stringByAppendingString:@"  "]);
}

int main(void)
{
    for (int scene = 0; scene < 7; scene++) {
        for (int dark = 0; dark < 2; dark++) {
            CGImageRef image = picture(scene);
            VNDetectContoursRequest *request = [[VNDetectContoursRequest alloc] initWithCompletionHandler:nil];
            request.detectsDarkOnLight = dark ? YES : NO;
            VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image options:@{}];
            NSError *error = nil;
            BOOL ok = [handler performRequests:@[request] error:&error];
            printf("scene %d dark=%d performed=%d error=%ld\n", scene, dark, ok, (long)error.code);
            VNContoursObservation *observation = request.results.firstObject;
            if (observation == nil) {
                printf("  no observation\n");
            } else {
                printf("  contours=%ld topLevel=%ld\n", (long)observation.contourCount, (long)observation.topLevelContourCount);
                for (VNContour *contour in [observation.topLevelContours sortedArrayUsingComparator:canonical])
                    show(contour, @"  ");
            }
            CGImageRelease(image);
        }
    }
    return 0;
}
