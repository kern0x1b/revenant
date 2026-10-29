#import "check.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#import "RevenantQRCode.h"

static NSData *revenant_render(NSString *text, NSString *level, int scale, double degrees, double blur, int *width, int *height, NSData *raw)
{
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:raw ?: [text dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [filter setValue:level forKey:@"inputCorrectionLevel"];
    CIImage *image = filter.outputImage;
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef modules = [context createCGImage:image fromRect:image.extent];
    int count = (int)CGImageGetWidth(modules);
    double side = (count + 8) * scale;
    double radians = degrees * M_PI / 180.0;
    int canvas = (int)ceil(side * (fabs(cos(radians)) + fabs(sin(radians)))) + 2 * scale;
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, canvas, canvas, 8, canvas, gray, kCGImageAlphaNone);
    CGColorSpaceRelease(gray);
    CGContextSetGrayFillColor(bitmap, 1, 1);
    CGContextFillRect(bitmap, CGRectMake(0, 0, canvas, canvas));
    CGContextTranslateCTM(bitmap, canvas / 2.0, canvas / 2.0);
    CGContextRotateCTM(bitmap, radians);
    CGContextSetInterpolationQuality(bitmap, kCGInterpolationNone);
    CGContextDrawImage(bitmap, CGRectMake(-count * scale / 2.0, -count * scale / 2.0, count * scale, count * scale), modules);
    CGImageRelease(modules);
    NSMutableData *pixels = [NSMutableData dataWithBytes:CGBitmapContextGetData(bitmap) length:(NSUInteger)canvas * canvas];
    CGContextRelease(bitmap);
    if (blur > 0) {
        NSMutableData *blurred = [pixels mutableCopy];
        const uint8_t *source = pixels.bytes;
        uint8_t *target = blurred.mutableBytes;
        int radius = (int)blur;
        for (int y = radius; y < canvas - radius; y++) {
            for (int x = radius; x < canvas - radius; x++) {
                int sum = 0, taps = 0;
                for (int dy = -radius; dy <= radius; dy++)
                    for (int dx = -radius; dx <= radius; dx++) {
                        sum += source[(y + dy) * canvas + x + dx];
                        taps++;
                    }
                target[y * canvas + x] = (uint8_t)(sum / taps);
            }
        }
        pixels = blurred;
    }
    *width = canvas;
    *height = canvas;
    return pixels;
}

static NSString *revenant_decode(NSData *pixels, int width, int height, int *version, int *level)
{
    RevenantQRResult results[REVENANT_QR_MAX_RESULTS];
    int found = revenant_qr_decode(pixels.bytes, width, height, width, results, REVENANT_QR_MAX_RESULTS);
    if (!found)
        return nil;
    NSString *text = [[NSString alloc] initWithBytes:results[0].text length:results[0].length encoding:NSUTF8StringEncoding];
    if (version)
        *version = results[0].version;
    if (level)
        *level = results[0].level;
    for (int index = 0; index < found; index++)
        revenant_qr_result_free(&results[index]);
    return text;
}

static NSString *revenant_text(NSUInteger length)
{
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger index = 0; index < length; index++)
        [text appendFormat:@"%c", (char)('a' + (index * 7 + index / 3) % 26)];
    return text;
}

