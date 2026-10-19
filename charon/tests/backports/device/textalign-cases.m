#import "textalign-cases.h"

static NSString *ink_side(UIView *view)
{
    CGSize size = view.bounds.size;
    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    [view.layer renderInContext:context];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRef cg = image.CGImage;
    size_t width = CGImageGetWidth(cg), height = CGImageGetHeight(cg);
    unsigned char *pixels = calloc(width * height, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), cg);
    CGContextRelease(bitmap);
    CGColorSpaceRelease(space);
    int minX = (int)width, maxX = -1;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++) {
            unsigned char *p = pixels + (y * width + x) * 4;
            if (p[0] < 128 && p[1] < 128 && p[2] < 128) {
                if ((int)x < minX) minX = (int)x;
                if ((int)x > maxX) maxX = (int)x;
            }
        }
    free(pixels);
    if (maxX < 0)
        return @"none";
    double centre = (minX + maxX) / 2.0 / width;
    return centre < 0.33 ? @"left" : centre > 0.66 ? @"right" : @"middle";
}

static NSString *text_of(id view, NSString *string, NSTextAlignment alignment)
{
    @try {
        [view setText:string];
        [view setTextAlignment:alignment];
        return [NSString stringWithFormat:@"alignment=%ld ink=%@", (long)[view textAlignment], ink_side(view)];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@", exception.name];
    }
}

void textalign_run(UIWindow *window, TextAlignRecorder record)
{
    UIViewController *controller = [[UIViewController alloc] init];
    window.rootViewController = controller;
    NSString *latin = @"Hello";
    NSString *hebrew = @"שלום";
    for (NSNumber *alignment in @[@0, @1, @2, @4]) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor whiteColor];
        UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
        field.textColor = [UIColor blackColor];
        field.backgroundColor = [UIColor whiteColor];
        [controller.view addSubview:label];
        [controller.view addSubview:field];
        record([NSString stringWithFormat:@"label.latin.%@", alignment], text_of(label, latin, alignment.integerValue));
        record([NSString stringWithFormat:@"label.hebrew.%@", alignment], text_of(label, hebrew, alignment.integerValue));
        record([NSString stringWithFormat:@"field.latin.%@", alignment], text_of(field, latin, alignment.integerValue));
        record([NSString stringWithFormat:@"field.hebrew.%@", alignment], text_of(field, hebrew, alignment.integerValue));
        UITextView *view = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
        [controller.view addSubview:view];
        @try {
            view.textAlignment = alignment.integerValue;
            record([NSString stringWithFormat:@"textview.getter.%@", alignment], [NSString stringWithFormat:@"%ld", (long)view.textAlignment]);
        } @catch (NSException *exception) {
            record([NSString stringWithFormat:@"textview.getter.%@", alignment], [NSString stringWithFormat:@"raised %@", exception.name]);
        }
    }
    UILabel *swap = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
    swap.textColor = [UIColor blackColor];
    swap.backgroundColor = [UIColor whiteColor];
    [controller.view addSubview:swap];
    swap.text = latin;
    swap.textAlignment = 4;
    NSString *before = ink_side(swap);
    swap.text = hebrew;
    record(@"label.textChange", [NSString stringWithFormat:@"%@ -> %@ alignment=%ld", before, ink_side(swap), (long)swap.textAlignment]);
    swap.textAlignment = 1;
    record(@"label.thenCentre", [NSString stringWithFormat:@"%ld %@", (long)swap.textAlignment, ink_side(swap)]);
}
