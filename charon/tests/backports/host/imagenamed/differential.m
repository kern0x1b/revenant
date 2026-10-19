#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "../../device/imagenamed-cases.h"

void host_attach_prefixed(const char *prefix);

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static UIImage *lookup(NSString *name, NSBundle *bundle, UITraitCollection *traits, BOOL ours)
{
    if (!ours)
        return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:traits];
    return ((UIImage * (*)(id, SEL, id, id, id))objc_msgSend)([UIImage class], NSSelectorFromString(@"charonHost_imageNamed:inBundle:compatibleWithTraitCollection:"), name, bundle, traits);
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        NSBundle *bundle = imagenamed_bundle();
        NSArray *names = IMAGENAMED_NAMES;
        NSMutableString *header = [NSMutableString stringWithString:@"static const char *const imagenamed_expectations[] = {\n"];
        NSMutableArray *traits = [NSMutableArray arrayWithObject:[NSNull null]];
        for (NSNumber *scale in IMAGENAMED_SCALES)
            for (NSNumber *idiom in IMAGENAMED_IDIOMS)
                [traits addObject:[UITraitCollection traitCollectionWithTraitsFromCollections:@[
                    [UITraitCollection traitCollectionWithDisplayScale:scale.doubleValue],
                    [UITraitCollection traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom.integerValue]]]];
        [traits addObject:[UITraitCollection traitCollectionWithDisplayScale:2]];
        [traits addObject:[UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad]];
        for (NSString *name in names) {
            for (id entry in traits) {
                UITraitCollection *collection = [entry isKindOfClass:[NSNull class]] ? nil : entry;
                NSString *label = [NSString stringWithFormat:@"%@ under %@", name.length ? name : @"(empty)", collection ? collection.description : @"no traits"];
                NSString *system = imagenamed_describe(lookup(name, bundle, collection, NO));
                compare(label, system, imagenamed_describe(lookup(name, bundle, collection, YES)));
                if (traits.count > 1 && [traits indexOfObject:entry] >= 1 && [traits indexOfObject:entry] <= 6)
                    [header appendFormat:@"    \"%@\",\n", system];
            }
        }
        compare(@"nil name", imagenamed_describe(lookup(nil, bundle, nil, NO)), imagenamed_describe(lookup(nil, bundle, nil, YES)));
        compare(@"a bundle of no images", imagenamed_describe(lookup(@"plain", [NSBundle bundleWithPath:NSTemporaryDirectory()], nil, NO)),
                imagenamed_describe(lookup(@"plain", [NSBundle bundleWithPath:NSTemporaryDirectory()], nil, YES)));
        [header appendString:@"};\n"];
        if (!failures && getenv("IMAGENAMED_EXPECTATIONS"))
            [header writeToFile:@(getenv("IMAGENAMED_EXPECTATIONS")) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("checks=%d failures=%d\n", checks, failures);
        return failures;
    }
}
