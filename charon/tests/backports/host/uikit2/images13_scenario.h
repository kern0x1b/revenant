#import "uirest.h"

// Which side this binary drives. The recorder (images13_system.m) links no port object and leaves it NO; the
// test sets it YES before it runs the same scenario. One header, two spellings, and the comparison is between
// the port's answers and the system's - which is the only reason the port's names appear at all.
static BOOL ur_img_port_mode;

// A prefixed selector for the port's copy of a name, spelled the way prefix_selectors.py's prefixed() spells it,
// which is not simply "charonHost" in front of the name: an Objective-C family keyword keeps its own spelling and
// the prefix goes after it. None of the names this scenario sends begins with one, and the rule is here so that
// a name added later cannot be spelled wrongly.
static SEL ur_img_sel(const char *name)
{
    static const char *families[] = {"mutableCopy", "copy", "init", "new", "alloc"};
    if (!ur_img_port_mode)
        return sel_registerName(name);
    char renamed[256];
    for (size_t index = 0; index < sizeof(families) / sizeof(families[0]); index++) {
        size_t length = strlen(families[index]);
        if (strncmp(name, families[index], length) != 0)
            continue;
        char tail = name[length];
        if (tail == '\0' || (tail >= 'A' && tail <= 'Z')) {
            snprintf(renamed, sizeof(renamed), "%sCharonHost%s", families[index], name + length);
            return sel_registerName(renamed);
        }
    }
    snprintf(renamed, sizeof(renamed), "charonHost%c%s", name[0] - 32, name + 1);
    return sel_registerName(renamed);
}

// The port's members are asked by their own names on the port's side and the system's on the system's, which is
// what this differential is: the group's port sources add categories to UIImage and UIImageView, and on the
// prefixed path those categories carry prefixed selectors, so a send that reaches the port has to name one.
// Measured on this group, over the objects the prefixed build produces, the declarations header names 23 of them
// - charonHostImageWithTintColor:, charonHostHasBaseline, charonHostConfiguration, charonHostImageNamed:
// inBundle:withConfiguration:, charonHostCheckmarkImage and the rest - and a send left with the bare name
// reaches the system instead. That is not always harmless: with the port's symbol configuration in hand,
// -[UIImage imageWithConfiguration:] (the system's, iOS 17) completes it with
// +[UIImageConfiguration _completeConfiguration:fromConfiguration:], which sends _initWithConfiguration: to its
// argument, and the port's class does not answer that:
//   -[CharonHostUIImageSymbolConfiguration _initWithConfiguration:]: unrecognized selector.
// The two helpers below are the send shapes the scenario needs; the port's own classes (the renamed
// UIImageConfiguration and UIImageSymbolConfiguration) keep the plain names, which is why those sends are
// written as they are.
static id ur_img0(id receiver, const char *name)
{
    return ((id (*)(id, SEL))objc_msgSend)(receiver, ur_img_sel(name));
}

static id ur_img1(id receiver, const char *name, id first)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(receiver, ur_img_sel(name), first);
}

static id ur_imgd(id receiver, const char *name, double value)
{
    return ((id (*)(id, SEL, double))objc_msgSend)(receiver, ur_img_sel(name), value);
}

static id ur_img2(id receiver, const char *name, id first, long second)
{
    return ((id (*)(id, SEL, id, long))objc_msgSend)(receiver, ur_img_sel(name), first, second);
}

static id ur_img3(id receiver, const char *name, id first, id second, id third)
{
    return ((id (*)(id, SEL, id, id, id))objc_msgSend)(receiver, ur_img_sel(name), first, second, third);
}

// The two members whose answer is used as a number rather than as an object, which a send through a cast
// answers as `id`: -hasBaseline is a BOOL and -baselineOffsetFromBottom a CGFloat, and both are read often
// enough here to be worth naming.
static BOOL image_has_baseline(UIImage *image)
{
    return (BOOL)((long (*)(id, SEL))objc_msgSend)(image, ur_img_sel("hasBaseline"));
}

static CGFloat image_baseline_offset(UIImage *image)
{
    return (CGFloat)((double (*)(id, SEL))objc_msgSend)(image, ur_img_sel("baselineOffsetFromBottom"));
}

