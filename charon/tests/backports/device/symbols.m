#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"
#import "symbols-expectations.h"

#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSData *archived(id object)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    archiver.requiresSecureCoding = YES;
    [archiver encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    return data;
}

static id unarchived(NSData *data, Class root)
{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    unarchiver.requiresSecureCoding = YES;
    id object = [unarchiver decodeObjectOfClass:root forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    return object;
}

static UIImage *bitmap(void)
{
    UIGraphicsBeginImageContext(CGSizeMake(4, 6));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static void run_checks(void)
{
    @autoreleasepool {
        for (NSString *name in @[@"UIImageConfiguration", @"UIImageSymbolConfiguration"]) {
            Class cls = NSClassFromString(name);
            CHECK(cls != Nil, NAMED(@"%@ is there", name));
            if (cls)
                CHECK_EQUAL(image_of((__bridge const void *)cls), @"libUIKitBackports.dylib", NAMED(@"%@ comes from the backports library", name));
        }
        CHECK([UIImageSymbolConfiguration superclass] == [UIImageConfiguration class], "the symbol configuration descends from the image configuration");
        for (NSString *name in @[@"UIImageSymbolWeightForFontWeight", @"UIFontWeightForImageSymbolWeight"]) {
            void *symbol = dlsym(RTLD_DEFAULT, name.UTF8String);
            CHECK(symbol != NULL, NAMED(@"%@ is there", name));
            CHECK_EQUAL(image_of(symbol), @"libUIKitBackports.dylib", NAMED(@"%@ comes from the backports library", name));
        }

        float boundaries[] = {-0.8f, -0.6f, -0.4f, 0, 0.23f, 0.3f, 0.4f, 0.56f, 0.62f};
        BOOL weights = YES;
        for (int index = 0; index < 9; index++)
            weights = weights && UIImageSymbolWeightForFontWeight(boundaries[index]) == index + 1 && UIFontWeightForImageSymbolWeight((UIImageSymbolWeight)(index + 1)) == boundaries[index]
                      && UIImageSymbolWeightForFontWeight(boundaries[index] == 0 ? -0.000001f : nextafterf(boundaries[index], -INFINITY)) == index;
        CHECK(weights, "the nine font weights are the boundaries of the nine symbol weights, and just below each the weight before");
        CHECK(UIImageSymbolWeightForFontWeight(-0.9) == UIImageSymbolWeightUnspecified && UIImageSymbolWeightForFontWeight(2) == UIImageSymbolWeightBlack && UIImageSymbolWeightForFontWeight(NAN) == UIImageSymbolWeightBlack,
              "below the lightest weight none is specified, and above the heaviest and for NaN it is black");
        CHECK(UIFontWeightForImageSymbolWeight(UIImageSymbolWeightUnspecified) == 0 && UIFontWeightForImageSymbolWeight((UIImageSymbolWeight)10) == 0, "an unspecified or unknown symbol weight is the regular font weight");

        UIImageSymbolConfiguration *unspecified = [UIImageSymbolConfiguration unspecifiedConfiguration];
        CHECK_EQUAL([unspecified description], @"unspecified", "the unspecified configuration says so");
        CHECK(unspecified == [UIImageSymbolConfiguration unspecifiedConfiguration] && unspecified.traitCollection == nil, "and is one object without traits");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithPointSize:12] description], @"pointSize=12", "a point size is described");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithPointSize:0] description], @"pointSize=17", "and a point size that is not above zero is the default of 17");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleLarge] description], @"pointSize=12, weight=Bold, scale=Large",
                    "with its weight and scale");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightUltraLight] description], @"weight=Ultra Light", "the lightest weight is Ultra Light");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault] description], @"scale=Default", "a scale is described");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleBody scale:UIImageSymbolScaleMedium] description], @"textStyle=UICTFontTextStyleBody, scale=Medium",
                    "a text style is described");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightUnspecified] description], @"unspecified", "an unspecified weight adds nothing");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithWeight:(UIImageSymbolWeight)42] description], @"weight=(null)", "and a weight that is none of the nine is kept and has no name");

        UIFont *regular = [UIFont systemFontOfSize:17], *bold = [UIFont boldSystemFontOfSize:17];
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithFont:regular] description], @"pointSize=17, weight=Regular", "a regular font gives its size and the regular weight");
        NSString *boldDescription = [[UIImageSymbolConfiguration configurationWithFont:bold scale:UIImageSymbolScaleSmall] description];
        CHECK(([boldDescription isEqualToString:@"pointSize=17, weight=Semibold, scale=Small"] || [boldDescription isEqualToString:@"pointSize=17, weight=Bold, scale=Small"]),
              "and a bold font a weight from Semibold up");
        CHECK_EQUAL([[UIImageSymbolConfiguration configurationWithFont:nil] description], @"pointSize=0, weight=Regular", "no font is a size of nothing");

        UIImageSymbolConfiguration *size = [UIImageSymbolConfiguration configurationWithPointSize:10];
        UIImageSymbolConfiguration *light = [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightLight];
        UIImageSymbolConfiguration *style = [UIImageSymbolConfiguration configurationWithTextStyle:@"UICTFontTextStyleTitle2"];
        CHECK_EQUAL([[size configurationByApplyingConfiguration:light] description], @"pointSize=10, weight=Light", "applying a weight keeps the size");
        CHECK_EQUAL([[size configurationByApplyingConfiguration:style] description], @"textStyle=UICTFontTextStyleTitle2", "a text style takes the place of a size");
        CHECK_EQUAL([[style configurationByApplyingConfiguration:size] description], @"pointSize=10", "and a size the place of a text style");
        CHECK_EQUAL([[[UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightThin] configurationByApplyingConfiguration:style] description],
                    @"textStyle=UICTFontTextStyleTitle2, weight=Thin", "a text style leaves the weight");
        CHECK([size configurationByApplyingConfiguration:nil] == size && [size configurationByApplyingConfiguration:unspecified] == size && [size configurationByApplyingConfiguration:size] == size,
              "applying nothing, the unspecified configuration or an equal one answers the same object");
        CHECK_EQUAL([[[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleLarge] configurationWithoutScale] description],
                    @"pointSize=20, weight=Bold", "without the scale");
        CHECK_EQUAL([[[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleLarge] configurationWithoutPointSizeAndWeight] description],
                    @"scale=Large", "without the size and weight");
        CHECK_EQUAL([[[UIImageSymbolConfiguration configurationWithTextStyle:@"UICTFontTextStyleTitle1" scale:UIImageSymbolScaleSmall] configurationWithoutTextStyle] description],
                    @"pointSize=28, scale=Small", "without the text style, the size of the style");
        CHECK([unspecified configurationWithoutScale] == unspecified && [size configurationWithoutWeight] == size, "removing what is not there answers the same object");

        UITraitCollection *display = [UITraitCollection traitCollectionWithDisplayScale:2];
        UIImageSymbolConfiguration *traits = [size configurationWithTraitCollection:display];
        CHECK_EQUAL([traits description], @"pointSize=10, traits=(DisplayScale = 2)", "the traits are described after the fields");
        CHECK([traits.traitCollection isEqual:display] && [traits configurationWithTraitCollection:display] == traits && [traits configurationWithTraitCollection:nil].traitCollection == nil,
              "a configuration keeps its traits and drops them with nil");
        UIImageConfiguration *plain = [[UIImageConfiguration alloc] performSelector:NSSelectorFromString(@"init")];
        CHECK_EQUAL([plain description], @"unspecified", "a plain image configuration is unspecified");
        CHECK_EQUAL([[[plain configurationWithTraitCollection:display] configurationByApplyingConfiguration:[plain configurationWithTraitCollection:
                       [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]]] description], @"traits=(DisplayScale = 2, UserInterfaceStyle = Dark)", "traits merge, the applied ones winning");
        CHECK_EQUAL([[size configurationByApplyingConfiguration:[plain configurationWithTraitCollection:display]] description], @"pointSize=10, traits=(DisplayScale = 2)",
                    "a symbol configuration takes the traits of a plain one");

        UIImageSymbolConfiguration *equal = [UIImageSymbolConfiguration configurationWithPointSize:10];
        CHECK([size isEqual:equal] && [size isEqualToConfiguration:equal] && size.hash == equal.hash && ![size isEqual:light] && ![size isEqual:traits] && ![size isEqualToConfiguration:nil] && [unspecified isEqualToConfiguration:nil],
              "configurations are equal by their values, and only the unspecified one equals nil");
        CHECK([size copy] != size && [[size copy] isEqual:size] && [[traits copy] isEqual:traits], "a copy is another object with the same values");

        for (UIImageSymbolConfiguration *config in @[unspecified, size, light, style, traits, [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleLarge]]) {
            UIImageSymbolConfiguration *back = unarchived(archived(config), [UIImageSymbolConfiguration class]);
            CHECK([back isEqual:config] && [[back description] isEqualToString:[config description]], NAMED(@"%@ survives secure coding", config));
        }
        UIImageConfiguration *plainBack = unarchived(archived([plain configurationWithTraitCollection:display]), [UIImageConfiguration class]);
        CHECK([plainBack.traitCollection isEqual:display], "and so do the traits of a plain configuration");

        UIImage *ordinary = bitmap();
        CHECK(ordinary.symbolConfiguration == nil && !ordinary.symbolImage, "an ordinary image has no symbol configuration and is not a symbol image");
        UIImage *applied = [ordinary imageByApplyingSymbolConfiguration:size];
        CHECK(applied != ordinary && applied.CGImage == ordinary.CGImage && CGSizeEqualToSize(applied.size, ordinary.size) && applied.scale == ordinary.scale,
              "applying a configuration gives another image of the same bitmap");
        CHECK([applied.symbolConfiguration.traitCollection isEqual:[UIScreen mainScreen].traitCollection] && !applied.symbolImage,
              "which holds the configuration over the traits of the screen and is still not a symbol image");
        CHECK_EQUAL([[applied imageByApplyingSymbolConfiguration:light].symbolConfiguration description],
                    [[[UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightLight] configurationWithTraitCollection:[UIScreen mainScreen].traitCollection] description],
                    "and a second one is applied over the first");
        CHECK([applied imageByApplyingSymbolConfiguration:nil] == applied && [ordinary imageByApplyingSymbolConfiguration:nil] != ordinary && [ordinary imageByApplyingSymbolConfiguration:nil].symbolConfiguration == nil,
              "applying nil keeps the image that has a configuration, and copies one that has none");

        CHECK([UIImage systemImageNamed:@"nonexistent.symbol.zz"] == nil && [UIImage systemImageNamed:@""] == nil && [UIImage systemImageNamed:nil] == nil, "a name that is not a symbol answers nil");
        UIImage *star = [UIImage systemImageNamed:@"star"];
        CHECK(star != nil && star.symbolImage && star.renderingMode == UIImageRenderingModeAlwaysTemplate && star.symbolConfiguration != nil && star.hasBaseline, "a symbol is drawn: a template symbol image with a configuration and a baseline");
        CHECK([UIImage systemImageNamed:@"star" compatibleWithTraitCollection:display] != nil && [UIImage systemImageNamed:@"star" withConfiguration:size] != nil, "in each of the three forms");
        UIImage *bigger = [star imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:60]];
        CHECK(bigger.size.width > star.size.width * 3 && bigger.symbolImage, "applying a point size draws the symbol again at that size");

        int mismatches = 0, insetMisses = 0, baselineMisses = 0, cellFailures = 0;
        NSMutableArray *worst = [NSMutableArray array];
        static const double configs[3][3] = {{17, 4, 2}, {34, 7, 3}, {12, 1, 1}};
        size_t count = sizeof CharonSymbolExpectations / sizeof CharonSymbolExpectations[0];
        for (size_t index = 0; index < count; index++) {
            NSString *name = @(CharonSymbolExpectations[index].name);
            for (int c = 0; c < 3; c++) {
                UIImage *image = [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:configs[c][0] weight:(UIImageSymbolWeight)configs[c][1] scale:(UIImageSymbolScale)configs[c][2]]];
                const float *want = CharonSymbolExpectations[index].metrics[c];
                if (!image || fabs(image.size.width - want[0]) > 1 || fabs(image.size.height - want[1]) > 1)
                    mismatches++;
                if (image) {
                    UIEdgeInsets insets = image.alignmentRectInsets;
                    if (fabs(insets.top - want[2]) > 1 || fabs(insets.left - want[3]) > 1 || fabs(insets.bottom - want[4]) > 1 || fabs(insets.right - want[5]) > 1)
                        insetMisses++;
                    if (fabs(image.baselineOffsetFromBottom - want[6]) > 1)
                        baselineMisses++;
                }
            }
            UIImage *image = [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium]];
            if (!image) {
                cellFailures++;
                continue;
            }
            size_t width = (size_t)ceil(image.size.width * 8), height = (size_t)ceil(image.size.height * 8);
            uint8_t *pixels = calloc(width * height, 1);
            CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
            UIGraphicsPushContext(context);
            CGContextTranslateCTM(context, 0, height);
            CGContextScaleCTM(context, 8, -8);
            [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
            UIGraphicsPopContext();
            CGContextRelease(context);
            int both = 0, either = 0;
            for (int gy = 0; gy < 16; gy++)
                for (int gx = 0; gx < 16; gx++) {
                    double sum = 0;
                    long cells = 0;
                    for (size_t y = gy * height / 16; y < (gy + 1) * height / 16; y++)
                        for (size_t x = gx * width / 16; x < (gx + 1) * width / 16; x++) {
                            sum += pixels[y * width + x];
                            cells++;
                        }
                    BOOL ours = cells && sum / cells >= 127.5, theirs = (CharonSymbolExpectations[index].grid[gy] >> (15 - gx)) & 1;
                    both += ours && theirs;
                    either += ours || theirs;
                }
            free(pixels);
            double overlap = either ? (double)both / either : 1;
            if (overlap < 0.35) {
                cellFailures++;
                if (worst.count < 6)
                    [worst addObject:[NSString stringWithFormat:@"%@ %.2f", name, overlap]];
            }
        }
        CHECK(count >= 500 && mismatches == 0, NAMED(@"every recorded symbol has the host's size at three configurations (%d beyond a point of %zu names)", mismatches, count));
        CHECK(insetMisses == 0 && baselineMisses == 0, NAMED(@"and its alignment insets and baseline (%d and %d beyond a point)", insetMisses, baselineMisses));
        CHECK(cellFailures <= (int)(count / 8), NAMED(@"and at 17 points a 16 by 16 grid that overlaps the host's by 0.35 for all but an eighth of them (%d do not; %@)", cellFailures, worst));

        UIImageView *view = [[UIImageView alloc] init];
        CHECK(view.preferredSymbolConfiguration == nil, "an image view has no preferred symbol configuration");
        view.preferredSymbolConfiguration = size;
        view.preferredSymbolConfiguration = equal;
        CHECK(view.preferredSymbolConfiguration == size, "an equal one leaves the first in place");
        view.preferredSymbolConfiguration = light;
        view.image = ordinary;
        CHECK(view.preferredSymbolConfiguration == light, "another replaces it, and the image does not touch it");
        view.preferredSymbolConfiguration = nil;
        CHECK(view.preferredSymbolConfiguration == nil, "and nil takes it away");
        UIImageView *symbolView = [[UIImageView alloc] init];
        symbolView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:40];
        symbolView.image = star;
        CHECK(symbolView.image.size.width > star.size.width * 2, "a symbol image put in a view with a preferred configuration is drawn at that size");
        symbolView.preferredSymbolConfiguration = nil;
        CHECK(symbolView.image.size.width <= star.size.width * 1.5, "and at its own again when the preferred configuration is taken away");

        CHECK([UIImageSymbolConfiguration respondsToSelector:@selector(configurationWithPaletteColors:)] == NO && [UIImageSymbolConfiguration respondsToSelector:@selector(configurationPreferringMulticolor)] == NO,
              "the members of later releases are not there");

    }
}

static NSString *const results_folder = @"/private/var/backports";

@interface CharonSymbolsDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonSymbolsDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"symbols.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)runAndReport
{
    @try {
        run_checks();
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"symbols.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonSymbolsDelegate");
    }
}
