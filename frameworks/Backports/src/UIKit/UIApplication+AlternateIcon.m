#import <UIKit/UIKit.h>
#include <notify.h>

static NSString *const revenant_alternate_icon_folder = @"/var/mobile/Library/Caches/org.revenant.alticon";
static NSString *const revenant_alternate_icon_key = @"CFBundleAlternateIconName";
static const char *const revenant_alternate_icon_changed = "org.revenant.alticon.changed";
static NSString *const revenant_alternate_icon_tweak = @"/Library/MobileSubstrate/DynamicLibraries/revenant-alticon.dylib";

static BOOL revenant_alternate_icon_tweak_installed(void)
{
    return [[NSFileManager defaultManager] fileExistsAtPath:revenant_alternate_icon_tweak];
}

static NSDictionary *revenant_alternate_icons(void)
{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *key = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"CFBundleIcons~ipad" : @"CFBundleIcons";
    NSDictionary *primary = info[key];
    NSDictionary *icons = [primary isKindOfClass:[NSDictionary class]] ? primary[@"CFBundleAlternateIcons"] : nil;
    return [icons isKindOfClass:[NSDictionary class]] ? icons : nil;
}

static NSString *revenant_alternate_icon_file(void)
{
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    return [revenant_alternate_icon_folder stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:@"plist"]];
}

static BOOL revenant_alternate_icon_declared(NSString *name)
{
    return [revenant_alternate_icons()[name] isKindOfClass:[NSDictionary class]];
}

static NSError *revenant_alternate_icon_error(NSString *description)
{
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@implementation UIApplication (RevenantAlternateIcon)

- (BOOL)supportsAlternateIcons
{
    return revenant_alternate_icons() != nil && revenant_alternate_icon_tweak_installed();
}

- (NSString *)alternateIconName
{
    if (![self supportsAlternateIcons])
        return nil;
    NSString *name = [NSDictionary dictionaryWithContentsOfFile:revenant_alternate_icon_file()][revenant_alternate_icon_key];
    return name.length && revenant_alternate_icon_declared(name) ? name : nil;
}

- (void)setAlternateIconName:(NSString *)alternateIconName completionHandler:(void (^)(NSError *))completionHandler
{
    NSError *error = nil;
    if (![self supportsAlternateIcons]) {
        error = revenant_alternate_icon_error(@"The requested operation couldn’t be completed because the feature is not supported.");
    } else if (alternateIconName.length && !revenant_alternate_icon_declared(alternateIconName)) {
        error = revenant_alternate_icon_error(@"The requested operation couldn’t be completed because the alternate icon is not declared.");
    } else {
        NSString *file = revenant_alternate_icon_file();
        if (alternateIconName.length) {
            NSFileManager *manager = [NSFileManager defaultManager];
            BOOL folderReady = [manager createDirectoryAtPath:revenant_alternate_icon_folder withIntermediateDirectories:YES
                                                   attributes:@{NSFilePosixPermissions: @(0700)} error:NULL]
                && [manager setAttributes:@{NSFilePosixPermissions: @(0700)} ofItemAtPath:revenant_alternate_icon_folder error:NULL];
            NSDictionary *state = @{revenant_alternate_icon_key: alternateIconName};
            if (!folderReady || ![state writeToFile:file atomically:YES])
                error = revenant_alternate_icon_error(@"The requested operation couldn’t be completed because the icon state could not be saved.");
        } else {
            [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
        }
        if (!error)
            notify_post(revenant_alternate_icon_changed);
    }
    if (!completionHandler)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(error);
    });
}

@end