static NSString *pixels_of(UIImage *image)
{
    CGFloat scale = 2;
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(rendered.CGImage));
    const UInt8 *bytes = CFDataGetBytePtr(data);
    NSMutableString *text = [NSMutableString string];
    unsigned long long hash = 1469598103934665603ULL;
    NSUInteger nonzero = 0;
    for (CFIndex index = 0; index < CFDataGetLength(data); index++) {
        hash = (hash ^ bytes[index]) * 1099511628211ULL;
        nonzero += bytes[index] != 0;
    }
    [text appendFormat:@"%llx %lu", hash, (unsigned long)nonzero];
    CFRelease(data);
    return text;
}

static UIImage *source_image(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 10), NO, 2);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, 10, 5));
    [[[UIColor blackColor] colorWithAlphaComponent:0.5] setFill];
    UIRectFill(CGRectMake(0, 5, 5, 5));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static NSString *summary(id configuration)
{
    NSString *text = [NSString stringWithFormat:@"%@", configuration];
    NSRange traits = [text rangeOfString:@"traits=("];
    NSString *head = traits.location == NSNotFound ? text : [text substringToIndex:traits.location];
    NSString *scale = @"";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"DisplayScale = [0-9.]+" options:0 error:nil];
    NSTextCheckingResult *match = traits.location == NSNotFound ? nil : [expression firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match)
        scale = [text substringWithRange:match.range];
    return [NSString stringWithFormat:@"%@ [%@]", head, scale];
}

