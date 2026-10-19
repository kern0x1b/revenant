#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

static void try(const char *what, CGColorSpaceRef space, size_t bpc, size_t bpp, CGBitmapInfo info)
{
    size_t width = 1, rowBytes = bpp / 8 * width;
    void *data = calloc(1, 64);
    CGContextRef context = CGBitmapContextCreate(data, width, 1, bpc, rowBytes, space, info);
    printf("measure %s: %s\n", what, context ? "made" : "refused");
    if (context) {
        CGFloat k[] = {1, 0, 0, 1};
        CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
        CGColorRef red = CGColorCreate(rgb, k);
        CGContextSetFillColorWithColor(context, red);
        CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
        if (bpc == 32) {
            float *f = data;
            printf("measure %s: red drawn %f %f %f %f\n", what, f[0], f[1], f[2], f[3]);
        } else {
            unsigned char *b = data;
            printf("measure %s: red drawn %d %d %d %d %d\n", what, b[0], b[1], b[2], b[3], b[4]);
        }
        CGContextRelease(context);
    }
    free(data);
}

int main(void)
{
    @autoreleasepool {
        CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray(), rgb = CGColorSpaceCreateDeviceRGB(), cmyk = CGColorSpaceCreateDeviceCMYK();
        try("gray 8", gray, 8, 8, kCGImageAlphaNone);
        try("gray 32 float", gray, 32, 32, kCGImageAlphaNone | kCGBitmapFloatComponents);
        try("gray 32 float + alpha", gray, 32, 64, kCGImageAlphaPremultipliedLast | kCGBitmapFloatComponents);
        try("rgb 32 float skip", rgb, 32, 128, kCGImageAlphaNoneSkipLast | kCGBitmapFloatComponents);
        try("rgb 32 float premultiplied", rgb, 32, 128, kCGImageAlphaPremultipliedLast | kCGBitmapFloatComponents);
        try("rgb 16", rgb, 16, 64, kCGImageAlphaPremultipliedLast);
        try("cmyk 8", cmyk, 8, 32, kCGImageAlphaNone);
        try("cmyk 32 float", cmyk, 32, 128, kCGImageAlphaNone | kCGBitmapFloatComponents);
    }
    return 0;
}
