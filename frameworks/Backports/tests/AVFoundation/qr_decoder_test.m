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

static uint8_t revenant_gf_exp[512], revenant_gf_log[256];

static void revenant_gf_setup(void)
{
    int value = 1;
    for (int index = 0; index < 255; index++) {
        revenant_gf_exp[index] = (uint8_t)value;
        revenant_gf_log[value] = (uint8_t)index;
        value <<= 1;
        if (value & 0x100)
            value ^= 0x11D;
    }
    for (int index = 255; index < 512; index++)
        revenant_gf_exp[index] = revenant_gf_exp[index - 255];
}

static uint8_t revenant_gf_multiply(uint8_t a, uint8_t b)
{
    if (!a || !b)
        return 0;
    return revenant_gf_exp[revenant_gf_log[a] + revenant_gf_log[b]];
}

static void revenant_rs_divisor(int degree, uint8_t *divisor)
{
    memset(divisor, 0, degree);
    divisor[degree - 1] = 1;
    uint8_t root = 1;
    for (int index = 0; index < degree; index++) {
        for (int j = 0; j < degree; j++) {
            divisor[j] = revenant_gf_multiply(divisor[j], root);
            if (j + 1 < degree)
                divisor[j] ^= divisor[j + 1];
        }
        root = revenant_gf_multiply(root, 0x02);
    }
}

static void revenant_rs_remainder(const uint8_t *data, int length, const uint8_t *divisor, int degree, uint8_t *remainder)
{
    memset(remainder, 0, degree);
    for (int index = 0; index < length; index++) {
        uint8_t factor = data[index] ^ remainder[0];
        memmove(remainder, remainder + 1, degree - 1);
        remainder[degree - 1] = 0;
        for (int j = 0; j < degree; j++)
            remainder[j] ^= revenant_gf_multiply(divisor[j], factor);
    }
}

static void revenant_put_bits(uint8_t *bytes, int *position, unsigned value, int count)
{
    for (int index = count - 1; index >= 0; index--, (*position)++) {
        if ((value >> index) & 1)
            bytes[*position >> 3] |= (uint8_t)(0x80 >> (*position & 7));
    }
}

static int revenant_format_bits(int data)
{
    int value = data << 10;
    for (int bit = 14; bit >= 10; bit--) {
        if (value & (1 << bit))
            value ^= 0x537 << (bit - 10);
    }
    return ((data << 10) | value) ^ 0x5412;
}

static void revenant_set_module(uint8_t dark[21][21], uint8_t function[21][21], int x, int y, int value)
{
    if (x < 0 || y < 0 || x >= 21 || y >= 21)
        return;
    dark[y][x] = value != 0;
    function[y][x] = 1;
}

static void revenant_draw_format(uint8_t dark[21][21], uint8_t function[21][21], int format)
{
    for (int index = 0; index <= 5; index++)
        revenant_set_module(dark, function, 8, index, (format >> index) & 1);
    revenant_set_module(dark, function, 8, 7, (format >> 6) & 1);
    revenant_set_module(dark, function, 8, 8, (format >> 7) & 1);
    revenant_set_module(dark, function, 7, 8, (format >> 8) & 1);
    for (int index = 9; index <= 14; index++)
        revenant_set_module(dark, function, 14 - index, 8, (format >> index) & 1);
    for (int index = 0; index <= 7; index++)
        revenant_set_module(dark, function, 20 - index, 8, (format >> index) & 1);
    for (int index = 8; index <= 14; index++)
        revenant_set_module(dark, function, 8, 6 + index, (format >> index) & 1);
    revenant_set_module(dark, function, 8, 13, 1);
}

