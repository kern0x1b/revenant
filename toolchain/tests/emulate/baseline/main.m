#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

typedef struct {
    size_t top;
    size_t bottom;
    size_t left;
    size_t right;
    size_t ink;
} InkBox;

static InkBox drawn_ink(NSAttributedString *text, CGFloat originY)
{
    const size_t width = 240;
    const size_t height = 80;
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    UIGraphicsPushContext(context);
    [text drawAtPoint:CGPointMake(20, originY)];
    UIGraphicsPopContext();
    InkBox box = { height, 0, width, 0, 0 };
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            if (pixels[(y * width + x) * 4 + 3] == 0)
                continue;
            box.ink++;
            if (y < box.top) box.top = y;
            if (y + 1 > box.bottom) box.bottom = y + 1;
            if (x < box.left) box.left = x;
            if (x + 1 > box.right) box.right = x + 1;
        }
    }
    CGContextRelease(context);
    free(pixels);
    return box;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("BASELINE-PROBE step=application\n");
        (void)[UIApplication sharedApplication];
        void *graphics = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_NOW);
        unsigned long (*font_type_id)(void) = graphics ? dlsym(graphics, "GSFontGetTypeID") : NULL;
        void (*gs_initialize)(void) = graphics ? dlsym(graphics, "GSInitialize") : NULL;
        printf("BASELINE-PROBE step=gs-font-type-id before=%lu\n", font_type_id ? font_type_id() : 0ul);
        if (gs_initialize) {
            gs_initialize();
        }
        printf("BASELINE-PROBE step=gs-initialize present=%d after=%lu\n", gs_initialize != NULL, font_type_id ? font_type_id() : 0ul);
        printf("BASELINE-PROBE step=font\n");
        UIFont *font = [UIFont systemFontOfSize:24];
        printf("BASELINE-PROBE step=strings\n");
        NSMutableAttributedString *plain = [[NSMutableAttributedString alloc] initWithString:@"Hxg" attributes:@{NSFontAttributeName: font}];
        NSMutableAttributedString *raised = [[NSMutableAttributedString alloc] initWithString:@"Hxg" attributes:@{NSFontAttributeName: font}];
        [raised addAttribute:NSBaselineOffsetAttributeName value:@6.0 range:NSMakeRange(0, raised.length)];
        printf("BASELINE-PROBE step=draw-plain\n");
        InkBox a = drawn_ink(plain, 20);
        printf("BASELINE-PROBE step=draw-raised\n");
        InkBox b = drawn_ink(raised, 20);
        printf("BASELINE-PROBE step=draw-control\n");
        InkBox c = drawn_ink(plain, 14);
        printf("BASELINE-PROBE plain top=%lu bottom=%lu left=%lu right=%lu ink=%lu\n",
               (unsigned long)a.top, (unsigned long)a.bottom, (unsigned long)a.left, (unsigned long)a.right, (unsigned long)a.ink);
        printf("BASELINE-PROBE raised top=%lu bottom=%lu left=%lu right=%lu ink=%lu\n",
               (unsigned long)b.top, (unsigned long)b.bottom, (unsigned long)b.left, (unsigned long)b.right, (unsigned long)b.ink);
        printf("BASELINE-PROBE shift=%ld ink-equal=%d\n", (long)b.top - (long)a.top, a.ink == b.ink);
        printf("BASELINE-PROBE control shift=%ld ink-equal=%d\n", (long)c.top - (long)a.top, a.ink == c.ink);
        printf("BASELINE-PROBE-DONE\n");
    }
    return 0;
}
