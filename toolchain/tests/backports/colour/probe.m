#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <AppKit/AppKit.h>
static NSColor *rgb(int r, int g, int b) { return [NSColor colorWithSRGBRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]; }
int main(void) { @autoreleasepool {
    struct { const char *name; int r, g, b; } cases[] = {
        {"black",0,0,0},{"white",255,255,255},{"red",255,0,0},{"green",0,128,0},{"blue",0,0,255},
        {"gray",128,128,128},{"darkGray",68,68,68},{"lightGray",200,200,200},{"orange",255,165,0},
        {"yellow",255,255,0},{"purple",128,0,128},{"brown",165,42,42},{"cyan",0,255,255},{"magenta",255,0,255},
        {"clear",0,0,0},{"pink",255,192,203},{"systemBlue",0,122,255},{"labelColor",0,0,0},
    };
    for (unsigned i = 0; i < sizeof(cases)/sizeof(cases[0]); i++) {
        NSColor *c = rgb(cases[i].r, cases[i].g, cases[i].b);
        printf("%s\t%s\n", cases[i].name, [[AXNameFromColor(c.CGColor) description] UTF8String]);
    }
    printf("aNilColor\t%s\n", [[AXNameFromColor(NULL) description] UTF8String]);
} return 0; }
