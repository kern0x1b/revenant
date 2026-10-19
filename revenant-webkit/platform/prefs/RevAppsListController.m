#import "RevPrefs.h"

static NSString *const kRevDomain = @"space.kern0x1b.rev";

@interface RevAppsListController : PSListController
@end

@implementation RevAppsListController

static NSArray *revListedApps(void) {
    NSMutableArray *out = [NSMutableArray array];
    [out addObject:@{ @"id": @"com.apple.mobilesafari", @"name": @"Safari", @"default": @YES }];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = @"/var/mobile/Applications";
    NSMutableArray *others = [NSMutableArray array];
    for (NSString *uuid in [fm contentsOfDirectoryAtPath:base error:NULL]) {
        NSString *dir = [base stringByAppendingPathComponent:uuid];
        for (NSString *item in [fm contentsOfDirectoryAtPath:dir error:NULL]) {
            if (![item hasSuffix:@".app"])
                continue;
            NSString *info = [[dir stringByAppendingPathComponent:item] stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:info];
            NSString *bid = [d objectForKey:@"CFBundleIdentifier"];
            NSString *name = [d objectForKey:@"CFBundleDisplayName"];
            if (![name isKindOfClass:[NSString class]] || name.length == 0)
                name = [d objectForKey:@"CFBundleName"];
            if (![name isKindOfClass:[NSString class]] || name.length == 0)
                name = [item stringByDeletingPathExtension];
            if (![bid isKindOfClass:[NSString class]] || bid.length == 0)
                continue;
            [others addObject:@{ @"id": bid, @"name": name, @"default": @NO }];
        }
    }
    [others sortUsingComparator:^NSComparisonResult(id a, id b) {
        return [[a objectForKey:@"name"] localizedCaseInsensitiveCompare:[b objectForKey:@"name"]];
    }];
    [out addObjectsFromArray:others];
    return out;
}

- (NSDictionary *)revInjectedApps {
    CFPreferencesAppSynchronize((CFStringRef)kRevDomain);
    CFPropertyListRef v = CFPreferencesCopyAppValue(CFSTR("InjectedApps"), (CFStringRef)kRevDomain);
    id value = [(id)v autorelease];
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

- (id)readInjection:(PSSpecifier *)spec {
    NSString *bid = [spec propertyForKey:@"revBundle"];
    id v = [[self revInjectedApps] objectForKey:bid];
    if (v)
        return v;
    return [spec propertyForKey:@"default"] ?: @NO;
}

- (void)setInjection:(id)value specifier:(PSSpecifier *)spec {
    NSString *bid = [spec propertyForKey:@"revBundle"];
    if (!bid)
        return;
    NSMutableDictionary *apps = [[[self revInjectedApps] mutableCopy] autorelease];
    [apps setObject:(value ?: @NO) forKey:bid];
    CFPreferencesSetAppValue(CFSTR("InjectedApps"), (CFTypeRef)apps, (CFStringRef)kRevDomain);
    CFPreferencesAppSynchronize((CFStringRef)kRevDomain);
}

- (NSArray *)specifiers {
    if (_specifiers)
        return _specifiers;
    NSMutableArray *s = [NSMutableArray array];

    PSSpecifier *g = [PSSpecifier groupSpecifierWithName:@"Apps"];
    [g setProperty:@"Turn the RevWebKit engine on or off per app. Respring after changing." forKey:@"footerText"];
    [s addObject:g];

    for (NSDictionary *app in revListedApps()) {
        PSSpecifier *sw = [PSSpecifier preferenceSpecifierNamed:[app objectForKey:@"name"]
                                                         target:self
                                                            set:@selector(setInjection:specifier:)
                                                            get:@selector(readInjection:)
                                                         detail:Nil
                                                           cell:PSSwitchCell
                                                           edit:Nil];
        [sw setProperty:[app objectForKey:@"id"] forKey:@"revBundle"];
        [sw setProperty:[app objectForKey:@"default"] forKey:@"default"];
        [s addObject:sw];
    }

    _specifiers = [s copy];
    return _specifiers;
}

- (NSString *)navigationTitle {
    return @"Per-App Injection";
}

@end
