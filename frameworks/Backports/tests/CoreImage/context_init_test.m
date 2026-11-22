#import "../Foundation/check.h"
#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>

BOOL revenant_install_context_init(Class target, SEL selector);

@interface CIContext (RevenantHostTest)
- (instancetype)initWithRevenantOptions:(NSDictionary *)options;
@end

static BOOL revenant_renders_red(CIContext *context)
{
    CIImage *image = [[CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]] imageByCroppingToRect:CGRectMake(0, 0, 4, 4)];
    uint8_t pixels[4 * 4 * 4] = {0};
    [context render:image toBitmap:pixels rowBytes:16 bounds:CGRectMake(0, 0, 4, 4) format:kCIFormatRGBA8 colorSpace:nil];
    return pixels[0] == 255 && pixels[1] == 0 && pixels[2] == 0 && pixels[3] == 255;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    IMP system = class_getMethodImplementation([CIContext class], @selector(initWithOptions:));
    BOOL replaced = revenant_install_context_init([CIContext class], @selector(initWithOptions:));
    BOOL kept = class_getMethodImplementation([CIContext class], @selector(initWithOptions:)) == system;
    revenant_check((!replaced && kept) != revenant_negative, "a system that has initWithOptions: keeps its own implementation", @"the backport replaced or added over the system method");

    CIContext *plain = [[CIContext alloc] initWithRevenantOptions:nil];
    revenant_check((plain != nil && [plain isKindOfClass:[CIContext class]]) != revenant_negative, "a context made without options is a CIContext", @"the initialiser returned nil or another class");
    revenant_check(revenant_renders_red(plain) != revenant_negative, "a context made without options renders a red image to red pixels", @"the pixels were not red");

    CIContext *software = [[CIContext alloc] initWithRevenantOptions:@{kCIContextUseSoftwareRenderer: @YES}];
    revenant_check((software != nil && revenant_renders_red(software)) != revenant_negative, "a context made with the software renderer option renders", @"the option context did not render");

    CIContext *again = [[CIContext alloc] initWithRevenantOptions:nil];
    revenant_check((again != plain) != revenant_negative, "each call gives its own context", @"two calls returned one object");

    __weak CIContext *weak = nil;
    @autoreleasepool {
        CIContext *scoped = [[CIContext alloc] initWithRevenantOptions:nil];
        weak = scoped;
    }
    revenant_check((weak == nil) != revenant_negative, "the initialiser returns one owned reference: dropping it frees the context", @"the context outlived its only owner");

    return revenant_finish();
}
