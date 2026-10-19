// matrix.m - UIImageAsset's variant rule, one line per measurement, over every registration pair and every unregister.
//
// One source, built twice by run.sh: against Mac Catalyst's own UIKit, and against the port's UIImageAsset and
// UIFocusGuide compiled with their classes renamed, so both live in one process. The two outputs must be equal,
// line for line. Labels name the keys and the answers and never a class, so the two builds print the same text.
//
// Keys: fourteen registrable keys (trait collections over display scale, idiom, style and layout direction, and
// image configurations, which have no scale), two trait collections without a scale that are lookup-only, and two
// nil lookups. A variant is tagged 1..3 by its image width, 10 points per tag. An answer prints the tag it carries
// ("v1"; "v1*" when it is the registered object itself), "nil", or "w<width>@<scale>" for an image this run did not
// register.

#import <UIKit/UIKit.h>
#import <UIKit/UIImageConfiguration.h>
#import <UIKit/UIImageSymbolConfiguration.h>

#define NLABELS 18
#define NREG 14

static NSString *const kLabels[NLABELS] = {
    @"s1", @"s2", @"s3", @"s1-phone", @"s2-pad", @"s2-dark", @"s1-light", @"s3-rtl", @"s2-ltr", @"s2-pad-dark",
    @"bare-phone", @"bare-dark", @"c12", @"c99", @"cbold", @"cscale", @"nil-trait", @"nil-config",
};
// the keys an asset can register, in this order; 10 and 11 are the bare trait collections, which have no scale
static const int kReg[NREG] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 14, 15 };

static NSArray *KEYS;
static UIImage *tag_image[4];

static UITraitCollection *scale_of(CGFloat s) { return [UITraitCollection traitCollectionWithDisplayScale:s]; }
static UITraitCollection *idiom_of(UIUserInterfaceIdiom i) { return [UITraitCollection traitCollectionWithUserInterfaceIdiom:i]; }
static UITraitCollection *style_of(UIUserInterfaceStyle s) { return [UITraitCollection traitCollectionWithUserInterfaceStyle:s]; }
static UITraitCollection *dir_of(UITraitEnvironmentLayoutDirection d) { return [UITraitCollection traitCollectionWithLayoutDirection:d]; }
static UITraitCollection *both(UITraitCollection *a, UITraitCollection *b) { return [UITraitCollection traitCollectionWithTraitsFromCollections:@[ a, b ]]; }

static BOOL is_config(int i) { return i >= 12 && i <= 15; }

// a fresh object equal to KEYS[i]: the asset is asked with a copy as well as with the registered object
static id make_key(int i)
{
    switch (i) {
    case 0: return scale_of(1);
    case 1: return scale_of(2);
    case 2: return scale_of(3);
    case 3: return both(scale_of(1), idiom_of(UIUserInterfaceIdiomPhone));
    case 4: return both(scale_of(2), idiom_of(UIUserInterfaceIdiomPad));
    case 5: return both(scale_of(2), style_of(UIUserInterfaceStyleDark));
    case 6: return both(scale_of(1), style_of(UIUserInterfaceStyleLight));
    case 7: return both(scale_of(3), dir_of(UITraitEnvironmentLayoutDirectionRightToLeft));
    case 8: return both(scale_of(2), dir_of(UITraitEnvironmentLayoutDirectionLeftToRight));
    case 9: return both(both(scale_of(2), idiom_of(UIUserInterfaceIdiomPad)), style_of(UIUserInterfaceStyleDark));
    case 10: return idiom_of(UIUserInterfaceIdiomPhone);
    case 11: return style_of(UIUserInterfaceStyleDark);
    case 12: return [UIImageSymbolConfiguration configurationWithPointSize:12];
    case 13: return [UIImageSymbolConfiguration configurationWithPointSize:99];
    case 14: return [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightBold];
    case 15: return [UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge];
    }
    return nil;
}

