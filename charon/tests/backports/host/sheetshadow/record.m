#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include "CharonSheetShadow.h"

/* The magic shadow of UIKit's sheet, asked of the host's own UIKit and Core Animation under Mac Catalyst (a probe of the
   oracle: private classes are asked by name here, never in the port). It checks what the port's shadow
   (packages/a/apple-backports/UIKit/CharonSheetShadow.c) rests on: a vibrant colour matrix set with -[CALayer setFilters:]
   (what 16.0's -[_UIShadowView _updateShadowVisualStyling] sets) computes its colour from what lies behind the layer, not
   from the layer's own content, and a view's alpha scales it as the content's does; the port's matrix, cap insets and
   generated image are the host shadow view's; and the port's pixel, laid over a destination, leaves what the filter
   leaves. It writes the host's image along an edge and its matrix where the device test reads them (SHADOW_RECORDS). */
typedef struct { float m11, m12, m13, m14, m15, m21, m22, m23, m24, m25, m31, m32, m33, m34, m35, m41, m42, m43, m44, m45; } Matrix;
@interface NSValue (Matrix)
+ (NSValue *)valueWithCAColorMatrix:(Matrix)matrix;
@end

static const Matrix lower = {0.796875f, -0.1875f, 0.078125f, 0, 0, -0.09375f, 0.71875f, 0.09375f, 0, 0.015625f, -0.09375f, -0.1875f, 0.96875f, 0, -0.015625f, -0.25f, -0.5f, -0.09375f, 1, 0};
static const Matrix redden = {0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0};

static id filter(NSString *type, const Matrix *matrix)
{
    id f = [NSClassFromString(@"CAFilter") performSelector:@selector(filterWithType:) withObject:type];
    if (matrix)
        [f setValue:[NSValue valueWithCAColorMatrix:*matrix] forKey:@"inputColorMatrix"];
    return f;
}

static void pixels(UIImage *image, CGSize size, void (^use)(const uint8_t *data, size_t width, size_t height))
{
    size_t w = (size_t)size.width, h = (size_t)size.height;
    uint8_t *data = calloc(w * h, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, w, h, 8, w * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), image.CGImage);
    use(data, w, h);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    free(data);
}

static UIImage *port_pixel(const float d[3])
{
    uint8_t pixel[4] = {(uint8_t)lroundf(d[0] * 255), (uint8_t)lroundf(d[1] * 255), (uint8_t)lroundf(d[2] * 255), 255};
    charon_sheet_shadow_pixel(pixel, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    memcpy(CGBitmapContextGetData(context), pixel, 4);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    UIImage *result = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    return result;
}

static UIImage *solid(CGFloat alpha)
{
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 1;
    return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40, 40) format:format] imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [[UIColor colorWithWhite:0 alpha:alpha] setFill];
        UIRectFill(CGRectMake(0, 0, 40, 40));
    }];
}

static int checks, failures;
static const float colours[4][3] = {{1, 0, 0}, {0, 0, 1}, {0.5f, 0.5f, 0.5f}, {1, 1, 1}};
static void check(BOOL ok, NSString *what)
{
    checks++;
    if (!ok)
        failures++;
    printf("%s %s\n", ok ? "ok" : "FAIL", what.UTF8String);
}

/* The destination a vibrant matrix is expected to leave, per the model the checks hold: the matrix applied to the
   destination pixel (opaque, unpremultiplied) and clamped to 0...1, laid over it with the layer's alpha times the
   matrix's own alpha. */
static void expected(const Matrix *m, float alpha, const float d[3], float out[3])
{
    const float *r = &m->m11;
    float a = fminf(fmaxf(r[15] * d[0] + r[16] * d[1] + r[17] * d[2] + r[18] + r[19], 0), 1);
    for (int c = 0; c < 3; c++) {
        float v = r[c * 5] * d[0] + r[c * 5 + 1] * d[1] + r[c * 5 + 2] * d[2] + r[c * 5 + 3] + r[c * 5 + 4];
        out[c] = d[c] + alpha * a * (fminf(fmaxf(v, 0), 1) - d[c]);
    }
}

@interface ShadowDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation ShadowDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options { return YES; }
@end

@interface ShadowScene : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ShadowScene

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.frame = CGRectMake(0, 0, 400, 300);
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self run]; });
}