static NSArray *images_scenario(NSString *folder, Class symbolClass, Class configurationClass)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIImage *image = source_image();
    UIColor *red = [UIColor colorWithRed:1 green:0 blue:0 alpha:1], *blue = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.5];
    for (UIColor *color in @[red, blue, [UIColor clearColor], [UIColor whiteColor]]) {
        UIImage *tinted = ur_img1(image, "imageWithTintColor:", color);
        [lines addObject:ur_line(@"tinted", @[pixels_of(tinted), NSStringFromCGSize(tinted.size), @(tinted.scale), @(tinted.renderingMode)])];
        UIImage *template = ur_img2(image, "imageWithTintColor:renderingMode:", color, UIImageRenderingModeAlwaysTemplate);
        [lines addObject:ur_line(@"tinted template", @[NSStringFromCGSize(template.size), @(template.scale), @(template.renderingMode)])];
    }
    UIImage *tintedNil = ur_img1(image, "imageWithTintColor:", nil);
    [lines addObject:ur_line(@"tinted with nil", @[pixels_of(tintedNil), @(tintedNil.renderingMode)])];
    UIImage *resizable = [image resizableImageWithCapInsets:UIEdgeInsetsMake(2, 2, 2, 2) resizingMode:UIImageResizingModeTile];
    UIImage *resized = ur_img1(resizable, "imageWithTintColor:", red);
    [lines addObject:ur_line(@"tinted resizable image", @[NSStringFromUIEdgeInsets(resized.capInsets), @(resized.resizingMode)])];
    UIImage *aligned = [image imageWithAlignmentRectInsets:UIEdgeInsetsMake(1, 2, 3, 4)];
    UIImage *alignedTinted = ur_img1(aligned, "imageWithTintColor:", red);
    [lines addObject:ur_line(@"tinted aligned image", NSStringFromUIEdgeInsets(alignedTinted.alignmentRectInsets))];
    UIImage *emptyTinted = ur_img1([[UIImage alloc] init], "imageWithTintColor:", red);
    [lines addObject:ur_line(@"tinted empty image", @[NSStringFromCGSize(emptyTinted.size)])];

    [lines addObject:ur_line(@"baseline", @[ur_yes(image_has_baseline(image)), @(image_baseline_offset(image))])];
    // The argument is a CGFloat, so it goes as one: ur_img1 would pass the NSNumber's POINTER, and the method reads
    // that pointer's bits as the double it returns. Measured before this line was spelled correctly: the port
    // answered 1.976262583364986e-323 and the system 3.458459520888726e-323 - two denormals, each one a heap
    // address reinterpreted, and the whole scenario was reading the port's own arguments back.
    UIImage *based = ur_imgd(image, "imageWithBaselineOffsetFromBottom:", 3);
    [lines addObject:ur_line(@"with baseline", @[ur_yes(image_has_baseline(based)), @(image_baseline_offset(based)), NSStringFromCGSize(based.size), @(based.scale), ur_yes(based != image), ur_yes(image_has_baseline(image))])];
    UIImage *without = ur_img0(based, "imageWithoutBaseline");
    [lines addObject:ur_line(@"without baseline", @[ur_yes(image_has_baseline(without)), @(image_baseline_offset(without)), ur_yes(image_has_baseline(based))])];
    UIImage *basedTinted = ur_img1(based, "imageWithTintColor:", red);
    [lines addObject:ur_line(@"baseline kept by a tint", @[ur_yes(image_has_baseline(basedTinted)), @(image_baseline_offset(basedTinted))])];

    UIImageConfiguration *plain = ur_img0(image, "configuration");
    [lines addObject:ur_line(@"configuration", @[summary(plain)])];
    UIImageSymbolConfiguration *symbol = [symbolClass configurationWithPointSize:20];
    UIImage *configured = ur_img1(image, "imageWithConfiguration:", symbol);
    [lines addObject:ur_line(@"with a symbol configuration", @[summary(ur_img0(configured, "configuration")), ur_yes(ur_img0(configured, "symbolConfiguration") != nil), ur_yes(configured != image), ur_yes(ur_img0(configured, "isSymbolImage"))])];
    UIImageConfiguration *traits = [plain configurationWithTraitCollection:[UITraitCollection traitCollectionWithDisplayScale:3]];
    (void)configurationClass;
    UIImage *traited = ur_img1(image, "imageWithConfiguration:", traits);
    [lines addObject:ur_line(@"with a plain configuration", @[summary(ur_img0(traited, "configuration")), ur_yes(traited != image), NSStringFromCGSize(traited.size)])];

    NSBundle *bundle = [NSBundle bundleWithPath:folder];
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *name in @[@"logo", @"logo.png", @"missing", @"dot"]) {
        UIImage *named = ur_img3([UIImage class], "imageNamed:inBundle:withConfiguration:", name, bundle, nil);
        [found addObject:named ? [NSString stringWithFormat:@"%@ %@ %g", name, NSStringFromCGSize(named.size), named.scale] : [name stringByAppendingString:@" nil"]];
    }
    [lines addObject:ur_line(@"images of a bundle", found)];
    UIImage *withConfiguration = ur_img3([UIImage class], "imageNamed:inBundle:withConfiguration:", @"logo", bundle, symbol);
    [lines addObject:ur_line(@"image of a bundle with a configuration", @[summary(ur_img0(withConfiguration, "configuration"))])];

    NSMutableArray *system = [NSMutableArray array];
    for (UIImage *glyph in @[ur_img0([UIImage class], "checkmarkImage"), ur_img0([UIImage class], "strokedCheckmarkImage"), ur_img0([UIImage class], "addImage"), ur_img0([UIImage class], "removeImage"), ur_img0([UIImage class], "actionsImage")])
        [system addObject:[NSString stringWithFormat:@"%@ %g", NSStringFromCGSize(glyph.size), glyph.scale]];
    [lines addObject:ur_line(@"system images", system)];
    NSMutableArray *flat = [NSMutableArray array];
    for (NSString *entry in lines)
        [flat addObject:[entry stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return flat;
}

static NSString *make_bundle(void)
{
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-images13.bundle"];
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>local.charon.images13</string></dict></plist>" writeToFile:[folder stringByAppendingPathComponent:@"Info.plist"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 6), NO, 1);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, 8, 6));
    [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[folder stringByAppendingPathComponent:@"logo.png"] atomically:YES];
    UIGraphicsEndImageContext();
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 12), NO, 1);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, 16, 12));
    [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[folder stringByAppendingPathComponent:@"logo@2x.png"] atomically:YES];
    UIGraphicsEndImageContext();
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 4), NO, 1);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, 4, 4));
    [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[folder stringByAppendingPathComponent:@"dot.png"] atomically:YES];
    UIGraphicsEndImageContext();
    return folder;
}