static UIImage *tagged(int tag)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10.0 * tag, 1), NO, 1);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// The tag is read from the pixel width, so a variant handed back at another scale still names its variant.
// "*" marks the registered object itself; without it the system answered a copy.
static NSString *tag_of(UIImage *image)
{
    if (!image)
        return @"nil";
    for (int t = 1; t <= 3; t++) {
        if (fabs(image.size.width * image.scale - 10.0 * t) < 0.001)
            return [NSString stringWithFormat:@"v%d@%.0f%@", t, image.scale, image == tag_image[t] ? @"*" : @""];
    }
    return [NSString stringWithFormat:@"w%.1f@%.1f", image.size.width, image.scale];
}

// copy: ask with a fresh equal key instead of the registered object
static UIImage *lookup(UIImageAsset *asset, int i, BOOL copy)
{
    if (i == 16)
        return [asset imageWithTraitCollection:nil];
    if (i == 17)
        return [asset imageWithConfiguration:nil];
    if (is_config(i))
        return [asset imageWithConfiguration:copy ? make_key(i) : KEYS[i]];
    return [asset imageWithTraitCollection:copy ? make_key(i) : KEYS[i]];
}

static void reg(UIImageAsset *asset, int i, int tag)
{
    if (is_config(i))
        [asset registerImage:tag_image[tag] withConfiguration:KEYS[i]];
    else
        [asset registerImage:tag_image[tag] withTraitCollection:KEYS[i]];
}

static void unreg(UIImageAsset *asset, int i)
{
    if (i == 16)
        [asset unregisterImageWithTraitCollection:nil];
    else if (i == 17)
        [asset unregisterImageWithConfiguration:nil];
    else if (is_config(i))
        [asset unregisterImageWithConfiguration:KEYS[i]];
    else
        [asset unregisterImageWithTraitCollection:KEYS[i]];
}

static void print_lookups(UIImageAsset *asset, NSString *prefix)
{
    for (int j = 0; j < NLABELS; j++)
        printf("%s | %s = %s\n", prefix.UTF8String, kLabels[j].UTF8String, tag_of(lookup(asset, j, NO)).UTF8String);
}