static NSArray *revenant_region_texts(const uint8_t *pixels, int pairWidth, int height, float x, float regionWidth, float *smallestX, float *largestX)
{
    RevenantQRResult results[REVENANT_QR_MAX_RESULTS];
    int found = revenant_qr_decode_region(pixels, pairWidth, height, pairWidth, x, 0, regionWidth, 1, results, REVENANT_QR_MAX_RESULTS);
    NSMutableArray *texts = [NSMutableArray array];
    *smallestX = (float)pairWidth;
    *largestX = 0;
    for (int index = 0; index < found; index++) {
        [texts addObject:[[NSString alloc] initWithBytes:results[index].text length:results[index].length encoding:NSUTF8StringEncoding] ?: @""];
        for (int corner = 0; corner < 4; corner++) {
            *smallestX = MIN(*smallestX, results[index].corners[corner][0]);
            *largestX = MAX(*largestX, results[index].corners[corner][0]);
        }
        revenant_qr_result_free(&results[index]);
    }
    return texts;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    int width, height;
    NSArray *levels = @[@"L", @"M", @"Q", @"H"];
    NSArray *texts = @[@"Hello, world", @"0123456789012345678901234567890", @"HELLO WORLD $%*+-./: 42", @"Привіт, світе! 你好 é", @"https://example.com/path?query=value&other=1",
                       revenant_text(150), revenant_text(400), revenant_text(900), revenant_text(1800)];
    int failures = 0, checked = 0;
    NSString *first = nil;
    NSMutableIndexSet *versions = [NSMutableIndexSet indexSet];
    for (NSString *text in texts) {
        for (NSString *level in levels) {
            if (text.length > 1500 && ![level isEqualToString:@"L"] && ![level isEqualToString:@"M"])
                continue;
            NSData *pixels = revenant_render(text, level, 4, 0, 0, &width, &height, nil);
            int version = 0;
            NSString *decoded = revenant_decode(pixels, width, height, &version, NULL);
            checked++;
            if (version)
                [versions addIndex:(NSUInteger)version];
            if (![decoded isEqualToString:text]) {
                failures++;
                if (!first)
                    first = [NSString stringWithFormat:@"level %@ length %lu gave %@", level, (unsigned long)text.length, decoded ? @"another text" : @"nothing"];
            }
        }
    }
    revenant_check(failures == 0, "every text decodes at every correction level", first ?: @"all decoded");
    revenant_check(versions.count >= 10, "many versions were covered", [NSString stringWithFormat:@"%lu versions", (unsigned long)versions.count]);
    NSMutableSet *covered = [NSMutableSet set];
    int sweepFailures = 0;
    for (NSString *level in levels) {
        for (NSUInteger length = 1; length <= 2953; length += MAX((NSUInteger)1, length / 25)) {
            NSString *text = revenant_text(length);
            NSData *pixels = revenant_render(text, level, 3, 0, 0, &width, &height, nil);
            int version = 0, found = 0;
            NSString *decoded = revenant_decode(pixels, width, height, &version, &found);
            if (decoded && [decoded isEqualToString:text])
                [covered addObject:[NSString stringWithFormat:@"%d%@", version, level]];
            else if (decoded || (length < 1273 || ([level isEqualToString:@"L"] && length < 2953) || ([level isEqualToString:@"M"] && length < 2331)))
            {
                sweepFailures++;
                printf("sweep failure level %s length %lu decoded %s\n", level.UTF8String, (unsigned long)length, decoded ? "other" : "nothing");
            }
        }
    }
    revenant_check(sweepFailures == 0, "a sweep of lengths decodes at every level", [NSString stringWithFormat:@"%d failures", sweepFailures]);
    revenant_check(covered.count >= 150, "nearly every version and level pair was covered", [NSString stringWithFormat:@"%lu pairs", (unsigned long)covered.count]);
    NSString *sample = @"Rotation and scale test 12345";
    NSArray *angles = @[@0, @90, @180, @270, @17, @-33, @45, @133];
    for (NSNumber *angle in angles) {
        NSData *pixels = revenant_render(sample, @"M", 5, angle.doubleValue, 0, &width, &height, nil);
        NSString *decoded = revenant_decode(pixels, width, height, NULL, NULL);
        revenant_check([decoded isEqualToString:sample], "a rotated code decodes", [NSString stringWithFormat:@"%@ degrees gave %@", angle, decoded]);
    }
    for (int scale = 2; scale <= 9; scale += 7) {
        NSData *pixels = revenant_render(sample, @"Q", scale, 8, 0, &width, &height, nil);
        revenant_check([revenant_decode(pixels, width, height, NULL, NULL) isEqualToString:sample], "a small and a large code decode", [NSString stringWithFormat:@"scale %d", scale]);
    }
    NSData *blurred = revenant_render(sample, @"H", 6, 4, 1, &width, &height, nil);
    revenant_check([revenant_decode(blurred, width, height, NULL, NULL) isEqualToString:sample], "a blurred code decodes", @"nothing");
    NSMutableData *damaged = [revenant_render(sample, @"H", 6, 0, 0, &width, &height, nil) mutableCopy];
    uint8_t *bytes = damaged.mutableBytes;
    for (int y = height / 2 - 12; y < height / 2 + 12; y++)
        for (int x = width / 2 - 12; x < width / 2 + 12; x++)
            bytes[y * width + x] = (uint8_t)((x ^ y) & 1 ? 255 : 0);
    revenant_check([revenant_decode(damaged, width, height, NULL, NULL) isEqualToString:sample], "damage within the correction capacity is repaired", @"nothing");
    NSMutableData *noise = [NSMutableData dataWithLength:300 * 300];
    uint8_t *noiseBytes = noise.mutableBytes;
    uint32_t state = 12345;
    for (int index = 0; index < 300 * 300; index++) {
        state = state * 1664525u + 1013904223u;
        noiseBytes[index] = (uint8_t)(state >> 24);
    }
    revenant_check(revenant_decode(noise, 300, 300, NULL, NULL) == nil, "noise decodes to nothing", @"decoded");
    NSMutableData *blank = [NSMutableData dataWithLength:300 * 300];
    memset(blank.mutableBytes, 255, blank.length);
    revenant_check(revenant_decode(blank, 300, 300, NULL, NULL) == nil, "a blank image decodes to nothing", @"decoded");
    NSData *two = revenant_render(@"first", @"L", 4, 0, 0, &width, &height, nil);
    NSString *expected = revenant_negative ? @"firsT" : @"first";
    revenant_check([revenant_decode(two, width, height, NULL, NULL) isEqualToString:expected], "the decoded text is the encoded text", @"differs");
    NSData *leftPixels = revenant_render(@"LEFT-CODE-001", @"M", 4, 0, 0, &width, &height, nil);
    int side = width;
    NSData *rightPixels = revenant_render(@"RIGHT-CODE-02", @"M", 4, 0, 0, &width, &height, nil);
    revenant_check(width == side && height == side, "two codes of one length render at one size", @"the sizes differ");
    int pairWidth = side * 2;
    NSMutableData *pair = [NSMutableData dataWithLength:(NSUInteger)pairWidth * side];
    uint8_t *frame = pair.mutableBytes;
    const uint8_t *leftBytes = leftPixels.bytes, *rightBytes = rightPixels.bytes;
    for (int y = 0; y < side; y++) {
        memcpy(frame + (size_t)y * pairWidth, leftBytes + (size_t)y * side, side);
        memcpy(frame + (size_t)y * pairWidth + side, rightBytes + (size_t)y * side, side);
    }
    float smallest = 0, largest = 0;
    NSArray *both = revenant_region_texts(frame, pairWidth, side, 0, 1, &smallest, &largest);
    revenant_check(both.count == 2 && [both containsObject:@"LEFT-CODE-001"] && [both containsObject:@"RIGHT-CODE-02"], "a region of the whole frame reports both codes", [both componentsJoinedByString:@", "]);
    NSArray *left = revenant_region_texts(frame, pairWidth, side, 0, 0.5f, &smallest, &largest);
    revenant_check(left.count == 1 && [left.firstObject isEqualToString:@"LEFT-CODE-001"] && largest < side, "a region of the left half reports only the left code, inside it", [NSString stringWithFormat:@"%@, corners up to x %.1f", left, (double)largest]);
    NSArray *right = revenant_region_texts(frame, pairWidth, side, 0.5f, 0.5f, &smallest, &largest);
    revenant_check(right.count == 1 && [right.firstObject isEqualToString:@"RIGHT-CODE-02"] && smallest >= side, "a region of the right half reports its code at full-frame coordinates", [NSString stringWithFormat:@"%@, corners from x %.1f", right, (double)smallest]);
    NSArray *cut = revenant_region_texts(frame, pairWidth, side, 0, 0.25f, &smallest, &largest);
    revenant_check(cut.count == 0, "a code cut by the edge of the region is not reported", [NSString stringWithFormat:@"%lu reported", (unsigned long)cut.count]);
    NSArray *outside = revenant_region_texts(frame, pairWidth, side, 1.5f, 0.5f, &smallest, &largest);
    revenant_check(outside.count == 0, "a region past the frame reports nothing", [NSString stringWithFormat:@"%lu reported", (unsigned long)outside.count]);
    return revenant_finish();
}
