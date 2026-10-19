#import "uirest.h"

static UIImage *solid_image(UIColor *color)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(6, 6), YES, 1);
    [color setFill];
    UIRectFill(CGRectMake(0, 0, 6, 6));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static void pixel_at(CALayer *layer, size_t width, size_t height, size_t x, size_t y, uint8_t *pixel)
{
    uint8_t *buffer = calloc(width * height, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(buffer, width, height, 8, width * 4, space, (uint32_t)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    [layer renderInContext:context];
    memcpy(pixel, buffer + (y * width + x) * 4, 4);
    CGContextRelease(context);
    free(buffer);
}

static BOOL is_red(const uint8_t *pixel)
{
    return pixel[0] > 200 && pixel[1] < 60 && pixel[2] < 60;
}

static BOOL is_blue(const uint8_t *pixel)
{
    return pixel[0] < 60 && pixel[1] < 60 && pixel[2] > 200;
}

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        UIPageControl *control = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
        control.numberOfPages = 3;
        [window addSubview:control];
        size_t width = 120, height = 30;
        CGFloat pitch = ([control sizeForNumberOfPages:3].width - [control sizeForNumberOfPages:1].width) / 2;
        size_t centre_y = (size_t)lround(CGRectGetMidY(control.bounds));
        size_t first_x = (size_t)lround(CGRectGetMidX(control.bounds) - pitch);
        size_t middle_x = (size_t)lround(CGRectGetMidX(control.bounds));
        size_t last_x = (size_t)lround(CGRectGetMidX(control.bounds) + pitch);
        uint8_t pixel[4];

        [control layoutSubviews];
        pixel_at(control.layer, width, height, first_x, centre_y, pixel);
        charon_check(!is_red(pixel) && !is_blue(pixel), "a page with no image keeps the release's dot",
                     [NSString stringWithFormat:@"pixel %d %d %d", pixel[0], pixel[1], pixel[2]]);

        [control setIndicatorImage:solid_image([UIColor blueColor]) forPage:1];
        [control layoutSubviews];
        pixel_at(control.layer, width, height, middle_x, centre_y, pixel);
        charon_check(is_blue(pixel), "a page's own image is drawn at its dot's centre",
                     [NSString stringWithFormat:@"pixel %d %d %d", pixel[0], pixel[1], pixel[2]]);

        control.preferredIndicatorImage = solid_image([UIColor redColor]);
        [control layoutSubviews];
        pixel_at(control.layer, width, height, first_x, centre_y, pixel);
        charon_check(is_red(pixel), "the preferred image shows on the first page", [NSString stringWithFormat:@"pixel %d %d %d", pixel[0], pixel[1], pixel[2]]);
        pixel_at(control.layer, width, height, last_x, centre_y, pixel);
        charon_check(is_red(pixel), "the preferred image shows on the last page", [NSString stringWithFormat:@"pixel %d %d %d", pixel[0], pixel[1], pixel[2]]);
        pixel_at(control.layer, width, height, middle_x, centre_y, pixel);
        charon_check(is_blue(pixel), "a page's own image wins over the preferred one", [NSString stringWithFormat:@"pixel %d %d %d", pixel[0], pixel[1], pixel[2]]);
    }
}
