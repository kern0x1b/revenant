#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <notify.h>

static NSString *const revenant_alticon_folder = @"/var/mobile/Library/Caches/org.revenant.alticon";
static NSString *const revenant_alticon_key = @"CFBundleAlternateIconName";
static const char *const revenant_alticon_changed = "org.revenant.alticon.changed";

static IMP revenant_alticon_original_load;
static NSMutableDictionary *revenant_alticon_known;

static NSString *revenant_alticon_state_file(NSString *identifier)
{
    return [revenant_alticon_folder stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:@"plist"]];
}

static NSString *revenant_alticon_chosen(NSString *identifier)
{
    return [NSDictionary dictionaryWithContentsOfFile:revenant_alticon_state_file(identifier)][revenant_alticon_key];
}

static NSString *revenant_alticon_bundle_path(NSString *identifier)
{
    Class controller = objc_getClass("SBApplicationController");
    if (!controller)
        return nil;
    id shared = [controller performSelector:NSSelectorFromString(@"sharedInstance")];
    NSArray *applications = [shared performSelector:NSSelectorFromString(@"applicationsWithBundleIdentifier:") withObject:identifier];
    return [applications.lastObject performSelector:NSSelectorFromString(@"path")];
}

static NSDictionary *revenant_alticon_declared(NSString *bundlePath, NSString *name)
{
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *key = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"CFBundleIcons~ipad" : @"CFBundleIcons";
    NSDictionary *primary = info[key];
    NSDictionary *icons = [primary isKindOfClass:[NSDictionary class]] ? primary[@"CFBundleAlternateIcons"] : nil;
    NSDictionary *icon = [icons isKindOfClass:[NSDictionary class]] ? icons[name] : nil;
    return [icon isKindOfClass:[NSDictionary class]] ? icon : nil;
}

static UIImage *revenant_alticon_image(NSString *identifier, float scale)
{
    NSString *name = revenant_alticon_chosen(identifier);
    if (!name.length)
        return nil;
    NSString *bundlePath = revenant_alticon_bundle_path(identifier);
    if (!bundlePath)
        return nil;
    NSArray *files = [revenant_alticon_declared(bundlePath, name) objectForKey:@"CFBundleIconFiles"];
    for (NSString *file in files) {
        NSString *extension = [file pathExtension].length ? [file pathExtension] : @"png";
        NSString *stem = [file stringByDeletingPathExtension];
        NSMutableArray *candidates = [NSMutableArray array];
        if (scale >= 2)
            [candidates addObject:[NSString stringWithFormat:@"%@@2x.%@", stem, extension]];
        [candidates addObject:[NSString stringWithFormat:@"%@.%@", stem, extension]];
        for (NSString *candidate in candidates) {
            NSString *path = [bundlePath stringByAppendingPathComponent:candidate];
            UIImage *image = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [UIImage imageWithContentsOfFile:path] : nil;
            if (image)
                return image;
        }
    }
    return nil;
}

static CGSize revenant_alticon_pixels(UIImage *image)
{
    return CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
}

static UIImage *revenant_alticon_load(id self, SEL _cmd, id identifier, int format, float scale)
{
    UIImage *original = ((UIImage *(*)(id, SEL, id, int, float))revenant_alticon_original_load)(self, _cmd, identifier, format, scale);
    UIImage *alternate = [identifier isKindOfClass:[NSString class]] ? revenant_alticon_image(identifier, scale) : nil;
    if (alternate && original && CGSizeEqualToSize(revenant_alticon_pixels(alternate), revenant_alticon_pixels(original)))
        return alternate;
    return original;
}

static NSString *revenant_alticon_display_name(NSString *identifier)
{
    NSString *bundlePath = revenant_alticon_bundle_path(identifier);
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]];
    return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: identifier;
}

static void revenant_alticon_reload(NSString *identifier)
{
    Class model = objc_getClass("SBIconModel");
    if (!model)
        return;
    id shared = [model performSelector:NSSelectorFromString(@"sharedInstance")];
    for (id icon in [shared performSelector:NSSelectorFromString(@"leafIcons")]) {
        if (![[icon performSelector:NSSelectorFromString(@"applicationBundleID")] isEqual:identifier])
            continue;
        if ([icon respondsToSelector:NSSelectorFromString(@"reloadIconImage")])
            [icon performSelector:NSSelectorFromString(@"reloadIconImage")];
    }
}

static void revenant_alticon_changed_handler(void)
{
    NSArray *states = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:revenant_alticon_folder error:NULL];
    for (NSString *file in states) {
        NSString *identifier = [file stringByDeletingPathExtension];
        NSString *chosen = revenant_alticon_chosen(identifier);
        NSString *previous = revenant_alticon_known[identifier];
        if ([chosen isEqual:previous] || (!chosen && !previous))
            continue;
        revenant_alticon_known[identifier] = chosen ?: @"";
        revenant_alticon_reload(identifier);
        NSString *name = chosen ?: @"";
        NSString *message = [NSString stringWithFormat:@"You have changed the icon for “%@” to “%@”.", revenant_alticon_display_name(identifier), name];
        [[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }
}

__attribute__((constructor))
static void revenant_alticon_load_tweak(void)
{
    revenant_alticon_known = [NSMutableDictionary dictionary];
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:revenant_alticon_folder error:NULL]) {
        NSString *identifier = [file stringByDeletingPathExtension];
        revenant_alticon_known[identifier] = revenant_alticon_chosen(identifier) ?: @"";
    }
    Class icon = objc_getClass("SBApplicationIcon");
    Method load = icon ? class_getInstanceMethod(icon, NSSelectorFromString(@"__loadIconImage:format:scale:")) : NULL;
    if (load)
        revenant_alticon_original_load = method_setImplementation(load, (IMP)revenant_alticon_load);
    static int token = NOTIFY_TOKEN_INVALID;
    notify_register_dispatch(revenant_alticon_changed, &token, dispatch_get_main_queue(), ^(int registered) {
        (void)registered;
        revenant_alticon_changed_handler();
    });
}
