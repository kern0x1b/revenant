#import "../Foundation/check.h"
#import <CoreImage/CoreImage.h>

static BOOL revenant_is(CIColor *color, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return color.numberOfComponents == 4 && fabs(color.red - red) < 1e-6 && fabs(color.green - green) < 1e-6 && fabs(color.blue - blue) < 1e-6 && fabs(color.alpha - alpha) < 1e-6;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        struct {
            const char *name;
            SEL selector;
            CGFloat red, green, blue, alpha;
        } named[] = {
            {"black", @selector(blackColor), 0, 0, 0, 1},
            {"white", @selector(whiteColor), 1, 1, 1, 1},
            {"gray", @selector(grayColor), 0.5, 0.5, 0.5, 1},
            {"red", @selector(redColor), 1, 0, 0, 1},
            {"green", @selector(greenColor), 0, 1, 0, 1},
            {"blue", @selector(blueColor), 0, 0, 1, 1},
            {"cyan", @selector(cyanColor), 0, 1, 1, 1},
            {"magenta", @selector(magentaColor), 1, 0, 1, 1},
            {"yellow", @selector(yellowColor), 1, 1, 0, 1},
            {"clear", @selector(clearColor), 0, 0, 0, 0},
        };
        for (size_t index = 0; index < sizeof named / sizeof named[0]; index++) {
            CIColor *(*getter)(id, SEL) = (CIColor * (*)(id, SEL)) REVENANT_CLASS_IMP(CIColor, named[index].selector, void *);
            CIColor *first = getter([CIColor class], named[index].selector);
            CIColor *second = getter([CIColor class], named[index].selector);
            NSString *title = [NSString stringWithFormat:@"the %s colour has its components and is one shared object", named[index].name];
            revenant_check((first != nil && first == second && revenant_is(first, named[index].red, named[index].green, named[index].blue, named[index].alpha)) != revenant_negative, title.UTF8String, @"the colour differs");
        }

        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CIColor *made = [CIColor colorWithRed:0.25 green:0.5 blue:0.75 alpha:0.5 colorSpace:space];
        CIColor *initialised = [[CIColor alloc] initWithRed:0.25 green:0.5 blue:0.75 colorSpace:space];
        CGColorSpaceRelease(space);
        revenant_check((revenant_is(made, 0.25, 0.5, 0.75, 0.5) && revenant_is(initialised, 0.25, 0.5, 0.75, 1)) != revenant_negative, "a colour made with a colour space keeps its components and alpha", @"the components differ");
    }
    return revenant_finish();
}