static NSData *revenant_eci_render(NSData *payload, int eci, int *width, int *height)
{
    if (payload.length > 13)
        return nil;
    revenant_gf_setup();
    const uint8_t *message = payload.bytes;
    int length = (int)payload.length;
    uint8_t codewords[26] = {0};
    int bits = 0;
    if (eci >= 0) {
        revenant_put_bits(codewords, &bits, 0x7, 4);
        revenant_put_bits(codewords, &bits, (unsigned)eci, 8);
    }
    revenant_put_bits(codewords, &bits, 0x4, 4);
    revenant_put_bits(codewords, &bits, (unsigned)length, 8);
    for (int index = 0; index < length; index++)
        revenant_put_bits(codewords, &bits, message[index], 8);
    revenant_put_bits(codewords, &bits, 0, MIN(4, 128 - bits));
    int used = (bits + 7) / 8;
    for (int index = used; index < 16; index++)
        codewords[index] = (index - used) % 2 == 0 ? 0xEC : 0x11;
    uint8_t divisor[10];
    revenant_rs_divisor(10, divisor);
    revenant_rs_remainder(codewords, 16, divisor, 10, codewords + 16);

    const int size = 21;
    uint8_t dark[21][21] = {{0}}, function[21][21] = {{0}};
    for (int index = 0; index < size; index++) {
        revenant_set_module(dark, function, 6, index, index % 2 == 0);
        revenant_set_module(dark, function, index, 6, index % 2 == 0);
    }
    const int centers[3][2] = {{3, 3}, {17, 3}, {3, 17}};
    for (int center = 0; center < 3; center++) {
        for (int dy = -4; dy <= 4; dy++) {
            for (int dx = -4; dx <= 4; dx++) {
                int distance = MAX(abs(dx), abs(dy));
                revenant_set_module(dark, function, centers[center][0] + dx, centers[center][1] + dy, distance != 2 && distance != 4);
            }
        }
    }
    revenant_draw_format(dark, function, revenant_format_bits(0));
    int bit = 0;
    for (int right = size - 1; right >= 1; right -= 2) {
        int column = right <= 6 ? right - 1 : right;
        for (int vertical = 0; vertical < size; vertical++) {
            for (int j = 0; j < 2; j++) {
                int x = column - j;
                int upward = ((column + 1) & 2) == 0;
                int y = upward ? size - 1 - vertical : vertical;
                if (!function[y][x] && bit < 208) {
                    dark[y][x] = (codewords[bit >> 3] >> (7 - (bit & 7))) & 1;
                    bit++;
                }
            }
        }
    }
    for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
            if (!function[y][x] && (x + y) % 2 == 0)
                dark[y][x] ^= 1;
        }
    }
    const int scale = 4, margin = 4;
    int side = (size + 2 * margin) * scale;
    NSMutableData *pixels = [NSMutableData dataWithLength:(NSUInteger)side * side];
    uint8_t *bytes = pixels.mutableBytes;
    for (int y = 0; y < side; y++) {
        for (int x = 0; x < side; x++) {
            int mx = x / scale - margin, my = y / scale - margin;
            bytes[y * side + x] = (mx >= 0 && my >= 0 && mx < size && my < size && dark[my][mx]) ? 0 : 255;
        }
    }
    *width = side;
    *height = side;
    return pixels;
}

static NSString *revenant_decode_charset(NSData *pixels, int width, int height, int *undecodable)
{
    RevenantQRResult results[REVENANT_QR_MAX_RESULTS];
    int found = revenant_qr_decode(pixels.bytes, width, height, width, results, REVENANT_QR_MAX_RESULTS);
    NSString *text = nil;
    *undecodable = -1;
    if (found) {
        *undecodable = results[0].undecodable;
        text = [[NSString alloc] initWithBytes:results[0].text length:results[0].length encoding:NSUTF8StringEncoding];
    }
    for (int index = 0; index < found; index++)
        revenant_qr_result_free(&results[index]);
    return text;
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
    int flag = -1;
    NSString *plain = revenant_decode_charset(revenant_eci_render([@"ABC" dataUsingEncoding:NSUTF8StringEncoding], -1, &width, &height), width, height, &flag);
    revenant_check([plain isEqualToString:@"ABC"] && flag == 0, "the test's encoder writes a code without an ECI that decodes", [NSString stringWithFormat:@"%@, flag %d", plain, flag]);
    const uint8_t shiftJISBytes[] = {0x93, 0xFA, 0x96, 0x7B, 0x8C, 0xEA};
    NSData *shiftJIS = [NSData dataWithBytes:shiftJISBytes length:sizeof(shiftJISBytes)];
    revenant_qr_set_converter(NULL);
    NSString *unconverted = revenant_decode_charset(revenant_eci_render(shiftJIS, 20, &width, &height), width, height, &flag);
    revenant_check(flag == 1 && unconverted.length == 0, "without a converter, a Shift_JIS code is flagged, not replaced", [NSString stringWithFormat:@"%@, flag %d", unconverted, flag]);
    revenant_qr_install_default_converter();
    NSString *japanese = revenant_decode_charset(revenant_eci_render(shiftJIS, 20, &width, &height), width, height, &flag);
    revenant_check([japanese isEqualToString:@"日本語"] && flag == 0, "a Shift_JIS code (ECI 20) decodes to its UTF-8 text", [NSString stringWithFormat:@"%@, flag %d", japanese, flag]);
    const uint8_t cyrillicBytes[] = {0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2};
    NSData *cyrillic = [NSData dataWithBytes:cyrillicBytes length:sizeof(cyrillicBytes)];
    NSString *windows = revenant_decode_charset(revenant_eci_render(cyrillic, 22, &width, &height), width, height, &flag);
    revenant_check([windows isEqualToString:@"Привет"] && flag == 0, "a Windows-1251 code (ECI 22) decodes to its UTF-8 text", [NSString stringWithFormat:@"%@, flag %d", windows, flag]);
    const uint8_t truncatedBytes[] = {0x93};
    NSData *truncated = [NSData dataWithBytes:truncatedBytes length:sizeof(truncatedBytes)];
    NSString *dropped = revenant_decode_charset(revenant_eci_render(truncated, 20, &width, &height), width, height, &flag);
    revenant_check(flag == 1 && dropped.length == 0, "bytes that do not match their declared charset are flagged, with no text", [NSString stringWithFormat:@"%@, flag %d", dropped, flag]);
    return revenant_finish();
}