- (void)run
{
    UIImage *kit = [UIImage performSelector:@selector(kitImageNamed:) withObject:@"_UIPopoverShadow"];
    printf("note the kit image _UIPopoverShadow: %s at scale %g\n", NSStringFromCGSize(kit.size).UTF8String, kit.scale);
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    Class shadowClass = NSClassFromString(@"_UIRoundedRectShadowView");
    check(shadowClass != Nil, @"the host has _UIRoundedRectShadowView");
    for (NSValue *card in @[[NSValue valueWithCGSize:CGSizeMake(200, 200)], [NSValue valueWithCGSize:CGSizeMake(40, 200)]]) {
        UIImageView *shadow = ((id (*)(id, SEL, CGFloat))objc_msgSend)([shadowClass alloc], NSSelectorFromString(@"initWithCornerRadius:"), 10);
        ((void (*)(id, SEL, BOOL))objc_msgSend)(shadow, NSSelectorFromString(@"setUseLowerIntensity:"), YES);
        CGSize size = card.CGSizeValue;
        CGRect frame = ((CGRect (*)(id, SEL, CGRect))objc_msgSend)(shadow, NSSelectorFromString(@"frameWithContentWithFrame:"), CGRectMake(0, 0, size.width, size.height));
        shadow.frame = frame;
        [self.window addSubview:shadow];
        [shadow layoutIfNeeded];
        double cap = charon_sheet_shadow_cap(frame.size.width, frame.size.height, 10, self.window.screen.scale);
        UIEdgeInsets insets = shadow.image.capInsets;
        check(CGRectEqualToRect(frame, CGRectInset(CGRectMake(0, 0, size.width, size.height), -150, -150)) && fabs(insets.top - cap) < 1e-6 && fabs(insets.left - cap) < 1e-6
                  && fabs(insets.bottom - cap) < 1e-6 && fabs(insets.right - cap) < 1e-6,
              [NSString stringWithFormat:@"the shadow view around a %@ card: frame %@, image %@, cap insets %@; the port: 150 points out, cap %g",
                  NSStringFromCGSize(size), NSStringFromCGRect(frame), NSStringFromCGSize(shadow.image.size), NSStringFromUIEdgeInsets(insets), cap]);
        if (size.width == 200) {
            id vibrant = nil;
            for (id f in shadow.layer.filters)
                if ([[f valueForKey:@"type"] isEqual:@"vibrantColorMatrix"])
                    vibrant = f;
            Matrix m = {0};
            [[vibrant valueForKey:@"inputColorMatrix"] getValue:&m];
            BOOL same = vibrant != nil;
            NSMutableArray *matrix = [NSMutableArray array];
            for (int i = 0; i < 20; i++) {
                same = same && (&m.m11)[i] == charon_sheet_shadow_matrix[i];
                [matrix addObject:@((&m.m11)[i])];
            }
            check(same, [NSString stringWithFormat:@"the lower-intensity shadow view's vibrant matrix is the port's: %@", [matrix componentsJoinedByString:@" "]]);
            records[@"matrix"] = matrix;
        }
        [shadow removeFromSuperview];
    }

    /* The port's corner against the host's image, pixel by pixel at its scale, and at 1x against the mean of each 2 x 2
       block, which is what drawing the 2x image at 1x gives. The bound is the fit's error (CharonSheetShadow.c). */
    CGSize kitPixels = CGSizeMake(kit.size.width * kit.scale, kit.size.height * kit.scale);
    pixels(kit, kitPixels, ^(const uint8_t *d, size_t w, size_t h) {
        const uint8_t *two = charon_sheet_shadow_corner((unsigned)kit.scale), *one = charon_sheet_shadow_corner(1);
        int worst = 0, worstOne = 0;
        double sum = 0;
        for (size_t i = 0; i < w * h; i++) {
            int e = abs((int)two[i] - (int)d[i * 4 + 3]);
            worst = MAX(worst, e);
            sum += e * e;
        }
        for (size_t y = 0; y < h / 2; y++)
            for (size_t x = 0; x < w / 2; x++) {
                double mean = (d[((2 * y) * w + 2 * x) * 4 + 3] + d[((2 * y) * w + 2 * x + 1) * 4 + 3] + d[((2 * y + 1) * w + 2 * x) * 4 + 3] + d[((2 * y + 1) * w + 2 * x + 1) * 4 + 3]) / 4.0;
                worstOne = MAX(worstOne, (int)ceil(fabs(one[y * (w / 2) + x] - mean) - 1e-9));
            }
        check(w == 400 && h == 400 && worst <= 3, [NSString stringWithFormat:@"the port's corner at scale %g is the host's image within 3/255: %zu x %zu, worst %d, rms %.2f", kit.scale, w, h, worst, sqrt(sum / (w * h))]);
        check(worstOne <= 3, [NSString stringWithFormat:@"the port's corner at scale 1 is the host's image drawn at 1x within 3/255: worst %d", worstOne]);
        NSMutableArray *edge = [NSMutableArray array];
        for (size_t y = 0; y < h; y++)
            [edge addObject:@(d[(y * w + w - 1) * 4 + 3])];
        records[@"edge"] = edge;
        records[@"edgeScale"] = @(kit.scale);
    });

    NSArray *backgrounds = @[[UIColor redColor], [UIColor blueColor], [UIColor colorWithWhite:0.5 alpha:1], [UIColor whiteColor]];
    UIView *root = self.window.rootViewController.view;
    /* Per background: a black layer at 0.5 plain, with a reddening matrix, with the vibrant matrix; then the vibrant
       matrix over an opaque layer in a view at alpha 0.5, as UIKit sets the magic alpha on its view; then the port's pixel
       for that background in a view at alpha 0.5. */
    for (NSUInteger b = 0; b < backgrounds.count; b++)
        for (NSUInteger k = 0; k < 5; k++) {
            UIView *back = [[UIView alloc] initWithFrame:CGRectMake(10 + k * 60, 10 + b * 60, 50, 50)];
            back.backgroundColor = backgrounds[b];
            UIView *layerView = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 40, 40)];
            layerView.layer.contents = (id)(k == 3 ? solid(1) : k == 4 ? port_pixel(colours[b]) : solid(0.5)).CGImage;
            if (k == 1) layerView.layer.filters = @[filter(@"colorMatrix", &redden)];
            if (k == 2 || k == 3) layerView.layer.filters = @[filter(@"vibrantColorMatrix", &lower)];
            if (k >= 3) layerView.alpha = 0.5;
            [back addSubview:layerView];
            [root addSubview:back];
        }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
        format.scale = 1;
        CGSize size = self.window.bounds.size;
        UIImage *shot = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *c) {
            [self.window drawViewHierarchyInRect:self.window.bounds afterScreenUpdates:YES];
        }];
        pixels(shot, size, ^(const uint8_t *d, size_t w, size_t h) {
            for (NSUInteger b = 0; b < backgrounds.count; b++) {
                /* The capture's full value: the background alone (the capture reads 249 for 1.0). */
                const uint8_t *alone = d + ((10 + b * 60 + 2) * w + 10 + 25) * 4;
                float full = MAX(MAX(alone[0], alone[1]), alone[2]) / (b == 0 ? colours[0][0] : b == 1 ? colours[1][2] : colours[b][0]);
                const uint8_t *plain = d + ((10 + b * 60 + 25) * w + 10 + 25) * 4;
                const uint8_t *red = d + ((10 + b * 60 + 25) * w + 70 + 25) * 4;
                const uint8_t *vibrant = d + ((10 + b * 60 + 25) * w + 130 + 25) * 4;
                const uint8_t *faded = d + ((10 + b * 60 + 25) * w + 190 + 25) * 4;
                const uint8_t *port = d + ((10 + b * 60 + 25) * w + 250 + 25) * 4;
                NSString *name = @[@"red", @"blue", @"grey", @"white"][b];
                float red_expected[3] = {0.5f + 0.5f * colours[b][0], 0.5f * colours[b][1], 0.5f * colours[b][2]};
                BOOL control = YES;
                for (int c = 0; c < 3; c++)
                    control = control && fabsf(red[c] - red_expected[c] * full) <= 3;
                check(control, [NSString stringWithFormat:@"the capture shows a layer's filters: a colour matrix that makes the layer red, over %@: %u %u %u", name, red[0], red[1], red[2]]);
                float model[3];
                expected(&lower, 0.5f, colours[b], model);
                BOOL matches = YES, differs = NO;
                for (int c = 0; c < 3; c++) {
                    matches = matches && fabsf(vibrant[c] - model[c] * full) <= 3;
                    differs = differs || abs((int)vibrant[c] - (int)plain[c]) > 6;
                }
                check(matches && differs, [NSString stringWithFormat:@"the vibrant matrix over %@ leaves %u %u %u: the matrix of what is behind (%.0f %.0f %.0f), not the black layer laid over it (%u %u %u)",
                      name, vibrant[0], vibrant[1], vibrant[2], model[0] * full, model[1] * full, model[2] * full, plain[0], plain[1], plain[2]]);
                BOOL alike = YES, portAlike = YES;
                for (int c = 0; c < 3; c++) {
                    alike = alike && abs((int)faded[c] - (int)vibrant[c]) <= 3;
                    portAlike = portAlike && abs((int)port[c] - (int)vibrant[c]) <= 3;
                }
                check(alike, [NSString stringWithFormat:@"a view's alpha of 0.5 scales the vibrant matrix over %@ as the content's does: %u %u %u", name, faded[0], faded[1], faded[2]]);
                check(portAlike, [NSString stringWithFormat:@"the port's pixel in a view at alpha 0.5 over %@ leaves what the vibrant matrix leaves: %u %u %u", name, port[0], port[1], port[2]]);
            }
        });
        NSString *out = [NSProcessInfo processInfo].environment[@"SHADOW_RECORDS"];
        if (out)
            [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingSortedKeys error:NULL] writeToFile:out atomically:YES];
        printf("checks=%d failures=%d\n", checks, failures);
        fflush(stdout);
        exit(failures ? 1 : 0);
    });
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"ShadowDelegate");
    }
}