static void attempt(NSString *label, void (^block)(void))
{
    @try {
        block();
        printf("err %s = none\n", label.UTF8String);
    } @catch (NSException *e) {
        printf("err %s = %s: %s\n", label.UTF8String, e.name.UTF8String, e.reason.UTF8String);
    }
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        for (int t = 1; t <= 3; t++)
            tag_image[t] = tagged(t);
        // indices 16 and 17 are the nil lookups, which never read KEYS; NSNull holds their places
        NSMutableArray *keys = [NSMutableArray array];
        for (int i = 0; i < NLABELS - 2; i++)
            [keys addObject:make_key(i)];
        KEYS = [keys arrayByAddingObjectsFromArray:@[ [NSNull null], [NSNull null] ]];

        // the fresh asset, and each key alone, with a copy of the key asked as well
        UIImageAsset *fresh = [[UIImageAsset alloc] init];
        print_lookups(fresh, @"fresh");
        for (int k = 0; k < NREG; k++) {
            int i = kReg[k];
            UIImageAsset *asset = [[UIImageAsset alloc] init];
            reg(asset, i, 1);
            NSString *prefix = [NSString stringWithFormat:@"single %@", kLabels[i]];
            print_lookups(asset, prefix);
            printf("%s | copy of %s = %s\n", prefix.UTF8String, kLabels[i].UTF8String, tag_of(lookup(asset, i, YES)).UTF8String);
        }

        // every ordered pair of registrable keys: the first registered is variant 1, the second variant 2
        for (int a = 0; a < NREG; a++) {
            for (int b = 0; b < NREG; b++) {
                if (a == b)
                    continue;
                UIImageAsset *asset = [[UIImageAsset alloc] init];
                reg(asset, kReg[a], 1);
                reg(asset, kReg[b], 2);
                print_lookups(asset, [NSString stringWithFormat:@"pair %@,%@", kLabels[kReg[a]], kLabels[kReg[b]]]);
            }
        }

        // the unregister of every key, over one key alone and over every ordered pair, each lookup printed
        for (int k = 0; k < NREG; k++) {
            for (int u = 0; u < NLABELS; u++) {
                UIImageAsset *asset = [[UIImageAsset alloc] init];
                reg(asset, kReg[k], 1);
                unreg(asset, u);
                print_lookups(asset, [NSString stringWithFormat:@"single %@ unreg %@", kLabels[kReg[k]], kLabels[u]]);
            }
        }
        for (int a = 0; a < NREG; a++) {
            for (int b = 0; b < NREG; b++) {
                if (a == b)
                    continue;
                for (int u = 0; u < NLABELS; u++) {
                    UIImageAsset *asset = [[UIImageAsset alloc] init];
                    reg(asset, kReg[a], 1);
                    reg(asset, kReg[b], 2);
                    unreg(asset, u);
                    print_lookups(asset, [NSString stringWithFormat:@"pair %@,%@ unreg %@", kLabels[kReg[a]], kLabels[kReg[b]], kLabels[u]]);
                }
            }
        }

        // the refusals and the nil cases, each on its own asset
        attempt(@"reg bare-phone (no scale)", ^{ UIImageAsset *x = [[UIImageAsset alloc] init]; reg(x, 10, 1); });
        attempt(@"reg bare-dark (no scale)", ^{ UIImageAsset *x = [[UIImageAsset alloc] init]; reg(x, 11, 1); });
        attempt(@"reg scale 0", ^{ UIImageAsset *x = [[UIImageAsset alloc] init]; [x registerImage:tag_image[1] withTraitCollection:scale_of(0)]; });
        attempt(@"reg scale -1", ^{ UIImageAsset *x = [[UIImageAsset alloc] init]; [x registerImage:tag_image[1] withTraitCollection:scale_of(-1)]; });
        attempt(@"reg nil trait", ^{ UIImageAsset *x = [[UIImageAsset alloc] init]; [x registerImage:tag_image[1] withTraitCollection:nil]; });
        attempt(@"reg nil config", ^{ UIImageAsset *x = [[UIImageAsset alloc] init]; [x registerImage:tag_image[1] withConfiguration:nil]; });
        attempt(@"reg nil image at s1", ^{
            UIImageAsset *x = [[UIImageAsset alloc] init];
            [x registerImage:nil withTraitCollection:KEYS[0]];
            printf("err nil-image-alone | s1 = %s\n", tag_of(lookup(x, 0, NO)).UTF8String);
        });
        attempt(@"reg nil image after s1", ^{
            UIImageAsset *x = [[UIImageAsset alloc] init];
            reg(x, 0, 1);
            [x registerImage:nil withTraitCollection:KEYS[0]];
            print_lookups(x, @"nil-image-over-s1");
        });
        attempt(@"reg nil image at config", ^{
            UIImageAsset *x = [[UIImageAsset alloc] init];
            [x registerImage:nil withConfiguration:KEYS[12]];
            print_lookups(x, @"nil-image-config-alone");
        });
        attempt(@"unreg nil on empty", ^{ UIImageAsset *x = [[UIImageAsset alloc] init]; unreg(x, 16); unreg(x, 17); print_lookups(x, @"empty-unreg-nil"); });

        // UIFocusGuide's defaults and its setters, read back
        UIFocusGuide *guide = [[UIFocusGuide alloc] init];
        printf("focus is a layout guide = %s\n", [guide isKindOfClass:[UILayoutGuide class]] ? "yes" : "no");
        printf("focus enabled = %s\n", guide.enabled ? "yes" : "no");
        printf("focus preferredFocusedView = %s\n", guide.preferredFocusedView ? "set" : "nil");
        printf("focus preferredFocusEnvironments = %s count %lu\n", guide.preferredFocusEnvironments ? "array" : "nil",
               (unsigned long)guide.preferredFocusEnvironments.count);
        guide.enabled = NO;
        printf("focus enabled after NO = %s\n", guide.enabled ? "yes" : "no");
        UIView *view = [[UIView alloc] init];
        guide.preferredFocusedView = view;
        printf("focus preferredFocusedView after set = %s\n", guide.preferredFocusedView == view ? "same" : "other");
        guide.preferredFocusEnvironments = @[ view ];
        printf("focus preferredFocusEnvironments after set = count %lu, first %s\n",
               (unsigned long)guide.preferredFocusEnvironments.count,
               guide.preferredFocusEnvironments.firstObject == view ? "same" : "other");
    }
    return 0;
}
