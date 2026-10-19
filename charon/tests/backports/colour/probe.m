// colour/probe.m - the first nineteen answers of AXNameFromColor, on the host.
//
// AXNameFromColor is ODDED and not carried: the host answers a curated named-colour vocabulary with a
// nearest-match rule and not the components of a colour, so the work is a black-box fit and not a
// lookup, and the fit has not been done. This is the smallest probe that shows the shape of the
// problem, and it is committed so that the fit starts from a reproducible set rather than from a
// number somebody remembers:
//
//   (128,128,128) and (200,200,200) both answer gray        a component answer would say light gray
//   (255,165,0) answers bright orange, (0,0,255) very dark blue, (255,255,0) very light vibrant yellow
//   (128,0,128) and (255,0,255) both answer dark magenta
//
// What is owed, and is in facts/Accessibility/Accessibility.md under Owed: probe the host densely - a
// regular 17x17x17 sRGB grid, 20,000 random colours, the named edge cases, and the neighbours of every
// grid point where the answer changes - identify the vocabulary and the decision rule by fitting
// candidate spaces (sRGB, linear, Lab, OKLab) with per-name prototypes and boundaries found by
// bisection, implement the port's own rule and the port's own prototype table from those measurements,
// and report the agreement over a held-out sample of at least 200,000 colours that were not in the fit
// set. Nothing is read out of the framework's binary or its resources; the names are facts of the
// answers the function returned.
//
// This probe is the host's own function and reads no user data: a colour in, a name out. What its
// answers mean - the pairs a component lookup could not produce - is in this directory's README, which
// is the one place that reading is written down, and the five steps of the fit are under Owed there.

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
